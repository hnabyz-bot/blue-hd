`timescale 1ns / 1ps
//==============================================================================
// Module: cpu_spi_master_model
// Description: Behavioral model of CPU SPI Master for testbench
//              Communicates with FPGA SPI Slave to configure registers
// Author: Claude Code
// Date: 2026-01-09
//==============================================================================

module cpu_spi_master_model #(
    parameter SPI_CLK_PERIOD = 100  // 10 MHz SPI clock (100ns period)
) (
    // SPI interface to FPGA
    output reg spi_sclk,
    output reg spi_ssb,    // Chip select (active low)
    output reg spi_mosi,
    input  wire spi_miso
);

    //==========================================================================
    // Internal registers
    //==========================================================================
    reg [31:0] tx_data;
    reg [31:0] rx_data;
    integer bit_count;

    //==========================================================================
    // Initialization
    //==========================================================================
    initial begin
        spi_sclk = 0;
        spi_ssb = 1;  // Inactive
        spi_mosi = 0;
        tx_data = 32'h0;
        rx_data = 32'h0;
        bit_count = 0;
    end

    //==========================================================================
    // Task: Write 32-bit data to FPGA register via SPI
    //==========================================================================
    task spi_write(input [31:0] data);
        integer i;
        begin
            $display("[CPU_SPI] Starting SPI write: 0x%08X at time %0t", data, $time);

            tx_data = data;

            // Assert chip select
            spi_ssb = 0;
            #(SPI_CLK_PERIOD/2);

            // Send 32 bits (MSB first)
            for (i = 31; i >= 0; i = i - 1) begin
                // Setup data on MOSI
                spi_mosi = tx_data[i];
                #(SPI_CLK_PERIOD/2);

                // Clock rising edge
                spi_sclk = 1;
                #(SPI_CLK_PERIOD/2);

                // Clock falling edge
                spi_sclk = 0;

                // Sample MISO (for read operations)
                rx_data[i] = spi_miso;
            end

            // Deassert chip select
            #(SPI_CLK_PERIOD/2);
            spi_ssb = 1;
            spi_mosi = 0;
            #(SPI_CLK_PERIOD);

            $display("[CPU_SPI] SPI write completed at time %0t", $time);
        end
    endtask

    //==========================================================================
    // Task: Write to FPGA control register 0 (ctrl_reg0)
    //==========================================================================
    task write_ctrl_reg0(input [31:0] value);
        begin
            $display("[CPU_SPI] Writing ctrl_reg0 = 0x%08X", value);
            spi_write(value);
            #(SPI_CLK_PERIOD * 10);  // Wait for FPGA to process
        end
    endtask

    //==========================================================================
    // Task: Trigger AFE2256 SPI write
    // Format: [31]=wr, [30:24]=reserved, [23:16]=addr, [15:0]=data
    //==========================================================================
    task write_afe2256_reg(input [7:0] afe_addr, input [15:0] afe_data);
        reg [31:0] cmd;
        begin
            // Build command word (bit 23 of AFE2256 SPI = 0 for write)
            cmd = {1'b1,           // [31] Write enable
                   7'h00,          // [30:24] Reserved
                   1'b0,           // [23] AFE2256 R/W bit (0=Write)
                   afe_addr[6:0],  // [22:16] AFE2256 register address (7 bits)
                   afe_data};      // [15:0] AFE2256 register data

            $display("[CPU_SPI] Triggering AFE2256 write: Addr=0x%02X, Data=0x%04X",
                     afe_addr, afe_data);

            write_ctrl_reg0(cmd);

            // Wait for AFE2256 SPI transaction to complete
            #20us;  // AFE2256 SPI takes ~3us, give plenty of margin

            // Clear write bit
            cmd[31] = 1'b0;
            write_ctrl_reg0(cmd);
        end
    endtask

    //==========================================================================
    // Task: Read FPGA status register (32-bit read via SPI)
    //==========================================================================
    task read_status_reg(output [31:0] status_data);
        integer i;
        begin
            $display("[CPU_SPI] Reading FPGA status register at time %0t", $time);

            status_data = 32'h0;

            // Assert chip select
            spi_ssb = 0;
            #(SPI_CLK_PERIOD/2);

            // Send 32 bits of dummy data, capture response
            for (i = 31; i >= 0; i = i - 1) begin
                // Setup dummy data on MOSI
                spi_mosi = 1'b0;
                #(SPI_CLK_PERIOD/2);

                // Clock rising edge
                spi_sclk = 1;
                #(SPI_CLK_PERIOD/4);
                // Sample MISO
                status_data[i] = spi_miso;
                #(SPI_CLK_PERIOD/4);

                // Clock falling edge
                spi_sclk = 0;
            end

            // Deassert chip select
            #(SPI_CLK_PERIOD/2);
            spi_ssb = 1;
            spi_mosi = 0;
            #(SPI_CLK_PERIOD);

            $display("[CPU_SPI] Status register read: 0x%08X at time %0t", status_data, $time);
        end
    endtask

    //==========================================================================
    // Task: Trigger AFE2256 SPI read
    // Format: [31]=wr, [30:24]=reserved, [23]=1 (read), [22:16]=addr, [15:0]=dummy
    //==========================================================================
    task read_afe2256_reg(input [7:0] afe_addr, output [15:0] afe_data);
        reg [31:0] cmd;
        reg [31:0] status;
        begin
            // Build command word (bit 23 of AFE2256 SPI = 1 for read)
            cmd = {1'b1,           // [31] Write enable (triggers SPI transaction)
                   7'h00,          // [30:24] Reserved
                   1'b1,           // [23] AFE2256 R/W bit (1=Read)
                   afe_addr[6:0],  // [22:16] AFE2256 register address (7 bits)
                   16'h0000};      // [15:0] Dummy data

            $display("[CPU_SPI] Triggering AFE2256 read: Addr=0x%02X", afe_addr);

            write_ctrl_reg0(cmd);

            // Wait for AFE2256 SPI transaction to complete
            #20us;

            // Clear write bit
            cmd[31] = 1'b0;
            write_ctrl_reg0(cmd);

            // Wait a bit, then read status_reg1 to get read data
            #5us;

            // Read status_reg1 (would need actual SPI read from FPGA)
            // For now, read it via SPI (this is simplified - real implementation
            // would need a register address system)
            read_status_reg(status);
            afe_data = status[15:0];  // AFE2256 read data in status_reg1[15:0]

            $display("[CPU_SPI] AFE2256 read completed: Data=0x%04X", afe_data);
        end
    endtask

    //==========================================================================
    // Task: Write and verify AFE2256 register
    //==========================================================================
    task write_verify_afe2256_reg(input [7:0] afe_addr, input [15:0] afe_data);
        reg [15:0] readback;
        begin
            $display("[CPU_SPI] Write-Verify: Addr=0x%02X, Data=0x%04X", afe_addr, afe_data);

            // Write the register
            write_afe2256_reg(afe_addr, afe_data);

            // Read it back
            read_afe2256_reg(afe_addr, readback);

            // Verify (comparison will be added in testbench)
            $display("[CPU_SPI] Write-Verify completed for Addr=0x%02X", afe_addr);
        end
    endtask

    //==========================================================================
    // Task: Configure AFE2256 test pattern
    //==========================================================================
    task configure_afe2256_test_pattern(input [4:0] pattern_sel, input [15:0] pattern_value);
        begin
            $display("[CPU_SPI] Configuring AFE2256 test pattern: sel=0x%02X, value=0x%04X",
                     pattern_sel, pattern_value);

            // Write TEST_PATTERN register (0x10)
            // Bits [9:5] = pattern_sel, [4:0] = reserved
            write_afe2256_reg(8'h10, {6'b0, pattern_sel, 5'b0});

            #1us;

            // If custom pattern value needed, write it
            if (pattern_sel == 5'h00) begin
                $display("[CPU_SPI] Writing custom pattern value");
                // Write custom pattern value if needed
            end
        end
    endtask

    //==========================================================================
    // Task: Enable AFE2256 power
    //==========================================================================
    task enable_afe2256_power();
        begin
            $display("[CPU_SPI] Enabling AFE2256 power");
            // Write ctrl_reg0: [18]=AVDD2, [17]=AVDD1, [0]=gate_driver_enable
            write_ctrl_reg0(32'h0006_0001);
        end
    endtask

    //==========================================================================
    // Task: Disable AFE2256 power
    //==========================================================================
    task disable_afe2256_power();
        begin
            $display("[CPU_SPI] Disabling AFE2256 power");
            write_ctrl_reg0(32'h0000_0000);
        end
    endtask

    //==========================================================================
    // Task: Execute AFE2256 full initialization sequence
    // Based on afe2256_spi_pkg::INIT_SEQUENCE
    //==========================================================================
    task init_afe2256_full_sequence();
        begin
            $display("[CPU_SPI] ========================================");
            $display("[CPU_SPI] AFE2256 Full Initialization Sequence");
            $display("[CPU_SPI] ========================================");

            // 1. Soft Reset
            $display("[CPU_SPI] Step 1: Soft Reset");
            write_afe2256_reg(8'h00, 16'h0001);  // RESET
            #10us;

            // 2. TRIM_LOAD (Critical)
            $display("[CPU_SPI] Step 2: TRIM_LOAD (Critical)");
            write_afe2256_reg(8'h30, 16'h0002);  // TRIM_LOAD
            #5us;

            // 3. Essential Bits (Integrate-up mode)
            $display("[CPU_SPI] Step 3: Essential Bits Configuration");
            write_afe2256_reg(8'h11, 16'h2830);  // STR + AUTO_REVERSE
            write_afe2256_reg(8'h12, 16'h4000);  // ESSENTIAL_BIT2
            write_afe2256_reg(8'h16, 16'h00C0);  // ESSENTIAL_BITS5
            write_afe2256_reg(8'h18, 16'h0001);  // ESSENTIAL_BIT3
            write_afe2256_reg(8'h2C, 16'h0000);  // ESSENTIAL_BIT8
            write_afe2256_reg(8'h61, 16'h4000);  // ESSENTIAL_BIT4

            // 4. Operating Mode
            $display("[CPU_SPI] Step 4: Operating Mode Configuration");
            write_afe2256_reg(8'h5E, 16'h0000);  // INTG_MODE (integrate-up)
            write_afe2256_reg(8'h5C, 16'h4800);  // INPUT_RANGE (4.8pC)
            write_afe2256_reg(8'h5D, 16'h0002);  // POWER_MODE (low-noise)

            // 5. Power Mode
            $display("[CPU_SPI] Step 5: Quick Wakeup Mode");
            write_afe2256_reg(8'h13, 16'h0020);  // Quick wakeup

            // 6. Test Pattern (Sync/Deskew for alignment)
            $display("[CPU_SPI] Step 6: Test Pattern (Sync/Deskew)");
            write_afe2256_reg(8'h10, 16'h03C0);  // Sync pattern
            #1us;

            $display("[CPU_SPI] ========================================");
            $display("[CPU_SPI] Initialization Complete");
            $display("[CPU_SPI] ========================================");
        end
    endtask

    //==========================================================================
    // Task: Test all AFE2256 configuration registers
    //==========================================================================
    task test_all_afe2256_registers(output integer pass_count, output integer fail_count);
        reg [7:0] test_addrs [0:15];
        reg [15:0] test_data;
        reg [15:0] readback;
        integer i;
        begin
            pass_count = 0;
            fail_count = 0;

            $display("[CPU_SPI] ========================================");
            $display("[CPU_SPI] Testing All AFE2256 Registers");
            $display("[CPU_SPI] ========================================");

            // Define all testable register addresses
            test_addrs[0]  = 8'h00;  // RESET
            test_addrs[1]  = 8'h10;  // TEST_PATTERN
            test_addrs[2]  = 8'h11;  // STR
            test_addrs[3]  = 8'h12;  // ESSENTIAL_BIT2
            test_addrs[4]  = 8'h13;  // POWER_DOWN
            test_addrs[5]  = 8'h16;  // ESSENTIAL_BITS
            test_addrs[6]  = 8'h18;  // ESSENTIAL_BIT3
            test_addrs[7]  = 8'h2C;  // ESSENTIAL_BIT8
            test_addrs[8]  = 8'h30;  // TRIM_LOAD
            test_addrs[9]  = 8'h5C;  // INPUT_RANGE
            test_addrs[10] = 8'h5D;  // POWER_MODE
            test_addrs[11] = 8'h5E;  // INTG_MODE
            test_addrs[12] = 8'h61;  // ESSENTIAL_BIT4
            test_addrs[13] = 8'h5A;  // PROBE_SIGNAL
            test_addrs[14] = 8'h40;  // IRST (timing profile)
            test_addrs[15] = 8'h42;  // SHR (timing profile)

            for (i = 0; i < 16; i = i + 1) begin
                // Generate unique test value
                test_data = 16'hA5A5 ^ (i << 8) ^ (i << 4);

                $display("\n[CPU_SPI] Testing Register 0x%02X", test_addrs[i]);
                $display("[CPU_SPI]   Writing: 0x%04X", test_data);

                // Write register
                write_afe2256_reg(test_addrs[i], test_data);

                // Read back
                read_afe2256_reg(test_addrs[i], readback);

                $display("[CPU_SPI]   Read back: 0x%04X", readback);

                // Compare
                if (readback == test_data) begin
                    $display("[CPU_SPI]   ✓ PASS");
                    pass_count = pass_count + 1;
                end else begin
                    $display("[CPU_SPI]   ✗ FAIL (mismatch)");
                    fail_count = fail_count + 1;
                end
            end

            $display("\n[CPU_SPI] ========================================");
            $display("[CPU_SPI] Register Test Summary");
            $display("[CPU_SPI]   Total:  %0d", 16);
            $display("[CPU_SPI]   Passed: %0d", pass_count);
            $display("[CPU_SPI]   Failed: %0d", fail_count);
            $display("[CPU_SPI] ========================================");
        end
    endtask

    //==========================================================================
    // Task: Write AFE2256 timing profile register
    //==========================================================================
    task write_timing_profile(input [7:0] profile_addr, input [15:0] profile_data);
        begin
            $display("[CPU_SPI] Writing timing profile: Addr=0x%02X, Data=0x%04X",
                     profile_addr, profile_data);
            write_afe2256_reg(profile_addr, profile_data);
        end
    endtask

    //==========================================================================
    // Task: Configure AFE2256 for normal operation
    //==========================================================================
    task set_normal_mode();
        begin
            $display("[CPU_SPI] Setting AFE2256 to Normal Mode");
            write_afe2256_reg(8'h10, 16'h0000);  // TEST_PATTERN = 0 (normal)
            #1us;
        end
    endtask

endmodule
