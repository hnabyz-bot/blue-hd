#==============================================================================
# File: run_synthesis_impl.tcl
# Description: Run synthesis and implementation for Cyan HD FPGA
# Author: Claude Code
# Date: 2026-01-07
#==============================================================================

# Open project
set project_dir "../vivado_project"
set project_name "cyan_hd"

puts "Opening project: $project_dir/$project_name.xpr"
open_project $project_dir/$project_name.xpr

#==============================================================================
# Step 1: Synthesize Clock Wizard IP
#==============================================================================
puts "\n=========================================="
puts "Step 1: Synthesizing Clock Wizard IP"
puts "==========================================\n"

if {[llength [get_runs clk_ctrl_synth_1]] > 0} {
    reset_run clk_ctrl_synth_1
    launch_runs clk_ctrl_synth_1
    wait_on_run clk_ctrl_synth_1
    puts "Clock Wizard IP synthesis complete"
} else {
    puts "WARNING: Clock Wizard IP synthesis run not found"
}

#==============================================================================
# Step 2: Run Synthesis
#==============================================================================
puts "\n=========================================="
puts "Step 2: Running Synthesis"
puts "==========================================\n"

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Open synthesized design
open_run synth_1 -name synth_1

# Report utilization
report_utilization -file $project_dir/${project_name}_utilization_synth.rpt

# Report timing
report_timing_summary -file $project_dir/${project_name}_timing_synth.rpt

puts "\nSynthesis completed successfully!"

#==============================================================================
# Step 3: Run Implementation
#==============================================================================
puts "\n=========================================="
puts "Step 3: Running Implementation"
puts "==========================================\n"

reset_run impl_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation results
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# Open implemented design
open_run impl_1

# Report timing summary
report_timing_summary -file $project_dir/${project_name}_timing_impl.rpt \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 10 \
    -input_pins \
    -routable_nets

# Report utilization
report_utilization -file $project_dir/${project_name}_utilization_impl.rpt \
    -hierarchical

# Report clock interaction
report_clock_interaction -file $project_dir/${project_name}_clock_interaction.rpt

# Report DRC
report_drc -file $project_dir/${project_name}_drc.rpt

# Get timing summary
set wns [get_property STATS.WNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]

puts "\n=========================================="
puts "Implementation Results"
puts "==========================================\n"
puts "Worst Negative Slack (WNS): $wns ns"
puts "Worst Hold Slack (WHS):     $whs ns"
puts ""

if {$wns < 0} {
    puts "ERROR: Timing closure failed (WNS < 0)"
    puts "See timing report: $project_dir/${project_name}_timing_impl.rpt"
} else {
    puts "SUCCESS: Timing closure achieved!"
}

puts "\n=========================================="
puts "All reports generated in: $project_dir/"
puts "==========================================\n"

close_project
