//==============================================================================
// File: afe2256_lvds_receiver.sv
// Description: 14-Channel LVDS Receiver for AFE2256 ROIC
//              - Integrates deserializer and reconstructor for each channel
//              - Supports 1-14 channels (configurable)
//              - Aggregates pixel data from all channels
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.0
//==============================================================================

`timescale 1ns / 1ps

module afe2256_lvds_receiver
    import afe2256_lvds_pkg::*;
#(
    parameter NUM_CHANNELS = 14     // Number of LVDS channels (1-14)
)(
    // System interface
    input  wire clk_sys,            // System clock (100 MHz)
    input  wire rst_n,              // Active LOW reset

    // LVDS differential inputs [0:NUM_CHANNELS-1]
    input  wire [NUM_CHANNELS-1:0] dclk_p,
    input  wire [NUM_CHANNELS-1:0] dclk_n,
    input  wire [NUM_CHANNELS-1:0] fclk_p,
    input  wire [NUM_CHANNELS-1:0] fclk_n,
    input  wire [NUM_CHANNELS-1:0] dout_p,
    input  wire [NUM_CHANNELS-1:0] dout_n,

    // Parallel pixel output (per channel)
    output wire [NUM_CHANNELS-1:0][11:0] pixel_data,
    output wire [NUM_CHANNELS-1:0][11:0] align_vector,
    output wire [NUM_CHANNELS-1:0]       pixel_valid,
    output wire [NUM_CHANNELS-1:0]       line_start,
    output wire [NUM_CHANNELS-1:0]       frame_start,

    // Status signals
    output wire [NUM_CHANNELS-1:0]       ch_locked,
    output wire [NUM_CHANNELS-1:0]       ch_aligned,
    output wire [NUM_CHANNELS-1:0][3:0]  ch_errors
);

    //==========================================================================
    // Generate LVDS Receivers for Each Channel
    //==========================================================================

    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : lvds_channel

            // Internal signals for this channel
            wire [3:0] deser_data;
            wire       deser_valid;
            wire       deser_frame_sync;
            wire       deser_bit_aligned;
            wire       deser_locked;
            wire [3:0] deser_errors;
            wire       ch_clkdiv;

            //------------------------------------------------------------------
            // Deserializer Instance
            //------------------------------------------------------------------
            afe2256_lvds_deserializer deser_inst (
                .clk_sys      (clk_sys),
                .rst_n        (rst_n),

                // LVDS inputs
                .dclk_p       (dclk_p[i]),
                .dclk_n       (dclk_n[i]),
                .fclk_p       (fclk_p[i]),
                .fclk_n       (fclk_n[i]),
                .dout_p       (dout_p[i]),
                .dout_n       (dout_n[i]),

                // Deserialized output
                .clkdiv_out   (ch_clkdiv),
                .data_out     (deser_data),
                .data_valid   (deser_valid),
                .frame_sync   (deser_frame_sync),
                .bit_aligned  (deser_bit_aligned),

                // Status
                .dclk_locked  (deser_locked),
                .error_flags  (deser_errors)
            );

            //------------------------------------------------------------------
            // Reconstructor Instance
            //------------------------------------------------------------------
            afe2256_lvds_reconstructor recon_inst (
                .clk          (ch_clkdiv),
                .rst_n        (rst_n),

                // Input from deserializer
                .data_in      (deser_data),
                .data_valid   (deser_valid),
                .frame_sync   (deser_frame_sync),
                .bit_aligned  (deser_bit_aligned),

                // 24-bit parallel output
                .pixel_data   (pixel_data[i]),
                .align_vector (align_vector[i]),
                .pixel_valid  (pixel_valid[i]),
                .line_start   (line_start[i]),
                .frame_start  (frame_start[i])
            );

            //------------------------------------------------------------------
            // Status Assignment
            //------------------------------------------------------------------
            assign ch_locked[i]  = deser_locked;
            assign ch_aligned[i] = deser_bit_aligned;
            assign ch_errors[i]  = deser_errors;

        end
    endgenerate

endmodule : afe2256_lvds_receiver
