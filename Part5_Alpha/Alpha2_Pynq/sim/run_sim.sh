#!/bin/bash
# Run behavioral simulation for systolic_array_wrapper
# Uses Vivado's xvlog/xelab/xsim

cd "$(dirname "$0")/.."

# Clean previous sim files
rm -rf sim/xsim.dir sim/*.log sim/*.jou sim/*.pb sim/*.wdb

# Create sim directory
mkdir -p sim
cd sim

# Compile all Verilog files
echo "=== Compiling Verilog files ==="
xvlog --sv \
    ../verilog/fifo_depth64.v \
    ../verilog/fifo_mux_2_1.v \
    ../verilog/fifo_mux_8_1.v \
    ../verilog/fifo_mux_16_1.v \
    ../verilog/l0.v \
    ../verilog/mac.v \
    ../verilog/mac_tile.v \
    ../verilog/mac_row.v \
    ../verilog/mac_array.v \
    ../verilog/ofifo.v \
    ../verilog/sfp.v \
    ../verilog/sram_32b_w2048.v \
    ../verilog/sram_128b_w2048.v \
    ../verilog/core.v \
    ../verilog/psum_bram.v \
    ../verilog/systolic_array_wrapper.v \
    ../verilog/systolic_array_wrapper_tb.v \
    2>&1 | tee compile.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

# Elaborate
echo ""
echo "=== Elaborating design ==="
xelab systolic_array_wrapper_tb -debug typical -s sim_snapshot 2>&1 | tee elaborate.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "ERROR: Elaboration failed!"
    exit 1
fi

# Run simulation
echo ""
echo "=== Running simulation ==="
xsim sim_snapshot -runall 2>&1 | tee simulate.log

echo ""
echo "=== Simulation complete ==="
