#==============================================================================
# File: add_testbench.tcl
# Description: Add testbench files to Vivado project
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open existing project
open_project vivado_project/cyan_hd.xpr

# Add testbench file to simulation fileset
add_files -fileset sim_1 -norecurse [list \
    "simulation/tb_src/tb_afe2256_spi.sv"
]

# Update compile order
update_compile_order -fileset sim_1

# Set tb_afe2256_spi as top module for simulation
set_property top tb_afe2256_spi [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set simulation runtime
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]

# Enable logging all signals
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# Save project
save_project

puts "========================================"
puts "Testbench successfully added to project"
puts "========================================"
puts "Simulation fileset: sim_1"
puts "Top module: tb_afe2256_spi"
puts "Runtime: 100us"
puts ""
puts "To run simulation:"
puts "1. Open vivado_project/cyan_hd.xpr"
puts "2. Flow Navigator -> SIMULATION -> Run Simulation"
puts "3. Select 'Run Behavioral Simulation'"
puts "========================================"

close_project
