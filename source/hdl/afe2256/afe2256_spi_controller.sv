//==============================================================================
// File: afe2256_spi_controller.sv
// Description: AFE2256 ROIC SPI Master Controller
//              - 24-bit SPI protocol (8-bit addr + 16-bit data)
//              - Write-only operation (Phase 1)
//              - CPOL=0, CPHA=0 (Mode 0)
//              - MSB First transmission
//              - 10 MHz SPI clock from 100 MHz system clock
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.1
//==============================================================================

module afe2256_spi_controller
    import afe2256_spi_pkg::*;
#(
    parameter NUM_ROICS = 1,           // Number of ROIC devices (1-16)
    parameter CLK_FREQ_MHZ = 100,      // System clock frequency (MHz)
    parameter SPI_FREQ_MHZ = 10        // SPI clock frequency (MHz)
)(
    // Clock and Reset
    input  wire clk,                   // System clock (100 MHz)
    input  wire rst_n,                 // Active LOW reset

    // Register Write Interface
    input  wire [7:0]  reg_addr,       // Register address (8-bit)
    input  wire [15:0] reg_wdata,      // Write data (16-bit)
    input  wire        reg_wr,         // Write request (1 cycle pulse)
    output reg         busy,           // Controller busy flag
    output reg         done,           // Transfer done (1 cycle pulse)

    // SPI Physical Interface
    output reg                    spi_sck,   // SPI Clock (10 MHz)
    output reg                    spi_sdi,   // SPI Data Out (FPGA → ROIC)
    input  wire [NUM_ROICS-1:0]   spi_sdo,   // SPI Data In (ROIC → FPGA, unused in Phase 1)
    output reg  [NUM_ROICS-1:0]   spi_sen_n  // Chip Select (Active LOW)
);

    //==========================================================================
    // Local Parameters
    //==========================================================================

    localparam int CLK_DIV = CLK_FREQ_MHZ / SPI_FREQ_MHZ;  // Clock divider = 10
    localparam int CLK_DIV_WIDTH = $clog2(CLK_DIV);        // Counter width

    //==========================================================================
    // FSM States
    //==========================================================================

    typedef enum logic [2:0] {
        IDLE   = 3'b000,   // Waiting for write request
        START  = 3'b001,   // Assert SEN (chip select)
        SHIFT  = 3'b010,   // Shift out 24 bits
        LOAD   = 3'b011,   // Deassert SEN, load register
        DONE   = 3'b100    // Generate done pulse
    } spi_state_t;

    spi_state_t state, next_state;

    //==========================================================================
    // Internal Signals
    //==========================================================================

    // Clock generation
    reg [CLK_DIV_WIDTH-1:0] clk_cnt;
    reg                     spi_clk_en;      // SPI clock enable pulse
    reg                     sck_int;         // Internal SCK (before output)

    // Shift register
    reg [SPI_TOTAL_BITS-1:0] shift_reg;      // 24-bit shift register
    reg [4:0]                 bit_cnt;        // Bit counter (0-23)

    // Control signals
    reg sen_n_int;                            // Internal SEN

    //==========================================================================
    // SPI Clock Generation (100 MHz → 10 MHz)
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt    <= '0;
            spi_clk_en <= 1'b0;
        end else begin
            if (state == SHIFT) begin
                if (clk_cnt == (CLK_DIV/2)-1) begin
                    clk_cnt    <= '0;
                    spi_clk_en <= 1'b1;
                end else begin
                    clk_cnt    <= clk_cnt + 1'b1;
                    spi_clk_en <= 1'b0;
                end
            end else begin
                clk_cnt    <= '0;
                spi_clk_en <= 1'b0;
            end
        end
    end

    //==========================================================================
    // SPI Clock (SCK) Generation
    // CPOL=0: Idle state is LOW
    // CPHA=0: Data captured on rising edge, shifted on falling edge
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_int <= 1'b0;
        end else begin
            if (state == SHIFT && spi_clk_en) begin
                sck_int <= ~sck_int;  // Toggle clock
            end else begin
                sck_int <= 1'b0;      // Idle LOW (CPOL=0)
            end
        end
    end

    //==========================================================================
    // FSM State Register
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    //==========================================================================
    // FSM Next State Logic
    //==========================================================================

    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (reg_wr)
                    next_state = START;
            end

            START: begin
                next_state = SHIFT;
            end

            SHIFT: begin
                if (spi_clk_en && !sck_int && bit_cnt == 24)
                    next_state = LOAD;
            end

            LOAD: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    //==========================================================================
    // Shift Register and Bit Counter
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (reg_wr) begin
                        // Load shift register with address and data (MSB first)
                        shift_reg <= {reg_addr, reg_wdata};
                        bit_cnt   <= '0;
                    end
                end

                SHIFT: begin
                    if (spi_clk_en && !sck_int) begin
                        // Shift on falling edge (CPHA=0)
                        shift_reg <= {shift_reg[SPI_TOTAL_BITS-2:0], 1'b0};
                        bit_cnt   <= bit_cnt + 1'b1;
                    end
                end

                LOAD: begin
                    bit_cnt <= '0;
                end

                default: begin
                    // Hold values
                end
            endcase
        end
    end

    //==========================================================================
    // SEN (Chip Select) Control
    // Active LOW during START, SHIFT, LOAD states
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sen_n_int <= 1'b1;  // Inactive HIGH
        end else begin
            case (state)
                START, SHIFT, LOAD: begin
                    sen_n_int <= 1'b0;  // Active LOW
                end

                default: begin
                    sen_n_int <= 1'b1;  // Inactive HIGH
                end
            endcase
        end
    end

    //==========================================================================
    // Output Signal Assignment
    //==========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_sck   <= 1'b0;
            spi_sdi   <= 1'b0;
            spi_sen_n <= '1;   // All chip selects inactive
            busy      <= 1'b0;
            done      <= 1'b0;
        end else begin
            // SPI Clock
            spi_sck <= sck_int;

            // SPI Data Out (MSB of shift register)
            // Output is valid from START state through SHIFT state
            if (state == START || state == SHIFT || state == LOAD) begin
                spi_sdi <= shift_reg[SPI_TOTAL_BITS-1];
            end else begin
                spi_sdi <= 1'b0;
            end

            // Chip Select (broadcast to all ROICs in Phase 1)
            spi_sen_n <= {NUM_ROICS{sen_n_int}};

            // Busy flag
            busy <= (state != IDLE) && (state != DONE);

            // Done pulse (1 cycle)
            done <= (state == DONE);
        end
    end

    //==========================================================================
    // Assertions for Simulation
    //==========================================================================

    `ifdef SIMULATION
        // Check SPI clock frequency (10 MHz = 5 system clocks per toggle)
        property spi_clk_freq;
            @(posedge clk) disable iff (!rst_n)
            (state == SHIFT && spi_clk_en) |=> ##5 spi_clk_en;
        endproperty
        assert property (spi_clk_freq)
            else $warning("SPI clock frequency deviation detected");

        // Check 24-bit transfer duration
        // 24 bits × 2 edges × 5 clocks = 240 system clocks + overhead
        property spi_24bit_transfer;
            @(posedge clk) disable iff (!rst_n)
            (state == START) |-> ##[240:260] (state == LOAD);
        endproperty
        assert property (spi_24bit_transfer)
            else $error("SPI transfer did not complete 24 bits correctly");

        // Check SEN timing (Active LOW during START, SHIFT, LOAD)
        property sen_active_during_transfer;
            @(posedge clk) disable iff (!rst_n)
            (state == START) |-> (sen_n_int == 1'b0) throughout (state != DONE);
        endproperty
        assert property (sen_active_during_transfer)
            else $error("SEN not active during SPI transfer");

        // Check CPOL=0 (SCK idle LOW)
        property sck_idle_low;
            @(posedge clk) disable iff (!rst_n)
            (state == IDLE || state == DONE) |-> (sck_int == 1'b0);
        endproperty
        assert property (sck_idle_low)
            else $error("CPOL=0 violation: SCK not LOW when idle");

        // Check bit counter range
        property bit_cnt_range;
            @(posedge clk) disable iff (!rst_n)
            (state == SHIFT) |-> (bit_cnt <= 24);
        endproperty
        assert property (bit_cnt_range)
            else $error("Bit counter out of range");
    `endif

endmodule : afe2256_spi_controller
