# Part2_SIMD - SIMD Systolic Array

## Structure
- `software/` - VGG16 Quantization Aware Training notebook (2-bit/4-bit activation support)
- `hardware/verilog/` - RTL design files with SIMD support
- `hardware/datafiles/` - Weight, activation, and psum files for SIMD modes
- `hardware/sim/` - Simulation files with filelist

## How to Run Simulation

Navigate to the simulation directory and run:
```bash
cd hardware/sim
iverilog -g2012 -o sim.vvp -f filelist
vvp sim.vvp
```

The testbench exercises both 4-bit-activation and 2-bit-activation modes automatically.

## Design Files
The `hardware/verilog/` folder contains SIMD-enabled versions of:
- `core.v` - Top-level core module with SIMD support
- `core_tb.v` - Testbench covering multiple activation bit-widths
- `mac_array.v`, `mac_row.v`, `mac_tile.v`, `mac.v` - SIMD MAC array hierarchy
- `fifo_depth64.v`, `ofifo.v`, `l0.v` - FIFO and buffer modules
- `sfp.v` - Special function processor
- `sram_128b_w2048.v`, `sram_32b_w2048.v` - SRAM memory models

## Data Files
- `weight_*.txt` - Quantized weight files
- `activation_2b.txt` - 2-bit activation inputs
- `psum_v2.txt` - Expected partial sums for SIMD verification

