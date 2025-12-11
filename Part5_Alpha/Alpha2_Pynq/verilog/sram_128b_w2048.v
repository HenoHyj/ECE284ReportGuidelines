`timescale 1ns/1ps

// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram_128b_w2048 (CLK, D, Q, CEN, WEN, A);

  input  CLK;
  input  WEN;  // Write Enable (active low)
  input  CEN;  // Chip Enable (active low)
  input  [127:0] D;
  input  [10:0] A;
  output [127:0] Q;
  parameter num = 2048;

  reg [127:0] memory [num-1:0];
  reg [10:0] add_q = 0;
  assign Q = memory[add_q];

  integer i;
  initial begin
    for (i = 0; i < num; i = i + 1) memory[i] = 128'b0;
  end

  always @ (posedge CLK) begin

   if (!CEN && WEN) // read 
      add_q <= A;
   if (!CEN && !WEN) // write
      memory[A] <= D; 

  end

endmodule
