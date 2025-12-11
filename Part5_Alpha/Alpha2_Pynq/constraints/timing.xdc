# timing.xdc
# Timing constraints for Part1 PYNQ project on RFSoC4x2
#
# The PS8 generates pl_clk0 at 100MHz by default.
# This file provides minimal constraints; Vivado will derive most
# constraints from the PS8 configuration.

# Clock constraint for PL clock (already defined by PS8, but explicit for reference)
# create_clock -period 10.000 -name pl_clk0 [get_pins design_1_i/zynq_ultra_ps_e_0/inst/PS8_i/PLCLK[0]]

# If timing fails, you can relax the constraint:
# set_property CLOCK_UNCERTAINTY 0.5 [get_clocks pl_clk0]

# False paths for asynchronous signals (if any)
# set_false_path -from [get_pins ...] -to [get_pins ...]

# Max delay constraints for AXI-Lite interface (optional)
# set_max_delay 10.0 -from [get_pins */s_axi_*] -to [get_pins */s_axi_*]
