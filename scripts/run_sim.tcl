#==============================================================================
# File: run_sim.tcl
# Description: Run simulation from command line (alternative to GUI)
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open project
open_project vivado_project/cyan_hd.xpr

# Update compile order (in case files changed)
update_compile_order -fileset sim_1

# Launch simulation
puts ""
puts "========================================"
puts "  Starting Behavioral Simulation"
puts "========================================"
puts "Top module: tb_afe2256_spi"
puts "Runtime: 100us"
puts ""

launch_simulation

# Run for specified time
run 100us

# Close simulation
close_sim

puts ""
puts "========================================"
puts "  Simulation Complete!"
puts "========================================"
puts "Check TCL console output above for test results"
puts "Waveform saved in vivado_project/cyan_hd.sim/"
puts ""

close_project
