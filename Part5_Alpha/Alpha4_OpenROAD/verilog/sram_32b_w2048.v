// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram_32b_w2048 (CLK, D, Q, CEN, WEN, A);

  input  CLK;
  input  WEN;  // Write Enable (active low)
  input  CEN;  // Chip Enable (active low)
  input  [31:0] D;
  input  [10:0] A;
  output [31:0] Q;

  ////////// TECH INDEPENDENT ///////////
  // parameter num = 2048;

  // reg [31:0] memory [num-1:0];
  // reg [10:0] add_q = 0;
  // assign Q = memory[add_q];

  // integer i;
  // initial begin
  //   for (i = 0; i < num; i = i + 1) memory[i] = 32'b0;
  // end

  // always @ (posedge CLK) begin

  //  if (!CEN && WEN) // read 
  //     add_q <= A;
  //  if (!CEN && !WEN) // write
  //     memory[A] <= D; 

  // end

  ////////// TECH DEPENDENT -- IHP-SG13G2 ///////////
  // source: https://github.com/IHP-GmbH/IHP-Open-PDK/tree/main/ihp-sg13g2/libs.ref/sg13g2_sram
  wire [3:0] enable_bank;
  wire [(32*4)-1:0] Q_temp;

  assign enable_bank[0] = (A[10:9] == 2'b00) ? 1'b1 : 1'b0;
  assign enable_bank[1] = (A[10:9] == 2'b01) ? 1'b1 : 1'b0;
  assign enable_bank[2] = (A[10:9] == 2'b10) ? 1'b1 : 1'b0;
  assign enable_bank[3] = (A[10:9] == 2'b11) ? 1'b1 : 1'b0;

  assign Q = (enable_bank[0]) ? Q_temp[31:0] : ((enable_bank[1]) ? Q_temp[63:32] : ((enable_bank[2]) ? Q_temp[95:64] : Q_temp[127:96]));

  genvar i;
  generate
    for (i = 0; i < 4; i = i+1) begin : gen_512x32
      RM_IHPSG13_1P_512x32_c2_bm_bist i_cut (
        .A_CLK (CLK),
        .A_DLY (1'b1),
        .A_ADDR(A[8:0]),
        .A_BM  ({32{1'b1}}),
        .A_MEN (!CEN & enable_bank[i]),
        .A_WEN (!WEN),
        .A_REN (WEN),
        .A_DIN (D),
        .A_DOUT(Q_temp[i*32 +: 32]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(9'd0),
        .A_BIST_DIN (32'd0),
        .A_BIST_BM  (32'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
      );
    end
  endgenerate

endmodule
