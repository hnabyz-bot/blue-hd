//==============================================================================
// File: afe2256_lvds_reconstructor.sv
// Description: 24-bit Parallel Data Reconstructor
//              - Converts 4-bit deserialized data to 24-bit parallel
//              - Extracts pixel data (12-bit) and alignment vector (12-bit)
//              - Handles frame synchronization
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.0
//==============================================================================

`timescale 1ns / 1ps

module afe2256_lvds_reconstructor
    import afe2256_lvds_pkg::*;
(
    // Clock and Reset
    input  wire        clk,           // clkdiv (DCLK/4)
    input  wire        rst_n,         // Active LOW reset

    // Input from deserializer (4-bit data stream)
    input  wire [3:0]  data_in,       // 4-bit parallel data
    input  wire        data_valid,    // Data valid flag
    input  wire        frame_sync,    // Frame sync pulse
    input  wire        bit_aligned,   // Bit alignment status

    // 24-bit parallel output
    output reg  [11:0] pixel_data,    // 12-bit pixel value
    output reg  [11:0] align_vector,  // 12-bit alignment/sync vector
    output reg         pixel_valid,   // Pixel data valid
    output reg         line_start,    // Start of line
    output reg         frame_start    // Start of frame
);

    //==========================================================================
    // Internal Registers
    //==========================================================================

    // 24-bit shift register (6 × 4-bit chunks)
    reg [23:0] shift_reg;
    reg [2:0]  chunk_cnt;       // Counter: 0-5 (6 chunks for 24 bits)
    reg        word_ready;

    // Frame state
    typedef enum logic [1:0] {
        WAIT_FRAME  = 2'b00,
        WAIT_LINE   = 2'b01,
        CAPTURE     = 2'b10
    } frame_state_t;

    frame_state_t state;

    // Line and pixel counters
    reg [8:0]  pixel_cnt;       // 0-255 (256 pixels per line)
    reg [7:0]  line_cnt;        // Line counter

    //==========================================================================
    // 24-bit Word Reconstruction
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 24'h000000;
            chunk_cnt  <= 3'd0;
            word_ready <= 1'b0;
        end else begin
            if (data_valid && bit_aligned) begin
                // Shift in 4-bit chunk (MSB first)
                shift_reg <= {shift_reg[19:0], data_in};

                if (chunk_cnt == 3'd5) begin
                    // 6th chunk complete - 24 bits ready
                    chunk_cnt  <= 3'd0;
                    word_ready <= 1'b1;
                end else begin
                    chunk_cnt  <= chunk_cnt + 1'b1;
                    word_ready <= 1'b0;
                end
            end else begin
                word_ready <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Frame and Line State Machine
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= WAIT_FRAME;
            pixel_cnt   <= 9'd0;
            line_cnt    <= 8'd0;
            frame_start <= 1'b0;
            line_start  <= 1'b0;
        end else begin
            case (state)
                WAIT_FRAME: begin
                    frame_start <= 1'b0;
                    line_start  <= 1'b0;

                    if (frame_sync) begin
                        state       <= WAIT_LINE;
                        frame_start <= 1'b1;
                        line_cnt    <= 8'd0;
                    end
                end

                WAIT_LINE: begin
                    frame_start <= 1'b0;

                    if (word_ready) begin
                        state      <= CAPTURE;
                        line_start <= 1'b1;
                        pixel_cnt  <= 9'd0;
                    end
                end

                CAPTURE: begin
                    line_start <= 1'b0;

                    if (word_ready) begin
                        if (pixel_cnt == 9'd255) begin
                            // End of line
                            pixel_cnt <= 9'd0;
                            line_cnt  <= line_cnt + 1'b1;

                            if (frame_sync) begin
                                // New frame detected
                                state       <= WAIT_FRAME;
                                frame_start <= 1'b1;
                            end else begin
                                state      <= WAIT_LINE;
                                line_start <= 1'b1;
                            end
                        end else begin
                            pixel_cnt <= pixel_cnt + 1'b1;
                        end
                    end
                end

                default: state <= WAIT_FRAME;
            endcase
        end
    end

    //==========================================================================
    // Pixel Data Extraction
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_data   <= 12'h000;
            align_vector <= 12'h000;
            pixel_valid  <= 1'b0;
        end else begin
            if (word_ready && (state == CAPTURE)) begin
                // Extract pixel and alignment data from 24-bit word
                // AFE2256 format: [23:12] = Pixel, [11:0] = Alignment/Sync
                pixel_data   <= shift_reg[23:12];
                align_vector <= shift_reg[11:0];
                pixel_valid  <= 1'b1;
            end else begin
                pixel_valid <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Assertions for Simulation
    //==========================================================================

    `ifdef SIMULATION
        // Check chunk counter range
        property chunk_cnt_range;
            @(posedge clk) disable iff (!rst_n)
            (chunk_cnt <= 3'd5);
        endproperty
        assert property (chunk_cnt_range)
            else $error("Chunk counter out of range");

        // Check pixel counter range
        property pixel_cnt_range;
            @(posedge clk) disable iff (!rst_n)
            (state == CAPTURE) |-> (pixel_cnt < 9'd256);
        endproperty
        assert property (pixel_cnt_range)
            else $error("Pixel counter out of range");

        // Check word ready timing
        property word_ready_timing;
            @(posedge clk) disable iff (!rst_n)
            (chunk_cnt == 3'd5 && data_valid) |-> ##1 word_ready;
        endproperty
        assert property (word_ready_timing)
            else $warning("Word ready timing violation");
    `endif

endmodule : afe2256_lvds_reconstructor
