# Usage: ./scripts/run_vivado.sh -mode batch -source scripts/build_bitstream.tcl
set project_file ./vivado_project/qmtech_beamformer.xpr
if {![file exists $project_file]} {
    error "Vivado project not found; run scripts/create_vivado_project.tcl first"
}

open_project $project_file
reset_run synth_1
reset_run impl_1
# A single local run avoids Vivado's VRS scheduler becoming orphaned when a
# synthesis worker exits before publishing its completion marker.
launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1

set run_status [get_property STATUS [get_runs impl_1]]
puts "SMIC_IMPL_STATUS=$run_status"
if {![string match "*Complete*" $run_status]} {
    error "Implementation or bitstream generation did not complete"
}

open_run impl_1
report_utilization -file ./vivado_project/impl_utilization.rpt
report_timing_summary -file ./vivado_project/impl_timing_summary.rpt
report_drc -file ./vivado_project/impl_drc.rpt
set bitstreams [glob -nocomplain ./vivado_project/qmtech_beamformer.runs/impl_1/*.bit]
puts "SMIC_BITSTREAM=$bitstreams"
exit
