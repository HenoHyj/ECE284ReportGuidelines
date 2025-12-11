// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset, mode_os, w_in, w_out, w_shift);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w;
output [bw-1:0] out_e;
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input  mode_os;
input  [bw-1:0] w_in;
output [bw-1:0] w_out;
input  w_shift;


reg [1:0] inst_q;
reg [bw-1:0] a_q; // activation
reg [bw-1:0] b_q; // weight
reg [psum_bw-1:0] c_q; // psum
reg load_ready_q;
reg [bw-1:0] w_out_q;
wire [psum_bw-1:0] mac_out;
wire [bw-1:0] w_eff;
wire [psum_bw-1:0] c_eff;

always @(posedge clk) begin
	if (reset == 1'b1) begin
		inst_q <= 2'b00;
		load_ready_q <= 1'b1;
		a_q <= 0;
		b_q <= 0;
		c_q <= 0;
		w_out_q <= 0;
	end else begin
		if (mode_os == 1'b1) begin
			if (w_shift == 1'b1 && load_ready_q == 1'b1)
				w_out_q <= w_in;

			if (inst_w[0] == 1'b1 && load_ready_q == 1'b1) begin
				b_q <= w_in;
				load_ready_q <= 1'b0;
			end

			inst_q[1] <= inst_w[1];
			inst_q[0] <= inst_w[0];

			if (|inst_w == 1'b1)
				a_q <= in_w;
			if (inst_w[1] == 1'b1)
				c_q <= in_n;
		end else begin
			inst_q[1] <= inst_w[1];

			if (|inst_w == 1'b1)
				a_q <= in_w;

			if (load_ready_q == 1'b0) begin
				inst_q[0] <= inst_w[0];
				if (inst_w[1] == 1'b1)
					c_q <= in_n;
			end else if (inst_w[0] == 1'b1) begin
				b_q <= in_w;
				load_ready_q <= 1'b0;
			end
		end
	end
end

assign w_eff = b_q;
assign c_eff = c_q;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q),
        .b(w_eff),
        .c(c_eff),
	.out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;
assign w_out = w_out_q;

endmodule
