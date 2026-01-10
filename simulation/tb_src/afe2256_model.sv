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
    parameter PIXEL_WIDTH = 16,          // 16-bit pixel data (AFE2256 actual spec)
    parameter HEADER_WIDTH = 8,          // 8-bit header
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

    // LVDS transmission state
    reg frame_active;
    integer pixel_count;
    integer bit_count;

    // LVDS clock and data
    reg lvds_clk;
    reg [15:0] current_pixel_data [0:13];
    reg [7:0] current_header [0:13];
    reg [23:0] current_serial_word [0:13];

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
        lvds_clk = 0;

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

        // Initialize data arrays
        for (int i = 0; i < 14; i++) begin
            current_pixel_data[i] = 16'h0;
            current_header[i] = 8'h0;
            current_serial_word[i] = 24'h0;
        end
    end

    //==========================================================================
    // SPI Slave Interface
    //==========================================================================
    // SPI Format: 24-bit transactions (per AFE2256 datasheet)
    // [23]    = R/W (1=Read, 0=Write)
    // [22:16] = Address (7 bits)
    // [15:0]  = Data (16 bits)
    // Bidirectional protocol with read capability

    reg [15:0] spi_read_data;
    reg spi_is_read;

    always @(posedge ROIC_SPI_SCK or posedge ROIC_SPI_SEN_N) begin
        if (ROIC_SPI_SEN_N) begin
            // CS deasserted - reset
            spi_bit_count <= 0;
            ROIC_SPI_SDO <= 1'bz;
            spi_is_read <= 0;
        end else begin
            // Shift in command data on SCK rising edge
            spi_shift_reg <= {spi_shift_reg[22:0], ROIC_SPI_SDI};
            spi_bit_count <= spi_bit_count + 1;

            // After 8 bits (R/W + address), determine if read operation
            if (spi_bit_count == 7) begin
                spi_is_read <= spi_shift_reg[6];  // bit 23 -> shifted to bit 6 after 8 clocks
                if (spi_shift_reg[6]) begin
                    // Read operation - prepare data
                    reg [6:0] read_addr;
                    read_addr = spi_shift_reg[5:0] << 1 | ROIC_SPI_SDI;  // Capture last bit
                    spi_read_data <= {config_regs[{1'b0, read_addr}], config_regs[{1'b0, read_addr} + 1]};
                    $display("[AFE2256] SPI Read: Addr=0x%02X", read_addr);
                end
            end

            // For read operations, shift out data on bits 8-23
            if (spi_is_read && spi_bit_count >= 8) begin
                ROIC_SPI_SDO <= spi_read_data[23 - spi_bit_count];
            end else begin
                ROIC_SPI_SDO <= 1'bz;
            end

            // After 24 bits, process write command if write operation
            if (spi_bit_count == 23) begin
                if (!spi_is_read) begin
                    process_spi_command(spi_shift_reg);
                end
                spi_bit_count <= 0;
            end
        end
    end

    // Process SPI command (Write operations only)
    task process_spi_command(input [23:0] cmd);
        reg [7:0] address;
        reg [15:0] data;
    begin
        // AFE2256 format: [23]=R/W (0=Write), [22:16]=Address, [15:0]=Data
        address = {1'b0, cmd[22:16]};
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

    // Generate LVDS clocks when frame is active
    // LVDS clock should be faster than MCLK0 for DDR data
    integer mclk_edge_count = 0;
    always @(posedge ROIC_MCLK0) begin
        if (!ROIC_AVDD1 || !ROIC_AVDD2) begin
            lvds_clk <= 1'b0;
            mclk_edge_count = 0;
        end else if (frame_active) begin
            // Generate faster clock for LVDS (e.g., 2x MCLK0 = 50MHz)
            lvds_clk <= ~lvds_clk;
            if (mclk_edge_count < 3) begin
                $display("[AFE2256] MCLK0 edge %0d, lvds_clk=%b, frame_active=%b",
                         mclk_edge_count, ~lvds_clk, frame_active);
            end
            mclk_edge_count = mclk_edge_count + 1;
        end else begin
            lvds_clk <= 1'b0;
            if (mclk_edge_count > 0 && mclk_edge_count < 3) begin
                $display("[AFE2256] MCLK0 running but frame_active=0");
            end
        end
    end

    // Drive DCLK outputs (combinational)
    always @(*) begin
        if (frame_active) begin
            DCLKP = {12{lvds_clk}};
            DCLKN = {12{~lvds_clk}};
            DCLKP_12_13 = {2{lvds_clk}};
            DCLKN_12_13 = {2{~lvds_clk}};
        end else begin
            DCLKP = 12'h000;
            DCLKN = 12'hFFF;
            DCLKP_12_13 = 2'b00;
            DCLKN_12_13 = 2'b11;
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

    // Generate pixel data (16-bit data + 8-bit header = 24 bits total per AFE2256 spec)
    always @(posedge lvds_clk) begin
        if (frame_active) begin
            // At start of new pixel, generate data
            if (bit_count == 0) begin
                if (pixel_count < 3) begin
                    $display("[AFE2256] Pixel %0d data generation at time %0t", pixel_count, $time);
                end
                for (int ch = 0; ch < 14; ch++) begin
                    // Generate 16-bit pixel data
                    if (test_pattern_enable) begin
                        if (test_pattern_sel == 5'h13) begin
                            // Ramp pattern: increment per pixel
                            current_pixel_data[ch] = pixel_count[15:0] + (ch << 8);
                        end else if (test_pattern_sel == 5'h1E) begin
                            // Sync/deskew pattern
                            current_pixel_data[ch] = 16'hFFF0;
                            current_header[ch] = 8'hAA;
                        end else if (test_pattern_sel == 5'h11) begin
                            // Row/Column pattern
                            current_pixel_data[ch] = 16'hAAAA;
                            current_header[ch] = 8'h55;
                        end else if (test_pattern_sel == 5'h17) begin
                            // All zeros
                            current_pixel_data[ch] = 16'h0000;
                            current_header[ch] = 8'h00;
                        end else if (test_pattern_sel == 5'h19) begin
                            // All ones
                            current_pixel_data[ch] = 16'hFFFF;
                            current_header[ch] = 8'hFF;
                        end else begin
                            // Other test patterns
                            current_pixel_data[ch] = test_pattern_value;
                            current_header[ch] = 8'h00;
                        end
                    end else if (ROIC_TP_SEL) begin
                        // External test pattern request
                        current_pixel_data[ch] = pixel_count[15:0] + ch;
                        current_header[ch] = {4'(ch), 4'b0000};
                    end else begin
                        // Simulated sensor data: 16-bit with offset + noise
                        current_pixel_data[ch] = 16'h8000 + ($random % 4096);
                        current_header[ch] = {4'(ch), pixel_count[3:0]};  // Channel ID + frame counter
                    end

                    // Combine into 24-bit serial word: [23:16]=header, [15:0]=pixel data
                    current_serial_word[ch] = {current_header[ch], current_pixel_data[ch]};
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
