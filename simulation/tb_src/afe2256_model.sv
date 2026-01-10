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
    reg [6:0] spi_addr;

    // SPI slave - shift in on SCK rising edge, shift out on falling edge
    always @(posedge ROIC_SPI_SCK or posedge ROIC_SPI_SEN_N) begin
        if (ROIC_SPI_SEN_N) begin
            // CS deasserted - reset
            spi_bit_count <= 0;
            spi_is_read <= 0;
        end else begin
            // Shift in command data on SCK rising edge
            spi_shift_reg <= {spi_shift_reg[22:0], ROIC_SPI_SDI};
            spi_bit_count <= spi_bit_count + 1;

            // After 8 bits (R/W + 7-bit address), determine operation type
            if (spi_bit_count == 7) begin
                spi_is_read <= spi_shift_reg[6];  // MSB (R/W bit)
                spi_addr <= {spi_shift_reg[5:0], ROIC_SPI_SDI};  // 7-bit address

                if (spi_shift_reg[6]) begin
                    // Read operation - prepare data from config registers
                    spi_read_data <= {config_regs[{1'b0, spi_shift_reg[5:0], ROIC_SPI_SDI}],
                                      config_regs[{1'b0, spi_shift_reg[5:0], ROIC_SPI_SDI} + 1]};
                    $display("[AFE2256 SPI] Read Addr=0x%02X at time %0t", {spi_shift_reg[5:0], ROIC_SPI_SDI}, $time);
                end
            end

            // After 24 bits, process write command
            if (spi_bit_count == 23) begin
                if (!spi_is_read) begin
                    process_spi_command({spi_shift_reg[22:0], ROIC_SPI_SDI});
                end else begin
                    $display("[AFE2256 SPI] Read complete: Data=0x%04X", spi_read_data);
                end
            end
        end
    end

    // SPI SDO - shift out on falling edge for read operations
    always @(negedge ROIC_SPI_SCK or posedge ROIC_SPI_SEN_N) begin
        if (ROIC_SPI_SEN_N) begin
            ROIC_SPI_SDO <= 1'bz;
        end else begin
            if (spi_is_read && spi_bit_count >= 8 && spi_bit_count < 24) begin
                // Shift out read data MSB first (bits 8-23)
                ROIC_SPI_SDO <= spi_read_data[23 - spi_bit_count];
            end else begin
                ROIC_SPI_SDO <= 1'bz;
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

    // LVDS clock generation - DDR mode requires precise timing
    // AFE2256 datasheet: DCLK frequency = (MCLK0 / scan_time) * pixels_per_channel
    // For simulation: Use ~50MHz DCLK (20ns period, 10ns half-period)

    reg lvds_dclk_gen;  // Separate DCLK generator
    integer dclk_count;

    initial begin
        lvds_dclk_gen = 0;
        dclk_count = 0;
    end

    // Free-running DCLK generator when frame is active and powered
    always @(posedge ROIC_MCLK0 or negedge frame_active) begin
        if (!frame_active || !ROIC_AVDD1 || !ROIC_AVDD2) begin
            lvds_clk <= 1'b0;
            dclk_count <= 0;
        end else begin
            // Toggle LVDS clock on every MCLK0 edge (creates 2x MCLK0 frequency)
            lvds_clk <= ~lvds_clk;
            dclk_count <= dclk_count + 1;

            if (dclk_count < 5) begin
                $display("[AFE2256 DCLK] Edge %0d at time %0t, lvds_clk=%b",
                         dclk_count, $time, ~lvds_clk);
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

    // Frame control via SYNC with timing verification
    time frame_start_time;
    time frame_end_time;
    time fclk_pulse_start;

    always @(posedge ROIC_SYNC) begin
        if (ROIC_AVDD1 && ROIC_AVDD2 && operation_mode != 2'b10) begin
            if (frame_active) begin
                $display("[AFE2256 WARNING] SYNC received while frame active at time %0t", $time);
            end

            // Start new frame
            frame_active <= 1;
            pixel_count <= 0;
            bit_count <= 0;
            frame_start_time = $time;

            // Generate frame clock pulse (FCLK)
            fclk_pulse_start = $time;
            FCLKP <= 12'hFFF;
            FCLKN <= 12'h000;
            FCLKP_12_13 <= 2'b11;
            FCLKN_12_13 <= 2'b00;

            #10;  // FCLK pulse width: 10ns (per datasheet)

            FCLKP <= 12'h000;
            FCLKN <= 12'hFFF;
            FCLKP_12_13 <= 2'b00;
            FCLKN_12_13 <= 2'b11;

            $display("[AFE2256 FRAME] Start at time %0t, FCLK pulse width=%0dns",
                     frame_start_time, $time - fclk_pulse_start);
        end else if (!ROIC_AVDD1 || !ROIC_AVDD2) begin
            $display("[AFE2256 ERROR] SYNC ignored - power off at time %0t", $time);
        end else if (operation_mode == 2'b10) begin
            $display("[AFE2256 ERROR] SYNC ignored - sleep mode at time %0t", $time);
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
                    frame_end_time = $time;

                    $display("[AFE2256 FRAME] End at time %0t", frame_end_time);
                    $display("[AFE2256 FRAME] Duration: %0dns (%0d pixels)",
                             frame_end_time - frame_start_time, pixel_count + 1);
                    $display("[AFE2256 FRAME] Total DCLK edges: %0d (expected: %0d)",
                             dclk_count, PIXELS_PER_CHANNEL * 24);

                    // Verify frame timing
                    if (pixel_count + 1 != PIXELS_PER_CHANNEL) begin
                        $display("[AFE2256 ERROR] Pixel count mismatch: %0d (expected %0d)",
                                 pixel_count + 1, PIXELS_PER_CHANNEL);
                    end
                end
            end
        end
    end

    //==========================================================================
    // Debug monitors and Power Sequencing
    //==========================================================================

    // Power sequencing timing verification
    time avdd1_on_time, avdd2_on_time;
    time avdd1_off_time, avdd2_off_time;
    reg power_valid;

    initial begin
        power_valid = 0;
        avdd1_on_time = 0;
        avdd2_on_time = 0;
    end

    // Monitor AVDD1 transitions
    always @(ROIC_AVDD1) begin
        if (ROIC_AVDD1) begin
            avdd1_on_time = $time;
            $display("[AFE2256 POWER] AVDD1 ON at time %0t", $time);
        end else begin
            avdd1_off_time = $time;
            $display("[AFE2256 POWER] AVDD1 OFF at time %0t", $time);
            if (avdd1_on_time > 0) begin
                $display("[AFE2256 POWER] AVDD1 was ON for %0dns", avdd1_off_time - avdd1_on_time);
            end
        end
    end

    // Monitor AVDD2 transitions
    always @(ROIC_AVDD2) begin
        if (ROIC_AVDD2) begin
            avdd2_on_time = $time;
            $display("[AFE2256 POWER] AVDD2 ON at time %0t", $time);
        end else begin
            avdd2_off_time = $time;
            $display("[AFE2256 POWER] AVDD2 OFF at time %0t", $time);
            if (avdd2_on_time > 0) begin
                $display("[AFE2256 POWER] AVDD2 was ON for %0dns", avdd2_off_time - avdd2_on_time);
            end
        end
    end

    // Combined power state monitoring
    always @(ROIC_AVDD1, ROIC_AVDD2) begin
        if (ROIC_AVDD1 && ROIC_AVDD2) begin
            if (!power_valid) begin
                power_valid = 1;
                $display("[AFE2256 POWER] Both rails ON - ROIC operational at time %0t", $time);

                // Check power-up sequence timing (datasheet: AVDD1 and AVDD2 can be simultaneous)
                if (avdd1_on_time > 0 && avdd2_on_time > 0) begin
                    if (avdd1_on_time != avdd2_on_time) begin
                        $display("[AFE2256 POWER] Warning: AVDD1/AVDD2 not simultaneous (delta=%0dns)",
                                 avdd1_on_time > avdd2_on_time ? avdd1_on_time - avdd2_on_time : avdd2_on_time - avdd1_on_time);
                    end
                end
            end
        end else begin
            if (power_valid) begin
                power_valid = 0;
                $display("[AFE2256 POWER] Power rails OFF - ROIC inactive at time %0t", $time);

                // Abort active frame if any
                if (frame_active) begin
                    $display("[AFE2256 ERROR] Frame aborted due to power loss at pixel %0d", pixel_count);
                    frame_active = 0;
                end
            end
        end
    end

    // Monitor mode changes
    always @(operation_mode) begin
        case (operation_mode)
            2'b00: $display("[AFE2256 MODE] NORMAL at time %0t", $time);
            2'b01: $display("[AFE2256 MODE] TEST PATTERN at time %0t", $time);
            2'b10: $display("[AFE2256 MODE] SLEEP at time %0t", $time);
            default: $display("[AFE2256 MODE] UNKNOWN at time %0t", $time);
        endcase
    end

    // Monitor test pattern changes
    always @(test_pattern_enable, test_pattern_sel) begin
        if (test_pattern_enable) begin
            case (test_pattern_sel)
                5'h00: $display("[AFE2256 TEST] Pattern: NORMAL (sensor data)");
                5'h11: $display("[AFE2256 TEST] Pattern: ROW/COLUMN (0xAAAA/0x55)");
                5'h13: $display("[AFE2256 TEST] Pattern: RAMP (incremental)");
                5'h17: $display("[AFE2256 TEST] Pattern: ALL ZEROS");
                5'h19: $display("[AFE2256 TEST] Pattern: ALL ONES");
                5'h1E: $display("[AFE2256 TEST] Pattern: SYNC/DESKEW (0xFFF0/0xAA)");
                default: $display("[AFE2256 TEST] Pattern: 0x%02X (unknown)", test_pattern_sel);
            endcase
        end
    end

endmodule
