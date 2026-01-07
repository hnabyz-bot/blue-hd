#==============================================================================
# File: run_sim.tcl
# Description: Vivado Simulator TCL script for AFE2256 SPI Controller
# Author: Claude Code
# Date: 2026-01-05
#==============================================================================

# Set project variables
set design_name "afe2256_spi"
set sim_dir "sim_output"

# Create simulation directory
file mkdir $sim_dir

# Create project
create_project $design_name $sim_dir -part xc7a35tfgg484-1 -force

# Add source files
add_files -fileset sources_1 [list \
    "../hdl/afe2256/afe2256_spi_pkg.sv" \
    "../hdl/afe2256/afe2256_spi_controller.sv"
]

# Add simulation files
add_files -fileset sim_1 [list \
    "tb_afe2256_spi.sv"
]

# Set top module
set_property top tb_afe2256_spi [get_filesets sim_1]

# Set simulation properties
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# Launch simulation
launch_simulation

# Run simulation
run all

# Close simulation
close_sim

puts "Simulation completed successfully"
