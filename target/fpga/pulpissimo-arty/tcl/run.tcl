source tcl/common.tcl

set PROJECT pulpissimo-$BOARD
set RTL ../../../rtl
set IPS ../../../ips
set CONSTRS constraints

# create project
create_project $PROJECT . -force -part $::env(XILINX_PART)
set_property board_part $XILINX_BOARD [current_project]

# Add sources
source ../pulpissimo/tcl/add_sources.tcl

# Override IPSApprox default variables
set FPGA_RTL rtl
set FPGA_IPS ips

# remove duplicate incompatible modules
# remove_files $IPS/pulp_soc/rtl/components/axi_slice_dc_slave_wrap.sv
# remove_file $IPS/pulp_soc/rtl/components/axi_slice_dc_master_wrap.sv
# remove_file $IPS/tech_cells_generic/pad_functional_xilinx.sv
# remove_file $IPS/riscv/rtl/riscv_ex_stage.sv

# Set Verilog Defines.
set DEFINES "FPGA_TARGET_XILINX=1 PULP_FPGA_EMUL=1 AXI4_XCHECK_OFF=1"
if { $BOARD == "arty" } {
    set DEFINES "$DEFINES ARTY=1"
}
set_property verilog_define $DEFINES [current_fileset]

# detect target clock
if [info exists ::env(FC_CLK_PERIOD_NS)] {
    set FC_CLK_PERIOD_NS $::env(FC_CLK_PERIOD_NS)
} else {
    set FC_CLK_PERIOD_NS 10.000
}
set CLK_HALFPERIOD_NS [expr ${FC_CLK_PERIOD_NS} / 2.0]

# Add toplevel wrapper
add_files -norecurse $FPGA_RTL/xilinx_pulpissimo.v

# Add Xilinx IPs
read_ip $FPGA_IPS/xilinx_clk_mngr/xilinx_clk_mngr.srcs/sources_1/ip/xilinx_clk_mngr/xilinx_clk_mngr.xci
read_ip $FPGA_IPS/xilinx_slow_clk_mngr/xilinx_slow_clk_mngr.srcs/sources_1/ip/xilinx_slow_clk_mngr/xilinx_slow_clk_mngr.xci

# Add wrappers and xilinx specific techcells
add_files -norecurse $FPGA_RTL/fpga_clk_gen.sv
add_files -norecurse $FPGA_RTL/fpga_slow_clk_gen.sv
add_files -norecurse $FPGA_RTL/fpga_bootrom.sv
add_files -norecurse $FPGA_RTL/pad_functional_xilinx.sv
add_files -norecurse $FPGA_RTL/pulp_clock_gating_xilinx.sv
add_files -norecurse $FPGA_RTL/cv32e40p_clock_gate_xilinx.sv

# set pulpissimo as top
set_property top xilinx_pulpissimo [current_fileset]; #

# needed only if used in batch mode
update_compile_order -fileset sources_1

# Add constraints
#Depends on revision of Nexys board
set rev $::env(rev)
add_files -fileset constrs_1 -norecurse $CONSTRS/arty-a7.xdc



# Elaborate design
synth_design -rtl -name rtl_1 -sfcu;# sfcu -> run synthesis in single file compilation unit mode

# Launch synthesis
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value -sfcu -objects [get_runs synth_1] ;# Use single file compilation unit mode to prevent issues with import pkg::* statements in the codebase
launch_runs synth_1 -jobs $CPUS
wait_on_run synth_1
open_run synth_1 -name netlist_1
set_property needs_refresh false [get_runs synth_1]

# Remove unused IOBUF cells in padframe (they are not optimized away since the
# pad driver also drives the input creating a datapath from pad_xy_o to pad_xy_i)
# Disconnect the nets and connect them to ground to avoid issues in optimization
remove_cell i_pulpissimo/i_padframe/i_pulpissimo_pads/i_all_pads/i_all_pads_pads/i_pad_bootsel*
disconnect_net -objects [get_nets i_pulpissimo/i_soc_domain/bootsel_i*]
connect_net -objects [get_nets i_pulpissimo/i_soc_domain/bootsel_i*] -net i_pulpissimo/<const0>

remove_cell i_pulpissimo/i_padframe/i_pulpissimo_pads/i_all_pads/i_all_pads_pads/i_pad_hyper*
disconnect_net -objects [get_nets i_pulpissimo/i_soc_domain/pad_to_hyper_i*]
connect_net -objects [get_nets i_pulpissimo/i_soc_domain/pad_to_hyper_i*] -net i_pulpissimo/<const0>

remove_cell i_pulpissimo/i_padframe/i_pulpissimo_pads/i_all_pads/i_all_pads_pads/i_pad_jtag_trst*
disconnect_net -objects [get_nets i_pulpissimo/i_soc_domain/jtag_trst_ni]
connect_net -objects [get_nets i_pulpissimo/i_soc_domain/jtag_trst_ni] -net i_pulpissimo/<const1>


# Launch Implementation

# set for RuntimeOptimized implementation
set_property "steps.opt_design.args.directive" "RuntimeOptimized" [get_runs impl_1]
set_property "steps.place_design.args.directive" "RuntimeOptimized" [get_runs impl_1]
set_property "steps.route_design.args.directive" "RuntimeOptimized" [get_runs impl_1]

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

launch_runs impl_1 -jobs $CPUS 
wait_on_run impl_1
launch_runs impl_1 -jobs $CPUS -to_step write_bitstream
wait_on_run impl_1

open_run impl_1

# Generate reports
exec mkdir -p reports/
exec rm -rf reports/*
check_timing                                                              -file reports/$PROJECT.check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack   -file reports/$PROJECT.timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                    -file reports/$PROJECT.timing.rpt
report_utilization -hierarchical                                          -file reports/$PROJECT.utilization.rpt
