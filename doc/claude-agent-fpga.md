# Claude Agent FPGA Design Guide

## 1. XDC Constraints Hierarchy

### 1.1 Constraint Processing Order
```tcl
# EARLY: Applied before synthesis (physical planning)
set_property PROCESSING_ORDER EARLY [get_files early.xdc]

# NORMAL: Standard constraints (default)
# LATE: Applied after implementation (overrides)
set_property PROCESSING_ORDER LATE [get_files late.xdc]
```

### 1.2 Constraint Priority Rules
- Physical constraints override timing constraints
- Later constraints override earlier ones in same file
- Tool-generated constraints have lowest priority
- User XDC > IP XDC > Tool defaults

## 2. Clock Constraints

### 2.1 Primary Clock Definition
```tcl
# Input clock from pin (Period in ns)
create_clock -period 10.000 -name sys_clk [get_ports sys_clk]

# Virtual clock (for I/O timing, no physical source)
create_clock -period 8.000 -name virt_clk

# PLL/MMCM generated clocks (auto-derived from input)
create_generated_clock -name clk_div2 \
  -source [get_pins pll_inst/CLKIN1] \
  -divide_by 2 [get_pins pll_inst/CLKOUT0]
```

### 2.2 Clock Groups and Relationships
```tcl
# Asynchronous clock groups (no timing analysis between them)
set_clock_groups -asynchronous \
  -group [get_clocks sys_clk] \
  -group [get_clocks lvds_clk]

# Physically exclusive clocks (never active simultaneously)
set_clock_groups -physically_exclusive \
  -group [get_clocks clk_mode1] \
  -group [get_clocks clk_mode2]

# Logically exclusive (mutex in RTL)
set_clock_groups -logically_exclusive \
  -group [get_clocks clk_a] \
  -group [get_clocks clk_b]
```

### 2.3 Clock Uncertainty and Jitter
```tcl
# Add jitter to clock (affects setup/hold)
set_clock_uncertainty -setup 0.200 [get_clocks sys_clk]
set_clock_uncertainty -hold 0.100 [get_clocks sys_clk]

# Input jitter for external clocks
set_input_jitter [get_clocks sys_clk] 0.050
```

## 3. I/O Timing Constraints

### 3.1 Input Delay (Source Synchronous)
```tcl
# System synchronous input
# Delay = Clock-to-out(max) + PCB_trace_delay(max)
set_input_delay -clock sys_clk -max 5.0 [get_ports data_in*]
# Delay = Clock-to-out(min) + PCB_trace_delay(min)
set_input_delay -clock sys_clk -min 2.0 [get_ports data_in*]

# Source synchronous (data and clock from same source)
set_input_delay -clock rx_clk -max 2.5 [get_ports rx_data*]
set_input_delay -clock rx_clk -min 0.5 [get_ports rx_data*]
set_input_delay -clock rx_clk -max 2.5 [get_ports rx_data*] -add_delay -clock_fall
set_input_delay -clock rx_clk -min 0.5 [get_ports rx_data*] -add_delay -clock_fall
```

### 3.2 Output Delay (Board Timing)
```tcl
# System synchronous output
# Delay = Setup_time(external) + PCB_trace_delay(max)
set_output_delay -clock sys_clk -max 3.0 [get_ports data_out*]
# Delay = -Hold_time(external) + PCB_trace_delay(min)
set_output_delay -clock sys_clk -min 1.0 [get_ports data_out*]

# Source synchronous (FPGA provides clock and data)
set_output_delay -clock tx_clk -max 2.0 [get_ports tx_data*]
set_output_delay -clock tx_clk -min -0.5 [get_ports tx_data*]
```

## 4. Timing Exceptions

### 4.1 False Path (No Timing Analysis Required)
```tcl
# Asynchronous reset (no timing relationship)
set_false_path -from [get_ports rst_n]
set_false_path -from [get_pins */rst_reg/C] -to [all_registers]

# Static configuration registers (set once, never change)
set_false_path -to [get_pins -hierarchical *config_reg*/D]

# Cross-domain paths (handled by synchronizer, constrained separately)
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# Test/debug logic
set_false_path -through [get_pins -hierarchical *debug*/D]
```

### 4.2 Multicycle Path (More Than 1 Cycle)
```tcl
# 2-cycle setup path (data has 2 cycles to arrive)
set_multicycle_path -setup 2 -from [get_pins src_reg/C] -to [get_pins dst_reg/D]
# Hold adjusted: 2-1=1 cycle
set_multicycle_path -hold 1 -from [get_pins src_reg/C] -to [get_pins dst_reg/D]

# 3-cycle path example
set_multicycle_path -setup 3 -from [get_clocks clk_slow] -to [get_clocks clk_fast]
set_multicycle_path -hold 2 -from [get_clocks clk_slow] -to [get_clocks clk_fast]
```

### 4.3 Max/Min Delay (Explicit Timing)
```tcl
# Maximum delay constraint (alternative to setup)
set_max_delay 5.0 -from [get_pins src/C] -to [get_pins dst/D]

# Minimum delay constraint (alternative to hold)
set_min_delay 1.0 -from [get_pins src/C] -to [get_pins dst/D]

# Datapath-only (ignore clock path delay)
set_max_delay -datapath_only 3.0 -from [get_pins src/C] -to [get_pins dst/D]
```

## 5. I/O Standards and Physical Constraints

### 5.1 I/O Standard Selection (Artix-7)
```tcl
# LVCMOS (Single-ended)
set_property IOSTANDARD LVCMOS33 [get_ports led*]     # 3.3V
set_property IOSTANDARD LVCMOS25 [get_ports gpio*]    # 2.5V
set_property IOSTANDARD LVCMOS18 [get_ports ddr3*]    # 1.8V

# LVDS (Differential) - Requires VCCO=2.5V for internal termination
set_property IOSTANDARD LVDS_25 [get_ports {lvds_p lvds_n}]
set_property DIFF_TERM TRUE [get_ports {lvds_p lvds_n}]

# LVDS without internal termination (external resistor)
set_property IOSTANDARD LVDS [get_ports {ext_lvds_p ext_lvds_n}]
```

### 5.2 Bank Voltage and Configuration
```tcl
# Configuration voltage (for configuration pins)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Bank VCCO must match IOSTANDARD requirements:
# - LVCMOS33 requires VCCO = 3.3V
# - LVCMOS25 requires VCCO = 2.5V
# - LVDS_25 requires VCCO = 2.5V
# - Cannot mix different VCCO in same bank
```

### 5.3 Pin Assignment and Drive Strength
```tcl
# Physical pin location (FGG484 package)
set_property PACKAGE_PIN H16 [get_ports sys_clk]
set_property PACKAGE_PIN D9 [get_ports led[0]]

# Drive strength (2, 4, 6, 8, 12, 16, 24 mA)
set_property DRIVE 12 [get_ports data_out*]

# Slew rate (SLOW for low EMI, FAST for high speed)
set_property SLEW FAST [get_ports high_speed_data*]
set_property SLEW SLOW [get_ports led*]

# Pull-up/Pull-down (for unused inputs)
set_property PULLUP TRUE [get_ports unused_input]
set_property PULLDOWN TRUE [get_ports optional_signal]
```

## 6. Clock Domain Crossing (CDC)

### 6.1 2-FF Synchronizer (Single-bit CDC)
```verilog
// Standard 2-flip-flop synchronizer for single-bit signals
(* ASYNC_REG = "TRUE" *)
reg [1:0] sync_ff;

always @(posedge clk_dst or negedge rst_n) begin
  if (!rst_n)
    sync_ff <= 2'b00;
  else
    sync_ff <= {sync_ff[0], async_in};
end

assign sync_out = sync_ff[1];
```

**XDC Constraints for 2-FF Synchronizer**:
```tcl
# Mark as async register (prevents optimization, enables MTBF reporting)
set_property ASYNC_REG TRUE [get_cells -hierarchical *sync_ff*]

# Constrain max delay (80% of destination clock period for metastability)
set_max_delay -datapath_only \
  [expr [get_property PERIOD [get_clocks clk_dst]] * 0.8] \
  -from [get_pins src_reg/C] -to [get_pins sync_ff[0]/D]

# False path alternative (if no timing relationship needed)
set_false_path -from [get_pins src_reg/C] -to [get_pins sync_ff[0]/D]
```

### 6.2 Async FIFO (Multi-bit CDC)
```verilog
// Use Xilinx XPM FIFO for reliable multi-bit CDC
xpm_fifo_async #(
  .FIFO_WRITE_DEPTH(16),
  .WRITE_DATA_WIDTH(32),
  .READ_DATA_WIDTH(32),
  .CDC_SYNC_STAGES(2),        // 2-FF synchronizer stages
  .FIFO_MEMORY_TYPE("auto"),  // Block RAM or distributed
  .RELATED_CLOCKS(0)          // 0 = async, 1 = related
) fifo_inst (
  .wr_clk(clk_a),
  .rd_clk(clk_b),
  .din(write_data),
  .wr_en(write_enable),
  .dout(read_data),
  .rd_en(read_enable),
  .full(fifo_full),
  .empty(fifo_empty)
);
```

### 6.3 Handshake Synchronizer (Control CDC)
```verilog
// Request-acknowledge handshake for control signals
// Source domain (clk_a)
reg req;
wire ack_sync;

always @(posedge clk_a) begin
  if (trigger && !req)
    req <= 1'b1;
  else if (ack_sync)
    req <= 1'b0;
end

// Destination domain (clk_b)
reg [1:0] req_sync;
reg ack;

always @(posedge clk_b) begin
  req_sync <= {req_sync[0], req};
  ack <= req_sync[1];
end

// Synchronize ack back to source domain
reg [1:0] ack_sync_ff;
always @(posedge clk_a) begin
  ack_sync_ff <= {ack_sync_ff[0], ack};
end
assign ack_sync = ack_sync_ff[1];
```

## 7. Power Integrity and PCB Guidelines

### 7.1 Decoupling Capacitor Placement
**Per-Pin Decoupling** (High-frequency noise):
- 0.1µF ceramic (X7R/X5R) within 1-2mm of each VCCINT/VCCAUX/VCCO pin
- Multiple vias to ground plane (minimize inductance)

**Bulk Capacitors** (Low-frequency stability):
- 10µF tantalum/ceramic per voltage rail
- 100µF electrolytic at power entry

**Artix-7 Specific**:
- VCCINT (1.0V): 0.1µF every pin + 10µF × 4 + 100µF × 1
- VCCAUX (1.8V): 0.1µF every pin + 10µF × 2
- VCCO (variable): 0.1µF every 4 pins + 10µF per bank

### 7.2 Power Distribution Network (PDN)
**Minimum 4-layer PCB Stack-up**:
```
Layer 1: Signal (Top)
Layer 2: Ground Plane (solid)
Layer 3: Power Plane (split per voltage)
Layer 4: Signal (Bottom)
```

**Voltage Domains**:
- VCCINT: 1.0V ± 50mV (core logic)
- VCCAUX: 1.8V ± 90mV (auxiliary, clocking)
- VCCO: 1.2V ~ 3.3V (I/O banks, varies per bank)
- VCCBRAM: 1.0V (block RAM, can tie to VCCINT)

### 7.3 Power Estimation
```tcl
# Vivado Power Analysis (post-implementation)
report_power -file power_report.txt

# Check critical metrics:
# - Total On-Chip Power < Board thermal capacity
# - Junction Temperature < 85°C (commercial grade)
# - I/O power = f(toggle_rate, capacitance, voltage)
```

## 8. Synthesis and Implementation Strategies

### 8.1 Synthesis Strategies (Vivado)
```tcl
# Performance-optimized (maximize Fmax)
set_property STEPS.SYNTH_DESIGN.ARGS.STRATEGY {Flow_PerfOptimized_high} [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE {PerformanceOptimized} [get_runs synth_1]

# Area-optimized (minimize resource usage)
set_property STEPS.SYNTH_DESIGN.ARGS.STRATEGY {Flow_AreaOptimized_high} [get_runs synth_1]

# Runtime-optimized (fast iterations during debug)
set_property STEPS.SYNTH_DESIGN.ARGS.STRATEGY {RuntimeOptimized} [get_runs synth_1]

# Custom options
set_property STEPS.SYNTH_DESIGN.ARGS.MORE_OPTIONS {-mode out_of_context} [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY {rebuilt} [get_runs synth_1]
```

### 8.2 Implementation Strategies
```tcl
# Timing closure focused
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE {ExtraNetDelay_high} [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE {AggressiveExplore} [get_runs impl_1]

# Congestion reduction
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE {AltSpreadLogic_high} [get_runs impl_1]

# Runtime reduction
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE {RuntimeOptimized} [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE {RuntimeOptimized} [get_runs impl_1]
```

### 8.3 Physical Optimization
```tcl
# Enable physical optimization stages
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Directives for phys_opt
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE {AggressiveExplore} [get_runs impl_1]
```

### 8.4 Incremental Compilation
```tcl
# Reuse placement/routing from reference design
set_property INCREMENTAL_CHECKPOINT [get_files reference.dcp] [get_runs impl_1]

# Use for minor RTL changes to preserve timing closure
```

## 9. Design Rule Checks (DRC)

### 9.1 Common DRC Violations and Solutions

