create_project UART_LOOP ../UART_LOOP -part xc7a50tftg256-1

add_files ../source/UART_RX.vhd
add_files ../source/UART_TX.vhd
add_files ../source/UART_LOOP_Top.vhd
update_compile_order -fileset sources_1

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name Data_Fifo
set_property -dict [list CONFIG.Component_Name {Data_Fifo} CONFIG.Input_Data_Width {8} CONFIG.Input_Depth {16} CONFIG.Output_Data_Width {8} CONFIG.Output_Depth {16} CONFIG.Use_Embedded_Registers {false} CONFIG.Reset_Pin {true} CONFIG.Reset_Type {Synchronous_Reset} CONFIG.Use_Dout_Reset {true} CONFIG.Data_Count_Width {4} CONFIG.Write_Data_Count_Width {4} CONFIG.Read_Data_Count_Width {4} CONFIG.Full_Threshold_Assert_Value {14} CONFIG.Full_Threshold_Negate_Value {13}] [get_ips Data_Fifo]

add_files -fileset constrs_1 ../constraints/UADR_RX_LOOP_LOC.xdc
add_files -fileset constrs_1 ../constraints/UADR_RX_LOOP_Timing.xdc
