# create_project.tcl
# Vivado TCL script to create Part1 PYNQ project for RFSoC4x2
#
# Usage:
#   cd hardware/part1_pynq
#   vivado -mode batch -source tcl/create_project.tcl
#
# Outputs:
#   output/part1_pynq.bit - Bitstream
#   output/part1_pynq.hwh - Hardware handoff for PYNQ

# =========================================================================
# Configuration
# =========================================================================
set project_name "part1_pynq"
set part "xczu48dr-ffvg1517-2-e"
set board_part "realdigital.org:rfsoc4x2:part0:1.0"
set design_name "design_1"

# Get script directory
set script_dir [file dirname [info script]]
set proj_dir [file normalize "$script_dir/.."]

puts "Project directory: $proj_dir"
puts "Creating project: $project_name"
puts "Target part: $part"

# =========================================================================
# Create Project
# =========================================================================
create_project $project_name "$proj_dir/vivado_proj" -part $part -force

# Try to set board part (may fail if board files not installed)
if {[catch {set_property board_part $board_part [current_project]} warn]} {
    puts "WARNING: Failed to set board_part. Board files may not be installed."
    puts "Continuing with part-only configuration..."
}

# =========================================================================
# Add RTL Sources
# =========================================================================
puts "Adding RTL sources..."

# Add all Verilog files from verilog directory
add_files -fileset sources_1 [glob -nocomplain "$proj_dir/verilog/*.v"]

# Set top module
set_property top systolic_array_wrapper [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

# =========================================================================
# Create Block Design
# =========================================================================
puts "Creating block design..."

create_bd_design $design_name

# =========================================================================
# Add Zynq UltraScale+ Processing System
# =========================================================================
puts "Adding Zynq UltraScale+ PS..."

# Create PS8 cell
set ps8 [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.* zynq_ultra_ps_e_0]

# Apply board automation to configure PS for the board
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {make_external "FIXED_IO, DDR"} [get_bd_cells zynq_ultra_ps_e_0]

# Configure PS8 - Enable M_AXI_HPM0_LPD (GP2) for PL access
# In ZynqMP: GP0=HPM0_FPD, GP1=HPM1_FPD, GP2=HPM0_LPD
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {1} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
] [get_bd_cells zynq_ultra_ps_e_0]

# =========================================================================
# Add Reset Controller
# =========================================================================
puts "Adding reset controller..."

set rst_ps8 [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0]

# =========================================================================
# Add RTL Module to Block Design
# =========================================================================
puts "Adding systolic array wrapper to block design..."

# Add the RTL module as a block design cell
create_bd_cell -type module -reference systolic_array_wrapper systolic_array_wrapper_0

# =========================================================================
# Add AXI Interconnect
# =========================================================================
puts "Adding AXI interconnect..."

set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells axi_interconnect_0]

# =========================================================================
# Connect Clocks
# =========================================================================
puts "Connecting clocks..."

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
    [get_bd_pins systolic_array_wrapper_0/s_axi_aclk] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] \
    [get_bd_pins rst_ps8_0/slowest_sync_clk] \
    [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]

# =========================================================================
# Connect Resets
# =========================================================================
puts "Connecting resets..."

# Connect PS reset output to reset controller
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
    [get_bd_pins rst_ps8_0/ext_reset_in]

# Connect reset controller outputs
connect_bd_net [get_bd_pins rst_ps8_0/peripheral_aresetn] \
    [get_bd_pins systolic_array_wrapper_0/s_axi_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN]

# =========================================================================
# Connect AXI Interfaces
# =========================================================================
puts "Connecting AXI interfaces..."

# PS to AXI interconnect
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD] \
    [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# AXI interconnect to wrapper
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
    [get_bd_intf_pins systolic_array_wrapper_0/s_axi]

# =========================================================================
# Assign Addresses
# =========================================================================
puts "Assigning addresses..."

# Assign address to the wrapper's AXI-Lite interface
# M_AXI_HPM0_LPD valid range is 0x80000000 with 512MB aperture
assign_bd_address -offset 0x80000000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] \
    [get_bd_addr_segs systolic_array_wrapper_0/s_axi/reg0]

