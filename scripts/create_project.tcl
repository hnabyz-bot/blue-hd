#==============================================================================
# File: create_project.tcl
# Description: Create Vivado project for Cyan HD FPGA
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
create_project $project_name $project_dir -part $part -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib work [current_project]

# Add source files
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

# Add IP cores (if exists)
set ip_dir "../source/ip"
if {[file exists $ip_dir/clk_ctrl]} {
    puts "Adding Clock Wizard IP..."
    add_files -norecurse [glob -nocomplain $ip_dir/clk_ctrl/clk_ctrl.xci]
} else {
    puts "WARNING: Clock Wizard IP not found at $ip_dir/clk_ctrl"
    puts "Run create_clk_ip.tcl first to generate the IP"
}

# Update compile order
update_compile_order -fileset sources_1

# Set synthesis strategy
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]

# Set implementation strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Enable incremental compile
set_property incremental_checkpoint "" [get_runs synth_1]

puts "Project created successfully: $project_dir/$project_name.xpr"
puts ""
puts "Next steps:"
puts "  1. Generate Clock Wizard IP: vivado -mode batch -source create_clk_ip.tcl"
puts "  2. Run synthesis: launch_runs synth_1"
puts "  3. Run implementation: launch_runs impl_1"
puts "  4. Generate bitstream: launch_runs impl_1 -to_step write_bitstream"
