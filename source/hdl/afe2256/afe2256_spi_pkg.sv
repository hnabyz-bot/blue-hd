//==============================================================================
// File: afe2256_spi_pkg.sv
// Description: AFE2256 ROIC SPI Register Package
//              - Register addresses and initialization values
//              - Based on AFE2256 datasheet and initialization sequence
// Author: Claude Code
// Date: 2026-01-06
// Version: 1.1
//==============================================================================

package afe2256_spi_pkg;

    //==========================================================================
    // Register Addresses (8-bit)
    //==========================================================================

    // Control Registers
    typedef enum logic [7:0] {
        REG_RESET           = 8'h00,  // RESET[0], REG_READ[1]
        REG_TEST_PATTERN    = 8'h10,  // TEST_PATTERN_SEL[9:5], CONFIG_MODE[11]
        REG_STR             = 8'h11,  // STR[5:4], AUTO_REVERSE[13], REVERSE_SCAN[15]
        REG_ESSENTIAL_BIT2  = 8'h12,  // ESSENTIAL_BIT2[14]
        REG_POWER_DOWN      = 8'h13,  // Power mode control
        REG_ESSENTIAL_BITS  = 8'h16,  // ESSENTIAL_BITS5[7:6], ESSENTIAL_BIT6[3]
        REG_ESSENTIAL_BIT3  = 8'h18,  // ESSENTIAL_BIT3[0]
        REG_ESSENTIAL_BIT8  = 8'h2C,  // ESSENTIAL_BIT8[0]
        REG_TRIM_LOAD       = 8'h30,  // TRIM_LOAD[1]
        REG_DIE_ID_HIGH     = 8'h31,  // Die ID [47:32]
        REG_DIE_ID_MID      = 8'h32,  // Die ID [31:16]
        REG_DIE_ID_LOW      = 8'h33,  // Die ID [15:0]

        // Timing Profile Registers (40h-55h)
        REG_IRST            = 8'h40,  // IRST rise/fall edges
        REG_SHR             = 8'h42,  // SHR rise/fall edges
        REG_SHS             = 8'h43,  // SHS rise/fall edges
        REG_LPF1            = 8'h46,  // LPF1 on/off edges
        REG_LPF2            = 8'h47,  // LPF2 on/off edges
        REG_TDEF            = 8'h4A,  // TDEF enable/disable edges
        REG_GATE_DRIVER     = 8'h4B,  // Gate driver signal edges
        REG_DF_SM0          = 8'h50,  // Charge dump control [0]
        REG_DF_SM1          = 8'h51,  // Charge dump control [1]
        REG_DF_SM2          = 8'h52,  // Charge dump control [2]
        REG_DF_SM3          = 8'h53,  // Charge dump control [3]
        REG_DF_SM4          = 8'h54,  // Charge dump control [4]
        REG_DF_SM5          = 8'h55,  // Charge dump control [5]

        // Configuration Registers
        REG_PROBE_SIGNAL    = 8'h5A,  // TG signal probe select
        REG_INPUT_RANGE     = 8'h5C,  // INPUT_CHARGE_RANGE[15:11], LPF frequencies
        REG_POWER_MODE      = 8'h5D,  // POWER_MODE[1], ENB_TDEF[10], DFTV controls
        REG_INTG_MODE       = 8'h5E,  // INTG_MODE[12]
        REG_ESSENTIAL_BIT4  = 8'h61   // ESSENTIAL_BIT4[14]
    } afe2256_reg_addr_t;

    //==========================================================================
    // Register Values for Initialization
    //==========================================================================

    // Power Modes
    localparam logic [15:0] PWR_QUICK_WAKEUP    = 16'h0020;
    localparam logic [15:0] PWR_NAP_PLL_ON      = 16'hF827;
    localparam logic [15:0] PWR_NAP             = 16'hF8A7;
    localparam logic [15:0] PWR_DOWN_PLL_ON     = 16'hFD3F;
    localparam logic [15:0] PWR_DOWN            = 16'hFFBF;

    // Test Patterns
    localparam logic [15:0] TEST_NORMAL         = 16'h0000;
    localparam logic [15:0] TEST_ROW_COLUMN     = 16'h0220;  // TEST_PATTERN_SEL=11h
    localparam logic [15:0] TEST_RAMP           = 16'h0260;  // TEST_PATTERN_SEL=13h
    localparam logic [15:0] TEST_ALL_ZEROS      = 16'h02E0;  // TEST_PATTERN_SEL=17h
    localparam logic [15:0] TEST_ALL_ONES       = 16'h0320;  // TEST_PATTERN_SEL=19h
    localparam logic [15:0] TEST_SYNC_DESKEW    = 16'h03C0;  // TEST_PATTERN_SEL=1Eh (for bit alignment)

    // Input Charge Range (INPUT_CHARGE_RANGE[15:11])
    localparam logic [15:0] CHARGE_0P6_PC       = 16'h0800;  // 0.6 pC (01h << 11)
    localparam logic [15:0] CHARGE_1P2_PC       = 16'h1000;  // 1.2 pC (02h << 11)
    localparam logic [15:0] CHARGE_2P4_PC       = 16'h2000;  // 2.4 pC (04h << 11)
    localparam logic [15:0] CHARGE_4P8_PC       = 16'h4000;  // 4.8 pC (08h << 11)
    localparam logic [15:0] CHARGE_7P2_PC       = 16'h6000;  // 7.2 pC (0Ch << 11)
    localparam logic [15:0] CHARGE_9P6_PC       = 16'hF800;  // 9.6 pC (1Fh << 11)

    // Scan Time Range (STR[5:4])
    localparam logic [15:0] STR_256_MCLK        = 16'h0000;  // 256 MCLK (integrate-up only)
    localparam logic [15:0] STR_512_MCLK        = 16'h0010;  // 512 MCLK
    localparam logic [15:0] STR_1024_MCLK       = 16'h0020;  // 1024 MCLK
    localparam logic [15:0] STR_2048_MCLK       = 16'h0030;  // 2048 MCLK

    // Integration Modes
    localparam logic [15:0] INTG_INTEGRATE_UP   = 16'h0000;  // Integrate-up (electron)
    localparam logic [15:0] INTG_INTEGRATE_DOWN = 16'h1000;  // Integrate-down (hole)

    //==========================================================================
    // Initialization Sequence Structure
    //==========================================================================

    typedef struct packed {
        logic [7:0]  addr;      // Register address
        logic [15:0] data;      // Register data
        logic [15:0] delay_us;  // Delay after write (microseconds)
    } init_reg_t;

    // Number of initialization registers
    localparam int INIT_REG_COUNT = 14;

    // Initialization sequence for Integrate-up mode with 4.8pC range
    localparam init_reg_t INIT_SEQUENCE[INIT_REG_COUNT] = '{
        // 1. Soft Reset
        '{addr: REG_RESET,          data: 16'h0001, delay_us: 16'd10000},  // RESET[0]=1, wait 10ms

        // 2. TRIM_LOAD (CRITICAL - Required after power cycle)
        '{addr: REG_TRIM_LOAD,      data: 16'h0002, delay_us: 16'd5000},   // TRIM_LOAD[1]=1, wait 5ms

        // 3. Essential Bits Configuration (Integrate-up mode)
        '{addr: REG_STR,            data: 16'h2830, delay_us: 16'd0},      // STR=2 (1024 MCLK), AUTO_REVERSE=1, ESSENTIAL_BIT1=1
        '{addr: REG_ESSENTIAL_BIT2, data: 16'h4000, delay_us: 16'd0},      // ESSENTIAL_BIT2=1 (for integrate-up)
        '{addr: REG_ESSENTIAL_BITS, data: 16'h00C0, delay_us: 16'd0},      // ESSENTIAL_BITS5=11b, ESSENTIAL_BIT6=0 (Normal-power)
        '{addr: REG_ESSENTIAL_BIT3, data: 16'h0001, delay_us: 16'd0},      // ESSENTIAL_BIT3=1
        '{addr: REG_ESSENTIAL_BIT8, data: 16'h0000, delay_us: 16'd0},      // ESSENTIAL_BIT8=0 (for integrate-up)
        '{addr: REG_ESSENTIAL_BIT4, data: 16'h4000, delay_us: 16'd0},      // ESSENTIAL_BIT4=1

        // 4. Operating Mode Configuration
        '{addr: REG_INTG_MODE,      data: 16'h0000, delay_us: 16'd0},      // INTG_MODE=0 (Integrate-up)
        '{addr: REG_INPUT_RANGE,    data: 16'h4800, delay_us: 16'd0},      // INPUT_CHARGE_RANGE=4.8pC
        '{addr: REG_POWER_MODE,     data: 16'h0002, delay_us: 16'd0},      // POWER_MODE=1 (Low-noise mode)

        // 5. Quick Wakeup Mode
        '{addr: REG_POWER_DOWN,     data: 16'h0020, delay_us: 16'd0},      // Quick wakeup

        // 6. Test Pattern for Bit Alignment (to be disabled after alignment)
        '{addr: REG_TEST_PATTERN,   data: 16'h03C0, delay_us: 16'd0},      // Sync/deskew pattern (0xFFF000)

        // 7. Normal Mode (after bit alignment is done)
        '{addr: REG_TEST_PATTERN,   data: 16'h0000, delay_us: 16'd0}       // Normal mode
    };

    //==========================================================================
    // SPI Protocol Constants
    //==========================================================================

    localparam int SPI_ADDR_BITS = 8;   // Address bits
    localparam int SPI_DATA_BITS = 16;  // Data bits
    localparam int SPI_TOTAL_BITS = 24; // Total transfer bits (8 addr + 16 data)

    // SPI Timing (for 100 MHz system clock)
    localparam int SPI_CLK_DIV = 10;    // 100 MHz / 10 = 10 MHz SPI clock

endpackage : afe2256_spi_pkg
