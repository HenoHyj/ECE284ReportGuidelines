# Alpha4 - OpenROAD Place and Route

## Description
This Alpha submission demonstrates the physical design flow using OpenROAD for the systolic array core.

## Structure
- `verilog/` - RTL source files
- `config.mk` - OpenROAD configuration
- `constraint.sdc` - Timing constraints
- `logs/` - Build log files (JSON format)
- `objects/` - Intermediate build objects
- `reports/` - PnR reports and layout images
- `additional_tech_sram_files/` - Technology SRAM files (LEF, LIB, GDS)
- `tech_sram_verification/` - SRAM behavioral verification files

## How to Run

### Prerequisites
- OpenROAD Flow Scripts installed
- IHP SG13G2 PDK configured

### Run the PnR flow:
```bash
bash run_openroad_part1.bash
```

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

