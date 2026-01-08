#==============================================================================
# File: run_full_sim.tcl
# Description: Vivado Simulator TCL script for full cyan_hd_top design
#              This script sets up a simulation project, compiles Xilinx
#              simulation libraries, adds all source files, and runs the
#              simulation for the top-level testbench.
# Author: Claude Code
# Date: 2026-01-08
#==============================================================================

# Set project variables
set design_name "cyan_hd_full_sim"
set sim_dir "./simulation/full_sim_output"
set part_name "xc7a35tfgg484-1"

# Create simulation output directory
file mkdir $sim_dir

# Create project
create_project $design_name $sim_dir -part $part_name -force
set proj [current_project]

# Set project properties
set_property target_language Verilog $proj
set_property simulator_language Mixed $proj
set_property default_lib xil_defaultlib $proj

# --- Compile Xilinx Simulation Libraries ---
puts "==> Compiling Xilinx simulation libraries..."
# Only compile if they haven't been compiled for this Vivado version/simulator
if {![file exists $sim_dir/xsim_libs/unisims_ver]} {
    compile_simlib -force -directory $sim_dir/xsim_libs -simulator xsim -language sysverilog -family artix7 -library unisims_ver -verbose
    # compile_simlib -force -directory $sim_dir/xsim_libs -simulator xsim -language sysverilog -family artix7 -library unimacro_ver -verbose
    # compile_simlib -force -directory $sim_dir/xsim_libs -simulator xsim -language sysverilog -family artix7 -library simprims_ver -verbose
} else {
    puts "Xilinx simulation libraries already compiled in $sim_dir/xsim_libs."
}
set_property sim.compile_debug_symbols true [get_filesets sim_1]


# --- Add all HDL source files ---
puts "==> Adding HDL source files..."

# Add files from source/hdl (including subdirectories)
set hdl_files [glob -nocomplain -directory ../source/hdl *.v *.sv *.vhd]
lappend hdl_files [glob -nocomplain -directory ../source/hdl/afe2256 *.v *.sv *.vhd]

if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
    puts "Added [llength $hdl_files] HDL source files."
}

# Add IP core files (e.g., clk_ctrl.xci)
if {[file exists "../source/ip/clk_ctrl/clk_ctrl.xci"]} {
    add_files -fileset sources_1 ../source/ip/clk_ctrl/clk_ctrl.xci
    puts "Added IP file: clk_ctrl.xci"
}

# --- Add simulation files ---
puts "==> Adding simulation testbench files..."
set sim_tb_files [glob -nocomplain -directory ../simulation/tb_src *.v *.sv]

if {[llength $sim_tb_files] > 0} {
    add_files -fileset sim_1 $sim_tb_files
    puts "Added [llength $sim_tb_files] simulation testbench files."
}

# Set top module for simulation
set_property top tb_cyan_hd_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set simulation properties
set_property -name {xsim.simulate.runtime} -value {10ms} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# --- Launch and Run Simulation ---
puts "==> Launching simulation..."
launch_simulation -simset sim_1 -mode behavioral

puts "==> Running simulation (10ms timeout)..."
run all

puts "==> Simulation finished!"

# Open waveform (optional, for GUI mode)
# open_wave_database $sim_dir/$design_name.sim/sim_1/behav/xsim/dump.wdb

# Close simulation
close_sim

puts "Full simulation script completed."
puts "Check $sim_dir/$design_name.sim/sim_1/behav/xsim/simulate.log for detailed results."