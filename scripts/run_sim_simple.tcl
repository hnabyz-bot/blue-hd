# Simple simulation script for tb_cyan_hd_top
# Run with: vivado -mode batch -source scripts/run_sim_simple.tcl

# Open project
open_project vivado_project/cyan_hd.xpr

# Launch simulation
launch_simulation -mode behavioral

# Run simulation for 50us
run 50us

# Close simulation
close_sim

# Exit
exit