**LUTLP-1**: LUT equation is too complex
- **Cause**: Unconnected LUT input pins after optimization
- **Fix**: Verify HDL logic, check for unintended latches
```tcl
# Identify problematic LUTs
report_drc -ruledeck default_drc -name lutlp_check
```

**NSTD-1**: Unspecified I/O standard
- **Cause**: Missing IOSTANDARD property on port
- **Fix**: Add IOSTANDARD to all ports
```tcl
set_property IOSTANDARD LVCMOS33 [get_ports missing_port]
```

**UCIO-1**: Unconstrained logical port
- **Cause**: Port has no LOC (pin assignment)
- **Fix**: Assign PACKAGE_PIN
```tcl
set_property PACKAGE_PIN A1 [get_ports unconstrained_port]
```

**PDRC-153**: Voltage mismatch
- **Cause**: VCCO ≠ IOSTANDARD voltage requirement
- **Fix**: Verify bank voltage matches I/O standard
```
Bank 34 has VCCO=3.3V but LVDS_25 requires 2.5V
→ Change IOSTANDARD to LVCMOS33 or set VCCO=2.5V
```

**REQP-1840**: set_input_delay missing
- **Cause**: Input port has no timing constraint
- **Fix**: Add input_delay or false_path
```tcl
set_input_delay -clock sys_clk 2.0 [get_ports data_in]
```

**REQP-1841**: set_output_delay missing
- **Cause**: Output port has no timing constraint
- **Fix**: Add output_delay
```tcl
set_output_delay -clock sys_clk 1.5 [get_ports data_out]
```

### 9.2 CDC-Specific Violations

**CDC-1**: No synchronizer for async signal
- **Cause**: Signal crosses clock domains without 2-FF sync
- **Fix**: Insert synchronizer
```tcl
report_cdc -file cdc_report.txt
# Review violations and add synchronizers
```

**CDC-6**: Convergent CDC paths
- **Cause**: Multiple async signals converge at one register
- **Fix**: Use async FIFO or handshake protocol

### 9.3 DRC Reporting and Waivers
```tcl
# Run comprehensive DRC
report_drc -file drc_full.txt

# Waive known non-critical violations
create_waiver -id {NSTD-1} -objects [get_ports debug_pin] \
  -description "Debug pin, no I/O standard needed"
```

## 10. Timing Closure Workflow

### 10.1 Iterative Timing Closure Process
```
1. Run synthesis
   → Check resource utilization (< 80% recommended)

2. Run implementation
   → Generate timing summary

3. Analyze timing report:
   report_timing_summary -file timing.txt

4. Decision tree:
   WNS < 0 (Setup violation):
   ├─ Missing constraints → Add create_clock, input/output_delay
   ├─ Unconstrained paths → Add false_path if intentional
   ├─ Real timing issue → Try these in order:
   │  ├─ Change synthesis strategy (PerfOptimized)
   │  ├─ Enable phys_opt_design
   │  ├─ Change place/route directive (AggressiveExplore)
   │  ├─ Add pipelining in RTL
   │  └─ Use BUFG for high-fanout nets

   WHS < 0 (Hold violation):
   ├─ Usually indicates flawed constraints
   ├─ Check min_delay on I/O paths
   └─ Enable post-route phys_opt to fix

   TNS < -50ns (Many violations):
   ├─ Review clock definitions (period too aggressive?)
   ├─ Check for unconstrained paths
   └─ Major RTL rework may be needed

5. Iterate until WNS ≥ 0, WHS ≥ 0, TNS = 0
```

### 10.2 Critical Timing Reports
```tcl
# Overall timing summary
report_timing_summary -delay_type min_max -path_type full \
  -report_unconstrained -file timing_summary.txt

# Worst 10 setup paths
report_timing -setup -nworst 10 -path_type full \
  -file timing_setup_worst10.txt

# Worst 10 hold paths
report_timing -hold -nworst 10 -path_type full \
  -file timing_hold_worst10.txt

# Clock interaction (async clocks, multicycle, false_path)
report_clock_interaction -delay_type min_max \
  -file clock_interaction.txt

# Unconstrained paths (must be zero for production)
report_timing_summary -report_unconstrained \
  -file unconstrained_paths.txt
```

### 10.3 Common Timing Issues and Solutions

**High-fanout nets** (> 1000 loads):
```tcl
# Insert BUFG for global distribution
# In RTL: Use (* keep = "true" *) for critical signals
# In XDC:
set_property CLOCK_BUFFER_TYPE BUFG [get_nets high_fanout_signal]
```

**Long routing paths**:
```verilog
// Add pipeline stage
always @(posedge clk) begin
  stage1 <= input_data;
  stage2 <= stage1;  // Extra register
  output_data <= stage2;
end
```

**CDC violations**:
```tcl
# Ensure synchronizers are constrained
set_max_delay -datapath_only [expr $clk_period * 0.8] \
  -from [get_pins src/C] -to [get_pins sync_ff[0]/D]
```

**Unconstrained paths**:
```tcl
# Identify source
report_timing_summary -report_unconstrained

# Fix: Add clock, I/O delay, or false_path
set_false_path -to [get_pins debug_reg/D]
```

## 11. UltraFast Design Methodology (UG949)

### 11.1 Constraint-Driven Design Principles
1. **Define all clocks BEFORE synthesis**
   - Primary clocks (create_clock)
   - Generated clocks (create_generated_clock)
   - Virtual clocks (for I/O timing)

2. **Constrain ALL I/O timing**
   - Input delays relative to input clock
   - Output delays relative to output clock
   - False paths for async signals

3. **Review timing after EVERY implementation**
   - Check WNS, TNS, WHS
   - Verify no unconstrained paths
   - Analyze critical paths

4. **Use incremental compilation for minor changes**
   - Preserve timing closure
   - Faster iteration time

### 11.2 Design Hierarchy Best Practices
```verilog
// Top-level: I/O, clock distribution, module instantiation only
module top (
  input wire clk,
  input wire rst_n,
  // ... ports
);

// Clock distribution
wire clk_core, clk_io;
clk_manager clk_mgr_inst (...);

// Instantiate functional blocks (well-defined interfaces)
block_a block_a_inst (...);
block_b block_b_inst (...);

endmodule
```

**Isolation benefits**:
- Independent timing analysis per block
- Reusable IP
- Parallel development

### 11.3 Register All I/Os (Input/Output Registers)
```verilog
// Input registers (close to pad)
reg [7:0] data_in_reg;
always @(posedge clk) data_in_reg <= data_in;

// Output registers (close to pad)
reg [7:0] data_out_reg;
always @(posedge clk) data_out_reg <= internal_data;
assign data_out = data_out_reg;
```

**Benefits**:
- Predictable I/O timing
- Reduced clock uncertainty
- Better timing closure

### 11.4 Synchronous Reset (Avoid Async Reset Issues)
```verilog
// Synchronous reset (preferred)
always @(posedge clk) begin
  if (!rst_n)
    counter <= 8'd0;
  else
    counter <= counter + 1;
end

// If async reset required, synchronize release
reg [1:0] rst_sync;
always @(posedge clk or negedge rst_n_async) begin
  if (!rst_n_async)
    rst_sync <= 2'b00;
  else
    rst_sync <= {rst_sync[0], 1'b1};
end
wire rst_n = rst_sync[1];
```

### 11.5 Performance Targets
| Metric | Requirement | Notes |
|--------|-------------|-------|
| **WNS** | ≥ 0 | Worst Negative Slack (setup) |
| **TNS** | = 0 | Total Negative Slack (setup) |
| **WHS** | ≥ 0 | Worst Hold Slack |
| **WPWS** | ≥ 0 | Worst Pulse Width Slack |
| **Unconstrained Paths** | 0 | All paths must be constrained |

## 12. Project-Specific: Artix-7 XC7A35T-FGG484

### 12.1 Device Resources
| Resource | XC7A35T | Notes |
|----------|---------|-------|
| Logic Cells | 33,280 | Configurable logic |
| Flip-Flops | 41,600 | Available FFs |
| LUTs | 20,800 | 6-input LUTs |
| Block RAM | 1,800 Kb | 50 × 36Kb blocks |
| DSP Slices | 90 | 25×18 multipliers |
| I/O Pins (FGG484) | 285 | User I/O |
| I/O Banks | 6 | Banks 0, 14, 15, 16, 34, 35 |
| CMTs | 5 | Clock Management Tiles |
| PLLs | 5 | Phase-Locked Loops |
| MMCMs | 5 | Mixed-Mode Clock Managers |
| Global Clocks (BUFG) | 32 | Low-skew distribution |

### 12.2 Clock Resources Details
**MMCM Features** (prefer over PLL for complex clocking):
- Input: 10 MHz ~ 800 MHz
- Multiply: ×2 ~ ×64
- Divide: ÷1 ~ ÷106
- Phase shift: 0° ~ 360° (fine resolution)
- Jitter filtering

**PLL Features** (simpler, lower power):
- Input: 19 MHz ~ 800 MHz
- Multiply: ×2 ~ ×64
- Divide: ÷1 ~ ÷52

### 12.3 I/O Standards Supported (FGG484)
| Standard | VCCO | Notes |
|----------|------|-------|
| LVCMOS12 | 1.2V | Low voltage |
| LVCMOS15 | 1.5V | DDR3 I/O |
| LVCMOS18 | 1.8V | Common for DDR3 |
| LVCMOS25 | 2.5V | Legacy, reliable |
| LVCMOS33 | 3.3V | Most common |
| LVDS_25 | 2.5V | Differential, internal term |
| LVDS | 2.5V | Differential, external term |
| SSTL15 | 1.5V | DDR3 |
| HSTL_I | 1.8V | High-speed transceiver |

### 12.4 FGG484 Package Pin Map
```
Pin Grid: AA1 ~ AB22 (22 rows × ~22 columns)
- Corner balls: A1, A22, AB1, AB22
- Verify pin location in UG475 (Artix-7 Packaging Guide)
```

## 13. Validation Checklist

### 13.1 Pre-Synthesis Checks
- [ ] All primary clocks defined (`create_clock`)
- [ ] Generated clocks defined or auto-derived
- [ ] Clock groups set (`set_clock_groups` for async domains)
- [ ] All I/O standards specified (`IOSTANDARD`)
- [ ] All pins assigned (`PACKAGE_PIN`)
- [ ] Bank voltages verified (VCCO matches IOSTANDARD)
- [ ] Configuration voltage set (`CFGBVS`, `CONFIG_VOLTAGE`)

### 13.2 Post-Synthesis Checks
- [ ] No critical synthesis warnings (SYNTH-8-*)
- [ ] Resource utilization < 80% (LUTs, FFs, BRAM, DSP)
- [ ] DRC clean (`report_drc`)
- [ ] No combinational loops
- [ ] No latches (unless intentional)
- [ ] Clock buffers inferred correctly (BUFG, BUFR)

### 13.3 Post-Implementation Checks
- [ ] **WNS ≥ 0** (setup timing met)
- [ ] **WHS ≥ 0** (hold timing met)
- [ ] **TNS = 0** (no setup violations)
- [ ] **TPWS ≥ 0** (pulse width met)
- [ ] No unconstrained paths (`report_timing_summary -report_unconstrained`)
- [ ] DRC violations = 0 (`report_drc`)
- [ ] CDC paths properly constrained (`report_cdc`)
- [ ] Power estimate < board thermal capacity (`report_power`)

### 13.4 Pre-Bitstream Checks
- [ ] Final timing report reviewed (all slacks positive)
- [ ] I/O configuration verified (drive strength, slew rate)
- [ ] CDC synchronizers in place and constrained
- [ ] DRC clean (no errors, waivers documented)
- [ ] Bitstream settings configured (if needed)
```tcl
# Example: Configure bitstream compression
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
```

## 14. RTL Coding Best Practices

### 14.1 Pipelining for High Performance
**Basic Pipelining Pattern**:
```verilog
// Single-stage computation (long combinational path)
assign result = ((a * b) + (c * d)) >> 4;

// 2-stage pipelined (better timing)
reg [31:0] stage1_mult_a, stage1_mult_b;
reg [31:0] stage2_result;

always @(posedge clk) begin
  // Stage 1: Multiplications
  stage1_mult_a <= a * b;
  stage1_mult_b <= c * d;

  // Stage 2: Add and shift
  stage2_result <= (stage1_mult_a + stage1_mult_b) >> 4;
end

assign result = stage2_result;
```

**Guidelines**:
- Split complex logic into stages with registers between
- Each stage should complete in < 60% of clock period
- Balance pipeline stages (avoid one stage dominating delay)
- Consider latency tolerance of application

### 14.2 Register Optimization
**Always use edge-triggered flip-flops**:
```verilog
// GOOD: Synchronous flip-flop
always @(posedge clk) begin
  if (!rst_n)
    counter <= 0;
  else
    counter <= counter + 1;
end

// BAD: Latch (avoid!)
always @(*) begin
  if (enable)
    data_out = data_in;  // Creates latch if incomplete
end
```

**Reset strategy**:
```verilog
// Synchronous reset (preferred for FPGA)
always @(posedge clk) begin
  if (!rst_n)
    state <= IDLE;
  else
    state <= next_state;
end

// Initialize all registers
reg [7:0] count = 8'd0;  // FPGA supports initialization
```

