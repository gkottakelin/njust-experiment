`timescale 1ns / 1ps

module tb_clock_divider;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    wire fast, slow;
    clock_divider_top dut (
        .clk_in(clk), .rst(rst), .clk_10mhz(fast), .clk_1khz(slow)
    );

    time last_fast_edge = 0;
    time last_fast_rise = 0;
    time last_slow_edge = 0;
    time last_slow_rise = 0;
    integer fast_half_periods = 0;
    integer fast_periods = 0;
    integer slow_half_periods = 0;
    integer slow_periods = 0;
    integer reset_checks = 0;
    integer edge_log;

    always @(posedge rst) begin
        last_fast_edge = 0;
        last_fast_rise = 0;
        last_slow_edge = 0;
        last_slow_rise = 0;
    end

    // Check the observable periods and pulse widths, independently of counters.
    always @(fast) begin
        if (!rst && !$isunknown(fast)) begin
            if ($time % 10 != 5) $fatal(1, "10 MHz edge not aligned to system rising edge");
            if (last_fast_edge != 0) begin
                if ($time-last_fast_edge != 50)
                    $fatal(1, "10 MHz half-period is %0t instead of 50 ns", $time-last_fast_edge);
                fast_half_periods = fast_half_periods + 1;
            end
            last_fast_edge = $time;
            if (fast) begin
                if (last_fast_rise != 0) begin
                    if ($time-last_fast_rise != 100) $fatal(1, "10 MHz period is not 100 ns");
                    fast_periods = fast_periods + 1;
                end
                last_fast_rise = $time;
            end
            if (fast_half_periods < 12)
                $fdisplay(edge_log, "%0d,10MHz,%0d", $time, fast);
        end
    end

    always @(slow) begin
        if (!rst && !$isunknown(slow)) begin
            if ($time % 10 != 5) $fatal(1, "1 kHz edge not aligned to system rising edge");
            if (last_slow_edge != 0) begin
                if ($time-last_slow_edge != 500000)
                    $fatal(1, "1 kHz half-period is %0t instead of 500 us", $time-last_slow_edge);
                slow_half_periods = slow_half_periods + 1;
            end
            last_slow_edge = $time;
            if (slow) begin
                if (last_slow_rise != 0) begin
                    if ($time-last_slow_rise != 1000000) $fatal(1, "1 kHz period is not 1 ms");
                    slow_periods = slow_periods + 1;
                end
                last_slow_rise = $time;
            end
            $fdisplay(edge_log, "%0d,1kHz,%0d", $time, slow);
        end
    end

    task automatic release_and_check_start;
        begin
            rst = 0;
            // Two clocks to release reset, then five clocks to the first fast rise.
            repeat (6) begin
                @(posedge clk);
                #1;
                if (fast !== 0 || slow !== 0) $fatal(1, "Output started early after reset");
            end
            @(posedge clk);
            #1;
            if (fast !== 1 || slow !== 0) $fatal(1, "First 10 MHz rise has wrong phase after reset");
        end
    endtask

    task automatic assert_and_check_reset;
        begin
            rst = 1;
            #1;
            if (fast !== 0 || slow !== 0) $fatal(1, "Active-high reset failed to clear outputs asynchronously");
            repeat (3) begin
                @(negedge clk);
                if (fast !== 0 || slow !== 0) $fatal(1, "Outputs changed while reset held high");
            end
            reset_checks = reset_checks + 1;
        end
    endtask

    initial begin
        edge_log = $fopen("simulation_edges.csv", "w");
        if (!edge_log) $fatal(1, "Cannot open edge log");
        $fdisplay(edge_log, "time_ns,signal,level");
        #37;
        if (fast !== 0 || slow !== 0) $fatal(1, "Initial reset failed");
        release_and_check_start();
        // More than three slow periods before an off-clock reset assertion.
        #3234461;
        assert_and_check_reset();
        #3;
        release_and_check_start();
        #2654321;
        assert_and_check_reset();
        // Also test a reset pulse shorter than one system period.
        #3;
        rst = 0;
        #2;
        rst = 1;
        #1;
        if (fast !== 0 || slow !== 0) $fatal(1, "Short reset pulse failed");
        #2;
        release_and_check_start();
        #2154321;
        if (fast_periods < 70000 || slow_periods < 4 || reset_checks != 2)
            $fatal(1, "Insufficient waveform coverage");
        $fclose(edge_log);
        $display("PASS: 10 MHz period=100 ns, high/low=50 ns; 1 kHz period=1 ms, high/low=500 us; %0d fast periods, %0d slow periods; reset hold, async assertion, sync release and short pulse checked", fast_periods, slow_periods);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
