#==============================================================================
# File: add_toplevel_tb.tcl
# Description: Add top-level testbench to Vivado project
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open project
open_project vivado_project/cyan_hd.xpr

# Add top-level testbench
add_files -fileset sim_1 -norecurse simulation/tb_src/tb_cyan_hd_top.sv

# Set file properties
set_property file_type SystemVerilog [get_files simulation/tb_src/tb_cyan_hd_top.sv]
set_property is_enabled true [get_files simulation/tb_src/tb_cyan_hd_top.sv]

# Update compile order
update_compile_order -fileset sim_1

puts ""
puts "========================================"
puts "  Top-level testbench added"
puts "========================================"
puts "Files in sim_1:"
foreach file [get_files -of_objects [get_filesets sim_1]] {
    puts "  - [file tail $file]"
}
puts ""
puts "Available testbenches:"
puts "  1. tb_afe2256_spi (SPI module only)"
puts "  2. tb_cyan_hd_top (Full system) <- NEW"
puts ""
puts "To select testbench, use:"
puts "  set_property top tb_cyan_hd_top [get_filesets sim_1]"
puts "========================================"

close_project
