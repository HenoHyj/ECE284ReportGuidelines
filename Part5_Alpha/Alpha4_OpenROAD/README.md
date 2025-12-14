# Alpha4 - OpenROAD Synthesis and PnR

## Description
This Alpha submission demonstrates the physical design flow using OpenROAD for the weight stationary systolic array core.

## Structure
- `verilog/` - RTL source files
- `config.mk` - OpenROAD configuration
- `constraint.sdc` - Timing constraints
- `logs/` - Build log files (JSON format)
- `objects/` - Intermediate build objects
- `reports/` - Synthesis and PnR flow reports and layout images
- `additional_tech_sram_files/` - Technology SRAM files (LEF, LIB, GDS) for configuration (512x32) not preloaded within OpenROAD
- `tech_sram_verification/` - SRAM behavioral verification files

## How to Run

### Prerequisites
- OpenROAD Flow Scripts installed
  - Follow the directions [**here**](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/master/docs/user/BuildWithDocker.md) to build OpenROAD-flow-scripts using Docker from sources. This build   method was verified to be functional with the file structure. Other build methods are not guaranteed to function.
  - Make sure the `OpenROAD-flow-scripts` directory is placed within the same directory as the rest of the files, i.e. `Alpha4_OpenROAD/OpenROAD-flow-scripts`

### Run the PnR flow:
```bash
./run_openroad_part1.sh
```
- use `chmod 777 ./run_openroad_part1.sh` if a file permissions error occurs.

### Verify SRAM modules:
```bash
cd tech_sram_verification
./run_iverilog
```

## Results
The `reports/` folder contains:
- Timing reports (`*_final.rpt`, `*_cts_final.rpt`)
- DRC reports (`5_route_drc.rpt`)
- Layout visualization images (`*.png`, `*.webp.png`)
- Synthesis statistics (`synth_stat.txt`)

## Key Metrics
Check the following reports for performance metrics:
- `reports/ihp-sg13g2/core/base/6_finish.rpt` - Final timing and area
- `reports/ihp-sg13g2/core/base/synth_stat.txt` - Synthesis statistics

