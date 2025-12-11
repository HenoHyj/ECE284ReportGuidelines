`timescale 1ns/1ps

module core (
  clk,
  inst,
  D_xmem,
  sfp_out,
  ofifo_out_port,
  reset,
  ofifo_valid
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input clk;
  input reset;
  input [33:0] inst;
  input [bw*row-1:0] D_xmem;
  output [psum_bw*col-1:0] sfp_out;
  output [psum_bw*col-1:0] ofifo_out_port;
  output ofifo_valid;

  // Decode instruction signals
  wire acc;
  wire CEN_pmem;
  wire WEN_pmem;
  wire [10:0] A_pmem;
  wire CEN_xmem;
  wire WEN_xmem;
  wire [10:0] A_xmem;
  wire ofifo_rd;
  wire ififo_wr;
  wire ififo_rd;
  wire l0_rd;
  wire l0_wr;
  wire execute;
  wire load;

  assign acc = inst[33];
  assign CEN_pmem = inst[32];
  assign WEN_pmem = inst[31];
  assign A_pmem = inst[30:20];
  assign CEN_xmem = inst[19];
  assign WEN_xmem = inst[18];
  assign A_xmem = inst[17:7];
  assign ofifo_rd = inst[6];
  assign ififo_wr = inst[5];
  assign ififo_rd = inst[4];
  assign l0_rd = inst[3];
  assign l0_wr = inst[2];
  assign execute = inst[1];
  assign load = inst[0];

  // Internal wires
  wire [1:0] inst_w;
  wire [row*bw-1:0] l0_out;
  wire [psum_bw*col-1:0] mac_out;
  wire [col-1:0] mac_valid;
  wire [psum_bw*col-1:0] pmem_out;
  wire [psum_bw*col-1:0] sfp_result; 
  wire [psum_bw*col-1:0] pmem_in;    
  wire [bw*row-1:0] xmem_out;
  wire l0_o_full;
  wire l0_o_ready;
  wire [col-1:0] ofifo_wr;
  wire ofifo_o_full;
  wire ofifo_o_ready;
  wire [psum_bw*col-1:0] ofifo_out;
  wire sfp_valid_out;
  
  // Wires for SFP Mux
  wire [psum_bw*col-1:0] sfp_in_mux;
  wire sfp_valid_in_mux;

  // Instruction for MAC array
  assign inst_w = {execute, load};

  // Activation/Weight SRAM (X memory)
  sram_32b_w2048 xmem_instance (
    .CLK(clk),
    .D(D_xmem),
    .Q(xmem_out),
    .CEN(CEN_xmem),
    .WEN(WEN_xmem),
    .A(A_xmem)
  );

  // L0 FIFO
  l0 #(
    .row(row),
    .bw(bw)
  ) l0_instance (
    .clk(clk),
    .in(xmem_out),
    .out(l0_out),
    .rd(l0_rd),
    .wr(l0_wr),
    .o_full(l0_o_full),
    .reset(reset),
    .o_ready(l0_o_ready)
  );

  // MAC Array
  mac_array #(
    .bw(bw),
    .psum_bw(psum_bw),
    .col(col),
    .row(row)
  ) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(mac_out),
    .in_w(l0_out),
    .in_n(pmem_out), 
    .inst_w(inst_w),
    .valid(mac_valid)
  );

  // Connection: PSUM SRAM Input comes from OFIFO
  assign pmem_in = ofifo_out;

  // PSUM SRAM
  sram_128b_w2048 pmem_instance (
    .CLK(clk),
    .D(pmem_in),
    .Q(pmem_out),
    .CEN(CEN_pmem),
    .WEN(WEN_pmem),
    .A(A_pmem)
  );

  // [FINAL FIX] SFP Input Mux Logic
  // If NOT executing (Verification mode), take data from SRAM (pmem_out).
  // If executing (Calculation mode), take data from MAC Array (mac_out).
  assign sfp_in_mux = (!execute) ? pmem_out : mac_out;
  
  // SFP Valid Mux Logic
  // Only process valid data when executing AND ALL columns have valid output
  assign sfp_valid_in_mux = execute & (&mac_valid);

  // Special Function Processor
  // ReLU disabled during partial sum computation; TB does final accumulation and ReLU
  sfp #(
    .col(col),
    .psum_bw(psum_bw)
  ) sfp_instance (
    .clk(clk),
    .reset(reset),
    .in(sfp_in_mux),      // Use muxed input
    .out(sfp_result),
    .acc_en(acc),
    .relu_en(1'b0),       // Disabled - ReLU applied after full accumulation
    .valid_in(sfp_valid_in_mux), // Use muxed valid
    .valid_out(sfp_valid_out)
  );
 
  // OFIFO write enable
  assign ofifo_wr = {col{sfp_valid_out}};

  // Output FIFO
  ofifo #(
    .col(col),
    .bw(psum_bw)
  ) ofifo_instance (
    .clk(clk),
    .in(sfp_result),    
    .out(ofifo_out),    
    .rd(ofifo_rd),
    .wr(ofifo_wr),
    .o_full(ofifo_o_full),
    .reset(reset),
    .o_ready(ofifo_o_ready),
    .o_valid(ofifo_valid)
  );
    
  // Output port shows SFP result
  assign sfp_out = sfp_result;

  // Output port for OFIFO data (for wrapper to capture)
  assign ofifo_out_port = ofifo_out;

endmodule


