# размещение пинов для платы AES-A7EV-7A50T-G

# тактовый сигнал
set_property PACKAGE_PIN N11 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# кнопка сброса
set_property PACKAGE_PIN N4 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# RX сигнал UART
set_property PACKAGE_PIN M12 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

# TX сигнал UART
set_property PACKAGE_PIN N6 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

# светодиоды
set_property PACKAGE_PIN L5 [get_ports {led[0]}]
set_property PACKAGE_PIN L4 [get_ports {led[1]}]
set_property PACKAGE_PIN M4 [get_ports {led[2]}]
set_property PACKAGE_PIN N3 [get_ports {led[3]}]
set_property PACKAGE_PIN N2 [get_ports {led[4]}]
set_property PACKAGE_PIN M2 [get_ports {led[5]}]
set_property PACKAGE_PIN N1 [get_ports {led[6]}]
set_property PACKAGE_PIN M1 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

