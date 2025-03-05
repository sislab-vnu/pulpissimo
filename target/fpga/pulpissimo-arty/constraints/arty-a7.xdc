### Constraint File for the Arty board

#######################################
#  _______ _           _              #
# |__   __(_)         (_)             #
#    | |   _ _ __ ___  _ _ __   __ _  #
#    | |  | | '_ ` _ \| | '_ \ / _` | #
#    | |  | | | | | | | | | | | (_| | #
#    |_|  |_|_| |_| |_|_|_| |_|\__, | #
#                               __/ | #
#                              |___/  #
#######################################


#Create constraint for the clock input of the nexys 4 board
create_clock -period 10.000 -name ref_clk [get_ports sys_clk]

## JTAG
create_clock -period 100.000 -name tck -waveform {0.000 50.000} [get_ports pad_jtag_tck]
set_input_jitter tck 1.000
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets i_pulpissimo/i_padframe/i_pulpissimo_pads/i_all_pads/i_all_pads_pads/i_pad_jtag_tck/O]


# minimize routing delay
set_input_delay -clock tck -clock_fall 5.000 [get_ports pad_jtag_tdi]
set_input_delay -clock tck -clock_fall 5.000 [get_ports pad_jtag_tms]
set_output_delay -clock tck 5.000 [get_ports pad_jtag_tdo]


set_max_delay -to [get_ports pad_jtag_tdo] 20.000
set_max_delay -from [get_ports pad_jtag_tms] 20.000
set_max_delay -from [get_ports pad_jtag_tdi] 20.000

set_max_delay -datapath_only -from [get_pins i_pulpissimo/i_soc_domain/i_pulp_soc/i_dmi_jtag/i_dmi_cdc/i_cdc_resp/i_src/data_src_q_reg*/C] -to [get_pins i_pulpissimo/i_soc_domain/i_pulp_soc/i_dmi_jtag/i_dmi_cdc/i_cdc_resp/i_dst/data_dst_q_reg*/D] 20.000
set_max_delay -datapath_only -from [get_pins i_pulpissimo/i_soc_domain/i_pulp_soc/i_dmi_jtag/i_dmi_cdc/i_cdc_resp/i_src/req_src_q_reg/C] -to [get_pins i_pulpissimo/i_soc_domain/i_pulp_soc/i_dmi_jtag/i_dmi_cdc/i_cdc_resp/i_dst/req_dst_q_reg/D] 20.000
set_max_delay -datapath_only -from [get_pins i_pulpissimo/i_soc_domain/i_pulp_soc/i_dmi_jtag/i_dmi_cdc/i_cdc_req/i_dst/ack_dst_q_reg/C] -to [get_pins i_pulpissimo/i_soc_domain/i_pulp_soc/i_dmi_jtag/i_dmi_cdc/i_cdc_req/i_src/ack_src_q_reg/D] 20.000


# reset signal
set_false_path -from [get_ports pad_reset_n]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets pad_reset_n_IBUF]

set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets i_pulpissimo/i_clock_gen/i_slow_clk_div/i_clk_mux/clk_o]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets i_pulpissimo/i_clock_gen/i_slow_clk_mngr/inst/clk_out1]

# Set ASYNC_REG attribute for ff synchronizers to place them closer together and
# increase MTBF
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/i_apb_adv_timer/u_tim0/u_in_stage/r_ls_clk_sync_reg*]
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/i_apb_adv_timer/u_tim1/u_in_stage/r_ls_clk_sync_reg*]
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/i_apb_adv_timer/u_tim2/u_in_stage/r_ls_clk_sync_reg*]
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/i_apb_adv_timer/u_tim3/u_in_stage/r_ls_clk_sync_reg*]
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/i_apb_timer_unit/s_ref_clk*]
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/i_ref_clk_sync/i_pulp_sync/r_reg_reg*]
set_property ASYNC_REG true [get_cells i_pulpissimo/i_soc_domain/i_pulp_soc_i/soc_peripherals_i/u_evnt_gen/r_ls_sync_reg*]

# Create asynchronous clock group between slow-clk and SoC clock. Those clocks
# are considered asynchronously and proper synchronization regs are in place
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/slow_clk_o]] \
                               -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/i_clk_manager/clk_out1]]

# Create asynchronous clock group between Per Clock  and SoC clock. Those clocks
# are considered asynchronously and proper synchronization regs are in place
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/i_clk_manager/clk_out1]] \
                               -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/i_clk_manager/clk_out2]]

# Create asynchronous clock group between JTAG TCK and SoC clock.
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins i_pulpissimo/pad_jtag_tck]] \
                               -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/i_clk_manager/clk_out1]]

# Create asynchronous clock group between JTAG TCK and per clock.
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins i_pulpissimo/pad_jtag_tck]] \
                               -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/i_clk_manager/clk_out2]]

# Create asynchronous clock group between slow clock and JTAG TCK.
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins i_pulpissimo/i_clock_gen/slow_clk_o]] \
                               -group [get_clocks -of_objects [get_pins i_pulpissimo/pad_jtag_tck]]

#############################################################
#  _____ ____         _____      _   _   _                  #
# |_   _/ __ \       / ____|    | | | | (_)                 #
#   | || |  | |_____| (___   ___| |_| |_ _ _ __   __ _ ___  #
#   | || |  | |______\___ \ / _ \ __| __| | '_ \ / _` / __| #
#  _| || |__| |      ____) |  __/ |_| |_| | | | | (_| \__ \ #
# |_____\____/      |_____/ \___|\__|\__|_|_| |_|\__, |___/ #
#                                                 __/ |     #
#                                                |___/      #
#############################################################

## Sys clock
set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports sys_clk]

## Buttons
set_property -dict {PACKAGE_PIN C2  IOSTANDARD LVCMOS33} [get_ports pad_reset_n]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports btnc_i] 
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports btnd_i]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports btnl_i]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports btnr_i]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports btnu_i]

## PMOD A as JTAG 
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports pad_jtag_tms]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports pad_jtag_tdi]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports pad_jtag_tdo]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports pad_jtag_tck]

##PMOD B for I2C and I2S
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports pad_i2c0_sda] 
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports pad_i2c0_scl]

set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports pad_i2s0_sck]
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports pad_i2s0_ws]
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports pad_i2s0_sdi]
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports pad_i2s1_sdi]

## UART
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports pad_uart_rx]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports pad_uart_tx]
#set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports pad_uart_cts]
#set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS33} [get_ports pad_uart_rts]

## LEDs
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports led0_o]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports led1_o]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports led2_o]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports led3_o]

## Switches
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports switch0_i]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} [get_ports switch1_i]

## QSPI Flash
## disabled. Have a look at the Readme
#set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports pad_spim_csn0]
#set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio0]
#set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio1]
#set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio2]
#set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio3]

#Use PMOD C for SPIM0
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports pad_spim_csn0]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio0]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio1]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio2]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports pad_spim_sdio3]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports pad_spim_sck]

## SD Card
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports pad_sdio_clk]
#set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS33} [get_ports { sd_cd }]; 
set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports pad_sdio_cmd]
set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports pad_sdio_data0]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports pad_sdio_data1]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports pad_sdio_data2]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33} [get_ports pad_sdio_data3]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports sdio_reset_o]

# Arty A7 has a quad SPI flash
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# Configuration options, can be used for all designs
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