### 14.3 Resource Optimization Techniques
**Use Block RAM (BRAM) for large storage**:
```verilog
// Large arrays map to BRAM automatically
reg [31:0] data_buffer [0:1023];  // 4KB → BRAM

always @(posedge clk) begin
  if (wr_en)
    data_buffer[wr_addr] <= wr_data;
  rd_data <= data_buffer[rd_addr];  // Registered output
end
```

**Map arithmetic to DSP slices**:
```verilog
// Multipliers use DSP48 blocks
reg [17:0] a, b;
reg [35:0] product;

always @(posedge clk) begin
  product <= a * b;  // Vivado infers DSP48
end

// MAC (Multiply-Accumulate) also uses DSP48
always @(posedge clk) begin
  if (reset)
    accumulator <= 0;
  else
    accumulator <= accumulator + (a * b);
end
```

**Resource sharing** (save area):
```verilog
// Without sharing: 2 multipliers
assign result_a = in_a * coeff_a;
assign result_b = in_b * coeff_b;

// With sharing: 1 multiplier (time-multiplexed)
always @(posedge clk) begin
  if (sel == 0)
    shared_mult <= in_a * coeff_a;
  else
    shared_mult <= in_b * coeff_b;
end
```

### 14.4 Avoiding Common RTL Pitfalls
**No combinational loops**:
```verilog
// BAD: Combinational loop
assign a = b & c;
assign b = a | d;  // Loop!

// GOOD: Break with register
always @(posedge clk) b_reg <= a | d;
assign a = b_reg & c;
```

**Avoid latches**:
```verilog
// Complete all branches to avoid latches
always @(*) begin
  case (state)
    IDLE:  next_state = RUN;
    RUN:   next_state = DONE;
    DONE:  next_state = IDLE;
    default: next_state = IDLE;  // Prevents latch
  endcase
end
```

**Meaningful signal names and comments**:
```verilog
// GOOD
wire axi_read_valid;
wire [31:0] fifo_write_data;

// BAD
wire x;
wire [31:0] d;
```

## 15. Floorplanning and Physical Optimization

### 15.1 When to Use Floorplanning (PBLOCK)
- **High utilization** (> 80%): Guide placement to avoid congestion
- **Timing closure issues**: Constrain critical paths to short routing
- **Partial reconfiguration**: Define reconfigurable regions
- **Modular design**: Isolate functional blocks

### 15.2 PBLOCK Creation and Guidelines
```tcl
# Create PBLOCK for module
create_pblock pblock_dsp_engine
add_cells_to_pblock pblock_dsp_engine [get_cells -hierarchical dsp_core_inst]

# Assign physical area (CLB coordinates)
resize_pblock pblock_dsp_engine -add {SLICE_X50Y50:SLICE_X99Y99}
resize_pblock pblock_dsp_engine -add {DSP48_X2Y20:DSP48_X3Y39}
resize_pblock pblock_dsp_engine -add {RAMB36_X3Y10:RAMB36_X4Y19}
```

**Density guidelines**:
- Target 70-80% LUT density (not 96%!)
- Leave routing resources for place & route
- Use contiguous rectangular regions when possible

### 15.3 Floorplanning Workflow
1. **Initial run**: No floorplanning, establish baseline
2. **Identify congestion**: Check `report_utilization -cells`
3. **Create PBLOCKs**: Group related logic
4. **Iterate**: Adjust boundaries based on congestion reports
5. **Verify timing**: Ensure floorplan helps, not hinders

```tcl
# Check PBLOCK utilization
report_utilization -pblocks pblock_dsp_engine
```

## 16. Metastability and MTBF

### 16.1 Metastability Fundamentals
When an async signal arrives near clock edge, FF can enter metastable state (neither 0 nor 1). After time tMET, it resolves to stable value, but if tMET < clock period, metastable value propagates, causing system errors.

### 16.2 MTBF Calculation
**Formula**:
```
MTBF = e^(tMET/C2) / (C1 × fCLK × fDATA)

Where:
- tMET = Available settling time (clock_period - Tsu - Tco - Troute)
- C1, C2 = Device constants (from datasheet)
- fCLK = Clock frequency of destination domain
- fDATA = Toggle rate of async signal
```

**Example (Artix-7)**:
- C1 ≈ 1e-10 (device-specific)
- C2 ≈ 50 ps (device-specific)
- fCLK = 100 MHz, fDATA = 10 MHz
- tMET = 10ns - 0.5ns - 0.3ns - 0.2ns = 9ns

```
MTBF = e^(9000ps/50ps) / (1e-10 × 1e8 × 1e7)
     = e^180 / 1e5
     ≈ 10^73 seconds (effectively infinite)
```

### 16.3 Synchronizer Design Rules
**2-FF synchronizer** (standard):
```verilog
(* ASYNC_REG = "TRUE" *) reg [1:0] sync_ff;
always @(posedge clk) sync_ff <= {sync_ff[0], async_in};
```

**3-FF synchronizer** (high-speed or critical):
```verilog
(* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;
always @(posedge clk) sync_ff <= {sync_ff[1:0], async_in};
```

**When to use 3-FF**:
- fCLK > 200 MHz and fDATA > 50 MHz
- Required MTBF > 10^15 seconds
- Mission-critical applications (medical, automotive)

### 16.4 Vivado MTBF Reporting
```tcl
# Enable CDC checks
set_property CDC.ASYNC_REG TRUE [get_cells -hier *sync_ff*]

# Generate CDC report
report_cdc -file cdc_report.txt

# Check MTBF (if available in report)
# Look for "MTBF" or "metastability" sections
```

## 17. Memory Interface Design (DDR3 with MIG)

### 17.1 MIG IP Core Configuration
**7-Series FPGAs**: No hard memory controller, use soft controller with hard PHY
- **PHY**: Physical layer (hard IP in FPGA)
- **Controller**: DDR3 protocol logic (soft IP, uses fabric)
- **Interface**: DFI (DDR PHY Interface) between controller and PHY

**User interfaces**:
- **Native Interface**: Direct low-level access
- **AXI4 Interface**: Standard AMBA bus (recommended for most)

### 17.2 Clock Requirements
DDR3 memory interface requires:
- **Reference clock**: 200 MHz (for input clock calibration)
- **System clock**: Typically 100 MHz (MIG generates DDR clocks internally)

```verilog
// Clock wizard generates required clocks
clk_wiz_0 clk_gen (
  .clk_in1(100MHz_board_clk),
  .clk_out1(sys_clk_100MHz),
  .clk_out2(ref_clk_200MHz),
  .locked(clk_locked)
);

// MIG instance
mig_7series_0 ddr3_ctrl (
  .sys_clk_i(sys_clk_100MHz),
  .clk_ref_i(ref_clk_200MHz),
  .sys_rst(sys_rst),
  .ui_clk(user_clk),           // User interface clock (output)
  .ui_clk_sync_rst(ui_rst),    // User interface reset
  // AXI interface signals...
  .ddr3_addr(ddr3_addr),
  .ddr3_ba(ddr3_ba),
  .ddr3_dq(ddr3_dq),
  // ...
);
```

### 17.3 Board Design Requirements
**PCB considerations**:
- **I/O Standard**: SSTL15 for DDR3 (1.5V)
- **Trace impedance**: 50Ω single-ended (controlled)
- **Termination**:
  - FPGA side: 50Ω internal (FPGA I/O blocks)
  - DDR3 side: On-die termination (ODT enabled via MIG)
- **Length matching**: ±0.5mm for data group, ±2.5mm for address/command
- **Power**: Clean 1.5V VCCO for DDR3 bank

**MIG wizard validation**:
- Checks speed grade, package, bank configuration
- Verifies VCCAUX_IO compatibility
- Validates data rate for target device

### 17.4 Design Checklist
- [ ] Full knowledge of DDR3 chip datasheet (timing, voltage)
- [ ] Board pinout accurately captured in MIG
- [ ] Reference clock 200 MHz stable and low-jitter
- [ ] Impedance-controlled PCB routing (50Ω)
- [ ] Decoupling capacitors: 0.1µF near each VREF pin
- [ ] Fly-by topology for address/command (if multi-rank)

## 18. Verification and Simulation Best Practices

### 18.1 Testbench Structure
**Self-checking testbench pattern**:
```verilog
module tb_counter;
  // Clock and reset
  reg clk, rst_n;
  reg [7:0] expected;

  // DUT instantiation
  wire [7:0] count;
  counter dut (
    .clk(clk),
    .rst_n(rst_n),
    .count(count)
  );

  // Clock generation (10ns period = 100MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // Test stimulus
  initial begin
    rst_n = 0;
    expected = 0;
    #20 rst_n = 1;

    // Check counter increments
    repeat(256) begin
      @(posedge clk);
      #1;  // Small delay after clock edge
      if (count !== expected) begin
        $error("Mismatch: count=%0d, expected=%0d", count, expected);
        $stop;
      end
      expected = expected + 1;
    end

    $display("Test PASSED");
    $finish;
  end
endmodule
```

### 18.2 Key Verification Principles
**Use assertions**:
```verilog
// Immediate assertion (combinational)
always @(*) begin
  assert (state != ILLEGAL_STATE)
    else $error("Entered illegal state");
end

// Concurrent assertion (sequential)
property valid_handshake;
  @(posedge clk) req |-> ##[1:5] ack;
endproperty
assert property (valid_handshake)
  else $error("Handshake violation");
```

**Coverage-driven verification**:
```verilog
covergroup state_coverage @(posedge clk);
  state_cp: coverpoint state {
    bins idle = {IDLE};
    bins run  = {RUN};
    bins done = {DONE};
    bins transitions = (IDLE => RUN), (RUN => DONE);
  }
endgroup
```

### 18.3 Simulation Tools and Workflows
**Vivado Simulator (XSIM)**:
```tcl
# Compile design sources
verilog work ../hdl/counter.v
verilog work ../tb/tb_counter.v

# Elaborate
elaborate -debug typical tb_counter

# Run simulation
run all
```

**ModelSim/Questa**:
```tcl
vlog -work work ../hdl/counter.v
vlog -work work ../tb/tb_counter.v
vsim -voptargs=+acc work.tb_counter
run -all
```

### 18.4 UVM for Complex Verification
For complex designs, consider UVM (Universal Verification Methodology):
- **Reusable components**: Drivers, monitors, scoreboards
- **Constrained randomization**: Automated test generation
- **Coverage tracking**: Functional coverage closure
- **Phased approach**: Build, connect, run, extract phases

**Note**: UVM primarily targets simulation (not synthesis), uses SystemVerilog.

### 18.5 Module-Level Verification Strategy

#### 18.5.1 Three-Level Verification Approach

**Level 1: Unit Testing** (Mandatory for all modules)
- Verify module in isolation with dedicated testbench
- Test all interface protocols (valid-ready handshakes, AXI transactions)
- Cover corner cases (reset during operation, back-to-back transactions)
- Achieve 100% code coverage (statement, branch, toggle)
- Verify parameterization (test multiple parameter configurations)

**Level 2: Integration Testing** (For modules with dependencies)
- Test module connections and interfaces
- Verify clock domain crossings (CDC) with timing violations injected
- Test resource sharing and arbitration
- Validate error propagation and recovery
- Check for interface deadlocks

**Level 3: System Testing** (Full design)
- End-to-end functionality with realistic stimulus
- Performance validation (throughput, latency)
- Stress testing (maximum load, boundary conditions)
- Long-duration tests (detect periodic glitches, memory leaks)
- Hardware co-simulation (if available)

#### 18.5.2 Module Verification Checklist

**For each module, verify**:
- [ ] **Reset behavior**: Module initializes correctly on async/sync reset
- [ ] **Clock domain isolation**: No CDC violations (check with CDC report)
- [ ] **Interface protocol compliance**: Valid-ready handshake rules enforced
- [ ] **Backpressure handling**: Module stalls correctly when downstream not ready
- [ ] **Error injection**: Module handles invalid inputs gracefully (no hangs)
- [ ] **Resource cleanup**: FIFOs drain, FSMs return to IDLE after abort
- [ ] **Timing closure**: Module meets timing at target frequency (static timing analysis)
- [ ] **Parameterization**: All parameter combinations tested (or assertions validate)

#### 18.5.3 Testbench Templates by Module Type

**Clock Manager Module Testbench**:
```verilog
module tb_clk_manager;
  reg clk_in_100mhz;
  reg rst_n_async;
  wire clk_core_200mhz, clk_io_50mhz, mmcm_locked;
  wire rst_core_n, rst_io_n;

  clk_manager dut (.*);

  // 100 MHz input clock
  initial clk_in_100mhz = 0;
  always #5 clk_in_100mhz = ~clk_in_100mhz;

  initial begin
    rst_n_async = 0;
    #100 rst_n_async = 1;

    // Wait for lock
    wait(mmcm_locked == 1);
    $display("MMCM locked at time %0t", $time);

    // Verify clock frequencies (measure period)
    fork
      check_clock_freq(clk_core_200mhz, 5.0, "core");  // 200 MHz = 5ns
      check_clock_freq(clk_io_50mhz, 20.0, "io");      // 50 MHz = 20ns
    join

    // Test reset synchronization
    rst_n_async = 0;
    #50 rst_n_async = 1;
    if (rst_core_n !== 0 || rst_io_n !== 0)
      $error("Reset not synchronized");

    wait(mmcm_locked == 1);
    @(posedge clk_core_200mhz);
    @(posedge clk_core_200mhz);
    if (rst_core_n !== 1)
      $error("Reset release failed");

    $display("Test PASSED");
    $finish;
  end

  task check_clock_freq(input clk, input real expected_period, input string name);
    real t1, t2, period;
    @(posedge clk) t1 = $realtime;
    @(posedge clk) t2 = $realtime;
    period = t2 - t1;
    if (period < expected_period * 0.9 || period > expected_period * 1.1)
      $error("%s clock period %0.2f ns (expected %0.2f ns)", name, period, expected_period);
    else
      $display("%s clock period OK: %0.2f ns", name, period);
  endtask
endmodule
```

