#==============================================================================
# File: add_afe_model.tcl
# Description: Add AFE2256 behavioral model to simulation
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open project
open_project vivado_project/cyan_hd.xpr

# Add AFE2256 model to simulation fileset
add_files -fileset sim_1 -norecurse simulation/tb_src/afe2256_model.sv

# Set file properties
set_property file_type SystemVerilog [get_files simulation/tb_src/afe2256_model.sv]
set_property is_enabled true [get_files simulation/tb_src/afe2256_model.sv]
set_property used_in_synthesis false [get_files simulation/tb_src/afe2256_model.sv]
set_property used_in_implementation false [get_files simulation/tb_src/afe2256_model.sv]

# Update compile order
update_compile_order -fileset sim_1

puts ""
puts "========================================"
puts "  AFE2256 Model Added"
puts "========================================"
puts "Files in sim_1:"
foreach file [get_files -of_objects [get_filesets sim_1]] {
    puts "  - [file tail $file]"
}
puts ""
puts "Compile order:"
set sim_files [get_files -compile_order sources -used_in simulation -of_objects [get_filesets sim_1]]
set idx 1
foreach file $sim_files {
    puts "  $idx. [file tail $file]"
    incr idx
}
puts "========================================"

close_project
