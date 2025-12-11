// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module ofifo (clk, in, out, rd, wr, o_full, reset, o_ready, o_valid);

  parameter col  = 8;
  parameter bw = 4;

  input  clk;
  input  [col-1:0] wr;
  input  rd;
  input  reset;
  input  [col*bw-1:0] in;
  output [col*bw-1:0] out;
  output o_full;
  output o_ready;
  output o_valid;

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg  rd_en;
  
  genvar i;

  // o_ready is true when NOT all FIFOs are full (at least one has room)
  assign o_ready = ~(&full) ;
  // o_full is true when ANY FIFO is full
  assign o_full  = |full ;
  // o_valid is true when ALL FIFOs have at least one element (none are empty)
  assign o_valid = ~(|empty) ;
  
  generate
  for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en),              // Same read enable for all columns
	 .wr(wr[i]),              // Individual write enable per column
         .o_empty(empty[i]),      
         .o_full(full[i]),        
	 .in(in[bw*(i+1)-1:bw*i]),    
	 .out(out[bw*(i+1)-1:bw*i]),  
         .reset(reset));
  end
  endgenerate


  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 0;
   end
   else begin
      // Read all columns at once when rd is asserted
      if (rd)
         rd_en <= 1;  
      else
         rd_en <= 0;  
   end
  end

endmodule

