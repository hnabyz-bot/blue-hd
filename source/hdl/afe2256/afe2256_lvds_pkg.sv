//==============================================================================
// File: afe2256_lvds_pkg.sv
// Description: AFE2256 ROIC LVDS Interface Package
//              - LVDS DDR deserialization parameters
//              - Data format definitions
//              - Timing parameters
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.0
//==============================================================================

package afe2256_lvds_pkg;

    //==========================================================================
    // LVDS Interface Parameters
    //==========================================================================

    // ISERDES2 Configuration
    localparam int DESER_FACTOR = 4;        // 1:4 deserialization ratio
    localparam string DATA_RATE = "DDR";    // Double Data Rate
    localparam int PIXEL_WIDTH = 12;        // 12-bit pixel data
    localparam int ALIGN_WIDTH = 12;        // 12-bit alignment vector
    localparam int TOTAL_WIDTH = 24;        // Total parallel width

    // Number of channels per ROIC
    localparam int CHANNELS_PER_ROIC = 256;

    // Frame timing (example for STR=1024 MCLK @ 10 MHz)
    localparam int LINE_PIXELS = 256;       // Pixels per line
    localparam real LINE_TIME_US = 102.4;   // Line time in microseconds

    //==========================================================================
    // LVDS Signal Configuration
    //==========================================================================

    typedef struct packed {
        logic dclk_p;    // Data clock positive
        logic dclk_n;    // Data clock negative
        logic fclk_p;    // Frame clock positive
        logic fclk_n;    // Frame clock negative
        logic dout_p;    // Data output positive
        logic dout_n;    // Data output negative
    } lvds_signals_t;

    //==========================================================================
    // Deserialized Data Format
    //==========================================================================

    typedef struct packed {
        logic [PIXEL_WIDTH-1:0] pixel_data;   // 12-bit pixel value
        logic [ALIGN_WIDTH-1:0] align_vector; // 12-bit alignment/sync
        logic                   frame_valid;  // Frame sync indicator
        logic                   line_valid;   // Line valid indicator
    } lvds_data_t;

    //==========================================================================
    // Bit Alignment Patterns (from AFE2256 datasheet)
    //==========================================================================

    // Sync/Deskew pattern (TEST_PATTERN_SEL = 1Eh)
    localparam logic [11:0] SYNC_PATTERN_HIGH = 12'hFFF;  // First 12 bits
    localparam logic [11:0] SYNC_PATTERN_LOW  = 12'h000;  // Second 12 bits

    // Row/Column test pattern (TEST_PATTERN_SEL = 11h)
    localparam logic [11:0] ROW_PATTERN = 12'hAAA;        // 101010...
    localparam logic [11:0] COL_PATTERN = 12'h555;        // 010101...

    //==========================================================================
    // Clock Frequency Ranges (DCLK)
    //==========================================================================

    // MCLK = 10 MHz, STR = 1024
    localparam real DCLK_FREQ_10M_1024 = 2.34e6;  // ~2.34 MHz

    // MCLK = 20 MHz, STR = 1024
    localparam real DCLK_FREQ_20M_1024 = 4.69e6;  // ~4.69 MHz

    // MCLK = 10 MHz, STR = 512
    localparam real DCLK_FREQ_10M_512  = 4.69e6;  // ~4.69 MHz

    //==========================================================================
    // ISERDES2 State Machine
    //==========================================================================

    typedef enum logic [2:0] {
        IDLE        = 3'b000,   // Waiting for valid DCLK
        ALIGN       = 3'b001,   // Bit alignment in progress
        SYNC        = 3'b010,   // Frame synchronization
        CAPTURE     = 3'b011,   // Active data capture
        ERROR       = 3'b100    // Error state
    } deser_state_t;

endpackage : afe2256_lvds_pkg
