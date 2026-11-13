# Usage: ./scripts/run_vivado.sh -mode batch -source scripts/create_vivado_project.tcl
# The supplied QMTECH V01 manual specifies XC7A100T-1FGG676C.
# Verify the marking on the fitted FPGA before use.
set part_name xc7a100tfgg676-1
create_project qmtech_beamformer ./vivado_project -part $part_name -force
set_property target_language Verilog [current_project]
add_files [glob ./rtl/*.sv]
add_files -fileset constrs_1 ./constraints/board_template.xdc
set_property top beamformer_top [current_fileset]
update_compile_order -fileset sources_1
puts "Project created with the QMTECH V01 pin constraints; verify PCB revision and fitted FPGA before implementation."
