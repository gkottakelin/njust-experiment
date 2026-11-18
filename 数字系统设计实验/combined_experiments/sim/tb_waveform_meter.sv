`timescale 1ns / 1fs
module tb_waveform_meter;
    localparam real REFERENCE=99999505.0;
    localparam real PI=3.141592653589793;
    reg clk=0;integer clock_edge_number=0;
    initial forever begin clock_edge_number=clock_edge_number+1;
        #(clock_edge_number*500000000.0/REFERENCE-$realtime)clk=~clk;end
    reg rst_n=0;
    reg [9:0] ad_in=512;
    wire adc_clk,adc_valid,dac_update;
    wire [9:0] adc_sample;
    sample_clocking u_sample(.clk(clk),.rst_n(rst_n),.ad_in(ad_in),.converter_clk(adc_clk),
        .adc_sample(adc_sample),.adc_valid(adc_valid),.dac_update(dac_update));
    wire signed [15:0] centered;
    wire centered_valid,settled,rising_event;
    adc_conditioner u_conditioner(.clk(clk),.rst_n(rst_n),.sample_valid(adc_valid),.adc_sample(adc_sample),
        .centered(centered),.centered_valid(centered_valid),.settled(settled));
    robust_crossing_detector u_crossing(.clk(clk),.rst_n(rst_n),.sample_valid(centered_valid),
        .enable(settled),.sample_in(centered),.rising_event(rising_event));
    reg [31:0] timestamp=0;
    always @(posedge clk)if(!rst_n)timestamp<=0;else timestamp<=timestamp+1'b1;
    wire [31:0] frequency_hz;wire valid,updated;
    reciprocal_frequency_meter #(.REFERENCE_HZ(99999505),.GATE_TICKS(200000)) u_meter(
        .clk(clk),.rst_n(rst_n),.rising_event(rising_event),.timestamp(timestamp),
        .frequency_hz(frequency_hz),.measurement_valid(valid),.measurement_update(updated));
    integer kind=0,code,next_code,pipe0=512,pipe1=512,pipe2=512;
    real f=100.0,a=64.0,bias=512.0,duty=0.5,p,value;
    always @(negedge adc_clk)begin
        p=$realtime*1e-9*f;p=p-$floor(p);
        if(kind==0)value=$sin(2*PI*p);
        else if(kind==1)value=p<duty?1.0:-1.0;
        else value=p<duty ? -1.0+2.0*p/duty : 1.0-2.0*(p-duty)/(1.0-duty);
        code=$rtoi($floor(bias+a*value+0.5));
        if(code<0 || code>1023)$fatal(1,"Waveform ADC clipping");
        next_code=pipe2;pipe2=pipe1;pipe1=pipe0;pipe0=code;
        #25;ad_in=next_code;
    end
    reg observing=0;
    integer events=0;
    real first_edge=0,last_edge=0,max_gap=0,gap;
    always @(posedge rising_event)if(observing)begin
        if(events==0)first_edge=$realtime;
        else begin gap=$realtime-last_edge;if(gap>max_gap)max_gap=gap;end
        last_edge=$realtime;events=events+1;
    end
    integer summary,case_number=0;
    task automatic check_case(input integer k,input real frequency,input real amplitude,
                              input real offset,input real width);
        real count_expected,err,limit,period_error;
        integer duration_ns;
        begin
            kind=k;f=frequency;a=amplitude;bias=offset;duty=width;
            #6000000;
            duration_ns=frequency<200?40000000:4000000;
            events=0;max_gap=0;observing=1;#(duration_ns);observing=0;
            count_expected=frequency*duration_ns*1e-9;
            if(events<count_expected-2 || events>count_expected+2)$fatal(1,"Missing/extra edges k=%0d f=%f edges=%0d",k,f,events);
            if(events<2)$fatal(1,"No waveform edge coverage");
            period_error=(last_edge-first_edge)/(events-1)-1e9/f;
            if(period_error<0)period_error=-period_error;
            if(period_error>110)$fatal(1,"Average edge period incorrect");
            if(max_gap>1e9/f+250)$fatal(1,"Missed waveform cycle");
            if(!valid)$fatal(1,"Waveform frequency unavailable");
            err=frequency_hz-f;if(err<0)err=-err;limit=2+f*0.0002;
            if(err>limit)$fatal(1,"Short-window waveform frequency incorrect k=%0d f=%f measured=%0d",k,f,frequency_hz);
            case_number=case_number+1;
            $display("WAVEFORM_METER: case=%0d kind=%0d input=%f adc_amplitude=%f duty=%f edges=%0d measured=%0d",case_number,k,f,a,duty,events,frequency_hz);
            $fdisplay(summary,"%0d,%0d,%f,%f,%f,%f,%0d,%0d,%f",case_number,k,f,a,bias,duty,events,frequency_hz,err);
        end
    endtask
    initial begin
        summary=$fopen("waveform_meter.csv","w");
        $fdisplay(summary,"case,kind,input_hz,amplitude_codes,bias_codes,duty,edges,measured_hz,short_window_error_hz");
        #40;rst_n=1;
        check_case(0,100.0,64,717,0.5);
        check_case(1,100.0,64,307,0.5);check_case(2,100.0,64,717,0.5);
        check_case(1,100000.0,32,717,0.5);check_case(2,100000.0,32,307,0.5);
        check_case(1,500000.0,64,717,0.5);check_case(2,500000.0,64,307,0.5);
        check_case(1,550321.0,128,512,0.25);check_case(2,550321.0,128,512,0.3);
        check_case(1,1000000.0,256,307,0.5);check_case(2,1000000.0,256,717,0.5);
        check_case(1,2000000.0,64,717,0.5);check_case(2,2000000.0,64,307,0.5);
        if(case_number!=13)$fatal(1,"Waveform measurement coverage incomplete");
        $fclose(summary);
        $display("PASS: sine/square/triangle ADC frequency measurement, 100 Hz to 2 MHz, amplitude/offset and asymmetric waveform cases; short integration window explicitly used");$finish;
    end
    initial begin #500000000;$fatal(1,"Waveform meter timeout");end
endmodule
