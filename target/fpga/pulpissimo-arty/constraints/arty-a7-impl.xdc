# These generated clocks are created by the clock-wizard IP constraints and are
# therefore grouped in an implementation-only, late-processing XDC.

# The slow, peripheral, SoC, and JTAG domains use explicit synchronizers.
set_clock_groups -asynchronous \
  -group [get_clocks clk_out1_xilinx_slow_clk_mngr] \
  -group [get_clocks clk_out1_xilinx_clk_mngr]

set_clock_groups -asynchronous \
  -group [get_clocks clk_out1_xilinx_clk_mngr] \
  -group [get_clocks clk_out2_xilinx_clk_mngr]

set_clock_groups -asynchronous \
  -group [get_clocks tck] \
  -group [get_clocks clk_out1_xilinx_clk_mngr]

set_clock_groups -asynchronous \
  -group [get_clocks tck] \
  -group [get_clocks clk_out2_xilinx_clk_mngr]

set_clock_groups -asynchronous \
  -group [get_clocks clk_out1_xilinx_slow_clk_mngr] \
  -group [get_clocks tck]
