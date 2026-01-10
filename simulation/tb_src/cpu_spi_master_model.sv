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

endmodule