**AXI Slave Module Testbench**:
```verilog
module tb_axi_slave_peripheral;
  reg aclk, aresetn;
  reg [11:0] s_axi_awaddr, s_axi_araddr;
  reg s_axi_awvalid, s_axi_wvalid, s_axi_arvalid;
  reg [31:0] s_axi_wdata;
  reg [3:0] s_axi_wstrb;
  wire s_axi_awready, s_axi_wready, s_axi_arready;
  wire s_axi_bvalid, s_axi_rvalid;
  wire [31:0] s_axi_rdata;

  axi_slave_peripheral dut (.*);

  // Clock generation
  initial aclk = 0;
  always #5 aclk = ~aclk;  // 100 MHz

  initial begin
    // Reset
    aresetn = 0;
    s_axi_awvalid = 0;
    s_axi_wvalid = 0;
    s_axi_arvalid = 0;
    #50 aresetn = 1;

    // Test 1: Write to control register
    axi_write(12'h000, 32'hDEADBEEF);
    #20;

    // Test 2: Read back control register
    axi_read(12'h000, 32'hDEADBEEF);
    #20;

    // Test 3: Read status register
    axi_read(12'h004, 32'h12345678);  // Assume status_reg tied to this value
    #20;

    // Test 4: Write to trigger register (write-1-pulse)
    axi_write(12'h008, 32'h00000001);
    @(posedge aclk);
    if (dut.trigger_pulse !== 1)
      $error("Trigger pulse not asserted");
    @(posedge aclk);
    if (dut.trigger_pulse !== 0)
      $error("Trigger pulse not single-cycle");
    #20;

    // Test 5: Back-to-back writes
    fork
      axi_write(12'h000, 32'hAAAA_AAAA);
      #1 axi_write(12'h000, 32'hBBBB_BBBB);
    join
    #20;

    $display("All tests PASSED");
    $finish;
  end

  // AXI write task
  task axi_write(input [11:0] addr, input [31:0] data);
    @(posedge aclk);
    s_axi_awaddr  = addr;
    s_axi_awvalid = 1;
    s_axi_wdata   = data;
    s_axi_wstrb   = 4'hF;
    s_axi_wvalid  = 1;

    // Wait for address handshake
    wait(s_axi_awready);
    @(posedge aclk);
    s_axi_awvalid = 0;

    // Wait for data handshake
    wait(s_axi_wready);
    @(posedge aclk);
    s_axi_wvalid = 0;

    // Wait for write response
    wait(s_axi_bvalid);
    @(posedge aclk);

    $display("AXI Write: addr=0x%03h, data=0x%08h", addr, data);
  endtask

  // AXI read task
  task axi_read(input [11:0] addr, input [31:0] expected);
    @(posedge aclk);
    s_axi_araddr  = addr;
    s_axi_arvalid = 1;

    // Wait for address handshake
    wait(s_axi_arready);
    @(posedge aclk);
    s_axi_arvalid = 0;

    // Wait for read data
    wait(s_axi_rvalid);
    if (s_axi_rdata !== expected)
      $error("AXI Read mismatch: addr=0x%03h, read=0x%08h, expected=0x%08h",
             addr, s_axi_rdata, expected);
    else
      $display("AXI Read OK: addr=0x%03h, data=0x%08h", addr, s_axi_rdata);
    @(posedge aclk);
  endtask
endmodule
```

**Async FIFO CDC Module Testbench**:
```verilog
module tb_async_fifo_cdc;
  reg wr_clk, wr_rst_n, rd_clk, rd_rst_n;
  reg [31:0] wr_data;
  reg wr_en, rd_en;
  wire wr_full, rd_empty;
  wire [31:0] rd_data;

  async_fifo_cdc #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) dut (.*);

  // Write clock: 100 MHz
  initial wr_clk = 0;
  always #5 wr_clk = ~wr_clk;

  // Read clock: 75 MHz (asynchronous)
  initial rd_clk = 0;
  always #6.67 rd_clk = ~rd_clk;

  initial begin
    // Reset both domains
    wr_rst_n = 0; rd_rst_n = 0;
    wr_en = 0; rd_en = 0;
    #50;
    wr_rst_n = 1; rd_rst_n = 1;
    #20;

    // Test 1: Fill FIFO completely
    fork
      begin : writer
        for (int i = 0; i < 16; i++) begin
          @(posedge wr_clk);
          wr_data = i;
          wr_en = 1;
          if (wr_full) begin
            $error("FIFO full prematurely at count %0d", i);
            $stop;
          end
        end
        @(posedge wr_clk);
        wr_en = 0;

        // Check full flag
        #100;
        if (!wr_full)
          $error("FIFO should be full");
      end

      begin : reader
        #200;  // Let FIFO fill first
        for (int i = 0; i < 16; i++) begin
          @(posedge rd_clk);
          rd_en = 1;
          @(posedge rd_clk);
          #1;  // Small delay for signal propagation
          if (rd_data !== i) begin
            $error("Data mismatch: read=%0d, expected=%0d", rd_data, i);
            $stop;
          end
        end
        @(posedge rd_clk);
        rd_en = 0;

        // Check empty flag
        #100;
        if (!rd_empty)
          $error("FIFO should be empty");
      end
    join

    // Test 2: Streaming (continuous write/read)
    fork
      begin : stream_wr
        for (int i = 100; i < 200; i++) begin
          @(posedge wr_clk);
          if (!wr_full) begin
            wr_data = i;
            wr_en = 1;
          end else begin
            wr_en = 0;
          end
        end
      end

      begin : stream_rd
        int read_val;
        int expected = 100;
        repeat(100) begin
          @(posedge rd_clk);
          if (!rd_empty) begin
            rd_en = 1;
            @(posedge rd_clk);
            #1;
            if (rd_data !== expected) begin
              $error("Stream mismatch: read=%0d, expected=%0d", rd_data, expected);
              $stop;
            end
            expected++;
          end else begin
            rd_en = 0;
          end
        end
      end
    join

    $display("All FIFO tests PASSED");
    $finish;
  end
endmodule
```

**FSM Control Unit Testbench**:
```verilog
module tb_control_fsm;
  reg clk, rst_n, start, abort;
  reg init_done, proc_done, error_flag;
  wire init_en, proc_en, result_valid;
  wire [2:0] fsm_state_out;

  control_fsm dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    // Reset
    rst_n = 0;
    start = 0; abort = 0;
    init_done = 0; proc_done = 0; error_flag = 0;
    #50 rst_n = 1;

    // Test 1: Normal operation (IDLE → INIT → PROCESS → IDLE)
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    // Should enter INIT state
    repeat(3) @(posedge clk);
    if (fsm_state_out !== 3'b010)
      $error("Expected INIT state");
    if (!init_en)
      $error("init_en should be asserted");

    // Complete initialization
    #100;
    init_done = 1;
    @(posedge clk);
    init_done = 0;

    // Should enter PROCESS state
    repeat(3) @(posedge clk);
    if (fsm_state_out !== 3'b100)
      $error("Expected PROCESS state");
    if (!proc_en)
      $error("proc_en should be asserted");

    // Complete processing
    #200;
    proc_done = 1;
    @(posedge clk);
    proc_done = 0;

    // Should return to IDLE, assert result_valid
    @(posedge clk);
    if (fsm_state_out !== 3'b001)
      $error("Expected IDLE state");

    // Test 2: Abort during processing
    #50;
    start = 1;
    @(posedge clk);
    start = 0;
    #100;
    init_done = 1;
    @(posedge clk);
    init_done = 0;
    #100;

    // Abort while processing
    abort = 1;
    @(posedge clk);
    abort = 0;

    // Should return to IDLE immediately
    repeat(3) @(posedge clk);
    if (fsm_state_out !== 3'b001)
      $error("Abort failed to return to IDLE");

    // Test 3: Timeout protection
    #50;
    start = 1;
    @(posedge clk);
    start = 0;

    // Don't assert init_done, should timeout
    #200000;  // Wait longer than TIMEOUT_CYCLES
    if (fsm_state_out !== 3'b001)
      $error("Timeout did not trigger");

    $display("FSM tests PASSED");
    $finish;
  end
endmodule
```

#### 18.5.4 Coverage Requirements

**Code coverage targets** (measured with simulator coverage tools):
- **Statement coverage**: 100% (every line executed)
- **Branch coverage**: 100% (every if/else, case branch taken)
- **Toggle coverage**: >95% (every signal toggles 0→1 and 1→0)
- **FSM coverage**: 100% (every state entered, every transition taken)

**Functional coverage** (specify in testbench):
```verilog
covergroup protocol_coverage @(posedge clk);
  // Cover all valid-ready combinations
  handshake: coverpoint {valid, ready} {
    bins valid_not_ready = {2'b10};
    bins valid_and_ready = {2'b11};
    bins not_valid       = {2'b0?};
  }

  // Cover back-to-back transactions
  transitions: coverpoint valid {
    bins back_to_back = (1 => 1);
    bins with_gap     = (1 => 0 => 1);
  }
endgroup
```

**Coverage closure workflow**:
1. Run testbench with coverage enabled
2. Generate coverage report (HTML/database)
3. Identify uncovered code paths
4. Add tests to hit uncovered paths
5. Iterate until 100% coverage achieved

#### 18.5.5 Continuous Integration for Verification

**Automated regression testing** (example Makefile):
```makefile
# Run all module testbenches
.PHONY: test
test: test_clk_manager test_axi_slave test_fifo test_fsm

test_clk_manager:
	xvlog tb_clk_manager.v clk_manager.v
	xelab -debug typical tb_clk_manager
	xsim tb_clk_manager -runall

test_axi_slave:
	xvlog tb_axi_slave_peripheral.v axi_slave_peripheral.v
	xelab -debug typical tb_axi_slave_peripheral
	xsim tb_axi_slave_peripheral -runall

# Generate coverage report
coverage:
	xcrg -report_format html -dir xsim.covdb -report_dir cov_report

# Fail if coverage < 95%
coverage_check:
	python3 check_coverage.py --threshold 95 xsim.covdb
```

**Git pre-commit hook** (`.git/hooks/pre-commit`):
```bash
#!/bin/bash
# Run regression tests before allowing commit
make test
if [ $? -ne 0 ]; then
  echo "ERROR: Tests failed, commit aborted"
  exit 1
fi
```

## 19. IP Integrator and Block Design

### 19.1 Block Design Workflow
1. **Create Block Design** (Vivado GUI or TCL)
2. **Add IP cores**: AXI peripherals, processors (MicroBlaze/Zynq)
3. **Connection Automation**: Vivado auto-connects AXI interfaces
4. **Validate Design**: Check for errors
5. **Generate Output Products**: Synthesis, simulation files
6. **Create HDL Wrapper**: Top-level Verilog/VHDL

### 19.2 AXI Interconnect Basics
**AXI4 protocol** (AMBA standard):
- **AXI4-Full**: High-performance, burst transfers
- **AXI4-Lite**: Simple register access (no bursts)
- **AXI4-Stream**: Streaming data (no address phase)

**AXI Interconnect IP**:
```
Master → AXI Interconnect → Slave 0 (Memory)
                          → Slave 1 (Peripheral 1)
                          → Slave 2 (Peripheral 2)
```

### 19.3 Block Design TCL Script
```tcl
# Create block design
create_bd_design "system"

# Add IP cores
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gpio_0
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 cpu_0

# Run connection automation
apply_bd_automation -rule xilinx.com:bd_rule:microblaze \
  -config {local_mem "8KB" ...} [get_bd_cells cpu_0]

# Validate design
validate_bd_design

# Generate output products
generate_target all [get_files system.bd]

# Create HDL wrapper
make_wrapper -files [get_files system.bd] -top
```

### 19.4 Custom AXI IP Creation
**Use AXI4-Lite for simple peripherals**:
- Vivado provides IP packager wizard
- Auto-generates AXI interface logic
- User adds custom logic in designated area

```verilog
// User logic area in AXI IP
always @(posedge S_AXI_ACLK) begin
  if (slv_reg_wren && axi_awaddr[3:2] == 2'h0)
    user_reg <= S_AXI_WDATA;  // Write to register
end

assign custom_output = user_reg[7:0];  // Drive FPGA pin
```

## 20. TCL Scripting for Automation

### 20.1 Project vs. Non-Project Mode
**Project Mode**:
- Creates .xpr file, manages sources
- Suitable for GUI interaction
- Slower rebuild (file I/O overhead)

**Non-Project Mode**:
- In-memory, no project file
- Faster automated builds
- Requires complete TCL script

