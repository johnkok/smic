# Usage: vivado -mode batch -source scripts/create_vivado_project.tcl
# Verify FPGA package before use; default is common XC7A100T FGG676 speed -2.
set part_name xc7a100tfgg676-2
create_project qmtech_beamformer ./vivado_project -part $part_name -force
set_property target_language Verilog [current_project]
add_files [glob ./rtl/*.sv]
add_files -fileset constrs_1 ./constraints/board_template.xdc
set_property top beamformer_top [current_fileset]
update_compile_order -fileset sources_1
puts "Project created. Assign physical PACKAGE_PIN constraints before implementation."
