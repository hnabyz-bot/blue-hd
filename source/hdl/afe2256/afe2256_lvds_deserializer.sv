//==============================================================================
// File: afe2256_lvds_deserializer.sv
// Description: AFE2256 LVDS Deserializer (Single Channel)
//              - Uses Xilinx ISERDES2 for 1:4 DDR deserialization
//              - Handles DCLK, FCLK, DOUT differential pairs
//              - Bit alignment and frame synchronization
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.0
//==============================================================================

`timescale 1ns / 1ps

module afe2256_lvds_deserializer
    import afe2256_lvds_pkg::*;
(
    // System interface
    input  wire clk_sys,          // System clock (100 MHz)
    input  wire rst_n,            // Active LOW reset

    // LVDS differential inputs
    input  wire dclk_p,           // Data clock positive
    input  wire dclk_n,           // Data clock negative
    input  wire fclk_p,           // Frame clock positive
    input  wire fclk_n,           // Frame clock negative
    input  wire dout_p,           // Data output positive
    input  wire dout_n,           // Data output negative

    // Deserialized output (clkdiv domain)
    output wire        clkdiv_out, // Divided clock output (DCLK/4)
    output reg  [3:0]  data_out,   // 4-bit parallel data (1:4 deser)
    output reg         data_valid,
    output reg         frame_sync,
    output reg         bit_aligned,

    // Status
    output reg         dclk_locked,
    output reg  [3:0]  error_flags
);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Differential to single-ended buffers
    wire dclk_buf;
    wire fclk_buf;
    wire dout_buf;

    // Clock management
    wire ioclk;          // IO clock (same as DCLK)
    wire clkdiv;         // Divided clock (DCLK/4) from BUFR

    // ISERDES2 outputs
    wire [3:0] iserdes_data;
    wire [3:0] iserdes_fclk;

    // Bit alignment
    reg  [2:0] bitslip_cnt;
    reg        bitslip;
    reg  [7:0] align_detect_cnt;
    reg        alignment_done;

    // Frame detection
    reg  [11:0] fclk_shift_reg;
    reg         fclk_edge_detected;

    //==========================================================================
    // Differential Input Buffers
    //==========================================================================

    IBUFDS #(
        .DIFF_TERM("TRUE"),         // Enable differential termination
        .IOSTANDARD("LVDS_25")
    ) ibufds_dclk (
        .I  (dclk_p),
        .IB (dclk_n),
        .O  (dclk_buf)
    );

    IBUFDS #(
        .DIFF_TERM("TRUE"),
        .IOSTANDARD("LVDS_25")
    ) ibufds_fclk (
        .I  (fclk_p),
        .IB (fclk_n),
        .O  (fclk_buf)
    );

    IBUFDS #(
        .DIFF_TERM("TRUE"),
        .IOSTANDARD("LVDS_25")
    ) ibufds_dout (
        .I  (dout_p),
        .IB (dout_n),
        .O  (dout_buf)
    );

    //==========================================================================
    // Clock Buffers
    //==========================================================================

    // IO Clock Buffer (for ISERDES2 high-speed clock)
    BUFIO bufio_inst (
        .I (dclk_buf),
        .O (ioclk)
    );

    // Regional Clock Buffer with divider (DCLK/4)
    // BUFR output is used directly (regional clock, no BUFG)
    // This saves BUFG resources (14 channels × 1 BUFG = 14 saved)
    // Deserializer and Reconstructor must be in same clock region
    BUFR #(
        .BUFR_DIVIDE("4"),
        .SIM_DEVICE("7SERIES")
    ) bufr_inst (
        .I   (dclk_buf),
        .O   (clkdiv),
        .CLR (1'b0),
        .CE  (1'b1)
    );

    // Export clkdiv directly from BUFR (regional clock)
    assign clkdiv_out = clkdiv;

    //==========================================================================
    // ISERDES2 for DOUT (Data Deserialization)
    //==========================================================================

    ISERDES2 #(
        .DATA_RATE      ("DDR"),        // DDR mode
        .DATA_WIDTH     (4),            // 1:4 deserialization
        .BITSLIP_ENABLE ("TRUE"),       // Enable bit alignment
        .SERDES_MODE    ("MASTER"),     // Master mode
        .INTERFACE_TYPE ("RETIMED")     // Retimed interface
    ) iserdes_dout (
        .D          (dout_buf),         // Serial data input
        .CLK0       (ioclk),            // IO clock
        .CLK1       (~ioclk),           // Inverted IO clock
        .CLKDIV     (clkdiv),           // Divided clock from BUFR
        .IOCE       (1'b1),             // IO clock enable
        .RST        (~rst_n),           // Active HIGH reset
        .BITSLIP    (bitslip),          // Bit alignment control
        .CE0        (1'b1),             // Clock enable
        .Q4         (iserdes_data[3]),  // MSB
        .Q3         (iserdes_data[2]),
        .Q2         (iserdes_data[1]),
        .Q1         (iserdes_data[0]),  // LSB
        // Unused cascade ports
        .FABRICOUT  (),
        .INCDEC     (),
        .VALID      (),
        .SHIFTIN    (1'b0),
        .SHIFTOUT   ()
    );

    //==========================================================================
    // ISERDES2 for FCLK (Frame Clock Deserialization)
    //==========================================================================

    ISERDES2 #(
        .DATA_RATE      ("DDR"),
        .DATA_WIDTH     (4),
        .BITSLIP_ENABLE ("FALSE"),      // No bitslip for FCLK
        .SERDES_MODE    ("MASTER"),
        .INTERFACE_TYPE ("RETIMED")
    ) iserdes_fclk (
        .D          (fclk_buf),
        .CLK0       (ioclk),
        .CLK1       (~ioclk),
        .CLKDIV     (clkdiv),           // Divided clock from BUFR
        .IOCE       (1'b1),
        .RST        (~rst_n),
        .BITSLIP    (1'b0),
        .CE0        (1'b1),
        .Q4         (iserdes_fclk[3]),
        .Q3         (iserdes_fclk[2]),
        .Q2         (iserdes_fclk[1]),
        .Q1         (iserdes_fclk[0]),
        .FABRICOUT  (),
        .INCDEC     (),
        .VALID      (),
        .SHIFTIN    (1'b0),
        .SHIFTOUT   ()
    );

    //==========================================================================
    // Bit Alignment State Machine
    //==========================================================================

    deser_state_t align_state;

    always_ff @(posedge clkdiv or negedge rst_n) begin
        if (!rst_n) begin
            align_state       <= IDLE;
            bitslip           <= 1'b0;
            bitslip_cnt       <= 3'd0;
            align_detect_cnt  <= 8'd0;
            alignment_done    <= 1'b0;
        end else begin
            case (align_state)
                IDLE: begin
                    if (dclk_locked) begin
                        align_state <= ALIGN;
                    end
                end

                ALIGN: begin
                    if (bitslip) begin
                        // Clear bitslip after 1 cycle
                        bitslip <= 1'b0;
                    end else begin
                        // Check for sync pattern (0xFFF000 = 12'hFFF + 12'h000)
                        // In 4-bit chunks: F, F, F, 0, 0, 0
                        if (iserdes_data == 4'hF) begin
                            align_detect_cnt <= align_detect_cnt + 1'b1;
                            if (align_detect_cnt >= 8'd10) begin
                                alignment_done <= 1'b1;
                                align_state    <= SYNC;
                            end
                        end else if (bitslip_cnt < 3'd4) begin
                            // Try next bit alignment
                            bitslip     <= 1'b1;
                            bitslip_cnt <= bitslip_cnt + 1'b1;
                            align_detect_cnt <= 8'd0;
                        end else begin
                            // Failed to align after 4 attempts
                            align_state <= ERROR;
                        end
                    end
                end

                SYNC: begin
                    bitslip <= 1'b0;
                    if (fclk_edge_detected) begin
                        align_state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    // Normal operation - data capture
                    if (!dclk_locked) begin
                        align_state <= IDLE;
                        alignment_done <= 1'b0;
                    end
                end

                ERROR: begin
                    // Error state - wait for reset
                    if (!dclk_locked) begin
                        align_state    <= IDLE;
                        bitslip_cnt    <= 3'd0;
                        alignment_done <= 1'b0;
                    end
                end

                default: align_state <= IDLE;
            endcase
        end
    end

    //==========================================================================
    // Frame Clock Edge Detection
    //==========================================================================

    always_ff @(posedge clkdiv or negedge rst_n) begin
        if (!rst_n) begin
            fclk_shift_reg     <= 12'h000;
            fclk_edge_detected <= 1'b0;
        end else begin
            fclk_shift_reg <= {fclk_shift_reg[7:0], iserdes_fclk};

            // Detect rising edge: ...0000_1111...
            if (fclk_shift_reg[11:8] == 4'h0 && fclk_shift_reg[7:4] == 4'hF) begin
                fclk_edge_detected <= 1'b1;
            end else begin
                fclk_edge_detected <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Clock Lock Detector
    //==========================================================================

    reg [15:0] dclk_toggle_cnt;
    reg [15:0] lock_timer;

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            dclk_toggle_cnt <= 16'd0;
            lock_timer      <= 16'd0;
            dclk_locked     <= 1'b0;
        end else begin
            // Simplified lock detection - assumes DCLK is present
            if (lock_timer < 16'd10000) begin
                lock_timer <= lock_timer + 1'b1;
            end else begin
                dclk_locked <= 1'b1;
            end
        end
    end

    //==========================================================================
    // Output Assignment
    //==========================================================================

    always_ff @(posedge clkdiv or negedge rst_n) begin
        if (!rst_n) begin
            data_out    <= 4'h0;
            data_valid  <= 1'b0;
            frame_sync  <= 1'b0;
            bit_aligned <= 1'b0;
        end else begin
            data_out    <= iserdes_data;
            data_valid  <= (align_state == CAPTURE);
            frame_sync  <= fclk_edge_detected;
            bit_aligned <= alignment_done;
        end
    end

    //==========================================================================
    // Error Flags
    //==========================================================================

    always_ff @(posedge clkdiv or negedge rst_n) begin
        if (!rst_n) begin
            error_flags <= 4'h0;
        end else begin
            error_flags[0] <= ~dclk_locked;           // DCLK not locked
            error_flags[1] <= ~alignment_done;        // Bit alignment failed
            error_flags[2] <= (align_state == ERROR); // FSM error state
            error_flags[3] <= 1'b0;                   // Reserved
        end
    end

endmodule : afe2256_lvds_deserializer
