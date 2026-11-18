`timescale 1ns / 1ps

module tb_dds_display;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg [7:0] sw = 0;
    reg [1:0] dip = 0;
    wire [7:0] cs, seg0, seg1, dac_data;
    wire dac_clk;
    dds_display_top #(.SCAN_SLOT_CYCLES(20)) dut (
        .clk_in(clk), .sys_rst_n(rst_n), .sw(sw), .dip(dip),
        .seg_cs_pin(cs), .seg_data_0_pin(seg0), .seg_data_1_pin(seg1),
        .clk_da(dac_clk), .sin_out(dac_data)
    );

    integer checked_samples = 0;
    integer checked_clocks = 0;
    integer model_phase = 0;
    integer model_sample = 128;
    time previous_dac_edge = 0;
    time data_update_time = 0;

    function automatic [31:0] expected_bcd(input integer word_value);
        longint unsigned hz;
        reg [31:0] result;
        integer n;
        begin
            hz = (64'd10000000 * word_value + 64'd128) / 256;
            result = 0;
            for (n = 0; n < 8; n = n + 1) begin
                result[n*4 +: 4] = hz % 10;
                hz = hz / 10;
            end
            expected_bcd = result;
        end
    endfunction

    function automatic [7:0] expected_segments(input [3:0] value, input bit dp);
        reg [6:0] bits_value;
        begin
            case (value)
                0: bits_value = 7'h3f;
                1: bits_value = 7'h06;
                2: bits_value = 7'h5b;
                3: bits_value = 7'h4f;
                4: bits_value = 7'h66;
                5: bits_value = 7'h6d;
                6: bits_value = 7'h7d;
                7: bits_value = 7'h07;
                8: bits_value = 7'h7f;
                9: bits_value = 7'h6f;
                10: bits_value = 7'h08;
                default: bits_value = 0;
            endcase
            expected_segments = {dp, bits_value};
        end
    endfunction

    // Check the DDS recurrence, LUT quantization and update rate throughout all K.
    always @(posedge clk) begin
        if (!dut.rst_n) begin
            model_phase = 0;
            model_sample = 128;
        end else if (dut.u_dds.divider == 0) begin
            model_phase = (model_phase + dut.sw_sync) % 256;
            // Fix the exact cardinal values rather than round floating-point sin(pi).
            case (model_phase)
                0, 128: model_sample = 128;
                64: model_sample = 255;
                192: model_sample = 0;
                default: model_sample = $rtoi($floor(127.5 + 127.5 * $sin(6.283185307179586 * model_phase / 256.0) + 0.5));
            endcase
            data_update_time = $time;
            #1;
            if (dac_data !== model_sample[7:0])
                $fatal(1, "DDS phase=%0d expected=%0d actual=%0d", model_phase, model_sample, dac_data);
            checked_samples = checked_samples + 1;
        end
    end

    always @(posedge dac_clk) begin
        if (dut.rst_n) begin
            if (previous_dac_edge != 0 && $time-previous_dac_edge != 100)
                $fatal(1, "DAC clock is not 10 MHz");
            if ($time-data_update_time != 50)
                $fatal(1, "DAC setup interval is not 50 ns");
            if (dac_data !== model_sample[7:0])
                $fatal(1, "Wrong sample at DAC capture edge");
            previous_dac_edge = $time;
            checked_clocks = checked_clocks + 1;
        end
    end
    always @(negedge rst_n) previous_dac_edge = 0;

    // All digit changes must pass through an all-off interval.
    reg [7:0] last_cs = 0;
    always @(negedge clk) begin
        if ((cs & (cs-1'b1)) != 0)
            $fatal(1, "Multiple digit selects active");
        if (cs != 0 && last_cs != 0 && cs != last_cs)
            $fatal(1, "Digit select changed without blanking");
        last_cs = cs;
    end

    task automatic check_frame(input [31:0] digits, input [7:0] dots);
        integer slot;
        reg [7:0] expected;
        begin
            // Begin on a fresh frame, allowing the mode/frame snapshot to settle.
            repeat (400) @(negedge clk);
            wait (cs == 0);
            wait (cs == 8'h01);
            for (slot = 0; slot < 8; slot = slot + 1) begin
                wait (cs == (8'b1 << slot));
                #1;
                expected = expected_segments((digits >> ((7-slot)*4)) & 15, dots[slot]);
                if (slot < 4) begin
                    if (seg0 !== expected || seg1 !== 0)
                        $fatal(1, "Left digit %0d expected=%h actual=%h", slot, expected, seg0);
                end else if (seg1 !== expected || seg0 !== 0)
                    $fatal(1, "Right digit %0d expected=%h actual=%h", slot, expected, seg1);
                wait (cs == 0);
            end
        end
    endtask

    integer k;
    initial begin
        #40;
        @(negedge clk) rst_n = 1;
        check_frame(32'h2610a652, 8'h02);
        dip = 1;
        for (k = 0; k < 256; k = k + 1) begin
            @(negedge clk) sw = k;
            repeat (65) @(negedge clk);
            if (dut.sw_sync !== k[7:0] || dut.frequency_bcd !== expected_bcd(k))
                $fatal(1, "K=%0d BCD expected=%h actual=%h", k, expected_bcd(k), dut.frequency_bcd);
            // A complete phase-state cycle per K, including aliased and DC cases.
            repeat (256) @(posedge dac_clk);
            if (k == 0 || k == 1 || k == 64 || k == 128 || k == 255)
                check_frame(expected_bcd(k), 8'h10);
        end
        if (expected_bcd(1) !== 32'h00039063 || expected_bcd(255) !== 32'h09960938)
            $fatal(1, "Rounding boundary regression");
        dip = 2;
        repeat (400) @(negedge clk);
        repeat (200) begin
            @(negedge clk);
            if (cs !== 0) $fatal(1, "Mode 10 should blank display");
        end
        dip = 3;
        repeat (400) @(negedge clk);
        if (cs !== 0) $fatal(1, "Mode 11 should blank display");
        @(negedge clk) rst_n = 0;
        #1;
        if (cs !== 0 || dac_clk !== 0 || dac_data !== 128)
            $fatal(1, "Reset did not clear outputs");
        repeat (5) @(negedge clk);
        sw = 0;
        dip = 0;
        rst_n = 1;
        check_frame(32'h2610a652, 8'h02);
        $display("PASS: all 256 K values, %0d DDS samples, %0d DAC clocks, rounding, display modes, scan blanking and reset", checked_samples, checked_clocks);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