### 20.2 Basic Build Script (Non-Project)
```tcl
# Set output directory
set outputDir ./build
file mkdir $outputDir

# Read design sources
read_verilog -sv ../hdl/top.v
read_verilog -sv ../hdl/submodule.v
read_xdc ../constrs/top.xdc

# Synthesis
synth_design -top top -part xc7a35tfgg484-1
write_checkpoint -force $outputDir/post_synth.dcp
report_utilization -file $outputDir/post_synth_util.txt

# Implementation
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $outputDir/post_route.dcp

# Reports
report_timing_summary -file $outputDir/timing.txt
report_utilization -file $outputDir/utilization.txt
report_power -file $outputDir/power.txt

# Bitstream
write_bitstream -force $outputDir/top.bit
```

### 20.3 Batch Mode Execution
```bash
# Run TCL script in batch mode (no GUI)
vivado -mode batch -source build.tcl

# Run with logging
vivado -mode batch -source build.tcl -log build.log -journal build.jou
```

### 20.4 Key TCL Commands
```tcl
# Design commands
read_verilog, read_vhdl, read_xdc
synth_design, opt_design, place_design, route_design

# Reporting
report_timing_summary, report_utilization, report_power, report_drc

# Constraints
create_clock, set_input_delay, set_output_delay, set_false_path

# Object queries
get_cells, get_nets, get_pins, get_ports, get_clocks
```

**Reference**: UG894 (Vivado TCL Scripting), UG835 (TCL Command Reference)

## 21. FPGA Debugging Techniques

### 21.1 Integrated Logic Analyzer (ILA)
**ILA IP Core** (Xilinx ChipScope):
- Captures internal FPGA signals during runtime
- Triggers on conditions (edge, value, pattern)
- Non-intrusive (design continues running)
- Uses FPGA resources (BRAM for capture buffer)

**ILA Insertion (Mark Debug)**:
```verilog
// RTL: Mark signals for debug
(* mark_debug = "true" *) wire [7:0] debug_state;
(* mark_debug = "true" *) wire handshake_fail;
```

**TCL: Insert ILA**:
```tcl
# Create debug core
create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]

# Connect probes
set_property port_width 8 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets {debug_state[*]}]
```

### 21.2 Virtual I/O (VIO)
**VIO IP Core**:
- Control FPGA signals from Vivado Hardware Manager
- Read internal values in real-time
- Inject stimulus without recompilation

**Use case**: Toggle reset, change configuration registers during debug

```tcl
create_debug_core u_vio_0 vio
set_property C_NUM_PROBE_IN 2 [get_debug_cores u_vio_0]
set_property C_NUM_PROBE_OUT 1 [get_debug_cores u_vio_0]

# Connect: probe_out drives rst_n, probe_in reads status
connect_debug_port u_vio_0/probe_out0 [get_nets rst_n]
connect_debug_port u_vio_0/probe_in0 [get_nets {status[*]}]
```

### 21.3 Debug Workflow
1. **Insert ILA/VIO**: Mark signals in RTL or insert IP manually
2. **Implement design**: ILA uses BRAM, impacts resource utilization
3. **Program FPGA**: Load bitstream
4. **Open Hardware Manager**: Vivado → Hardware Manager
5. **Set trigger conditions**: Edge, value, comparison
6. **Arm trigger**: Wait for condition
7. **Capture waveform**: Analyze in integrated waveform viewer

### 21.4 Debugging Best Practices
**Minimize resource impact**:
- ILA depth: 1024 samples typical (not 32K)
- Probe only critical signals (not entire bus if not needed)
- Remove debug cores before final release

**Incremental compile**:
- Mark debug without full rebuild (Vivado debug feature)
- Faster iteration for debug insertion

**Comparison**: Xilinx ILA ≈ Intel SignalTap ≈ Gowin Analyzer Oscilloscope

## 22. Static Timing Analysis Deep Dive

### 22.1 STA Fundamentals
**Goal**: Verify design meets timing under all conditions without simulation

**Key metrics**:
- **WNS (Worst Negative Slack)**: Most critical setup violation (must be ≥ 0)
- **TNS (Total Negative Slack)**: Sum of all negative slacks (should be 0)
- **WHS (Worst Hold Slack)**: Most critical hold violation (must be ≥ 0)

### 22.2 Slack Calculation
**Setup slack** (data must arrive before clock edge):
```
Setup Slack = (Clock Period - Clock Uncertainty - Tco - Tlogic - Troute) - Tsetup

Positive slack: Signal arrives early (good)
Negative slack: Signal arrives late (violation)
```

**Hold slack** (data must remain stable after clock edge):
```
Hold Slack = (Tco + Tlogic + Troute) - Thold

Positive slack: Data stable long enough (good)
Negative slack: Data changes too soon (violation)
```

### 22.3 Critical Path Analysis
**Critical path** = Path with worst (most negative) slack

**Report critical paths**:
```tcl
# Top 10 failing setup paths
report_timing -setup -nworst 10 -path_type full

# Examine specific path
report_timing -from [get_pins src_ff/C] -to [get_pins dst_ff/D]
```

**Path components**:
1. Clock path delay (source)
2. Logic delay (LUTs, MUXes)
3. Net delay (routing)
4. Clock path delay (destination)
5. Setup/hold time

### 22.4 Timing Closure Techniques
**If WNS < 0**:
1. Reduce clock period (if too aggressive)
2. Add pipelining (break long combinational path)
3. Change synthesis strategy (PerformanceOptimized)
4. Enable physical optimization (phys_opt_design)
5. Use different place/route directive (AggressiveExplore)
6. Manually place critical cells (LOC constraints)

**If WHS < 0** (rare in FPGAs):
- Usually indicates constraint error
- Enable post-route physical optimization
- Check for large clock skew

### 22.5 Modern FPGA Timing (2025 Research)
Recent studies show Artix-7 designs achieving 472-510 MHz (mean 493 MHz), with variance due to placement/routing randomness. STA tools use vendor models to extract critical-path delays with per-path slack resolution.

## 23. Configuration and Bitstream Loading

### 23.1 Configuration Methods (Artix-7)
**JTAG Programming** (Volatile):
- Direct download from Vivado Hardware Manager
- Uses .bit file
- Lost on power cycle
- Ideal for development/debugging

**SPI Flash Programming** (Non-volatile):
- Bitstream stored in external flash (e.g., SPI, Quad-SPI)
- FPGA configured automatically on power-up (Master SPI mode)
- Uses .bin or .mcs file
- Persistent configuration

### 23.2 JTAG Programming Workflow
```tcl
# In Vivado Hardware Manager
open_hw_manager
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE {design.bit} [current_hw_device]
program_hw_devices [current_hw_device]
```

### 23.3 SPI Flash Programming
**Generate bitstream for flash**:
```tcl
# In Vivado, enable BIN file generation
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

# Generate bitstream
write_bitstream -bin_file design.bit
```

**Program flash via JTAG** (Vivado Hardware Manager):
1. Right-click FPGA → Add Configuration Memory Device
2. Select flash type (e.g., s25fl128sxxxxxx0 for 16MB Quad-SPI)
3. Select .bin file
4. Program flash
5. Power cycle FPGA (or press PROG button)

### 23.4 Bitstream Security
```tcl
# Enable bitstream encryption (requires key)
set_property BITSTREAM.ENCRYPTION.ENCRYPT YES [current_design]
set_property BITSTREAM.ENCRYPTION.ENCRYPTKEYSELECT {bbram} [current_design]

# Enable readback protection
set_property BITSTREAM.CONFIG.PROHIBIT_READBACK TRUE [current_design]
```

**Note**: Encryption uses AES-256, key stored in BBRAM or eFUSE.

## 24. Power Optimization Techniques

### 24.1 Clock Gating
```verilog
// Manual clock gating (save dynamic power)
wire gated_clk;
assign gated_clk = clk & enable;

always @(posedge gated_clk) begin
  // Logic only switches when enabled
  data_reg <= data_in;
end

// Prefer: Enable signal on register (FPGA-friendly)
always @(posedge clk) begin
  if (enable)
    data_reg <= data_in;
end
```

**Tool-based clock gating**:
```tcl
# Vivado can automatically insert clock gates
set_property CLOCK_GATING TRUE [get_cells module_inst]
```

### 24.2 Dynamic Voltage and Frequency Scaling (DVFS)
**Concept**: Adjust voltage/frequency based on workload
- Reduce VCC during low-performance mode → lower power
- Implemented externally (board-level voltage regulator control)
- FPGA design signals power controller

**Recent research (2025)**: DVFS reduces energy 27-48% in ultra-low-power systems, especially IoT and edge applications.

### 24.3 Resource Optimization for Power
**Use Block RAM over distributed RAM**:
- BRAM: Lower power for large storage
- Distributed RAM (LUTs): Higher power, better latency

**Use DSP blocks for arithmetic**:
- DSP48: Optimized for power in multiplication/MAC
- LUT-based: Higher power consumption

**Disable unused I/Os**:
```tcl
set_property IOSTANDARD LVCMOS33 [get_ports unused_pin]
set_property DRIVE 2 [get_ports unused_pin]
set_property SLEW SLOW [get_ports unused_pin]
```

### 24.4 Power Analysis
```tcl
# Vivado Power Report
report_power -file power.txt

# Interpret results:
# - On-Chip Power: VCCINT + VCCAUX + VCCO
# - Dynamic Power: Switching activity
# - Static Power: Leakage (constant)
```

**Power reduction checklist**:
- [ ] Enable clock gating for idle blocks
- [ ] Use lowest drive strength for I/O
- [ ] Reduce toggle rate (lower clock frequency if possible)
- [ ] Use BRAM/DSP instead of LUTs for large operations

## 25. Modular Design and IP Reuse

### 25.1 Hierarchical Partitioning Strategy
**Benefits**:
- Parallel development (team-based design)
- Incremental compilation (faster rebuild)
- IP reuse across projects
- Simplified debugging (isolate modules)

**Partitioning guidelines**:
1. Define clear interfaces (AXI, custom protocols)
2. Separate timing-critical from non-critical logic
3. Isolate IP blocks that won't change
4. Create self-contained modules with dedicated resources

### 25.2 Design Hierarchy Example
```
top
├── clk_manager (clock generation)
├── control_unit (FSM, configuration)
├── data_processing (DSP, BRAM)
│   ├── fir_filter
│   └── fft_engine
├── io_interface (AXI, UART, SPI)
└── debug_logic (ILA, VIO)
```

### 25.3 IP Packaging and Reuse
**Vivado IP Packager**:
1. Create IP project: Tools → Create and Package IP
2. Define ports and parameters
3. Add documentation (IP-XACT metadata)
4. Package IP (generates .zip)
5. Add to IP repository for reuse

**Best practices**:
- Version control for IP cores
- Document interfaces thoroughly (timing, protocols)
- Include testbenches with IP
- Use parameters for configurability

### 25.4 Incremental Compilation (Vivado)
```tcl
# Lock timing-closed partition
set_property HD.PARTITION 1 [get_cells data_processing_inst]
set_property INCREMENTAL_CHECKPOINT prev_run.dcp [get_runs impl_1]

# Only re-synthesize changed modules
```

**Use when**:
- Minor RTL changes to one module
- Preserving timing closure in stable modules
- Faster iteration during development

### 25.5 Module Design Templates

#### 25.5.1 Clock Manager Module
**Purpose**: Centralized clock generation and distribution with proper domain isolation.

```verilog
module clk_manager (
  // Input clock and reset
  input  wire       clk_in_100mhz,     // External 100 MHz clock
  input  wire       rst_n_async,        // Asynchronous reset (active-low)

  // Generated clocks
  output wire       clk_core_200mhz,   // Core logic clock
  output wire       clk_io_50mhz,      // I/O interface clock
  output wire       clk_ddr_400mhz,    // DDR controller clock

  // Status
  output wire       mmcm_locked,       // PLL locked indicator
  output wire       rst_core_n,        // Synchronized reset for core domain
  output wire       rst_io_n           // Synchronized reset for I/O domain
);

  // Internal signals
  wire clk_fb;              // MMCM feedback clock
  wire clk_core_unbuf;      // Unbuffered core clock
  wire clk_io_unbuf;        // Unbuffered I/O clock
  wire clk_ddr_unbuf;       // Unbuffered DDR clock

  // MMCM instance (Mixed-Mode Clock Manager)
  MMCME2_BASE #(
    .CLKFBOUT_MULT_F(8.0),         // 100 MHz * 8 = 800 MHz (VCO)
    .CLKIN1_PERIOD(10.0),          // 100 MHz input period
    .CLKOUT0_DIVIDE_F(4.0),        // 800 / 4 = 200 MHz (core)
    .CLKOUT1_DIVIDE(16),           // 800 / 16 = 50 MHz (I/O)
    .CLKOUT2_DIVIDE(2),            // 800 / 2 = 400 MHz (DDR)
    .DIVCLK_DIVIDE(1)
  ) mmcm_inst (
    .CLKIN1(clk_in_100mhz),
    .CLKFBIN(clk_fb),
    .CLKOUT0(clk_core_unbuf),
    .CLKOUT1(clk_io_unbuf),
    .CLKOUT2(clk_ddr_unbuf),
    .CLKFBOUT(clk_fb),
    .LOCKED(mmcm_locked),
    .PWRDWN(1'b0),
    .RST(~rst_n_async)
  );

  // Global buffer for clock distribution
  BUFG bufg_core (.I(clk_core_unbuf), .O(clk_core_200mhz));
  BUFG bufg_io   (.I(clk_io_unbuf),   .O(clk_io_50mhz));
  BUFG bufg_ddr  (.I(clk_ddr_unbuf),  .O(clk_ddr_400mhz));

  // Reset synchronizers (2-FF synchronizer for each clock domain)
  reset_sync reset_sync_core (
    .clk(clk_core_200mhz),
    .async_rst_n(rst_n_async & mmcm_locked),
    .sync_rst_n(rst_core_n)
  );

  reset_sync reset_sync_io (
    .clk(clk_io_50mhz),
    .async_rst_n(rst_n_async & mmcm_locked),
    .sync_rst_n(rst_io_n)
  );

endmodule

// Reset synchronizer helper module
module reset_sync (
  input  wire clk,
  input  wire async_rst_n,
  output reg  sync_rst_n
);
  reg rst_sync_ff1;

  always @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n) begin
      rst_sync_ff1 <= 1'b0;
      sync_rst_n   <= 1'b0;
    end else begin
      rst_sync_ff1 <= 1'b1;
      sync_rst_n   <= rst_sync_ff1;
    end
  end
endmodule
```

