# размещение пинов для платы AES-A7EV-7A50T-G

# тактовый сигнал
set_property PACKAGE_PIN N11 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# кнопка сброса
set_property PACKAGE_PIN N4 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# сигнал UART
set_property PACKAGE_PIN M12 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

# светодиоды
set_property PACKAGE_PIN L5 [get_ports {data[0]}]
set_property PACKAGE_PIN L4 [get_ports {data[1]}]
set_property PACKAGE_PIN M4 [get_ports {data[2]}]
set_property PACKAGE_PIN N3 [get_ports {data[3]}]
set_property PACKAGE_PIN N2 [get_ports {data[4]}]
set_property PACKAGE_PIN M2 [get_ports {data[5]}]
set_property PACKAGE_PIN N1 [get_ports {data[6]}]
set_property PACKAGE_PIN M1 [get_ports {data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {data[7]}]

