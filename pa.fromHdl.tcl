
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

create_project -name bdantes -dir "/home/sd/bdantes/planAhead_run_3" -part xc3s700anfgg484-5
set_param project.pinAheadLayout yes
set srcset [get_property srcset [current_run -impl]]
set_property target_constrs_file "Leitor_Tecla.ucf" [current_fileset -constrset]
set hdlfile [add_files [list {../Downloads/Forca-em-vhdl-master/list_ch08_01_ps2_rx.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {../Downloads/Forca-em-vhdl-master/fifo.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {../Downloads/Forca-em-vhdl-master/list_ch08_03_kb_lcode.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {../Downloads/Forca-em-vhdl-master/Leitor_Tecla.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set_property top Leitor_Tecla $srcset
add_files [list {Leitor_Tecla.ucf}] -fileset [get_property constrset [current_run]]
open_rtl_design -part xc3s700anfgg484-5
