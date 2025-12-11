// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (clk, out_s, in_w, in_n, valid, inst_w, reset, mode_os, w_stream, w_shift);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input clk, reset, mode_os;
  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input [bw-1:0] in_w;
  input [1:0] inst_w;
  input [psum_bw*col-1:0] in_n;
  input [bw-1:0] w_stream;
  input w_shift;

  wire [(col+1)*bw-1:0] temp;
  wire [(col+1)*2-1:0] temp_inst;
  wire [(col+1)*bw-1:0] w_temp;
  wire [1:0] tile_inst [0:col-1];

  assign temp[bw-1:0] = in_w;
  assign temp_inst[1:0] = inst_w;
  assign w_temp[bw-1:0] = w_stream;

  genvar i;
  generate
  for (i = 0; i < col; i = i + 1) begin : col_num
      assign tile_inst[i] = mode_os ? {temp_inst[i*2 + 1], inst_w[0]} : temp_inst[i*2 +: 2];

      mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
         .clk(clk),
         .reset(reset),
	 .mode_os(mode_os),
	 .w_in(w_temp[i*bw +: bw]),
	 .w_out(w_temp[(i+1)*bw +: bw]),
	 .w_shift(w_shift),
	 .in_w(temp[i*bw +: bw]),
	 .out_e(temp[(i+1)*bw +: bw]),
	 .inst_w(tile_inst[i]),
	 .inst_e(temp_inst[(i+1)*2 +: 2]),
	 .in_n(in_n[i*psum_bw +: psum_bw]),
	 .out_s(out_s[i*psum_bw +: psum_bw]));

      assign valid[i] = temp_inst[(i+1)*2 + 1];
  end
  endgenerate

endmodule
