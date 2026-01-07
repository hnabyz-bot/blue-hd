#==============================================================================
# File: fix_testbench.tcl
# Description: Fix testbench file properties in Vivado project
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open existing project
open_project vivado_project/cyan_hd.xpr

# Enable the testbench file
set_property is_enabled true [get_files simulation/tb_src/tb_afe2256_spi.sv]

# Set file type to SystemVerilog
set_property file_type SystemVerilog [get_files simulation/tb_src/tb_afe2256_spi.sv]

# Ensure it's used in simulation only
set_property used_in synthesis false [get_files simulation/tb_src/tb_afe2256_spi.sv]
set_property used_in implementation false [get_files simulation/tb_src/tb_afe2256_spi.sv]
set_property used_in simulation true [get_files simulation/tb_src/tb_afe2256_spi.sv]

# Update compile order
update_compile_order -fileset sim_1

# Set simulation properties
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.saif_all_signals} -value {false} -objects [get_filesets sim_1]

# Ensure top module is set correctly
set_property top tb_afe2256_spi [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "========================================"
puts "Testbench configuration fixed!"
puts "========================================"
puts "File: simulation/tb_src/tb_afe2256_spi.sv"
puts "Status: ENABLED"
puts "Type: SystemVerilog"
puts "Top Module: tb_afe2256_spi"
puts "Runtime: 100us"
puts ""
puts "Ready to simulate in Vivado GUI!"
puts "========================================"

close_project
