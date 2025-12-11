// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;

  reg [(row+1)*2-1:0] inst_q = 0;
  wire [psum_bw*col*row-1:0] out_s_temp;
  wire [psum_bw*col*row-1:0] in_n_temp;
  wire [col*row-1:0] valid_temp;

  assign in_n_temp[psum_bw*col-1:0] = in_n;
  assign out_s = out_s_temp[psum_bw*col*(row-1) +: psum_bw*col];
  assign valid = valid_temp[col*(row-1) +: col];

  genvar i;
  generate
  for (i = 1; i < row; i = i + 1) begin : psum_chain
      assign in_n_temp[i*psum_bw*col +: psum_bw*col] = out_s_temp[(i-1)*psum_bw*col +: psum_bw*col];
  end

  for (i = 0; i < row; i = i + 1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
      .clk(clk),
      .reset(reset),
      .valid(valid_temp[i*col +: col]),
      .in_w(in_w[i*bw +: bw]),
      .in_n(in_n_temp[i*psum_bw*col +: psum_bw*col]),
      .inst_w(inst_q[i*2 +: 2]),
      .out_s(out_s_temp[i*psum_bw*col +: psum_bw*col]));

      always @(posedge clk) begin
	  inst_q[(i+1)*2 +: 2] <= inst_q[i*2 +: 2];
      end
  end
  endgenerate

  always @ (posedge clk)
      inst_q[1:0] <= inst_w;

endmodule