# =========================================================================
# Validate and Save Block Design
# =========================================================================
puts "Validating block design..."

validate_bd_design
save_bd_design

# =========================================================================
# Generate Block Design Wrapper
# =========================================================================
puts "Generating block design wrapper..."

make_wrapper -files [get_files "$proj_dir/vivado_proj/$project_name.srcs/sources_1/bd/$design_name/$design_name.bd"] -top

# Add wrapper to project
set wrapper_file [glob -nocomplain "$proj_dir/vivado_proj/$project_name.gen/sources_1/bd/$design_name/hdl/*_wrapper.v"]
if {$wrapper_file eq ""} {
    set wrapper_file [glob -nocomplain "$proj_dir/vivado_proj/$project_name.srcs/sources_1/bd/$design_name/hdl/*_wrapper.v"]
}
if {$wrapper_file ne ""} {
    add_files -norecurse $wrapper_file
    set_property top ${design_name}_wrapper [current_fileset]
} else {
    puts "ERROR: Could not find block design wrapper!"
    exit 1
}

update_compile_order -fileset sources_1

# =========================================================================
# Add Constraints
# =========================================================================
puts "Adding timing constraints..."

if {[file exists "$proj_dir/constraints/timing.xdc"]} {
    add_files -fileset constrs_1 "$proj_dir/constraints/timing.xdc"
}

# =========================================================================
# Run Synthesis
# =========================================================================
puts "Running synthesis..."

launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis completed successfully."

# =========================================================================
# Run Implementation
# =========================================================================
puts "Running implementation..."

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

puts "Implementation completed successfully."

# =========================================================================
# Export Artifacts
# =========================================================================
puts "Exporting artifacts..."

# Create output directory
file mkdir "$proj_dir/output"

# Find and copy bitstream
set bit_file [glob -nocomplain "$proj_dir/vivado_proj/$project_name.runs/impl_1/*.bit"]
if {$bit_file ne ""} {
    file copy -force $bit_file "$proj_dir/output/part1_pynq.bit"
    puts "Bitstream exported: output/part1_pynq.bit"
} else {
    puts "WARNING: Bitstream not found!"
}

# Find and copy hardware handoff file
set hwh_candidates [list \
    "$proj_dir/vivado_proj/$project_name.gen/sources_1/bd/$design_name/hw_handoff/$design_name.hwh" \
    "$proj_dir/vivado_proj/$project_name.srcs/sources_1/bd/$design_name/hw_handoff/$design_name.hwh" \
]

set hwh_found 0
foreach hwh_file $hwh_candidates {
    if {[file exists $hwh_file]} {
        file copy -force $hwh_file "$proj_dir/output/part1_pynq.hwh"
        puts "Hardware handoff exported: output/part1_pynq.hwh"
        set hwh_found 1
        break
    }
}

if {!$hwh_found} {
    puts "WARNING: Hardware handoff file not found!"
}

# =========================================================================
# Export Block Design TCL for Reproducibility
# =========================================================================
puts "Exporting block design TCL..."

write_bd_tcl -force "$proj_dir/output/${design_name}_bd.tcl"

# =========================================================================
# Summary
# =========================================================================
puts ""
puts "==========================================================================="
puts "Project creation complete!"
puts "==========================================================================="
puts ""
puts "Output files:"
puts "  - output/part1_pynq.bit  (Bitstream for FPGA)"
puts "  - output/part1_pynq.hwh  (Hardware handoff for PYNQ)"
puts ""
puts "To deploy on RFSoC4x2:"
puts "  1. Copy .bit and .hwh files to PYNQ board"
puts "  2. Run the notebook/part1_demo.ipynb notebook"
puts ""

exit 0
