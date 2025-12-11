# Part1_Vanilla - 2D Systolic Array (4-bit Quantization)

## Structure
- `software/` - VGG16 Quantization Aware Training notebook
- `hardware/verilog/` - RTL design files for systolic array
- `hardware/datafiles/` - Weight, activation, and psum files
- `hardware/sim/` - Simulation files with filelist
- `synth/` - FPGA synthesis reports

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

## Design Files
The `hardware/verilog/` folder contains:
- `core.v` - Top-level core module
- `core_tb.v` - Testbench for verification
- `mac_array.v`, `mac_row.v`, `mac_tile.v`, `mac.v` - MAC array hierarchy
- `fifo_depth64.v`, `ofifo.v`, `l0.v` - FIFO and buffer modules
- `sfp.v` - Special function processor
- `sram_128b_w2048.v`, `sram_32b_w2048.v` - SRAM memory models

## Data Files
- `weight_*.txt` - Quantized weight files (9 layers)
- `activation.txt` - Input activations
- `psum.txt` - Expected partial sums for verification

