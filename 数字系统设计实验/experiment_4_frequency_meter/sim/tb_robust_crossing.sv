`timescale 1ns / 1ps
module tb_robust_crossing;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,valid=0,enable=0;
    reg signed [15:0] sample=0;
    wire event_out;
    robust_crossing_detector detector(.clk(clk),.rst_n(rst_n),.sample_valid(valid),
        .enable(enable),.sample_in(sample),.rising_event(event_out));
    real phase=0,frequency=100000,amplitude=32;
    integer sample_index=0,code;
    reg collect=0;
    integer edges=0;
    time first_edge,last_edge;
    always @(posedge event_out) if(collect)begin
        if(edges==0)first_edge=$time;
        last_edge=$time;edges=edges+1;
    end
    always @(negedge clk)begin
        valid=sample_index==0;
        if(valid)begin
            code=$rtoi($floor(amplitude*$sin(phase)+0.5));
            sample=code;
            phase=phase+6.283185307179586*frequency/10000000.0;
            if(phase>=6.283185307179586)phase=phase-6.283185307179586;
        end
        sample_index=sample_index==9?0:sample_index+1;
    end
    task automatic check_tone(input real f,input real a,input real initial_phase,input integer duration_ns);
        real measured,error;
        begin
            collect=0;enable=0;frequency=f;amplitude=a;phase=initial_phase;
            #2000000; // Allow peak release after amplitude changes.
            edges=0;enable=1;collect=1;
            #(duration_ns);collect=0;
            if(edges<2)$fatal(1,"No robust crossings at %f",f);
            measured=(edges-1)*1000000000.0/(last_edge-first_edge);
            error=measured-f;if(error<0)error=-error;
            if(error>0.1)$fatal(1,"Robust detector missed or added cycles: input=%f measured=%f phase=%f",f,measured,initial_phase);
            $display("ROBUST: f=%f ADC_peak=%f phase=%f measured=%f",f,a,initial_phase,measured);
        end
    endtask
    integer i;
    initial begin
        #35;rst_n=1;
        check_tone(100.0,16.0,0,30000000); // Low-end amplitude after DC rejection.
        check_tone(100000.0,32.0,0,2000000);
        for(i=0;i<12;i=i+1)check_tone(2000000.0,64.0,i*6.283185307179586/60.0,1000000);
        collect=0;enable=0;amplitude=0;#3000000;edges=0;enable=1;collect=1;#1000000;
        if(edges!=0)$fatal(1,"False robust crossings on zero input");
        $display("PASS: robust crossing detector, 100 Hz/100 kHz/2 MHz phase sweep, 0.25 Vpp at 100 kHz, no-input silence");
        $finish;
    end
    initial begin #150000000;$fatal(1,"Robust detector timeout");end
endmodule
