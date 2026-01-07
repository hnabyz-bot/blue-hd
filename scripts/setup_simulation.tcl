#==============================================================================
# File: setup_simulation.tcl
# Description: Setup simulation fileset in Vivado project
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open existing project
open_project vivado_project/cyan_hd.xpr

# Enable the testbench file (remove AutoDisabled)
set_property is_enabled true [get_files simulation/tb_src/tb_afe2256_spi.sv]

# Set file type to SystemVerilog
set_property file_type SystemVerilog [get_files simulation/tb_src/tb_afe2256_spi.sv]

# Update compile order for simulation
update_compile_order -fileset sim_1

# Set top module for simulation
set_property top tb_afe2256_spi [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Configure simulation settings
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

puts ""
puts "========================================"
puts "  SIMULATION SETUP COMPLETE"
puts "========================================"
puts "Testbench file: simulation/tb_src/tb_afe2256_spi.sv"
puts "Top module:     tb_afe2256_spi"
puts "Runtime:        100us"
puts "Log signals:    ENABLED"
puts ""
puts "HOW TO RUN SIMULATION:"
puts "1. Open vivado_project/cyan_hd.xpr in Vivado GUI"
puts "2. Flow Navigator → SIMULATION"
puts "3. Click 'Run Simulation' → 'Run Behavioral Simulation'"
puts "4. Wait for compilation (may take 1-2 minutes)"
puts "5. Run All or type 'run 100us' in TCL console"
puts ""
puts "EXPECTED OUTPUT:"
puts "- 6 test cases (all should PASS)"
puts "- Test summary at end"
puts "========================================"
puts ""

close_project
