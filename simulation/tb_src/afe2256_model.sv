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
    parameter PIXEL_WIDTH = 12,          // 12-bit pixel data (project uses 12-bit mode)
    parameter ALIGN_WIDTH = 12,          // 12-bit alignment vector
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

    // Configuration register addresses (from afe2256_spi_pkg.sv)
    localparam ADDR_RESET = 8'h00;
    localparam ADDR_TEST_PATTERN = 8'h10;
    localparam ADDR_STR = 8'h11;
    localparam ADDR_POWER_DOWN = 8'h13;
    localparam ADDR_TRIM_LOAD = 8'h30;
    localparam ADDR_INPUT_RANGE = 8'h5C;
    localparam ADDR_POWER_MODE = 8'h5D;
    localparam ADDR_INTG_MODE = 8'h5E;

    reg [15:0] test_pattern_value;
    reg test_pattern_enable;
    reg [4:0] test_pattern_sel;  // TEST_PATTERN_SEL[9:5]
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
        test_pattern_sel = 5'h00;
        test_pattern_value = 16'hAAAA;
        operation_mode = 2'b00;  // Normal mode
        bit_count = 0;
        pixel_count = 0;
        frame_active = 0;

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
    // SPI Format: 24-bit transactions (per AFE2256 datasheet)
    // [23:16] = Address (8 bits)
    // [15:0]  = Data (16 bits)
    // Write-only protocol (no read operation)

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
        reg [7:0] address;
        reg [15:0] data;
    begin
        // AFE2256 format: [23:16]=Address, [15:0]=Data
        address = cmd[23:16];
        data = cmd[15:0];

        // Store in config registers (split 16-bit data into 2 bytes)
        config_regs[address] <= data[15:8];
        config_regs[address+1] <= data[7:0];

        // Update internal state based on register writes
        case (address)
            ADDR_RESET: begin
                if (data[0]) begin
                    // RESET[0]=1: Soft reset
                    test_pattern_enable <= 0;
                    operation_mode <= 2'b00;
                    $display("[AFE2256] RESET command received");
                end
            end

            ADDR_TEST_PATTERN: begin
                // TEST_PATTERN_SEL[9:5] in data[9:5]
                test_pattern_sel <= data[9:5];
                case (data[9:5])
                    5'h00: begin  // Normal mode
                        test_pattern_enable <= 0;
                        $display("[AFE2256] Test pattern: NORMAL");
                    end
                    5'h11: begin  // Row/Column pattern
                        test_pattern_enable <= 1;
                        test_pattern_value <= 16'hAAAA;  // Alternating pattern
                        $display("[AFE2256] Test pattern: ROW/COLUMN (0xAAAA)");
                    end
                    5'h13: begin  // Ramp pattern
                        test_pattern_enable <= 1;
                        test_pattern_value <= 16'h0000;  // Will increment
                        $display("[AFE2256] Test pattern: RAMP");
                    end
                    5'h17: begin  // All zeros
                        test_pattern_enable <= 1;
                        test_pattern_value <= 16'h0000;
                        $display("[AFE2256] Test pattern: ALL ZEROS");
                    end
                    5'h19: begin  // All ones
                        test_pattern_enable <= 1;
                        test_pattern_value <= 16'hFFFF;
                        $display("[AFE2256] Test pattern: ALL ONES");
                    end
                    5'h1E: begin  // Sync/deskew pattern (0xFFF000)
                        test_pattern_enable <= 1;
                        test_pattern_value <= 16'hFFF0;  // High 12 bits = FFF
                        $display("[AFE2256] Test pattern: SYNC/DESKEW (0xFFF000)");
                    end
                    default: begin
                        test_pattern_enable <= 0;
                        $display("[AFE2256] Test pattern: Unknown (0x%02X)", data[9:5]);
                    end
                endcase
            end

            ADDR_POWER_DOWN: begin
                if (data[15:5] == 11'h7FF) begin
                    operation_mode <= 2'b10;  // Sleep
                    $display("[AFE2256] Power mode: SLEEP");
                end else begin
                    operation_mode <= 2'b00;  // Active
                    $display("[AFE2256] Power mode: ACTIVE (0x%04X)", data);
                end
            end

            ADDR_TRIM_LOAD: begin
                if (data[1]) begin
                    $display("[AFE2256] TRIM_LOAD executed");
                end
            end

            ADDR_STR: begin
                $display("[AFE2256] STR config: 0x%04X (STR[5:4]=%0d)", data, data[5:4]);
            end

            ADDR_INPUT_RANGE: begin
                $display("[AFE2256] Input range: 0x%04X (CHARGE_RANGE[15:11]=%0d)", data, data[15:11]);
            end

            default: begin
                // Other registers - just store
            end
        endcase

        $display("[AFE2256] SPI Write: Addr=0x%02X, Data=0x%04X", address, data);
    end
    endtask

    //==========================================================================
    // LVDS Data Output Generation
    //==========================================================================
    // Triggered by SYNC signal
    reg frame_active;
    integer pixel_count;
    integer bit_count;  // Bit counter for 24-bit serial output
    reg [11:0] current_pixel_data [0:13];  // 12-bit pixel data for 14 channels
    reg [11:0] current_align [0:13];       // 12-bit alignment vector for 14 channels
    reg [23:0] current_serial_word [0:13]; // 24-bit word = 12-bit align + 12-bit pixel

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
            bit_count <= 0;

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

    // Generate pixel data (12-bit pixel + 12-bit alignment = 24 bits total per project spec)
    always @(posedge DCLKP[0]) begin
        if (frame_active) begin
            // At start of new pixel, generate data
            if (bit_count == 0) begin
                for (int ch = 0; ch < 14; ch++) begin
                    // Generate 12-bit pixel data
                    if (test_pattern_enable) begin
                        if (test_pattern_sel == 5'h13) begin
                            // Ramp pattern: increment per pixel
                            current_pixel_data[ch] = pixel_count[11:0] + ch[3:0];
                        end else if (test_pattern_sel == 5'h1E) begin
                            // Sync/deskew pattern (0xFFF per afe2256_lvds_pkg.sv)
                            current_pixel_data[ch] = 12'hFFF;
                            current_align[ch] = 12'h000;  // SYNC_PATTERN_HIGH/LOW
                        end else if (test_pattern_sel == 5'h11) begin
                            // Row/Column pattern (0xAAA per pkg)
                            current_pixel_data[ch] = 12'hAAA;
                            current_align[ch] = 12'h555;
                        end else begin
                            // Other test patterns
                            current_pixel_data[ch] = test_pattern_value[11:0];
                            current_align[ch] = 12'h000;
                        end
                    end else if (ROIC_TP_SEL) begin
                        // External test pattern request
                        current_pixel_data[ch] = pixel_count[11:0] + ch[3:0];
                        current_align[ch] = 12'h000;
                    end else begin
                        // Simulated sensor data: 12-bit with offset + noise
                        current_pixel_data[ch] = 12'h800 + ($random % 256);
                        current_align[ch] = 12'h000;  // Normal alignment
                    end

                    // Combine into 24-bit serial word: [23:12]=alignment, [11:0]=pixel data
                    current_serial_word[ch] = {current_align[ch], current_pixel_data[ch]};
                end
            end

            // Output bit-serially (MSB first) on channels 0-11
            for (int ch = 0; ch < 12; ch++) begin
                DOUTP[ch] <= current_serial_word[ch][23 - bit_count];
                DOUTN[ch] <= ~current_serial_word[ch][23 - bit_count];
            end

            // Output bit-serially on channels 12-13
            for (int ch = 12; ch <= 13; ch++) begin
                DOUTP_12_13[ch] <= current_serial_word[ch][23 - bit_count];
                DOUTN_12_13[ch] <= ~current_serial_word[ch][23 - bit_count];
            end

            bit_count <= bit_count + 1;

            // After 24 bits, move to next pixel
            if (bit_count >= 23) begin
                bit_count <= 0;
                pixel_count <= pixel_count + 1;

                // End of frame (256 pixels per channel)
                if (pixel_count >= PIXELS_PER_CHANNEL - 1) begin
                    frame_active <= 0;
                    $display("[AFE2256] Frame end at time %0t (pixels=%0d)", $time, pixel_count+1);
                end
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
