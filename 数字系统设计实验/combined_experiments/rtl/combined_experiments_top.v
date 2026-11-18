`timescale 1ns / 1ps
module combined_experiments_top #(
    parameter integer REFERENCE_HZ=99999505,
    parameter integer GATE_TICKS=80000000,
    parameter integer TIMEOUT_TICKS=150000000,
    parameter integer WARMUP_SAMPLES=50000,
    parameter integer SCAN_SLOT_CYCLES=100000,
    parameter integer MODE_DEBOUNCE_CYCLES=100000,
    parameter integer MODE_MUTE_CYCLES=2000,
    // ADC-code / 4 at unity FIR gain leaves room for square-wave fundamentals.
    parameter integer DAC_SCALE_SHIFT=6
) (
    input wire clk_in,input wire sys_rst_n,input wire rst,
    input wire [7:0] sw,input wire [7:0] dip,input wire [9:0] ad_in,
    output wire clk_ad,output wire clk_da,output reg [7:0] dac_data,
    output wire clk_10mhz,output reg clk_1khz,
    output wire [7:0] seg_cs_pin,output wire [7:0] seg_data_0_pin,output wire [7:0] seg_data_1_pin
);
    // S0/R11 high or RST/P15 low asserts the same global reset. Modes never reset cores.
    wire async_reset=rst||!sys_rst_n;
    (* ASYNC_REG="TRUE" *) reg [1:0] reset_release=2'b11;
    always @(posedge clk_in or posedge async_reset)
        if(async_reset)reset_release<=2'b11;else reset_release<={reset_release[0],1'b0};
    wire rst_n=!reset_release[1];
    (* ASYNC_REG="TRUE" *) reg [7:0] sw_meta,sw_sync;
    (* ASYNC_REG="TRUE" *) reg [7:0] dip_meta,dip_sync;
    always @(posedge clk_in or negedge rst_n)begin
        if(!rst_n)begin sw_meta<=0;sw_sync<=0;dip_meta<=0;dip_sync<=0;end
        else begin sw_meta<=sw;sw_sync<=sw_meta;dip_meta<=dip;dip_sync<=dip_meta;end
    end
    wire [9:0] adc_sample;
    wire adc_valid,dac_update,converter_clk;
    sample_clocking u_sampling(.clk(clk_in),.rst_n(rst_n),.ad_in(ad_in),.converter_clk(converter_clk),
        .adc_sample(adc_sample),.adc_valid(adc_valid),.dac_update(dac_update));
    assign clk_ad=converter_clk;assign clk_da=converter_clk;assign clk_10mhz=converter_clk;
    reg [15:0] slow_count;
    reg [31:0] timestamp;
    always @(posedge clk_in or negedge rst_n)begin
        if(!rst_n)begin slow_count<=0;clk_1khz<=0;timestamp<=0;end
        else begin
            timestamp<=timestamp+1'b1;
            if(slow_count==49999)begin slow_count<=0;clk_1khz<=~clk_1khz;end
            else slow_count<=slow_count+1'b1;
        end
    end

    // Exact DIP[7:0] codes: 00 pattern, 01 divider, 02 student, 04 DDS,
    // 08 frequency meter, 10 shift 500 kHz, 11 shift 100 kHz.
    reg [7:0] active_mode,mode_candidate;
    reg [31:0] mode_stable_count,mute_count;
    reg mode_changed;
    always @(posedge clk_in or negedge rst_n)begin
        if(!rst_n)begin active_mode<=0;mode_candidate<=0;mode_stable_count<=0;mode_changed<=0;end
        else begin
            mode_changed<=0;
            if(dip_sync!=mode_candidate)begin mode_candidate<=dip_sync;mode_stable_count<=0;end
            else if(mode_stable_count<MODE_DEBOUNCE_CYCLES)mode_stable_count<=mode_stable_count+1'b1;
            if(dac_update && dip_sync==mode_candidate && mode_stable_count>=MODE_DEBOUNCE_CYCLES && active_mode!=mode_candidate)
                begin active_mode<=mode_candidate;mode_changed<=1;end
        end
    end
    always @(posedge clk_in or negedge rst_n)begin
        if(!rst_n)mute_count<=MODE_MUTE_CYCLES;
        else if(mode_changed)mute_count<=MODE_MUTE_CYCLES;
        else if(mute_count!=0)mute_count<=mute_count-1'b1;
    end

    // Single continuously running ADC conditioner and calibrated frequency meter.
    wire signed [15:0] centered;
    wire centered_valid,settled,rising_event;
    adc_conditioner #(.WARMUP_SAMPLES(WARMUP_SAMPLES)) u_conditioner(
        .clk(clk_in),.rst_n(rst_n),.sample_valid(adc_valid),.adc_sample(adc_sample),
        .centered(centered),.centered_valid(centered_valid),.rising_event(),.settled(settled));
    robust_crossing_detector u_crossing(.clk(clk_in),.rst_n(rst_n),.sample_valid(centered_valid),
        .enable(settled),.sample_in(centered),.rising_event(rising_event));
    wire [31:0] frequency_hz;
    wire measurement_valid,measurement_update;
    reciprocal_frequency_meter #(.REFERENCE_HZ(REFERENCE_HZ),.GATE_TICKS(GATE_TICKS),.TIMEOUT_TICKS(TIMEOUT_TICKS))
      u_meter(.clk(clk_in),.rst_n(rst_n),.rising_event(rising_event),.timestamp(timestamp),
        .frequency_hz(frequency_hz),.measurement_valid(measurement_valid),.measurement_update(measurement_update));

    // DDS retains the task's 8-bit phase accumulator and nominal 10 MHz formula.
    reg [7:0] dds_phase,dds_sample;
    wire [7:0] next_dds_phase=dds_phase+sw_sync;
    wire [7:0] next_dds_sample;
    sine_rom u_sine(.phase(next_dds_phase),.sample(next_dds_sample));
    always @(posedge clk_in or negedge rst_n)begin
        if(!rst_n)begin dds_phase<=0;dds_sample<=128;end
        else if(dac_update)begin dds_phase<=next_dds_phase;dds_sample<=next_dds_sample;end
    end
    wire [31:0] dds_bcd,measured_bcd;
    frequency_display_value u_dds_value(.clk(clk_in),.rst_n(rst_n),.tuning_word(sw_sync),.bcd(dds_bcd));
    binary_to_bcd u_measured_value(.clk(clk_in),.rst_n(rst_n),.value(frequency_hz),.bcd(measured_bcd));
    combined_display #(.SLOT_CYCLES(SCAN_SLOT_CYCLES)) u_display(.clk(clk_in),.rst_n(rst_n),
        .active_mode(active_mode),.dds_bcd(dds_bcd),.measured_bcd(measured_bcd),
        .measurement_valid(measurement_valid),.seg_cs_pin(seg_cs_pin),
        .seg_data_0_pin(seg_data_0_pin),.seg_data_1_pin(seg_data_1_pin));

    // Actual ADC data is mixed and filtered at 10 MSPS throughout.
    // The frequency meter is display-only; no pre-mixer decimation is used.
    wire signed [15:0] adc_q4=centered<<<4;
    wire signed [15:0] mixed_5a,mixed_5b,filtered_5a,filtered_5b;
    wire mixed_valid_5a,mixed_valid_5b,filtered_valid_5a,filtered_valid_5b;
    wire overrun_5a,overrun_5b;
    frequency_mixer #(.SHIFT_HZ(500000),.REFERENCE_HZ(REFERENCE_HZ)) u_mixer_5a(
        .clk(clk_in),.rst_n(rst_n),.input_valid(centered_valid),.sample_in(adc_q4),
        .output_valid(mixed_valid_5a),.sample_out(mixed_5a));
    frequency_mixer #(.SHIFT_HZ(100000),.REFERENCE_HZ(REFERENCE_HZ)) u_mixer_5b(
        .clk(clk_in),.rst_n(rst_n),.input_valid(centered_valid),.sample_in(adc_q4),
        .output_valid(mixed_valid_5b),.sample_out(mixed_5b));
    translation_fir_5a u_fir_5a(.clk(clk_in),.rst_n(rst_n),.input_valid(mixed_valid_5a),.sample_in(mixed_5a),
        .output_valid(filtered_valid_5a),.sample_out(filtered_5a),.overrun(overrun_5a));
    translation_fir_5b u_fir_5b(.clk(clk_in),.rst_n(rst_n),.input_valid(mixed_valid_5b),.sample_in(mixed_5b),
        .output_valid(filtered_valid_5b),.sample_out(filtered_5b),.overrun(overrun_5b));
    // Both FIR pipelines have the same latency and produce one result per ADC sample.
    wire signed [15:0] translated_sample=(active_mode==8'h11) ? filtered_5b : filtered_5a;
    wire translated_valid=filtered_valid_5a;
    reg signed [15:0] last_translated;
    localparam signed [16:0] DAC_ROUND=17'sd1<<(DAC_SCALE_SHIFT-1);
    wire signed [16:0] rounded=($signed({last_translated[15],last_translated})+DAC_ROUND)>>>DAC_SCALE_SHIFT;
    wire signed [17:0] dac_signed=$signed({rounded[16],rounded})+18'sd128;
    always @(posedge clk_in or negedge rst_n)begin
        if(!rst_n)begin last_translated<=0;dac_data<=128;end
        else begin
            if(translated_valid)last_translated<=translated_sample;
            // Only this register drives the physical DAC, on its falling edge.
            if(dac_update)begin
                if(mute_count!=0 || mode_changed)dac_data<=128;
                else if(active_mode==8'h04)dac_data<=dds_sample;
                else if(active_mode!=8'h10 && active_mode!=8'h11)dac_data<=128;
                else if(dac_signed<0)dac_data<=0;
                else if(dac_signed>255)dac_data<=255;
                else dac_data<=dac_signed[7:0];
            end
        end
    end
endmodule
