# Part3_Reconfigurable - Reconfigurable Systolic Array

## Structure
- `software/` - VGG16 Quantization Aware Training notebook
- `hardware/verilog/` - RTL design files with reconfigurable architecture
- `hardware/datafiles/` - Weight, activation, and psum files
- `hardware/sim/` - Simulation files with filelist

## How to Run Simulation

Navigate to the simulation directory and run:
```bash
cd hardware/sim
iverilog -o sim.vvp -f filelist
vvp sim.vvp
```

Or using commercial tools:
```bash
cd hardware/sim
iveri filelist
irun
```

The testbench covers the expected reconfigurable modes without requiring recompilation.

## Design Files
The `hardware/verilog/` folder contains reconfigurable versions of:
- `core.v` - Top-level core module with reconfiguration support
- `core_tb.v` - Testbench for reconfigurable verification
- `mac_array.v`, `mac_row.v`, `mac_tile.v`, `mac.v` - Reconfigurable MAC array
- `fifo_depth64.v`, `ofifo.v`, `l0.v` - FIFO and buffer modules
- `sfp.v` - Special function processor
- `sram_128b_w2048.v`, `sram_32b_w2048.v` - SRAM memory models

## Data Files
- `weight_*.txt` - Quantized weight files (9 layers)
- `activation.txt` - Input activations
- `psum.txt` - Expected partial sums for verification
- `input.txt` - Additional input data

