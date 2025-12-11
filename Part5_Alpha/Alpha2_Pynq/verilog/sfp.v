`timescale 1ns/1ps

module sfp (clk, reset, in, out, acc_en, relu_en, valid_in, valid_out);

  parameter col = 8;
  parameter psum_bw = 16;

  input clk;
  input reset;
  input [psum_bw*col-1:0] in;
  output [psum_bw*col-1:0] out;
  input acc_en;      
  input relu_en;
  input valid_in;    
  output valid_out;

  reg [psum_bw*col-1:0] acc_reg;
  reg [psum_bw*col-1:0] out_reg;
  reg valid_out_reg;
  
  function [psum_bw-1:0] sanitize;
    input [psum_bw-1:0] v;
    integer b;
    begin
      for (b = 0; b < psum_bw; b = b + 1) begin
        sanitize[b] = (v[b] === 1'bx) ? 1'b0 : v[b];
      end
    end
  endfunction
  
  // Intermediate wires for next-state logic
  wire [psum_bw*col-1:0] next_acc;
  wire [psum_bw*col-1:0] next_out;

  assign out = out_reg;
  assign valid_out = valid_out_reg;

  genvar k;
  generate
    for (k=0; k<col; k=k+1) begin : gen_sfp_logic
        // Extract current column inputs
        wire signed [psum_bw-1:0] col_in = sanitize(in[psum_bw*(k+1)-1:psum_bw*k]);
        wire signed [psum_bw-1:0] col_acc = sanitize(acc_reg[psum_bw*(k+1)-1:psum_bw*k]);
        
        // 1. Calculate Next Accumulation Value (Combinational)
        wire signed [psum_bw-1:0] sum;
        assign sum = acc_en ? (col_acc + col_in) : col_in;
        
        // 2. Calculate Next Output Value (ReLU Logic on the NEW sum)
        wire signed [psum_bw-1:0] relu_res;
        assign relu_res = (relu_en && sum[psum_bw-1]) ? {psum_bw{1'b0}} : sum;
        
        // Pack into vectors
        assign next_acc[psum_bw*(k+1)-1:psum_bw*k] = sum;
        assign next_out[psum_bw*(k+1)-1:psum_bw*k] = relu_res;
    end
  endgenerate

  always @ (posedge clk) begin
    if (reset) begin
      acc_reg <= 0;
      out_reg <= 0;
      valid_out_reg <= 0;
    end else begin
      valid_out_reg <= valid_in;
      
      if (valid_in) begin
          // Update registers with the pre-calculated next values
          acc_reg <= next_acc;
          out_reg <= next_out; 
      end
    end
  end

endmodule
