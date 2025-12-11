// psum_bram.v
// Simple dual-port BRAM for partial sum storage
// 324 entries x 128 bits = 5184 bytes
// Port A: Write (during OFIFO_READ)
// Port B: Read (during ACCUMULATE)

`timescale 1ns/1ps

module psum_bram #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 9,   // 2^9 = 512 > 324
    parameter DEPTH = 324
)(
    input  wire                    clk,

    // Port A - Write
    input  wire                    we_a,
    input  wire [ADDR_WIDTH-1:0]   addr_a,
    input  wire [DATA_WIDTH-1:0]   din_a,

    // Port B - Read
    input  wire                    en_b,
    input  wire [ADDR_WIDTH-1:0]   addr_b,
    output reg  [DATA_WIDTH-1:0]   dout_b
);

    // BRAM storage
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port A - Write
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
    end

    // Port B - Read
    always @(posedge clk) begin
        if (en_b) begin
            dout_b <= mem[addr_b];
        end
    end

endmodule
