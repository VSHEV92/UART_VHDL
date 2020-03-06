create_project UART_RX_LED ../UART_RX_LED -part xc7a50tftg256-1

add_files ../source/UART_RX_LED_Top.vhd
add_files ../source/UART_RX.vhd
update_compile_order -fileset sources_1

add_files -fileset constrs_1 ../constraints/UADR_RX_LED_LOC.xdc
add_files -fileset constrs_1 ../constraints/UADR_RX_LED_Timing.xdc
