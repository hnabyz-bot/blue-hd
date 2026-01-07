//==============================================================================
// File: reset_sync.sv
// Description: Reset Synchronizer Module
//              - Synchronizes asynchronous reset to clock domain
//              - Uses 2-stage synchronizer to prevent metastability
// Author: Claude Code
// Date: 2026-01-07
// Version: 1.0
//==============================================================================

`timescale 1ns / 1ps

module reset_sync (
    input  wire clk,           // Target clock domain
    input  wire async_rst_n,   // Asynchronous reset (active LOW)
    output wire sync_rst_n     // Synchronized reset (active LOW)
);

    // Two-stage synchronizer for reset
    (* ASYNC_REG = "TRUE" *) reg sync_ff1;
    (* ASYNC_REG = "TRUE" *) reg sync_ff2;

    always_ff @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= 1'b1;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sync_rst_n = sync_ff2;

endmodule : reset_sync
