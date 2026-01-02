# ========================================
# Blue 100um FPGA Project Creation Script
# ========================================
# Usage: vivado -mode batch -source create_project.tcl
# Or: vivado -mode gui -source create_project.tcl

# Project Configuration
set project_name "blue_hd"
set project_dir "./build"
set part_name "xc7a35tfgg484-1"

# Create project directory if it doesn't exist
file mkdir $project_dir

# Create project
create_project $project_name $project_dir -part $part_name -force
set proj [current_project]

# Set project properties
set_property target_language Verilog $proj
set_property simulator_language Mixed $proj
set_property default_lib work $proj

# Add HDL source files
if {[file exists "./source/hdl"]} {
    set hdl_files [glob -nocomplain ./source/hdl/*.v ./source/hdl/*.sv ./source/hdl/*.vhd]
    if {[llength $hdl_files] > 0} {
        add_files -fileset sources_1 $hdl_files
        puts "Added [llength $hdl_files] HDL source files"
    }
}

# Add IP files
if {[file exists "./source/ip"]} {
    set ip_files [glob -nocomplain ./source/ip/*.xci]
    if {[llength $ip_files] > 0} {
        add_files -fileset sources_1 $ip_files
        puts "Added [llength $ip_files] IP files"
    }
}

# Add constraint files
if {[file exists "./source/constrs/cyan_hd_top.xdc"]} {
    add_files -fileset constrs_1 ./source/constrs/cyan_hd_top.xdc
    puts "Added constraint file: cyan_hd_top.xdc"
}

# Add simulation files
if {[file exists "./simulation/tb_src"]} {
    set sim_files [glob -nocomplain ./simulation/tb_src/*.v ./simulation/tb_src/*.sv]
    if {[llength $sim_files] > 0} {
        add_files -fileset sim_1 $sim_files
        puts "Added [llength $sim_files] simulation files"
    }
}

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=========================================="
puts "Project '$project_name' created successfully!"
puts "Location: $project_dir/$project_name.xpr"
puts "Part: $part_name"
puts "=========================================="
puts "Next steps:"
puts "  1. Open project: vivado $project_dir/$project_name.xpr"
puts "  2. Set top module if needed"
puts "  3. Run synthesis and implementation"
puts "=========================================="
