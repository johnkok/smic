# Usage: ./scripts/run_vivado.sh -mode batch -source scripts/synthesize.tcl
set project_file ./vivado_project/qmtech_beamformer.xpr
if {![file exists $project_file]} {
    error "Vivado project not found; run scripts/create_vivado_project.tcl first"
}

open_project $project_file
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
puts "SMIC_SYNTH_STATUS=$run_status"
if {![string match "*Complete*" $run_status]} {
    error "Synthesis did not complete"
}

open_run synth_1
report_utilization -file ./vivado_project/synth_utilization.rpt
report_timing_summary -file ./vivado_project/synth_timing_summary.rpt
puts "SMIC_RAMB36=[llength [get_cells -hier -filter {REF_NAME == RAMB36E1}]]"
puts "SMIC_RAMB18=[llength [get_cells -hier -filter {REF_NAME == RAMB18E1}]]"
exit