**Key design points**:
- MMCM generates multiple synchronized clocks from single input
- BUFG ensures low-skew global distribution
- Each clock domain has dedicated synchronized reset
- `mmcm_locked` gates reset release to prevent metastability

#### 25.5.2 AXI4-Lite Slave Peripheral Template
**Purpose**: Standard memory-mapped peripheral for CPU/DMA access.

```verilog
module axi_slave_peripheral #(
  parameter C_ADDR_WIDTH = 12,       // 4KB address space
  parameter C_DATA_WIDTH = 32        // 32-bit data bus
)(
  // AXI4-Lite interface
  input  wire                       aclk,
  input  wire                       aresetn,

  // Write address channel
  input  wire [C_ADDR_WIDTH-1:0]    s_axi_awaddr,
  input  wire [2:0]                 s_axi_awprot,
  input  wire                       s_axi_awvalid,
  output wire                       s_axi_awready,

  // Write data channel
  input  wire [C_DATA_WIDTH-1:0]    s_axi_wdata,
  input  wire [C_DATA_WIDTH/8-1:0]  s_axi_wstrb,
  input  wire                       s_axi_wvalid,
  output wire                       s_axi_wready,

  // Write response channel
  output wire [1:0]                 s_axi_bresp,
  output wire                       s_axi_bvalid,
  input  wire                       s_axi_bready,

  // Read address channel
  input  wire [C_ADDR_WIDTH-1:0]    s_axi_araddr,
  input  wire [2:0]                 s_axi_arprot,
  input  wire                       s_axi_arvalid,
  output wire                       s_axi_arready,

  // Read data channel
  output wire [C_DATA_WIDTH-1:0]    s_axi_rdata,
  output wire [1:0]                 s_axi_rresp,
  output wire                       s_axi_rvalid,
  input  wire                       s_axi_rready,

  // User logic interface
  output wire [31:0]                ctrl_reg,      // Control register
  input  wire [31:0]                status_reg,    // Status register
  output wire                       trigger_pulse  // Single-cycle pulse
);

  // Register map
  localparam ADDR_CTRL   = 12'h000;  // 0x000: Control register (R/W)
  localparam ADDR_STATUS = 12'h004;  // 0x004: Status register (RO)
  localparam ADDR_TRIG   = 12'h008;  // 0x008: Trigger register (W1P)

  // Internal registers
  reg [C_ADDR_WIDTH-1:0]  awaddr_reg;
  reg [C_ADDR_WIDTH-1:0]  araddr_reg;
  reg [C_DATA_WIDTH-1:0]  ctrl_reg_int;
  reg                     awready_reg;
  reg                     wready_reg;
  reg                     bvalid_reg;
  reg                     arready_reg;
  reg                     rvalid_reg;
  reg [C_DATA_WIDTH-1:0]  rdata_reg;
  reg                     trigger_pulse_reg;

  // Write transaction state machine
  localparam W_IDLE = 2'b00, W_DATA = 2'b01, W_RESP = 2'b10;
  reg [1:0] wr_state;

  always @(posedge aclk) begin
    if (!aresetn) begin
      wr_state      <= W_IDLE;
      awaddr_reg    <= 0;
      ctrl_reg_int  <= 0;
      awready_reg   <= 1'b0;
      wready_reg    <= 1'b0;
      bvalid_reg    <= 1'b0;
      trigger_pulse_reg <= 1'b0;
    end else begin
      trigger_pulse_reg <= 1'b0;  // Default: pulse is single-cycle

      case (wr_state)
        W_IDLE: begin
          awready_reg <= 1'b1;
          if (s_axi_awvalid && awready_reg) begin
            awaddr_reg  <= s_axi_awaddr;
            awready_reg <= 1'b0;
            wready_reg  <= 1'b1;
            wr_state    <= W_DATA;
          end
        end

        W_DATA: begin
          if (s_axi_wvalid && wready_reg) begin
            wready_reg <= 1'b0;
            bvalid_reg <= 1'b1;

            // Write to registers based on address
            case (awaddr_reg)
              ADDR_CTRL:   ctrl_reg_int     <= s_axi_wdata;
              ADDR_TRIG:   trigger_pulse_reg <= 1'b1;  // Write-1-pulse
              default:     ;  // Ignore writes to read-only addresses
            endcase

            wr_state <= W_RESP;
          end
        end

        W_RESP: begin
          if (s_axi_bready && bvalid_reg) begin
            bvalid_reg <= 1'b0;
            wr_state   <= W_IDLE;
          end
        end
      endcase
    end
  end

  // Read transaction (single-cycle response)
  always @(posedge aclk) begin
    if (!aresetn) begin
      araddr_reg  <= 0;
      arready_reg <= 1'b0;
      rvalid_reg  <= 1'b0;
      rdata_reg   <= 0;
    end else begin
      // Address handshake
      arready_reg <= 1'b1;
      if (s_axi_arvalid && arready_reg) begin
        araddr_reg  <= s_axi_araddr;
        arready_reg <= 1'b0;
        rvalid_reg  <= 1'b1;

        // Read from registers
        case (s_axi_araddr)
          ADDR_CTRL:   rdata_reg <= ctrl_reg_int;
          ADDR_STATUS: rdata_reg <= status_reg;
          default:     rdata_reg <= 32'hDEADBEEF;  // Error indicator
        endcase
      end

      // Data handshake
      if (s_axi_rready && rvalid_reg) begin
        rvalid_reg <= 1'b0;
      end
    end
  end

  // Output assignments
  assign s_axi_awready = awready_reg;
  assign s_axi_wready  = wready_reg;
  assign s_axi_bvalid  = bvalid_reg;
  assign s_axi_bresp   = 2'b00;  // OKAY response
  assign s_axi_arready = arready_reg;
  assign s_axi_rvalid  = rvalid_reg;
  assign s_axi_rdata   = rdata_reg;
  assign s_axi_rresp   = 2'b00;  // OKAY response

  assign ctrl_reg      = ctrl_reg_int;
  assign trigger_pulse = trigger_pulse_reg;

endmodule
```

**Key design points**:
- Full AXI4-Lite protocol compliance
- Simple state machine for write transactions
- Combinational read response (1-cycle latency)
- Write-1-pulse trigger register pattern
- Clear separation of AXI interface and user logic

#### 25.5.3 Asynchronous FIFO for Clock Domain Crossing
**Purpose**: Safe data transfer between unrelated clock domains.

```verilog
module async_fifo_cdc #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 4         // Depth = 2^4 = 16 entries
)(
  // Write clock domain
  input  wire                   wr_clk,
  input  wire                   wr_rst_n,
  input  wire [DATA_WIDTH-1:0]  wr_data,
  input  wire                   wr_en,
  output wire                   wr_full,

  // Read clock domain
  input  wire                   rd_clk,
  input  wire                   rd_rst_n,
  output wire [DATA_WIDTH-1:0]  rd_data,
  input  wire                   rd_en,
  output wire                   rd_empty
);

  localparam DEPTH = 1 << ADDR_WIDTH;

  // Dual-port RAM
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  // Gray code pointers
  reg [ADDR_WIDTH:0] wr_ptr_gray, wr_ptr_bin;
  reg [ADDR_WIDTH:0] rd_ptr_gray, rd_ptr_bin;

  // Synchronized pointers (cross clock domains)
  reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
  reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

  // Binary to Gray code converter
  function [ADDR_WIDTH:0] bin2gray;
    input [ADDR_WIDTH:0] bin;
    begin
      bin2gray = bin ^ (bin >> 1);
    end
  endfunction

  // Gray to Binary code converter
  function [ADDR_WIDTH:0] gray2bin;
    input [ADDR_WIDTH:0] gray;
    integer i;
    begin
      gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
      for (i = ADDR_WIDTH-1; i >= 0; i = i - 1)
        gray2bin[i] = gray2bin[i+1] ^ gray[i];
    end
  endfunction

  // Write clock domain
  always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_ptr_bin  <= 0;
      wr_ptr_gray <= 0;
    end else if (wr_en && !wr_full) begin
      mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
      wr_ptr_bin  <= wr_ptr_bin + 1;
      wr_ptr_gray <= bin2gray(wr_ptr_bin + 1);
    end
  end

  // Synchronize read pointer to write clock domain (2-FF)
  always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rd_ptr_gray_sync1 <= 0;
      rd_ptr_gray_sync2 <= 0;
    end else begin
      rd_ptr_gray_sync1 <= rd_ptr_gray;
      rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
  end

  assign wr_full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                     rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});

  // Read clock domain
  reg [DATA_WIDTH-1:0] rd_data_reg;

  always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_ptr_bin  <= 0;
      rd_ptr_gray <= 0;
      rd_data_reg <= 0;
    end else if (rd_en && !rd_empty) begin
      rd_data_reg <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
      rd_ptr_bin  <= rd_ptr_bin + 1;
      rd_ptr_gray <= bin2gray(rd_ptr_bin + 1);
    end
  end

  // Synchronize write pointer to read clock domain (2-FF)
  always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wr_ptr_gray_sync1 <= 0;
      wr_ptr_gray_sync2 <= 0;
    end else begin
      wr_ptr_gray_sync1 <= wr_ptr_gray;
      wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
  end

  assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync2);
  assign rd_data  = rd_data_reg;

endmodule
```

**Key design points**:
- Gray code pointers eliminate multi-bit transition glitches
- 2-FF synchronizers for CDC (MTBF > 10^12 hours)
- Dual-port RAM synthesizes to BRAM or distributed RAM
- Full/empty detection accounts for pointer wrap-around
- No FIFO resets required across clock domains

#### 25.5.4 FSM-Based Control Unit Template
**Purpose**: State machine for sequencing operations with timeout protection.

```verilog
module control_fsm (
  input  wire       clk,
  input  wire       rst_n,

  // Control inputs
  input  wire       start,          // Start operation
  input  wire       abort,          // Abort current operation

  // Status inputs from data path
  input  wire       init_done,      // Initialization complete
  input  wire       proc_done,      // Processing complete
  input  wire       error_flag,     // Error detected

  // Control outputs to data path
  output reg        init_en,        // Enable initialization
  output reg        proc_en,        // Enable processing
  output reg        result_valid,   // Result is valid
  output reg [2:0]  fsm_state_out   // For debugging (ILA)
);

  // State encoding (one-hot for faster decode)
  localparam [2:0]
    IDLE    = 3'b001,
    INIT    = 3'b010,
    PROCESS = 3'b100;

  reg [2:0] state, next_state;

  // Timeout counter (protects against hangs)
  localparam TIMEOUT_CYCLES = 10000;  // 50us @ 200 MHz
  reg [15:0] timeout_cnt;
  wire timeout = (timeout_cnt == TIMEOUT_CYCLES);

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = state;  // Default: stay in current state

    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        if (abort || timeout)
          next_state = IDLE;
        else if (init_done)
          next_state = PROCESS;
      end

      PROCESS: begin
        if (abort || error_flag || timeout)
          next_state = IDLE;
        else if (proc_done)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Output logic (registered for timing)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      init_en      <= 1'b0;
      proc_en      <= 1'b0;
      result_valid <= 1'b0;
      timeout_cnt  <= 0;
    end else begin
      // Default outputs
      init_en      <= 1'b0;
      proc_en      <= 1'b0;
      result_valid <= 1'b0;

      case (state)
        IDLE: begin
          timeout_cnt <= 0;
        end

        INIT: begin
          init_en     <= 1'b1;
          timeout_cnt <= timeout_cnt + 1;
        end

        PROCESS: begin
          proc_en     <= 1'b1;
          timeout_cnt <= timeout_cnt + 1;

          if (proc_done && !error_flag)
            result_valid <= 1'b1;
        end
      endcase

      // Reset timeout on state transitions
      if (state != next_state)
        timeout_cnt <= 0;
    end
  end

  assign fsm_state_out = state;

endmodule
```

**Key design points**:
- One-hot encoding for fast state decode
- Registered outputs for better timing
- Timeout protection against hung states
- Abort capability for user intervention
- State output for ILA debugging

### 25.6 Module Interface Standards

#### 25.6.1 Clock Domain Naming Convention
**Mandatory naming pattern**: `signal_name_clk<domain>`

```verilog
// Good examples
wire [31:0] data_clk_core;      // Signal in core clock domain
wire        valid_clk_io;       // Signal in I/O clock domain
wire        ready_clk_ddr;      // Signal in DDR clock domain

// Bad examples (ambiguous)
wire [31:0] data;               // Which clock domain?
wire        axi_valid;          // Not clear which AXI clock
```

