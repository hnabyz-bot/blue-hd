#==============================================================================
# File: create_project_and_ip.tcl
# Description: Create Vivado project and generate Clock Wizard IP
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Project settings
set project_name "cyan_hd"
set project_dir "../vivado_project"
set part "xc7a35tfgg484-1"

# Create project directory
file mkdir $project_dir

# Create project
puts "Creating Vivado project..."
create_project $project_name $project_dir -part $part -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib work [current_project]

#==============================================================================
# Generate Clock Wizard IP
#==============================================================================
puts "Generating Clock Wizard IP..."

set ip_dir "../source/ip"
file mkdir $ip_dir

create_ip -name clk_wiz -vendor xilinx.com -library ip \
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
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.USE_LOCKED {true} \
] [get_ips clk_ctrl]

# Generate IP
puts "Generating IP output products..."
generate_target all [get_ips clk_ctrl]

# Create synthesis run for IP
create_ip_run [get_ips clk_ctrl]

puts "Clock Wizard IP created successfully"

#==============================================================================
# Add source files
#==============================================================================
puts "Adding HDL source files..."

# Add packages first
add_files -norecurse {
    ../source/hdl/afe2256/afe2256_lvds_pkg.sv
    ../source/hdl/afe2256/afe2256_spi_pkg.sv
}

# Add AFE2256 modules
add_files -norecurse {
    ../source/hdl/afe2256/afe2256_lvds_deserializer.sv
    ../source/hdl/afe2256/afe2256_lvds_reconstructor.sv
    ../source/hdl/afe2256/afe2256_lvds_receiver.sv
    ../source/hdl/afe2256/afe2256_spi_controller.sv
}

# Add utility modules
add_files -norecurse {
    ../source/hdl/reset_sync.sv
}

# Add top-level
add_files -norecurse {
    ../source/hdl/cyan_hd_top.sv
}

# Set top module
set_property top cyan_hd_top [current_fileset]

# Add constraints
add_files -fileset constrs_1 -norecurse ../source/constrs/cyan_hd_top.xdc

# Update compile order
update_compile_order -fileset sources_1

#==============================================================================
# Set strategies
#==============================================================================
puts "Configuring synthesis and implementation strategies..."

# Set synthesis strategy
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]

# Set implementation strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Save project
save_project_as $project_name $project_dir -force

puts ""
puts "=========================================="
puts "Project created successfully!"
puts "=========================================="
puts "Project: $project_dir/$project_name.xpr"
puts "IP Core: $ip_dir/clk_ctrl"
puts ""
puts "Next steps:"
puts "  1. Run synthesis IP: launch_runs clk_ctrl_synth_1; wait_on_run clk_ctrl_synth_1"
puts "  2. Run synthesis: launch_runs synth_1; wait_on_run synth_1"
puts "  3. Run implementation: launch_runs impl_1; wait_on_run impl_1"
puts "  4. Check timing: open_run impl_1; report_timing_summary"
puts ""
