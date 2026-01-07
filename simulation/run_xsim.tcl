#==============================================================================
# File: run_xsim.tcl
# Description: Simplified Vivado xsim script for AFE2256 SPI Controller
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Change to simulation directory
cd [file dirname [info script]]

# Create work directory
file mkdir xsim_work

# Compile SystemVerilog files
puts "==> Compiling source files..."

# Compile package first
exec xvlog -sv \
    ../source/hdl/afe2256/afe2256_spi_pkg.sv \
    -work xsim_work

# Compile DUT
exec xvlog -sv \
    ../source/hdl/afe2256/afe2256_spi_controller.sv \
    -work xsim_work

# Compile testbench
exec xvlog -sv \
    tb_src/tb_afe2256_spi.sv \
    -work xsim_work

puts "==> Elaborating design..."

# Elaborate
exec xelab -debug typical \
    -top tb_afe2256_spi \
    -snapshot tb_afe2256_spi_snapshot \
    -work xsim_work

puts "==> Running simulation..."

# Simulate
exec xsim tb_afe2256_spi_snapshot \
    -runall \
    -log simulation.log \
    -wdb waveform.wdb

puts "==> Simulation completed!"
puts "Check simulation.log for results"
