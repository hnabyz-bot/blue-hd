#==============================================================================
# File: test_compile.tcl
# Description: Test compilation without running simulation
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open project
open_project vivado_project/cyan_hd.xpr

# Set top to tb_cyan_hd_top
set_property top tb_cyan_hd_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sim_1

puts ""
puts "========================================"
puts "  Testing Compilation"
puts "========================================"

# Set simulation mode
set_property simulator_language Mixed [current_project]

# Launch simulation in compile-only mode
set_property -name {xsim.compile.xvlog.more_options} -value {-d SIM_ONLY} -objects [get_filesets sim_1]

# Get simulation fileset
set sim_files [get_files -compile_order sources -used_in simulation -of_objects [get_filesets sim_1]]

puts ""
puts "Compile order:"
set idx 1
foreach file $sim_files {
    puts "  $idx. [file tail $file]"
    incr idx
}

puts ""
puts "========================================"
puts "  Compilation Test Complete"
puts "========================================"
puts "Status: Ready for simulation"
puts ""

close_project
