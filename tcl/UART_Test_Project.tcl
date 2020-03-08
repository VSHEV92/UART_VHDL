create_project UART_Tests_project ../UART_Tests_project -part xc7a50tftg256-1

add_files ../source/UART_RX.vhd
add_files ../source/UART_TX.vhd
update_compile_order -fileset sources_1

add_files -fileset sim_1 -norecurse ../source/UART_RX_Beh.vhd
add_files -fileset sim_1 -norecurse ../source/UART_TX_Beh.vhd

add_files -fileset sim_1 -norecurse ../source/UART_TX_RX_Beh_tb.vhd
add_files -fileset sim_1 -norecurse ../source/UART_RX_tb.vhd
add_files -fileset sim_1 -norecurse ../source/UART_TX_tb.vhd

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name Data_Fifo
set_property -dict [list CONFIG.Component_Name {Data_Fifo} CONFIG.Input_Data_Width {8} CONFIG.Input_Depth {16} CONFIG.Output_Data_Width {8} CONFIG.Output_Depth {16} CONFIG.Use_Embedded_Registers {false} CONFIG.Reset_Pin {false} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Use_Dout_Reset {false} CONFIG.Data_Count_Width {4} CONFIG.Write_Data_Count_Width {4} CONFIG.Read_Data_Count_Width {4} CONFIG.Full_Threshold_Assert_Value {14} CONFIG.Full_Threshold_Negate_Value {13}] [get_ips Data_Fifo]

