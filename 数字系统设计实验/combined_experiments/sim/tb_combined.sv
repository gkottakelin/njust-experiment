`timescale 1ns / 1fs
module tb_combined;
    localparam real REFERENCE=99999505.0;
    localparam real HALF_CLOCK=500000000.0/REFERENCE;
    // Schedule absolute ideal edge times so 1 fs quantization does not accumulate
    // into a false 1 kHz divider error when REFERENCE changes by only a few Hz.
    reg clk=0;
    integer clock_edge_number=0;
    initial forever begin
        clock_edge_number=clock_edge_number+1;
        #(clock_edge_number*HALF_CLOCK-$realtime)clk=~clk;
    end
    reg sys_rst_n=0,rst=0;
    reg [7:0] sw=0;
    reg [7:0] dip=0;
    reg [9:0] ad_in=512;
    wire adc_clk,dac_clk,fast,slow;
    wire [7:0] dac,cs,seg0,seg1;
    // The separate frontend/precision suites cover 100 Hz and the production
    // 0.8 s gate. Use a 0.2 ms gate here to exercise the full FIR path quickly.
    combined_experiments_top #(.GATE_TICKS(20000),.TIMEOUT_TICKS(4000000),.WARMUP_SAMPLES(1000),
        .SCAN_SLOT_CYCLES(40),.MODE_DEBOUNCE_CYCLES(200)) dut(
        .clk_in(clk),.sys_rst_n(sys_rst_n),.rst(rst),.sw(sw),.dip(dip),.ad_in(ad_in),
        .clk_ad(adc_clk),.clk_da(dac_clk),.dac_data(dac),.clk_10mhz(fast),.clk_1khz(slow),
        .seg_cs_pin(cs),.seg_data_0_pin(seg0),.seg_data_1_pin(seg1));
    real phase=0,input_frequency=0,amplitude=0,bias=512;
    integer code,next_code,pipe0=512,pipe1=512,pipe2=512;
    always @(negedge adc_clk)begin
        code=$rtoi($floor(bias+amplitude*$sin(phase)+0.5));
        if(code<0 || code>1023)$fatal(1,"ADC model clipped");
        phase=phase+6.283185307179586*input_frequency/(REFERENCE/10);
        if(phase>=6.283185307179586)phase=phase-6.283185307179586;
        next_code=pipe2;pipe2=pipe1;pipe1=pipe0;pipe0=code;
        #25;ad_in=next_code;
    end
    integer reset_assertions=0,mode_changes=0,system_cycles=0,last_interp=-1;
    always @(negedge dut.rst_n)reset_assertions=reset_assertions+1;
    always @(posedge clk)begin
        system_cycles<=system_cycles+1;
        if(dut.rst_n)begin
            if(dut.overrun_5a || dut.overrun_5b)
                $fatal(1,"Continuous processing overrun/cadence error during mode switch");
            if(dut.mode_changed)mode_changes=mode_changes+1;
        end
    end
    always @(posedge dut.translated_valid)if(dut.rst_n)begin
        #0.001;
        if(last_interp>=0 && system_cycles-last_interp!=10)$fatal(1,"Mode switch disturbed full-rate FIR cadence");
        last_interp=system_cycles;
    end
    real last_fast=0,last_slow=0,last_data_change=0,difference;
    integer fast_halves=0,slow_halves=0;
    always @(fast)if(dut.rst_n)begin
        if(last_fast!=0)begin
            difference=$realtime-last_fast-10*HALF_CLOCK;
            if(difference>0.001 || difference< -0.001)$fatal(1,"10 MHz divider duty/period error");
            fast_halves=fast_halves+1;
        end
        last_fast=$realtime;
    end
    always @(slow)if(dut.rst_n)begin
        if(last_slow!=0)begin
            difference=$realtime-last_slow-100000*HALF_CLOCK;
            if(difference>0.001 || difference< -0.001)$fatal(1,"1 kHz divider duty/period error");
            slow_halves=slow_halves+1;
        end
        last_slow=$realtime;
    end
    always @(dac)if(dut.rst_n)begin
        last_data_change=$realtime;
        #0.001;
        if(dut.u_sampling.phase!=1)$fatal(1,"Physical DAC data changed outside its falling-edge update");
    end
    always @(posedge dac_clk)if(dut.rst_n)begin
        #0.001;
        if(adc_clk!==1 || fast!==1)$fatal(1,"Shared 10 MHz clocks diverged");
        if(last_data_change>0 && $realtime-last_data_change<49.99)$fatal(1,"DAC setup lead below 50 ns");
    end
    reg [7:0] last_cs=0;
    always @(negedge clk)if(dut.rst_n)begin
        if((cs&(cs-1'b1))!=0)$fatal(1,"Display enables more than one digit");
        if(cs!=0 && last_cs!=0 && cs!=last_cs)$fatal(1,"Display missing blanking interval");
        last_cs=cs;
    end
    function automatic [6:0] segments(input [3:0] c);
        case(c)
            0:segments=7'h3f;1:segments=7'h06;2:segments=7'h5b;3:segments=7'h4f;4:segments=7'h66;
            5:segments=7'h6d;6:segments=7'h7d;7:segments=7'h07;8:segments=7'h7f;9:segments=7'h6f;
            10:segments=7'h08;default:segments=7'h40;
        endcase
    endfunction
    function automatic [31:0] bcd_value(input integer value);
        integer v,i;
        begin v=value;for(i=0;i<8;i=i+1)begin bcd_value[4*i+:4]=v%10;v=v/10;end end
    endfunction
    task automatic set_mode(input [7:0] m);
        begin
            dip=m;wait(dut.active_mode==m);
            #22000;
            if(dut.mute_count!=0)$fatal(1,"Mode output did not settle");
            if(reset_assertions!=1)$fatal(1,"An additional global reset occurred during mode switch");
        end
    endtask
    task automatic check_display(input [31:0] digits,input [7:0] dots);
        integer i;
        reg [7:0] expected;
        begin
            repeat(1000)@(negedge clk);
            wait(cs==0);wait(cs==1);
            for(i=0;i<8;i=i+1)begin
                wait(cs==(8'b1<<i));#0.001;
                expected={dots[i],segments((digits>>((7-i)*4))&15)};
                if(i<4)begin if(seg0!==expected || seg1!==0)$fatal(1,"Left digit/dot mismatch");end
                else if(seg1!==expected || seg0!==0)$fatal(1,"Right digit/dot mismatch");
                wait(cs==0);
            end
        end
    endtask
    reg collecting=0;
    integer file_handle,case_index=0,output_count=0;
    always @(posedge dac_clk)if(collecting)begin
        $fdisplay(file_handle,"%0.6f,%0d",$realtime,dac);output_count=output_count+1;
    end
    task automatic capture(input integer duration_ns);
        begin
            case_index=case_index+1;output_count=0;
            file_handle=$fopen($sformatf("combined_case_%0d.csv",case_index),"w");
            if(!file_handle)$fatal(1,"Cannot open DAC sample record");
            $fdisplay(file_handle,"time_ns,dac_code");
            collecting=1;#(duration_ns);collecting=0;$fclose(file_handle);
            if(output_count<5000)$fatal(1,"Insufficient full-rate DAC samples");
        end
    endtask
    task automatic dds_case(input [7:0] k);
        begin
            sw=k;set_mode(8'h04);#100000;
            check_display(bcd_value((k*78125+1)>>1),8'h10);
            capture(600000);
            $display("COMBINED_DDS: K=%0d nominal_hz=%0d case=%0d",k,(k*78125+1)>>1,case_index);
        end
    endtask
    task automatic shift_case(input [7:0] m,input real f,input real a,input real b,input integer duration_ns);
        real err;
        begin
            // Drain the 409.6 us DC estimator after changing the ADC offset.
            input_frequency=f;amplitude=a;bias=b;set_mode(m);#3000000;
            if(!dut.measurement_valid)$fatal(1,"ADC measurement unavailable after changing mode/input");
            err=dut.frequency_hz-f;if(err<0)err=-err;
            if(err>600)$fatal(1,"Short-window ADC integration reading out of range");
            capture(duration_ns);
            $display("COMBINED_SHIFT: mode=%0d fin=%f measured=%0d case=%0d",m,f,dut.frequency_hz,case_index);
        end
    endtask
    integer k,mode_code;
    real measure_error;
    initial begin
        #40;sys_rst_n=1;
        #100000;
        check_display(32'h12345678,8'h00);
        if(dac!=128)$fatal(1,"Pattern mode must idle DAC at midpoint");
        set_mode(8'h02);check_display(32'h2610a652,8'h02);
        // All 256 DDS setting displays without another reset.
        set_mode(8'h04);
        for(k=0;k<256;k=k+1)begin
            sw=k;repeat(200)@(negedge clk);#0.001;
            if(dut.dds_bcd!==bcd_value((k*78125+1)>>1))$fatal(1,"DDS BCD error for K=%0d",k);
        end
        // Exhaust all eight DIP bits. Invalid codes must not alias a valid mode.
        sw=11;repeat(200)@(negedge clk);
        for(mode_code=0;mode_code<256;mode_code=mode_code+1)begin
            set_mode(mode_code);
            case(mode_code)
                0:check_display(32'h12345678,8'h00);
                2:check_display(32'h2610a652,8'h02);
                4:check_display(bcd_value((11*78125+1)>>1),8'h10);
                8,16,17:check_display(32'hffffffff,0);
                default:begin
                    repeat(400)@(negedge clk);
                    if(cs!=0)$fatal(1,"Divider/invalid DIP code did not blank display: %0h",mode_code);
                end
            endcase
            if(mode_code!=4 && dac!=128)$fatal(1,"Idle/zero-input mode produced an unexpected DAC signal");
        end
        set_mode(8'h00);
        // A sub-debounce pulse must not switch the global function.
        dip=8'h11;repeat(20)@(negedge clk);dip=0;repeat(500)@(negedge clk);
        if(dut.active_mode!=0)$fatal(1,"Mode debounce accepted a short pulse");
        dds_case(1);dds_case(16);dds_case(64);dds_case(11);
        set_mode(8'h08);check_display(32'hffffffff,0);
        if(dac!=128)$fatal(1,"Frequency-meter mode must idle the DAC at midpoint");
        input_frequency=10000.0;amplitude=64;bias=717;#3000000;
        if(!dut.measurement_valid)$fatal(1,"No frontend frequency result");
        measure_error=dut.frequency_hz-10000.0;if(measure_error<0)measure_error=-measure_error;
        if(measure_error>100)$fatal(1,"Frontend integration failed");
        check_display(bcd_value(dut.frequency_hz),8'h10);
        input_frequency=2000000.0;amplitude=256;bias=307;#3000000;
        if(!dut.measurement_valid)$fatal(1,"No high-frequency result");
        measure_error=dut.frequency_hz-2000000.0;if(measure_error<0)measure_error=-measure_error;
        if(measure_error>600)$fatal(1,"2 MHz short-window integration failed");
        shift_case(8'h10,500000.0,128,512,1000000);
        shift_case(8'h10,500100.0,64,717,20000000);
        shift_case(8'h10,525123.45,256,307,1000000);
        shift_case(8'h10,600000.0,128,717,1000000);
        shift_case(8'h11,500000.0,64,717,1000000);
        shift_case(8'h11,500123.45,256,307,1000000);
        shift_case(8'h11,550321.0,128,512,1000000);
        shift_case(8'h11,600000.0,128,717,1000000);
        set_mode(8'h10);set_mode(8'h11);set_mode(8'h02);check_display(32'h2610a652,8'h02);
        set_mode(8'h00);check_display(32'h12345678,8'h00);
        if(reset_assertions!=1 || mode_changes<260)$fatal(1,"Combined mode/reset coverage incomplete");
        if(fast_halves<10000 || slow_halves<8)$fatal(1,"Divider coverage incomplete");
        if(case_index!=12)$fatal(1,"DAC coverage incomplete");
        $display("PASS: all 256 DIP codes checked; 00 pattern 12345678, 01 divider, 02 student, 04 DDS, 08 meter, 10 5A, 11 5B; all 256 DDS settings, one startup reset, continuous dividers and calibrated 10 MSPS ADC/mixer/FIR/DAC paths; 0.2 ms integration-only meter gate");
        $finish;
    end
    initial begin #500000000;$fatal(1,"Combined integration timeout");end
endmodule
