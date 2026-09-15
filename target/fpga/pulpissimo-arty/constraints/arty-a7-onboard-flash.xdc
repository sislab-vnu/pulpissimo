# Arty A7-100T onboard 128-Mbit configuration flash.
# Applied after arty-a7.xdc to move SPIM0 from PMOD C to the onboard device.
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports pad_spim_csn0]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio0]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio1]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio2]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio3]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports pad_spim_sck]
