`timescale 1ns / 1ps
//==============================================================================
// Module: afe2256_model
// Description: Behavioral model of AFE2256 ROIC for testbench simulation
// Author: Claude Code
// Date: 2026-01-07
//==============================================================================
//
// AFE2256 ROIC Features:
// - 14 LVDS output channels (256 pixels x 14 channels = 3584 pixels)
// - SPI slave interface for configuration
// - Differential LVDS outputs (DCLK, FCLK, DOUT per channel)
// - Control signals: TP_SEL, SYNC, MCLK0, AVDD1, AVDD2
//
//==============================================================================

module afe2256_model #(
    parameter NUM_CHANNELS = 14,
    parameter PIXEL_WIDTH = 14,
    parameter PIXELS_PER_CHANNEL = 256
) (
    // Control inputs from FPGA
    input  wire        ROIC_TP_SEL,        // Test pattern select
    input  wire        ROIC_SYNC,          // Synchronization signal
    input  wire        ROIC_MCLK0,         // Master clock from FPGA
    input  wire        ROIC_AVDD1,         // Analog power 1
    input  wire        ROIC_AVDD2,         // Analog power 2

    // SPI slave interface (receives configuration from FPGA)
    input  wire        ROIC_SPI_SCK,       // SPI clock
    input  wire        ROIC_SPI_SDI,       // SPI data in (from FPGA)
    output reg         ROIC_SPI_SDO,       // SPI data out (to FPGA)
    input  wire        ROIC_SPI_SEN_N,     // Chip select (Active LOW)

    // LVDS outputs - Channels 0-11
    output reg  [0:11] DCLKP, DCLKN,       // Data clocks
    output reg  [0:11] FCLKP, FCLKN,       // Frame clocks
    output reg  [0:11] DOUTP, DOUTN,       // Data outputs

    // LVDS outputs - Channels 12-13
    output reg  [12:13] DCLKP_12_13, DCLKN_12_13,
    output reg  [12:13] FCLKP_12_13, FCLKN_12_13,
    output reg  [12:13] DOUTP_12_13, DOUTN_12_13
);

    //==========================================================================
    // Internal Registers (SPI Configuration)
    //==========================================================================
    reg [23:0] spi_shift_reg;
    reg [7:0] spi_bit_count;
    reg [7:0] config_regs [0:255];  // 256 configuration registers

    // Configuration register addresses (example)
    localparam ADDR_RESET = 8'h00;
    localparam ADDR_MODE = 8'h01;
    localparam ADDR_GAIN = 8'h10;
    localparam ADDR_OFFSET = 8'h20;
    localparam ADDR_TEST_PATTERN = 8'h30;

    reg [15:0] test_pattern_value;
    reg test_pattern_enable;
    reg [1:0] operation_mode;  // 0=normal, 1=test, 2=sleep

    //==========================================================================
    // Power-on initialization
    //==========================================================================
    initial begin
        // Initialize SPI
        ROIC_SPI_SDO = 1'bz;
        spi_shift_reg = 24'h0;
        spi_bit_count = 0;

        // Initialize configuration registers
        for (int i = 0; i < 256; i++) begin
            config_regs[i] = 8'h00;
        end

        // Default configuration
        test_pattern_enable = 0;
        test_pattern_value = 16'hAAAA;
        operation_mode = 2'b00;  // Normal mode

        // Initialize LVDS outputs (idle state)
        DCLKP = 12'h000;
        DCLKN = 12'hFFF;
        FCLKP = 12'h000;
        FCLKN = 12'hFFF;
        DOUTP = 12'h000;
        DOUTN = 12'hFFF;

        DCLKP_12_13 = 2'b00;
        DCLKN_12_13 = 2'b11;
        FCLKP_12_13 = 2'b00;
        FCLKN_12_13 = 2'b11;
        DOUTP_12_13 = 2'b00;
        DOUTN_12_13 = 2'b11;
    end

    //==========================================================================
    // SPI Slave Interface
    //==========================================================================
    // SPI Format: 24-bit transactions
    // [23:22] = Operation (00=write, 01=read)
    // [21:16] = Address (6 bits)
    // [15:0]  = Data (16 bits)

    always @(posedge ROIC_SPI_SCK or posedge ROIC_SPI_SEN_N) begin
        if (ROIC_SPI_SEN_N) begin
            // CS deasserted - reset
            spi_bit_count <= 0;
            ROIC_SPI_SDO <= 1'bz;
        end else begin
            // Shift in data on SCK rising edge
            spi_shift_reg <= {spi_shift_reg[22:0], ROIC_SPI_SDI};
            spi_bit_count <= spi_bit_count + 1;

            // After 24 bits, process command
            if (spi_bit_count == 23) begin
                process_spi_command(spi_shift_reg);
                spi_bit_count <= 0;
            end
        end
    end

    // Process SPI command
    task process_spi_command(input [23:0] cmd);
        reg [1:0] operation;
        reg [7:0] address;
        reg [15:0] data;
    begin
        operation = cmd[23:22];
        address = cmd[21:14];
        data = cmd[13:0];

        case (operation)
            2'b00: begin  // Write
                config_regs[address] <= data[7:0];

                // Update internal state based on register writes
                case (address)
                    ADDR_RESET: begin
                        if (data[0]) begin
                            // Reset command
                            test_pattern_enable <= 0;
                            operation_mode <= 2'b00;
                        end
                    end

                    ADDR_MODE: begin
                        operation_mode <= data[1:0];
                    end

                    ADDR_TEST_PATTERN: begin
                        test_pattern_enable <= data[0];
                        test_pattern_value <= data[15:0];
                    end
                endcase

                $display("[AFE2256] SPI Write: Addr=0x%02X, Data=0x%04X", address, data);
            end

            2'b01: begin  // Read
                ROIC_SPI_SDO <= config_regs[address][7];
                $display("[AFE2256] SPI Read: Addr=0x%02X, Data=0x%02X", address, config_regs[address]);
            end
        endcase
    end
    endtask

    //==========================================================================
    // LVDS Data Output Generation
    //==========================================================================
    // Triggered by SYNC signal
    reg frame_active;
    integer pixel_count;
    reg [13:0] current_pixel_data [0:13];  // 14 channels

    // Generate LVDS clocks when frame is active
    always @(posedge ROIC_MCLK0) begin
        if (ROIC_AVDD1 && ROIC_AVDD2) begin
            // Power is on, generate clocks
            if (frame_active) begin
                // Toggle data clocks (200 MHz)
                DCLKP <= ~DCLKP;
                DCLKN <= ~DCLKN;
                DCLKP_12_13 <= ~DCLKP_12_13;
                DCLKN_12_13 <= ~DCLKN_12_13;
            end
        end
    end

    // Frame control via SYNC
    always @(posedge ROIC_SYNC) begin
        if (ROIC_AVDD1 && ROIC_AVDD2 && operation_mode != 2'b10) begin
            // Start new frame
            frame_active <= 1;
            pixel_count <= 0;

            // Generate frame clock pulse
            FCLKP <= 12'hFFF;
            FCLKN <= 12'h000;
            FCLKP_12_13 <= 2'b11;
            FCLKN_12_13 <= 2'b00;

            #10;  // Frame clock pulse width

            FCLKP <= 12'h000;
            FCLKN <= 12'hFFF;
            FCLKP_12_13 <= 2'b00;
            FCLKN_12_13 <= 2'b11;

            $display("[AFE2256] Frame start at time %0t", $time);
        end
    end

    // Generate pixel data
    always @(posedge DCLKP[0]) begin
        if (frame_active && pixel_count < PIXELS_PER_CHANNEL) begin
            // Generate test pattern or simulated pixel data
            for (int ch = 0; ch < 14; ch++) begin
                if (test_pattern_enable) begin
                    current_pixel_data[ch] = test_pattern_value;
                end else if (ROIC_TP_SEL) begin
                    // Ramp test pattern
                    current_pixel_data[ch] = pixel_count[13:0] + ch;
                end else begin
                    // Simulated sensor data (simple noise + offset)
                    current_pixel_data[ch] = 14'h0800 + ($random % 256);
                end
            end

            // Output differential data on channels 0-11
            for (int ch = 0; ch < 12; ch++) begin
                DOUTP[ch] <= current_pixel_data[ch][pixel_count % 14];
                DOUTN[ch] <= ~current_pixel_data[ch][pixel_count % 14];
            end

            // Output differential data on channels 12-13
            for (int ch = 12; ch <= 13; ch++) begin
                DOUTP_12_13[ch] <= current_pixel_data[ch][pixel_count % 14];
                DOUTN_12_13[ch] <= ~current_pixel_data[ch][pixel_count % 14];
            end

            pixel_count <= pixel_count + 1;

            // End of frame
            if (pixel_count == PIXELS_PER_CHANNEL - 1) begin
                frame_active <= 0;
                $display("[AFE2256] Frame end at time %0t (pixels=%0d)", $time, pixel_count);
            end
        end
    end

    //==========================================================================
    // Debug monitors
    //==========================================================================
    // Monitor power state
    always @(ROIC_AVDD1, ROIC_AVDD2) begin
        if (ROIC_AVDD1 && ROIC_AVDD2) begin
            $display("[AFE2256] Power ON at time %0t", $time);
        end else begin
            $display("[AFE2256] Power OFF at time %0t", $time);
        end
    end

    // Monitor mode changes
    always @(operation_mode) begin
        case (operation_mode)
            2'b00: $display("[AFE2256] Mode: NORMAL");
            2'b01: $display("[AFE2256] Mode: TEST PATTERN");
            2'b10: $display("[AFE2256] Mode: SLEEP");
            default: $display("[AFE2256] Mode: UNKNOWN");
        endcase
    end

endmodule
