module sfp (clk, reset, in, out, acc_en, act_en, valid_in, valid_out);

  parameter col = 8;
  parameter psum_bw = 16;
  // Activation type: 0=None, 1=ReLU, 2=Sigmoid, 3=Tanh
  parameter act_type = 1;

  input clk;
  input reset;
  input [psum_bw*col-1:0] in;
  output [psum_bw*col-1:0] out;
  input acc_en;
  input act_en;      // Activation enable
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

  // Sigmoid LUT: output [0, 127], uses upper bits of x for table index
  function [psum_bw-1:0] sigmoid_lut;
    input signed [psum_bw-1:0] x;
    reg [3:0] idx;
    begin
      if (x[psum_bw-1]) // negative
        idx = (x < -2048) ? 4'd0 : ~x[10:7] + 1;
      else // positive
        idx = (x > 2047) ? 4'd15 : x[10:7] + 8;

      case (idx)
        4'd0:  sigmoid_lut = 4;
        4'd1:  sigmoid_lut = 8;
        4'd2:  sigmoid_lut = 14;
        4'd3:  sigmoid_lut = 24;
        4'd4:  sigmoid_lut = 36;
        4'd5:  sigmoid_lut = 48;
        4'd6:  sigmoid_lut = 56;
        4'd7:  sigmoid_lut = 62;
        4'd8:  sigmoid_lut = 66;
        4'd9:  sigmoid_lut = 72;
        4'd10: sigmoid_lut = 80;
        4'd11: sigmoid_lut = 92;
        4'd12: sigmoid_lut = 104;
        4'd13: sigmoid_lut = 114;
        4'd14: sigmoid_lut = 120;
        4'd15: sigmoid_lut = 124;
      endcase
    end
  endfunction

  // Tanh LUT: output [-128, 127], uses upper bits of x for table index
  function signed [psum_bw-1:0] tanh_lut;
    input signed [psum_bw-1:0] x;
    reg [2:0] idx;
    reg sign;
    reg [psum_bw-1:0] abs_x;
    reg [7:0] mag;
    begin
      sign = x[psum_bw-1];
      abs_x = sign ? -x : x;
      idx = (abs_x > 1023) ? 3'd7 : abs_x[9:7];

      case (idx)
        3'd0: mag = 8;
        3'd1: mag = 24;
        3'd2: mag = 48;
        3'd3: mag = 80;
        3'd4: mag = 104;
        3'd5: mag = 118;
        3'd6: mag = 124;
        3'd7: mag = 127;
      endcase

      tanh_lut = sign ? -mag : mag;
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
        wire signed [psum_bw-1:0] col_in = sanitize(in[psum_bw*(k+1)-1:psum_bw*k]);
        wire signed [psum_bw-1:0] col_acc = sanitize(acc_reg[psum_bw*(k+1)-1:psum_bw*k]);
        wire signed [psum_bw-1:0] sum;
        wire signed [psum_bw-1:0] act_res;

        assign sum = acc_en ? (col_acc + col_in) : col_in;

        if (act_type == 0) begin : gen_none
            assign act_res = sum;
        end else if (act_type == 1) begin : gen_relu
            assign act_res = (act_en && sum[psum_bw-1]) ? {psum_bw{1'b0}} : sum;
        end else if (act_type == 2) begin : gen_sigmoid
            assign act_res = act_en ? sigmoid_lut(sum) : sum;
        end else if (act_type == 3) begin : gen_tanh
            assign act_res = act_en ? tanh_lut(sum) : sum;
        end else begin : gen_default
            assign act_res = sum;
        end

        assign next_acc[psum_bw*(k+1)-1:psum_bw*k] = sum;
        assign next_out[psum_bw*(k+1)-1:psum_bw*k] = act_res;
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
