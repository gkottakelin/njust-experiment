`timescale 1ns / 1ps
module tb_meter_precision;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, rising_event=0;
    reg [31:0] timestamp=0;
    wire [31:0] frequency;
    wire valid, updated;
    reciprocal_frequency_meter #(.REFERENCE_HZ(99999505),.GATE_TICKS(80000000)) dut (
        .clk(clk), .rst_n(rst_n), .rising_event(rising_event), .timestamp(timestamp),
        .frequency_hz(frequency), .measurement_valid(valid), .measurement_update(updated)
    );
    wire [31:0] uncalibrated_frequency;
    wire uncalibrated_valid,uncalibrated_updated;
    reciprocal_frequency_meter #(.REFERENCE_HZ(100000000),.GATE_TICKS(80000000)) uncalibrated (
        .clk(clk),.rst_n(rst_n),.rising_event(rising_event),.timestamp(timestamp),
        .frequency_hz(uncalibrated_frequency),.measurement_valid(uncalibrated_valid),
        .measurement_update(uncalibrated_updated)
    );
    reg observed=0;
    integer measured=0;
    integer measured_uncalibrated=0;
    always @(negedge clk) if (updated && valid) begin
        if(!uncalibrated_valid || !uncalibrated_updated)
            $fatal(1,"Parallel uncalibrated measurement was not synchronized");
        observed=1; measured=frequency; measured_uncalibrated=uncalibrated_frequency;
    end
    integer log_file;
    task automatic check_frequency(input real expected, input integer base);
        integer i, limit, quantized_tick;
        real err;
        begin
            // Model a 99,999,505 Hz counter and its /10 ADC sample grid, skipping
            // idle cycles. A nominal 100 MHz conversion overreads by about 4.95 ppm.
            @(negedge clk); rising_event=0; timestamp=timestamp+32'd160000000;
            repeat(5) @(negedge clk);
            #1; observed=0;
            i=0; limit=$rtoi($ceil(expected*0.8))+160;
            while (!observed && i<limit) begin
                quantized_tick=$rtoi($floor(i*9999950.5/expected+0.5))*10;
                @(negedge clk); timestamp=base+quantized_tick; rising_event=1;
                @(negedge clk); rising_event=0;
                #1; i=i+1;
            end
            if (!observed) $fatal(1,"No measurement for %f Hz",expected);
            err=measured-expected; if(err<0) err=-err;
            if (err>1.0) $fatal(1,"Expected %f Hz, measured %d, error %f",expected,measured,err);
            if(expected==1000000.0 && (measured_uncalibrated!=1000005 || measured!=1000000))
                $fatal(1,"1 MHz +4.95 ppm correction has the wrong direction or scale");
            if(expected==2000000.0 && (measured_uncalibrated!=2000010 || measured!=2000000))
                $fatal(1,"2 MHz +4.95 ppm correction has the wrong direction or scale");
            $display("PRECISION: input=%f Hz uncalibrated=%0d Hz corrected=%0d Hz error=%f Hz",expected,measured_uncalibrated,measured,err);
            $fdisplay(log_file,"%f,%0d,%0d,%f",expected,measured_uncalibrated,measured,err);
            repeat(110) @(negedge clk);
        end
    endtask
    initial begin
        log_file=$fopen("meter_precision.csv","w");
        $fdisplay(log_file,"input_hz,uncalibrated_hz,measured_hz,error_hz");
        #30; rst_n=1;
        check_frequency(100.0,32'hff000000);
        check_frequency(100.37,32'h10000000);
        check_frequency(1000.125,32'h20000000);
        check_frequency(39062.5,32'h30000000);
        check_frequency(123456.789,32'h40000000);
        check_frequency(500000.0,32'h50000000);
        check_frequency(599999.2,32'h60000000);
        check_frequency(1000000.0,32'h68000000);
        check_frequency(1000000.3,32'h70000000);
        check_frequency(1999999.4,32'h80000000);
        check_frequency(2000000.0,32'h90000000);
        @(negedge clk); timestamp=timestamp+32'd150000100;
        repeat(5) @(negedge clk);
        if(valid || frequency!=0) $fatal(1,"Signal-loss timeout failed");
        $fclose(log_file);
        $display("PASS: reciprocal precision <= 1 Hz with 0.8 s gate and -4.95 ppm calibration; 1 MHz +5 Hz and 2 MHz +10 Hz biases corrected, ADC timestamp quantization, wrap, timeout and changes without reset");
        $finish;
    end
    initial begin #1000000000; $fatal(1,"Precision test timeout"); end
endmodule