**Cross-domain signals must use CDC primitives**:
```verilog
// Single-bit CDC (pulse synchronizer)
pulse_sync u_pulse_sync (
  .src_clk(clk_a),
  .src_pulse(trigger_clk_a),
  .dst_clk(clk_b),
  .dst_pulse(trigger_clk_b)
);

// Multi-bit CDC (async FIFO)
async_fifo_cdc #(.DATA_WIDTH(32)) u_fifo (
  .wr_clk(clk_a),
  .wr_data(data_clk_a),
  .wr_en(wr_en_clk_a),
  .rd_clk(clk_b),
  .rd_data(data_clk_b),
  .rd_en(rd_en_clk_b)
);
```

#### 25.6.2 Valid-Ready Handshake Protocol
**Standard for all streaming interfaces** (replaces simple enable signals).

```verilog
module producer (
  input  wire        clk,
  input  wire        rst_n,

  // Streaming output
  output reg  [31:0] data_out,
  output reg         valid_out,
  input  wire        ready_in      // Backpressure from consumer
);

  always @(posedge clk) begin
    if (valid_out && ready_in) begin
      // Transaction completed, generate next data
      data_out  <= next_data;
      valid_out <= has_more_data;
    end else if (!valid_out) begin
      // Start new transaction
      data_out  <= first_data;
      valid_out <= 1'b1;
    end
    // If valid && !ready, stall (keep data_out and valid_out stable)
  end
endmodule

module consumer (
  input  wire        clk,
  input  wire        rst_n,

  // Streaming input
  input  wire [31:0] data_in,
  input  wire        valid_in,
  output reg         ready_out     // Backpressure control
);

  always @(posedge clk) begin
    if (valid_in && ready_out) begin
      // Consume data
      process_data(data_in);
    end

    // Ready signal logic (example: FIFO not full)
    ready_out <= !internal_fifo_full;
  end
endmodule
```

**Handshake rules**:
1. `valid` must NOT depend on `ready` (avoid combinational loops)
2. `ready` MAY depend on `valid`
3. Once `valid` asserted, data must remain stable until `ready` asserted
4. Transaction completes when `valid && ready` on rising clock edge

#### 25.6.3 Reset Strategy Standards

**Type 1: Asynchronous reset, synchronous de-assertion** (recommended for most designs)
```verilog
module design_with_async_reset (
  input  wire clk,
  input  wire rst_n_async,  // Asynchronous active-low reset
  output reg  data_valid
);

  // Synchronize reset release
  reg rst_n_sync1, rst_n_sync2;

  always @(posedge clk or negedge rst_n_async) begin
    if (!rst_n_async) begin
      rst_n_sync1 <= 1'b0;
      rst_n_sync2 <= 1'b0;
    end else begin
      rst_n_sync1 <= 1'b1;
      rst_n_sync2 <= rst_n_sync1;
    end
  end

  wire rst_n = rst_n_sync2;  // Use synchronized reset

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      data_valid <= 1'b0;
    else
      data_valid <= compute_valid();
  end
endmodule
```

**Type 2: Synchronous reset** (use for BRAM-heavy designs to save resources)
```verilog
always @(posedge clk) begin
  if (!rst_n_sync)
    data_valid <= 1'b0;
  else
    data_valid <= compute_valid();
end
```

**Global reset tree**: Use dedicated `clk_manager` module to generate synchronized resets for each clock domain (see template 25.5.1).

#### 25.6.4 Parameterization Guidelines

**Use parameters for configurability, but avoid over-parameterization**.

```verilog
module configurable_filter #(
  // Mandatory parameters (must be set by user)
  parameter DATA_WIDTH = 16,              // Bit width
  parameter TAP_COUNT  = 8,               // Number of FIR taps

  // Optional parameters (reasonable defaults)
  parameter COEFF_WIDTH = 18,             // Default matches DSP48 width
  parameter OUTPUT_REG  = 1,              // Pipeline output stage

  // Derived parameters (do not override)
  parameter MULT_WIDTH = DATA_WIDTH + COEFF_WIDTH,
  parameter ACCUM_WIDTH = MULT_WIDTH + $clog2(TAP_COUNT)
)(
  input  wire                    clk,
  input  wire [DATA_WIDTH-1:0]   data_in,
  output wire [ACCUM_WIDTH-1:0]  data_out
);
  // Implementation
endmodule
```

**Parameter validation** (synthesizable assertions):
```verilog
initial begin
  if (DATA_WIDTH < 8 || DATA_WIDTH > 32)
    $error("DATA_WIDTH must be 8-32 bits");
  if (TAP_COUNT < 2 || TAP_COUNT > 256)
    $error("TAP_COUNT must be 2-256");
end
```

### 25.7 Module Resource Budgeting

#### 25.7.1 Artix-7 XC7A35T Resource Allocation
**Total available resources**:
- Logic Cells: 33,280
- Flip-Flops: 41,600
- LUTs: 20,800
- BRAM (36Kb): 50 blocks (1,800 Kb total)
- DSP48E1 Slices: 90

**Recommended allocation strategy** (reserve 20% for routing/overhead):

| Module Category | LUT % | FF % | BRAM | DSP | Priority |
|----------------|-------|------|------|-----|----------|
| Clock Manager | 0.5% | 0.3% | 0 | 0 | P0 |
| Control/Config | 5% | 10% | 2 | 0 | P0 |
| Data Processing | 50% | 40% | 30 | 70 | P1 |
| I/O Interface | 10% | 15% | 8 | 5 | P1 |
| Debug (ILA/VIO) | 5% | 5% | 5 | 0 | P2 |
| **Reserve** | 20% | 20% | 5 | 15 | - |
| **TOTAL** | 90% | 90% | 50 | 90 | - |

**Example module budgets**:
```
clk_manager:      200 LUT,  50 FF,  0 BRAM,  0 DSP (0.9% LUT)
axi_ctrl_regs:  1,000 LUT, 800 FF,  2 BRAM,  0 DSP (4.8% LUT)
fir_filter:     3,500 LUT, 2.5k FF, 4 BRAM, 16 DSP (16.8% LUT)
fft_1024pt:     5,000 LUT, 4.0k FF, 12 BRAM, 40 DSP (24.0% LUT)
axi_dma:        2,000 LUT, 1.5k FF, 6 BRAM,  0 DSP (9.6% LUT)
uart_interface:   500 LUT, 300 FF,  1 BRAM,  0 DSP (2.4% LUT)
ila_debug:      1,200 LUT, 800 FF,  4 BRAM,  0 DSP (5.8% LUT)
```

#### 25.7.2 Resource Overflow Mitigation

**When module exceeds budget**:
1. **Partition into sub-modules**: Split large modules at natural boundaries
   ```
   fft_1024pt (24% LUT) → Exceeds budget
   ├── fft_butterfly (8% LUT)
   ├── fft_twiddle (6% LUT)
   └── fft_reorder (10% LUT)
   ```

2. **Time-multiplex resources**: Share DSP/BRAM across operations
   ```verilog
   // Bad: Parallel multipliers (uses 4 DSP)
   assign out1 = a1 * b1;
   assign out2 = a2 * b2;
   assign out3 = a3 * b3;
   assign out4 = a4 * b4;

   // Good: Time-multiplexed (uses 1 DSP)
   always @(posedge clk) begin
     case (cycle)
       0: out1 <= a1 * b1;
       1: out2 <= a2 * b2;
       2: out3 <= a3 * b3;
       3: out4 <= a4 * b4;
     endcase
   end
   ```

3. **Optimize synthesis settings**:
   ```tcl
   # Per-module synthesis strategy
   set_property STRATEGY Flow_AreaOptimized_high [get_runs synth_1]

   # Flatten hierarchy for small modules
   set_property FLATTEN_HIERARCHY full [get_cells small_module_inst]

   # Keep hierarchy for large modules (enables incremental compile)
   set_property FLATTEN_HIERARCHY none [get_cells large_module_inst]
   ```

**Resource monitoring script** (TCL):
```tcl
# Check resource usage per module
report_utilization -hierarchical -hierarchical_depth 2 \
  -file reports/utilization_hierarchical.rpt

# Flag modules exceeding budget (example: >25% LUT)
set lut_budget 5200  ;# 25% of 20,800
foreach cell [get_cells -hierarchical] {
  set lut_count [get_property LUT_COUNT $cell]
  if {$lut_count > $lut_budget} {
    puts "WARNING: $cell uses $lut_count LUTs (exceeds budget)"
  }
}
```

### 25.8 Module Version Control and Change Tracking

#### 25.8.1 Module Version Header Template

**Mandatory header for all RTL files**:
```verilog
//==============================================================================
// Module: clk_manager
// Description: Centralized clock generation with MMCM and reset synchronization
//
// Author: [Your Name]
// Created: 2026-01-04
// Version: 1.2.0
//
// Version History:
//   1.0.0 (2025-12-01) - Initial release
//     - Basic MMCM configuration for 3 clock domains
//     - 2-FF reset synchronizers
//   1.1.0 (2025-12-15) - Feature addition
//     - Added 4th clock domain (clk_aux_100mhz)
//     - Enhanced MMCM lock detection with debounce
//   1.2.0 (2026-01-04) - Bug fix
//     - Fixed race condition in reset release (Issue #42)
//     - Changed reset polarity to active-low for consistency
//
// Dependencies:
//   - None (self-contained primitive instantiation)
//
// Parameters:
//   - None (clock frequencies hard-coded to board spec)
//
// Known Issues:
//   - None
//
// License: [Your License]
//==============================================================================

module clk_manager (
  // ...
);
```

**Header field requirements**:
- **Module name**: Matches file name (e.g., `clk_manager.v`)
- **Description**: 1-2 sentence summary of functionality
- **Version**: Semantic versioning (MAJOR.MINOR.PATCH)
  - MAJOR: Interface-breaking changes (port additions/removals)
  - MINOR: New features, backward-compatible
  - PATCH: Bug fixes, no interface changes
- **Version History**: Last 3-5 versions with date, summary, issue references
- **Dependencies**: List other modules/IPs this module instantiates
- **Parameters**: Document expected parameter ranges
- **Known Issues**: Open bugs or limitations

#### 25.8.2 Git Branching Strategy for FPGA Projects

**Branch structure**:
```
main (production-ready releases)
├── develop (integration branch)
│   ├── feature/add-ddr3-controller
│   ├── feature/axi-dma-engine
│   ├── bugfix/timing-closure-issue-42
│   └── refactor/modularize-io-interface
└── release/v2.0.0 (release candidate)
```

**Branch naming conventions**:
- `feature/short-description`: New functionality
- `bugfix/issue-number-short-desc`: Bug fixes
- `refactor/short-description`: Code cleanup, no functional change
- `release/vX.Y.Z`: Release preparation branches

**Workflow**:
1. **Feature development**: Branch from `develop`
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/add-uart-controller
   # Work on feature, commit frequently
   git commit -m "Add UART TX module with 8N1 config"
   git commit -m "Add UART RX module with FIFO buffering"
   ```

2. **Pull request review**: Before merging to `develop`
   - Verify synthesis/implementation success
   - Check timing closure (no negative slack)
   - Run testbenches (100% pass rate)
   - Peer code review

3. **Merge to develop**:
   ```bash
   git checkout develop
   git merge --no-ff feature/add-uart-controller
   git tag -a uart-v1.0.0 -m "UART controller initial release"
   git push --tags
   ```

4. **Release process**: When `develop` is stable
   ```bash
   git checkout -b release/v2.0.0
   # Final testing, documentation updates
   git checkout main
   git merge --no-ff release/v2.0.0
   git tag -a v2.0.0 -m "Release v2.0.0: Added UART, DDR3 controller"
   git push --tags
   ```

#### 25.8.3 Commit Message Standards for FPGA

**Format** (Conventional Commits):
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature (RTL module, IP integration)
- `fix`: Bug fix (timing violation, functional error)
- `refactor`: Code restructuring (no functional change)
- `test`: Testbench additions/modifications
- `docs`: Documentation only (README, comments)
- `constraint`: XDC constraint changes
- `perf`: Performance optimization (resource reduction, speed improvement)

**Scope**: Module or subsystem affected (e.g., `clk_manager`, `axi_slave`, `xdc`)

**Examples**:
```bash
# Good commit messages
git commit -m "feat(axi_dma): Add scatter-gather DMA engine with ring buffer

- Supports up to 16 BD (Buffer Descriptors)
- AXI4-Full master interface for memory access
- Interrupt generation on transfer completion

Closes #67"

git commit -m "fix(timing): Close setup violation in data_processing module

- Added pipeline stage in DSP48 multiply path
- WNS improved from -0.8ns to +0.5ns
- Resource impact: +50 FF

Fixes #42"

git commit -m "refactor(io_interface): Split UART into TX/RX sub-modules

- Improved modularity for IP reuse
- No functional changes
- Passes all existing testbenches"

