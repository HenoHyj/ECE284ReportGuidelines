// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset, mode_2b);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input  mode_2b; // 1 = 2-bit activations with two weight lanes


reg [1:0] inst_q;
reg [bw-1:0] a_q; // activation
reg [bw-1:0] b0_q; // weight lane 0 (default weight)
reg [bw-1:0] b1_q; // weight lane 1 for 2-bit mode
reg [psum_bw-1:0] c_q; // psum
reg load_ready_q;
reg [1:0] weight_count;
wire [psum_bw-1:0] mac_out;
wire [psum_bw-1:0] mac_single_out;
wire [psum_bw-1:0] mac_lane0_out;
wire [psum_bw-1:0] mac_lane1_out;
wire [bw-1:0] a_low_2b;
wire [bw-1:0] a_high_2b;

always @(posedge clk) begin

	if (reset == 1'b1) begin
		inst_q <= 2'b00;
		load_ready_q <= 1'b1;
		weight_count <= 0;
		b0_q <= 0;
		b1_q <= 0;
		a_q <= 0;
		c_q <= 0;
	end else begin
		inst_q[1] <= inst_w[1];

		if (|inst_w == 1'b1)
			a_q <= in_w;

		if (load_ready_q == 1'b0) begin
			inst_q[0] <= inst_w[0];
			
			if (inst_w[1] == 1'b1)
				c_q <= in_n;
		end
		else if (inst_w[0] == 1'b1) begin
			// 4-bit mode: single weight load. 2-bit mode: load two weights back-to-back.
			if (mode_2b == 1'b1) begin
				if (weight_count == 0) begin
					b0_q <= in_w;
					weight_count <= 1;
				end else begin
					b1_q <= in_w;
					weight_count <= 0;
					load_ready_q <= 1'b0;
				end
			end else begin
				b0_q <= in_w;
				weight_count <= 0;
				load_ready_q <= 1'b0;
			end
		end
	end
end

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b(b0_q),
        .c(c_q),
	.out(mac_single_out)
); 

assign a_low_2b  = {{(bw-2){1'b0}}, a_q[1:0]};
assign a_high_2b = {{(bw-2){1'b0}}, a_q[3:2]};

mac #(.bw(bw), .psum_bw(psum_bw)) mac_lane0 (
        .a(a_low_2b),
        .b(b0_q),
        .c({psum_bw{1'b0}}),
        .out(mac_lane0_out)
);

mac #(.bw(bw), .psum_bw(psum_bw)) mac_lane1 (
        .a(a_high_2b),
        .b(b1_q),
        .c({psum_bw{1'b0}}),
        .out(mac_lane1_out)
);

assign mac_out = (mode_2b == 1'b1) ? (mac_lane0_out + mac_lane1_out + c_q) : mac_single_out;

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;

endmodule
