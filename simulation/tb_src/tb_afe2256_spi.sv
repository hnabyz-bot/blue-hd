//==============================================================================
// File: tb_afe2256_spi.sv
// Description: Testbench for AFE2256 SPI Controller
//              - Verifies 24-bit SPI protocol (CPOL=0, CPHA=0)
//              - Validates initialization sequence
//              - Checks timing and waveform compliance
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.1
//==============================================================================

`timescale 1ns / 1ps

module tb_afe2256_spi;

    import afe2256_spi_pkg::*;

    //==========================================================================
    // Testbench Parameters
    //==========================================================================

    localparam CLK_PERIOD = 10;          // 100 MHz clock (10ns period)
    localparam SPI_PERIOD = 100;         // 10 MHz SPI clock (100ns period)
    localparam NUM_ROICS = 1;

    //==========================================================================
    // DUT Signals
    //==========================================================================

    // Clock and Reset
    logic clk;
    logic rst_n;

    // Register Write Interface
    logic [7:0]  reg_addr;
    logic [15:0] reg_wdata;
    logic        reg_wr;
    logic        busy;
    logic        done;

    // SPI Physical Interface
    logic                   spi_sck;
    logic                   spi_sdi;
    logic [NUM_ROICS-1:0]   spi_sdo;
    logic [NUM_ROICS-1:0]   spi_sen_n;

    //==========================================================================
    // Testbench Variables
    //==========================================================================

    logic [23:0] captured_data;          // Captured SPI data
    int          bit_count;              // Bit counter for SPI capture
    int          test_count;             // Test case counter
    int          error_count;            // Error counter

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    afe2256_spi_controller #(
        .NUM_ROICS    (NUM_ROICS),
        .CLK_FREQ_MHZ (100),
        .SPI_FREQ_MHZ (10)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .reg_addr    (reg_addr),
        .reg_wdata   (reg_wdata),
        .reg_wr      (reg_wr),
        .busy        (busy),
        .done        (done),
        .spi_sck     (spi_sck),
        .spi_sdi     (spi_sdi),
        .spi_sdo     (spi_sdo),
        .spi_sen_n   (spi_sen_n)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // SPI Data Capture Process
    // Captures data on rising edge of SCK (CPHA=0)
    //==========================================================================

    always @(posedge spi_sck or posedge spi_sen_n[0]) begin
        if (spi_sen_n[0]) begin
            // Reset on SEN deassert
            captured_data <= 24'h0;
            bit_count <= 0;
        end else begin
            // Capture data on rising edge
            if (bit_count < 24) begin
                captured_data <= {captured_data[22:0], spi_sdi};
                bit_count <= bit_count + 1;
            end
        end
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================

    initial begin
        // Initialize signals
        rst_n = 0;
        reg_addr = 8'h00;
        reg_wdata = 16'h0000;
        reg_wr = 0;
        spi_sdo = '0;
        test_count = 0;
        error_count = 0;

        // VCD dump for waveform analysis
        $dumpfile("tb_afe2256_spi.vcd");
        $dumpvars(0, tb_afe2256_spi);

        $display("================================================================================");
        $display("AFE2256 SPI Controller Testbench");
        $display("================================================================================");
        $display("Clock Frequency: 100 MHz");
        $display("SPI Frequency: 10 MHz");
        $display("SPI Mode: CPOL=0, CPHA=0");
        $display("Data Format: 24-bit (8-bit addr + 16-bit data), MSB First");
        $display("================================================================================\n");

        // Reset sequence
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*5);

        //======================================================================
        // Test 1: Single Register Write
        //======================================================================
        test_count = test_count + 1;
        $display("[TEST %0d] Single Register Write", test_count);
        $display("  Writing: Addr=0x10, Data=0xABCD");

        @(posedge clk);
        reg_addr = 8'h10;
        reg_wdata = 16'hABCD;
        reg_wr = 1;

        @(posedge clk);
        reg_wr = 0;

        // Wait for transfer complete
        wait(done);
        @(posedge clk);

        // Verify captured data
        if (captured_data == 24'h10ABCD) begin
            $display("  ✓ PASS: Captured data = 0x%06X", captured_data);
        end else begin
            $display("  ✗ FAIL: Expected 0x10ABCD, got 0x%06X", captured_data);
            error_count = error_count + 1;
        end

        #(CLK_PERIOD*20);

        //======================================================================
        // Test 2: Reset Register Write
        //======================================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Reset Register Write", test_count);
        $display("  Writing: Addr=0x00, Data=0x0001 (RESET[0]=1)");

        @(posedge clk);
        reg_addr = REG_RESET;
        reg_wdata = 16'h0001;
        reg_wr = 1;

        @(posedge clk);
        reg_wr = 0;

        wait(done);
        @(posedge clk);

        if (captured_data == 24'h000001) begin
            $display("  ✓ PASS: Captured data = 0x%06X", captured_data);
        end else begin
            $display("  ✗ FAIL: Expected 0x000001, got 0x%06X", captured_data);
            error_count = error_count + 1;
        end

        #(CLK_PERIOD*20);

        //======================================================================
        // Test 3: TRIM_LOAD Register Write (CRITICAL)
        //======================================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] TRIM_LOAD Register Write", test_count);
        $display("  Writing: Addr=0x30, Data=0x0002 (TRIM_LOAD[1]=1)");

        @(posedge clk);
        reg_addr = REG_TRIM_LOAD;
        reg_wdata = 16'h0002;
        reg_wr = 1;

        @(posedge clk);
        reg_wr = 0;

        wait(done);
        @(posedge clk);

        if (captured_data == 24'h300002) begin
            $display("  ✓ PASS: Captured data = 0x%06X", captured_data);
        end else begin
            $display("  ✗ FAIL: Expected 0x300002, got 0x%06X", captured_data);
            error_count = error_count + 1;
        end

        #(CLK_PERIOD*20);

        //======================================================================
        // Test 4: Multiple Consecutive Writes
        //======================================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Multiple Consecutive Writes", test_count);

        for (int i = 0; i < 5; i++) begin
            logic [7:0] addr_test = 8'h10 + i;
            logic [15:0] data_test = 16'h1000 + i;

            $display("  Write %0d: Addr=0x%02X, Data=0x%04X", i+1, addr_test, data_test);

            @(posedge clk);
            reg_addr = addr_test;
            reg_wdata = data_test;
            reg_wr = 1;

            @(posedge clk);
            reg_wr = 0;

            wait(done);
            @(posedge clk);

            logic [23:0] expected = {addr_test, data_test};
            if (captured_data == expected) begin
                $display("    ✓ PASS: Captured = 0x%06X", captured_data);
            end else begin
                $display("    ✗ FAIL: Expected 0x%06X, got 0x%06X", expected, captured_data);
                error_count = error_count + 1;
            end

            #(CLK_PERIOD*10);
        end

        //======================================================================
        // Test 5: SPI Timing Verification
        //======================================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] SPI Timing Verification", test_count);

        real sck_period_measured;
        time sck_rise_time1, sck_rise_time2;

        @(posedge clk);
        reg_addr = 8'h5C;
        reg_wdata = 16'h4800;  // INPUT_RANGE = 4.8pC
        reg_wr = 1;

        @(posedge clk);
        reg_wr = 0;

        // Measure SCK period
        @(posedge spi_sck);
        sck_rise_time1 = $time;
        @(posedge spi_sck);
        sck_rise_time2 = $time;
        sck_period_measured = sck_rise_time2 - sck_rise_time1;

        $display("  Measured SCK period: %.1f ns (Expected: 100 ns)", sck_period_measured);

        if (sck_period_measured >= 95 && sck_period_measured <= 105) begin
            $display("  ✓ PASS: SCK frequency within tolerance");
        end else begin
            $display("  ✗ FAIL: SCK frequency out of range");
            error_count = error_count + 1;
        end

        wait(done);
        @(posedge clk);

        #(CLK_PERIOD*20);

        //======================================================================
        // Test 6: Full Initialization Sequence
        //======================================================================
        test_count = test_count + 1;
        $display("\n[TEST %0d] Full Initialization Sequence (%0d registers)",
                 test_count, INIT_REG_COUNT);

        for (int i = 0; i < INIT_REG_COUNT; i++) begin
            automatic init_reg_t init_reg = INIT_SEQUENCE[i];

            $display("  Init[%2d]: Addr=0x%02X, Data=0x%04X, Delay=%0d us",
                     i, init_reg.addr, init_reg.data, init_reg.delay_us);

            @(posedge clk);
            reg_addr = init_reg.addr;
            reg_wdata = init_reg.data;
            reg_wr = 1;

            @(posedge clk);
            reg_wr = 0;

            wait(done);
            @(posedge clk);

            logic [23:0] expected = {init_reg.addr, init_reg.data};
            if (captured_data == expected) begin
                $display("    ✓ Verified: 0x%06X", captured_data);
            end else begin
                $display("    ✗ Mismatch: Expected 0x%06X, got 0x%06X", expected, captured_data);
                error_count = error_count + 1;
            end

            // Simulate delay (scaled down 1000x for simulation)
            if (init_reg.delay_us > 0) begin
                #(init_reg.delay_us);  // In simulation, treat as ns
            end

            #(CLK_PERIOD*10);
        end

        //======================================================================
        // Test Summary
        //======================================================================
        #(CLK_PERIOD*100);

        $display("\n================================================================================");
        $display("Test Summary");
        $display("================================================================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors: %0d", error_count);

        if (error_count == 0) begin
            $display("Status: ✓ ALL TESTS PASSED");
        end else begin
            $display("Status: ✗ TESTS FAILED");
        end
        $display("================================================================================\n");

        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================

    initial begin
        #(CLK_PERIOD * 100000);  // 1ms timeout
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end

    //==========================================================================
    // Protocol Checker - CPOL=0, CPHA=0
    //==========================================================================

    property spi_cpol0_idle;
        @(posedge clk) disable iff (!rst_n)
        (spi_sen_n[0] == 1'b1) |-> (spi_sck == 1'b0);
    endproperty

    property spi_sen_active_low;
        @(posedge clk) disable iff (!rst_n)
        (busy == 1'b1) |-> (spi_sen_n[0] == 1'b0);
    endproperty

    // Assertions
    assert property (spi_cpol0_idle)
        else $error("CPOL=0 violation: SCK not idle LOW");

    assert property (spi_sen_active_low)
        else $error("SEN timing violation: Not active during transfer");

endmodule : tb_afe2256_spi
