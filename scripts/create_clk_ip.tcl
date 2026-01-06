#==============================================================================
# File: create_clk_ip.tcl
# Description: Create Clock Wizard IP for Cyan HD FPGA
#              Input: 50 MHz differential (MCLK_50M_p/n)
#              Outputs: 100 MHz, 200 MHz, 25 MHz
# Author: Claude Code
# Date: 2026-01-06
#==============================================================================

# Set IP output directory
set ip_dir "../source/ip"
file mkdir $ip_dir

# Create Clock Wizard IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name clk_ctrl \
    -dir $ip_dir

# Configure Clock Wizard
set_property -dict [list \
    CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ {50.000} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {25.000} \
    CONFIG.CLKOUT1_PORT {clk_100m} \
    CONFIG.CLKOUT2_PORT {clk_200m} \
    CONFIG.CLKOUT3_PORT {clk_25m} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.LOCKED_PORT {locked} \
    CONFIG.USE_LOCKED {true} \
] [get_ips clk_ctrl]

# Generate IP
generate_target all [get_ips clk_ctrl]
create_ip_run [get_ips clk_ctrl]
launch_runs clk_ctrl_synth_1
wait_on_run clk_ctrl_synth_1

puts "Clock Wizard IP created successfully"
puts "  Input: 50 MHz differential"
puts "  Output 1: 100 MHz (System clock)"
puts "  Output 2: 200 MHz (High-speed processing)"
puts "  Output 3: 25 MHz (MIPI CSI-2)"
