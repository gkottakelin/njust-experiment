`timescale 1ns / 1fs
// End-to-end full-rate ADC translation. The expected nonsinusoidal output is
// fixed-LO mixing followed by the exact FIR, not a regenerated ideal waveform.
module tb_waveform_translation;
    localparam real REFERENCE=99999505.0,PI=3.141592653589793;
    reg clk=0;
    integer edge_number=0;
    initial forever begin
        edge_number=edge_number+1;
        #(edge_number*500000000.0/REFERENCE-$realtime)clk=~clk;
    end
    reg sys_rst_n=0;
    reg [7:0] dip=8'h10;
    reg [9:0] ad_in=512;
    wire adc_clk,dac_clk;
    wire [7:0] dac;
    combined_experiments_top dut(.clk_in(clk),.sys_rst_n(sys_rst_n),.rst(1'b0),
        .sw(8'd127),.dip(dip),.ad_in(ad_in),.clk_ad(adc_clk),.clk_da(dac_clk),.dac_data(dac));
    integer kind=0,code,code_out,pipe0=512,pipe1=512,pipe2=512;
    real frequency=550000,amplitude=96,duty=0.5,bias=512;
    real phase,shape,value;
    always @(negedge adc_clk)begin
        phase=$realtime*1e-9*frequency;
        phase=phase-$floor(phase);
        if(kind==0)shape=$sin(2*PI*phase);
        else if(kind==1)shape=phase<duty ? 1.0 : -1.0;
        else if(kind==2)begin
            if(phase<duty)shape=-1.0+2.0*phase/duty;
            else shape=1.0-2.0*(phase-duty)/(1.0-duty);
        end else shape=$sin(2*PI*phase)+0.3*$sin(6*PI*phase+0.4);
        value=bias+amplitude*shape;code=$rtoi($floor(value+0.5));
        if(code<0 || code>1023)$fatal(1,"ADC input clipped");
        code_out=pipe2;pipe2=pipe1;pipe1=pipe0;pipe0=code;
        #25;ad_in=code_out;
    end
    integer raw_file,out_file,metadata,case_number=0,raw_count=0,out_count=0;
    reg collecting=0;
    always @(posedge clk)if(dut.centered_valid && collecting)begin
        $fdisplay(raw_file,"%0.6f,%0d",$realtime,$signed(dut.centered));raw_count=raw_count+1;
    end
    always @(posedge dac_clk)if(collecting)begin
        $fdisplay(out_file,"%0.6f,%0d",$realtime,dac);out_count=out_count+1;
        if(dut.overrun_5a || dut.overrun_5b)$fatal(1,"Full-rate filter overrun");
    end
    task automatic capture(input [7:0] mode,input integer waveform,input real freq,input real shape_duty,
                           input real input_amplitude=96.0);
        begin
            dip=mode;kind=waveform;frequency=freq;duty=shape_duty;amplitude=input_amplitude;
            bias=case_number%2==0 ? 640 : 384;
            wait(dut.active_mode==mode);
            #1500000;
            case_number=case_number+1;raw_count=0;out_count=0;
            raw_file=$fopen($sformatf("waveform_input_%0d.csv",case_number),"w");
            out_file=$fopen($sformatf("waveform_output_%0d.csv",case_number),"w");
            if(!raw_file || !out_file)$fatal(1,"Cannot write waveform samples");
            $fdisplay(raw_file,"time_ns,centered_adc");$fdisplay(out_file,"time_ns,dac");
            $fdisplay(metadata,"%0d,%0d,%0d,%0.3f,%0.6f,%0.3f",case_number,mode,waveform,freq,shape_duty,input_amplitude);
            collecting=1;#1000000;collecting=0;$fclose(raw_file);$fclose(out_file);
            if(raw_count<9990 || out_count<9990)$fatal(1,"Lost full-rate ADC/DAC samples");
            $display("WAVEFORM_TRANSLATION: case=%0d mode=%0d kind=%0d frequency=%0.3f",case_number,mode,kind,frequency);
        end
    endtask
    integer mode_index;
    initial begin
        metadata=$fopen("waveform_cases.csv","w");
        $fdisplay(metadata,"case,mode,kind,frequency_hz,duty,adc_amplitude");
        #40;sys_rst_n=1;
        for(mode_index=0;mode_index<2;mode_index=mode_index+1)begin
            capture(mode_index==0 ? 8'h10 : 8'h11,0,550000,0.5);
            capture(mode_index==0 ? 8'h10 : 8'h11,1,500000,0.5);
            capture(mode_index==0 ? 8'h10 : 8'h11,1,550000,0.5);
            capture(mode_index==0 ? 8'h10 : 8'h11,2,550000,0.5);
            capture(mode_index==0 ? 8'h10 : 8'h11,1,550321,0.25);
            capture(mode_index==0 ? 8'h10 : 8'h11,2,600000,0.3);
            capture(mode_index==0 ? 8'h10 : 8'h11,3,550000,0.5);
            capture(mode_index==0 ? 8'h10 : 8'h11,1,500000,0.5,256.0);
            capture(mode_index==0 ? 8'h10 : 8'h11,1,600000,0.5,256.0);
        end
        $fclose(metadata);
        $display("PASS: 18 full-rate sine, square, triangle, asymmetric and harmonic-input ADC-to-DAC captures including full-amplitude square waves; analyze_waveforms.py checks exact mixer/FIR response");
        $finish;
    end
    initial begin #60000000;$fatal(1,"Waveform test timeout");end
endmodule
