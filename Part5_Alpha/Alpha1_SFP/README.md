# Alpha1 - SFP Reconfiguration

## Description
This Alpha submission implements a reconfigurable Special Function Processor (SFP) module for the systolic array.

## Structure
- `hardware/verilog/` - RTL design files with SFP reconfiguration
- `hardware/datafiles/` - Test data files
- `hardware/sim/` - Simulation files with filelist

## How to Run

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

## Key Features
- Reconfigurable SFP module in `sfp.v`
- Supports different activation functions and post-processing operations

