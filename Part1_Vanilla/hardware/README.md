Hardware folder layout and quick run steps

This folder contains three subfolders:
- `verilog/` : place all HDL source files here (e.g., core.v, corelet.v, mac_array.v).
- `datafiles/` : weight, activation and psum files used by the testbench.
- `sim/` : contains the `filelist` (plain text, no extension) and any simulation scripts or testbenches.

Run steps (for reference):
```pwsh
cd Part2_SIMD/hardware/sim
iverilog -g2012 -o sim.vvp -f filelist
vvp sim.vvp
```

Notes:
- `filelist` must list relative paths to the sources in `../verilog/`.
- Do not include absolute paths.