# Bad commit messages (too vague)
git commit -m "update code"
git commit -m "fix bug"
git commit -m "WIP"
```

#### 25.8.4 Module Release Checklist

**Before tagging a module release** (e.g., `uart-v1.0.0`):
- [ ] **Synthesis successful**: No critical warnings (DRC clean)
- [ ] **Timing closure**: WNS ≥ 0ns, all clocks constrained
- [ ] **Testbench passes**: 100% of test cases pass
- [ ] **Code coverage**: ≥95% statement/branch coverage
- [ ] **Resource budget**: Module within allocated LUT/BRAM/DSP limits
- [ ] **Documentation updated**: Module header, README, interface spec
- [ ] **CHANGELOG entry**: Added version, changes, known issues
- [ ] **Peer review**: At least one other engineer reviewed code
- [ ] **CDC check**: No clock domain crossing violations (if applicable)
- [ ] **Lint clean**: No critical lint warnings (dead code, unused signals)

#### 25.8.5 CHANGELOG Format

**File**: `CHANGELOG.md` (project root)

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- AXI4-Stream FIFO adapter for width conversion (32-bit ↔ 128-bit)

### Changed
- Migrated clock manager from PLL to MMCM for lower jitter

### Fixed
- UART RX overrun error during back-to-back reception

## [2.0.0] - 2026-01-04
### Added
- DDR3 controller using Xilinx MIG IP (16-bit data width, 800 Mbps)
- AXI DMA engine with scatter-gather support
- UART controller (115200 baud, 8N1, FIFO depth=16)

### Changed
- Refactored I/O interface into modular sub-blocks (UART, SPI, GPIO)
- Updated constraint file for new DDR3 pinout

### Fixed
- Timing closure in data_processing module (added pipeline stage)
- CDC violation between core and I/O clocks (Issue #42)

### Removed
- Deprecated legacy parallel bus interface (replaced by AXI)

## [1.0.0] - 2025-11-15
### Added
- Initial release with basic clock management and GPIO
```

**Update rules**:
- **Unreleased section**: Add changes as they are committed
- **On release**: Move Unreleased to new version section, create new Unreleased

#### 25.8.6 Module Dependency Tracking

**Dependency graph documentation** (in `docs/module_dependencies.md`):
```markdown
# Module Dependency Graph

## Top-Level Hierarchy
```
cyan_hd_top
├── clk_manager (no dependencies)
├── axi_interconnect (Xilinx IP)
│   ├── axi_slave_ctrl_regs
│   ├── axi_slave_ddr3_ctrl
│   └── axi_dma_engine
├── data_processing
│   ├── fir_filter (depends on: clk_manager)
│   └── fft_engine (depends on: clk_manager)
└── io_interface
    ├── uart_controller (depends on: clk_manager)
    └── spi_master (depends on: clk_manager)
```

## Critical Paths
- **DDR3 Data Path**: axi_interconnect → axi_dma_engine → data_processing
- **Control Path**: uart_controller → axi_slave_ctrl_regs → all modules

## Version Compatibility Matrix
| Module | Version | Requires clk_manager | Requires AXI Interconnect |
|--------|---------|---------------------|---------------------------|
| axi_dma_engine | 1.2.0 | ≥1.1.0 | ≥2.0 |
| uart_controller | 1.0.0 | ≥1.0.0 | No |
| fir_filter | 2.1.0 | ≥1.2.0 | No |
```

**Dependency change protocol**:
1. If module A changes interface, increment MAJOR version
2. Identify all dependent modules (grep codebase for instantiations)
3. Update dependent modules or add compatibility shim
4. Document in CHANGELOG under "BREAKING CHANGES"

#### 25.8.7 Git Hooks for FPGA Projects

**Pre-commit hook** (`.git/hooks/pre-commit`):
```bash
#!/bin/bash
# FPGA-specific pre-commit checks

echo "Running pre-commit checks..."

# 1. Check for module version headers
missing_headers=$(find source/hdl -name "*.v" -type f -exec grep -L "Version:" {} \;)
if [ -n "$missing_headers" ]; then
  echo "ERROR: Files missing version headers:"
  echo "$missing_headers"
  exit 1
fi

# 2. Verify no hardcoded absolute paths (use relative paths)
hardcoded_paths=$(grep -rn "C:\|/home/" source/ --include="*.v" --include="*.xdc" --include="*.tcl")
if [ -n "$hardcoded_paths" ]; then
  echo "ERROR: Hardcoded absolute paths found:"
  echo "$hardcoded_paths"
  exit 1
fi

# 3. Check for common RTL mistakes (latches, etc.)
latch_warnings=$(grep -rn "always @" source/hdl --include="*.v" | grep -v "posedge\|negedge")
if [ -n "$latch_warnings" ]; then
  echo "WARNING: Potential latches (combinational always without edge):"
  echo "$latch_warnings"
  # Note: This is a warning, not an error (some designs intentionally use latches)
fi

# 4. Ensure CHANGELOG updated (if not a docs-only commit)
if git diff --cached --name-only | grep -qvE '\.md$|\.txt$'; then
  if ! git diff --cached --name-only | grep -q "CHANGELOG.md"; then
    echo "WARNING: Non-documentation changes without CHANGELOG update"
    echo "Consider updating CHANGELOG.md"
  fi
fi

echo "Pre-commit checks passed!"
exit 0
```

**Make executable**:
```bash
chmod +x .git/hooks/pre-commit
```

#### 25.8.8 Collaborative Development Best Practices

**Multi-designer workflow**:
1. **Module ownership**: Assign each module to primary owner
   - Owner reviews all changes to their module
   - Owner maintains module version header and tests

2. **Interface freeze dates**: For critical milestones
   - Announce "interface freeze" date (e.g., 2 weeks before tapeout)
   - After freeze: only bug fixes, no new features/interface changes
   - Exception process for critical fixes

3. **Integration testing cadence**:
   - Daily: Automated synthesis check (main branch)
   - Weekly: Full implementation + timing closure check
   - Before release: Hardware validation on dev board

4. **Code review guidelines for FPGA**:
   - [ ] RTL follows naming conventions (Section 25.6)
   - [ ] Clock domain crossings use CDC primitives (no bare signals)
   - [ ] Testbench provided (or updated if modified)
   - [ ] Synthesis successful with no critical warnings
   - [ ] Resource impact documented (LUT/FF/BRAM/DSP delta)
   - [ ] Timing impact assessed (setup/hold slack)

**Pull request template** (`.github/pull_request_template.md`):
```markdown
## Description
Brief summary of changes

## Type of Change
- [ ] New feature (feat)
- [ ] Bug fix (fix)
- [ ] Refactor (no functional change)
- [ ] Constraint update (XDC)
- [ ] Performance optimization

## Module(s) Affected
- `clk_manager` (v1.2.0 → v1.3.0)
- `axi_slave` (v2.0.0, no version change)

## Testing
- [ ] Testbench passes (specify: `make test_clk_manager`)
- [ ] Synthesis successful
- [ ] Timing closure (WNS = +0.3ns)
- [ ] Code coverage ≥95%

## Resource Impact
| Resource | Before | After | Delta |
|----------|--------|-------|-------|
| LUT | 12,500 | 12,650 | +150 |
| FF | 10,200 | 10,250 | +50 |
| BRAM | 30 | 30 | 0 |
| DSP | 45 | 45 | 0 |

## Checklist
- [ ] Module version header updated
- [ ] CHANGELOG.md updated
- [ ] Documentation updated (if interface changed)
- [ ] No hardcoded paths or magic numbers
- [ ] Peer reviewed by [Reviewer Name]
```

## 26. High-Speed Interfaces (SerDes and LVDS)

### 26.1 LVDS Basics (Artix-7)
**LVDS (Low-Voltage Differential Signaling)**:
- Data rate: Up to 1.25 Gbps (Artix-7)
- Differential pair: P/N signals
- IOSTANDARD: LVDS_25 (VCCO = 2.5V)

**Simple LVDS TX/RX**:
```verilog
// LVDS Output (transmit)
OBUFDS lvds_tx_buf (
  .I(data_out),
  .O(lvds_tx_p),
  .OB(lvds_tx_n)
);

// LVDS Input (receive)
IBUFDS lvds_rx_buf (
  .I(lvds_rx_p),
  .IB(lvds_rx_n),
  .O(data_in)
);
```

### 26.2 LVDS SERDES (Serializer/Deserializer)
**SerDes IP Core**:
- Converts parallel data → serial (TX)
- Converts serial → parallel data (RX)
- Includes clock recovery (DPA: Dynamic Phase Alignment)

**Example**: 8-bit parallel @ 100 MHz → 1-bit serial @ 800 Mbps

**Applications**:
- Camera Link
- FPD-Link (Flat Panel Display)
- Channel Link
- Custom high-speed protocols

### 26.3 High-Speed Interface Constraints
```tcl
# LVDS input (source-synchronous)
create_clock -period 10.000 [get_ports lvds_clk_p]

# Input delay for data relative to clock
set_input_delay -clock lvds_clk_p -max 2.0 [get_ports lvds_data_p*]
set_input_delay -clock lvds_clk_p -min 0.5 [get_ports lvds_data_p*]

# Differential termination
set_property DIFF_TERM TRUE [get_ports lvds_data_p*]
set_property DIFF_TERM TRUE [get_ports lvds_clk_p]
```

### 26.4 PCB Design for High-Speed LVDS
- **Trace impedance**: 100Ω differential
- **Length matching**: ±0.5mm for data pairs, ±2.5mm clock-to-data
- **Routing**: Avoid vias, minimize stubs
- **Termination**: 100Ω resistor at receiver (external or DIFF_TERM internal)

## 27. Formal Verification and Equivalence Checking

### 27.1 Formal Verification Basics
**Formal verification** proves design properties mathematically (exhaustive, no simulation needed).

**Types**:
- **Assertion-based**: Prove RTL assertions hold
- **Equivalence checking**: Prove RTL ≡ Netlist ≡ Post-route
- **Model checking**: Verify FSM properties

### 27.2 Assertion-Based Verification
**SystemVerilog Assertions (SVA)**:
```verilog
// Property: ack must occur 1-5 cycles after req
property handshake_timing;
  @(posedge clk) req |-> ##[1:5] ack;
endproperty

assert property (handshake_timing)
  else $error("Handshake timeout");

// Cover: Track if both req and ack go high
cover property (@(posedge clk) req && ack);
```

**Formal tools**:
- Cadence JasperGold
- Synopsys VC Formal
- Siemens Questa Formal

### 27.3 Equivalence Checking (EC)
**Purpose**: Verify RTL = Synthesized Netlist = Placed-and-Routed Design

**Flow**:
1. RTL → Synthesis → Netlist (verify RTL ≡ Netlist)
2. Netlist → Place & Route → Post-route (verify Netlist ≡ Post-route)

**Why needed**:
- Synthesis optimizations (retiming, logic minimization)
- Place & route may alter logic (rare, but possible)

**Tools**:
- Siemens Questa Equivalence for FPGA
- Synopsys FormalPro

### 27.4 Formal Verification Benefits
- **Exhaustive**: Covers all possible inputs (vs. simulation samples)
- **Early bug detection**: Find corner cases simulation misses
- **Fast**: No testbench development time
- **FPGA-specific**: Catches synthesis/P&R errors

**Limitations**:
- Requires assertions (manual effort)
- Complex designs may have capacity issues
- Learning curve for assertion writing

## 28. Summary and Quick Reference

### 28.1 Critical Design Checks
**Pre-Synthesis**:
- [ ] All clocks constrained (create_clock)
- [ ] All I/O timing constrained (input_delay, output_delay)
- [ ] False paths marked (async signals, debug logic)
- [ ] All I/O standards and pins assigned

**Post-Synthesis**:
- [ ] Utilization < 80% (LUTs, FFs, BRAM, DSP)
- [ ] No critical warnings (SYNTH-8-*)
- [ ] No latches (unless intentional)

**Post-Implementation**:
- [ ] **WNS ≥ 0, WHS ≥ 0, TNS = 0**
- [ ] DRC clean
- [ ] CDC paths synchronized and constrained
- [ ] Power < board capacity

### 28.2 Common Vivado Commands
```tcl
# Synthesis
read_verilog, read_vhdl, read_xdc
synth_design -top <top> -part <device>

# Implementation
opt_design, place_design, phys_opt_design, route_design

# Reports
report_timing_summary, report_utilization, report_power, report_drc, report_cdc

# Bitstream
write_bitstream -force <file.bit>
```

### 28.3 Key Reference Documents
- **UG949**: UltraFast Design Methodology
- **UG903**: Using Constraints (XDC)
- **UG475**: Artix-7 Packaging and Pinout
- **UG586**: 7-Series Memory Interface Solutions (MIG)
- **UG470**: 7-Series Configuration User Guide
- **UG894**: Vivado TCL Scripting
- **UG835**: Vivado TCL Command Reference

### 28.4 Resource Websites
- **AMD (Xilinx) Documentation**: [www.xilinx.com/support/documentation](https://www.xilinx.com/support/documentation)
- **Verification Academy**: [verificationacademy.com](https://verificationacademy.com)
- **FPGA Developer**: [www.fpgadeveloper.com](https://www.fpgadeveloper.com)
- **Project F**: [projectf.io](https://projectf.io)

---

**Version**: v4.0 (Final)
**Date**: 2026-01-03
**Target**: Xilinx Artix-7 XC7A35T-FGG484-1
**Tool**: Vivado 2023.x+
**Coverage**: XDC, Timing, I/O, CDC, Power, RTL, Verification, Debugging, Configuration, High-Speed I/O
**Reference**: UG949, UG903, UG475, UG586, UG470, UG894, UG835
