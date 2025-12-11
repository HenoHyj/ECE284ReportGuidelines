// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (clk, out_s, in_w, in_n, valid, inst_w, reset);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input clk, reset;
  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input [1:0] inst_w;
  input [psum_bw*col-1:0] in_n;

  wire [(col+1)*bw-1:0] temp;
  wire [(col+1)*2-1:0] temp_inst;

  assign temp[bw-1:0] = in_w;
  assign temp_inst[1:0] = inst_w;


  genvar i;
  generate
  for (i = 0; i < col; i = i + 1) begin : col_num
      mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
         .clk(clk),
         .reset(reset),
	 .in_w(temp[i*bw +: bw]),
	 .out_e(temp[(i+1)*bw +: bw]),
	 .inst_w(temp_inst[i*2 +: 2]),
	 .inst_e(temp_inst[(i+1)*2 +: 2]),
	 .in_n(in_n[i*psum_bw +: psum_bw]),
	 .out_s(out_s[i*psum_bw +: psum_bw]));

      assign valid[i] = temp_inst[(i+1)*2 + 1];
  end
  endgenerate

endmodule
