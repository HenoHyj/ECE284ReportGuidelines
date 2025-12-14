// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;

reg clk = 0;
reg reset = 1;

wire [34:0] inst_q; 

reg [1:0]  inst_w_q = 0; 
reg [bw*row-1:0] D_xmem_q = 0;
reg CEN_xmem = 1;
reg WEN_xmem = 1;
reg [10:0] A_xmem = 0;
reg CEN_xmem_q = 1;
reg WEN_xmem_q = 1;
reg [10:0] A_xmem_q = 0;
reg CEN_pmem = 1;
reg WEN_pmem = 1;
reg [10:0] A_pmem = 0;
reg CEN_pmem_q = 1;
reg WEN_pmem_q = 1;
reg [10:0] A_pmem_q = 0;
reg ofifo_rd_q = 0;
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;
reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc_q = 0;
reg mode_2b_q = 0;
reg acc = 0;
reg mode_2b = 0; // inst[34] : 0 = 4-bit (part1), 1 = 2-bit SIMD mode (part2)

reg [1:0]  inst_w; 
reg [bw*row-1:0] D_xmem;
reg [psum_bw*col-1:0] answer;
reg [psum_bw*col-1:0] pmem_shadow [0:len_kij*len_nij-1];
reg signed [psum_bw-1:0] acc_cols [0:col-1];
reg [psum_bw*col-1:0] computed;
reg signed [psum_bw-1:0] slice;


reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
reg l0_rd;
reg l0_wr;
reg execute;
reg load;
reg [8*64:1] stringvar;
reg [8*64:1] w_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij;
integer error;
integer part2_vector_handle;

// Variables for golden verification
reg [255:0] golden_256b;
reg [127:0] golden_128b;
reg [127:0] golden_relu;
reg signed [15:0] golden_ch;
integer err_golden;
integer idx_g, o_nij_g, psum_nij_g;

// Variables for weight loading
reg [31:0] w_lines [0:7];
reg [31:0] w_transposed [0:7];
reg [3:0] w_nibble;
integer wi, wj;
reg [psum_bw-1:0] relu_val;

// Variables for 2-bit activation loading
reg [15:0] act_tile0 [0:len_nij-1];
reg [15:0] act_tile1 [0:len_nij-1];
reg [31:0] act_packed;
reg [1:0] val0, val1;

// Variables for 2-bit weight loading
reg [31:0] w_lines_b0 [0:7];
reg [31:0] w_lines_b1 [0:7];
reg [31:0] w_transposed_b0 [0:7];
reg [31:0] w_transposed_b1 [0:7];
reg [31:0] w_interleaved [0:15];

// Variables for convolution indexing
integer idx, o_nij, psum_nij;
integer o_ni_dim, a_pad_ni_dim, ki_dim;

// Variables for 2-bit mode verification
reg signed [psum_bw-1:0] psum_2b [0:col-1];
reg signed [psum_bw-1:0] slice_2b;
reg [psum_bw*col-1:0] computed_2b;

assign inst_q[34] = mode_2b_q;
assign inst_q[33] = acc_q;
assign inst_q[32] = CEN_pmem_q;
assign inst_q[31] = WEN_pmem_q;
assign inst_q[30:20] = A_pmem_q;
assign inst_q[19]   = CEN_xmem_q;
assign inst_q[18]   = WEN_xmem_q;
assign inst_q[17:7] = A_xmem_q;
assign inst_q[6]   = ofifo_rd_q;
assign inst_q[5]   = ififo_wr_q;
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q;
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; 
assign inst_q[0]   = load_q; 


core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
        .D_xmem(D_xmem_q), 
        .sfp_out(sfp_out), 
	.reset(reset)); 


initial begin 

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  x_file = $fopen("../../../Part1_Vanilla/hardware/datafiles/activation.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
  /////////////////////////

  /////// Activation data writing to memory ///////
  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
    #0.5 clk = 1'b1;   
  end

  #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////


  for (kij=0; kij<9; kij=kij+1) begin  // kij loop

    case(kij)
     0: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_0.txt";
     1: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_1.txt";
     2: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_2.txt";
     3: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_3.txt";
     4: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_4.txt";
     5: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_5.txt";
     6: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_6.txt";
     7: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_7.txt";
     8: w_file_name = "../../../Part1_Vanilla/hardware/datafiles/weight_8.txt";
    endcase
    

    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   





    /////// Kernel data writing to memory (transposed) ///////
      for (wi=0; wi<col; wi=wi+1) begin
        w_scan_file = $fscanf(w_file, "%32b", w_lines[wi]);
      end

      // Transpose: w_transposed[out_ch] = {W[out_ch][7], W[out_ch][6], ..., W[out_ch][0]}
      // Where W[out_ch][in_ch] = w_lines[in_ch][4*out_ch+3:4*out_ch]
      for (wi=0; wi<col; wi=wi+1) begin  // wi = out_ch for transposed
        w_transposed[wi] = 0;
        for (wj=0; wj<row; wj=wj+1) begin  // wj = in_ch
          // Extract W[out_ch=wi][in_ch=wj] from w_lines[wj]
          w_nibble = (w_lines[wj] >> (4*wi)) & 4'hF;
          // Place in transposed[wi] at position for in_ch=wj
          w_transposed[wi] = w_transposed[wi] | (w_nibble << (4*wj));
        end
      end

      // Write transposed weights to XMEM
      A_xmem = 11'b10000000000;
      for (t=0; t<col; t=t+1) begin
        #0.5 clk = 1'b0; D_xmem = w_transposed[t]; WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;
      end

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Kernel data writing to L0 ///////
    A_xmem = 11'b10000000000;

    // Prime XMEM with first address
    #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 0;
    #0.5 clk = 1'b1;

    // Read from XMEM while writing to L0
    for (t=0; t<col; t=t+1) begin
      #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 1; A_xmem = 11'b10000000000 + t + 1;
      #0.5 clk = 1'b1;
    end

    // One more L0 write to capture last data
    #0.5 clk = 1'b0; l0_wr = 1; CEN_xmem = 1; WEN_xmem = 1;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Kernel loading to PEs ///////
    for (t=0; t<col; t=t+1) begin
      #0.5 clk = 1'b0; load = 1; l0_rd = 1;
      #0.5 clk = 1'b1;
    end

    // Extra cycles to let instruction propagate through all columns
    for (t=0; t<col+4; t=t+1) begin
      #0.5 clk = 1'b0; load = 1; l0_rd = 0;
      #0.5 clk = 1'b1;
    end
    /////////////////////////////////////
  


    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end
    /////////////////////////////////////



    /////// Activation data writing to L0 ///////
    A_xmem = 0;
    
    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 1; if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;
    end
    
    #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; WEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Execution ///////
    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; execute = 1; l0_rd = 1;
      #0.5 clk = 1'b1;
    end

    // Drain the pipeline
    for (t=0; t<row+col; t=t+1) begin
      #0.5 clk = 1'b0; execute = 1; l0_rd = 0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; execute = 0;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////


    //////// OFIFO READ ////////
    // Prime the OFIFO read pipeline
    #0.5 clk = 1'b0; ofifo_rd = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;

    // Now read and capture len_nij entries
    for (t=0; t<len_nij; t=t+1) begin
      pmem_shadow[kij*len_nij + t] = core_instance.ofifo_out;
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; ofifo_rd = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////

    $display("kij %0d captured %0d entries from OFIFO", kij, len_nij);
    /////////////////////////////////////


  end  // end of kij loop


  ////////// Accumulation (testbench-only) /////////
  out_file = $fopen("../../../Part1_Vanilla/hardware/datafiles/output.txt", "r");  

  if (out_file == 0) begin
    $display("############ Skipping verification: missing output.txt ##############");
  end else begin
    // Following three lines are to remove the first three comment lines of the file
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 

    error = 0;

    $display("############ Verification Start (TB accumulation) #############"); 

    for (i=1; i<len_onij+1; i=i+1) begin
      // expected line from file
      out_scan_file = $fscanf(out_file,"%128b", answer);

      // accumulate across kij for each column (reverse order to match output.txt row ordering)
      for (k=0; k<col; k=k+1) acc_cols[k] = 0;

      o_ni_dim = 4;
      a_pad_ni_dim = 6;
      ki_dim = 3;

      for (kij=0; kij<len_kij; kij=kij+1) begin
        for (k=0; k<col; k=k+1) begin
          o_nij = i - 1;
          psum_nij = (o_nij / o_ni_dim) * a_pad_ni_dim + (o_nij % o_ni_dim) +
                     (kij / ki_dim) * a_pad_ni_dim + (kij % ki_dim);
          idx = kij * len_nij + ((psum_nij + len_nij - (5 - k)) % len_nij);
          slice = (pmem_shadow[idx] >> (k*psum_bw));
          acc_cols[k] = acc_cols[k] + slice;
        end
      end

      // ReLU and pack
      computed = 0;
      for (k=0; k<col; k=k+1) begin
        if (acc_cols[k][psum_bw-1] == 1'b1)
          relu_val = {psum_bw{1'b0}};
        else
          relu_val = acc_cols[k];
        computed = computed | (relu_val << (k*psum_bw));
      end

      if (i == 1) $display("4-bit mode: computed[0] = %h", computed);
      if (computed == answer)
        $display("%2d-th output featuremap Data matched! :D", i);
      else begin
        $display("%2d-th output featuremap Data ERROR!!", i); 
        $display("computed: %128b", computed);
        $display("answer  : %128b", answer);
        error = 1;
      end
    end

    if (error == 0) begin
    	$display("############ No error detected ##############"); 
    	$display("########### Project Completed !! ############"); 

    end

    $fclose(out_file);
  end
  //////////////////////////////////

  for (t=0; t<10; t=t+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
  end

  ////////// 2-bit SIMD Mode Test (Part2 specific) /////////
  // Uses Part2's activation_2b.txt (16-bit, 2-bit per channel) and Part2's weights
  $display("############ Starting 2-bit SIMD Mode Test ############");

  mode_2b = 1;  // Enable 2-bit SIMD mode

  // Read 2-bit activation file and pack into 32-bit format
  // activation_2b.txt: 16 bits = 8 channels × 2 bits each
  // Hardware expects: 32 bits = 8 channels × 4 bits each
  // Pack: each 2-bit value goes to a[1:0], a[3:2] = 0
  x_file = $fopen("../datafiles/activation_2b.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1;

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1;

  #0.5 clk = 1'b0;
  #0.5 clk = 1'b1;
  /////////////////////////

  /////// Activation data writing to memory (pack tile0 + tile1) ///////
    for (t=0; t<len_nij; t=t+1) begin
      x_scan_file = $fscanf(x_file,"%16b", act_tile0[t]);
    end
    for (t=0; t<len_nij; t=t+1) begin
      x_scan_file = $fscanf(x_file,"%16b", act_tile1[t]);
    end

    for (t=0; t<len_nij; t=t+1) begin
      act_packed = 0;
      for (j=0; j<8; j=j+1) begin
        val0 = (act_tile0[t] >> (j*2)) & 2'b11;
        val1 = (act_tile1[t] >> (j*2)) & 2'b11;
        act_packed = act_packed | (({val1, val0}) << (j*4));
      end
      #0.5 clk = 1'b0; D_xmem = act_packed; WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;
    end

  #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1;

  $fclose(x_file);
  /////////////////////////////////////////////////


  for (kij=0; kij<9; kij=kij+1) begin  // kij loop

    // Use Part2's weight files
    case(kij)
     0: w_file_name = "../datafiles/weight_0.txt";
     1: w_file_name = "../datafiles/weight_1.txt";
     2: w_file_name = "../datafiles/weight_2.txt";
     3: w_file_name = "../datafiles/weight_3.txt";
     4: w_file_name = "../datafiles/weight_4.txt";
     5: w_file_name = "../datafiles/weight_5.txt";
     6: w_file_name = "../datafiles/weight_6.txt";
     7: w_file_name = "../datafiles/weight_7.txt";
     8: w_file_name = "../datafiles/weight_8.txt";
    endcase


    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1;

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;


    /////// Kernel data writing to memory (transposed, 16 weights for 2-bit mode) ///////
      for (wi=0; wi<col; wi=wi+1) begin
        w_scan_file = $fscanf(w_file, "%32b", w_lines_b0[wi]);
      end
      for (wi=0; wi<col; wi=wi+1) begin
        w_scan_file = $fscanf(w_file, "%32b", w_lines_b1[wi]);
      end

      for (wi=0; wi<col; wi=wi+1) begin
        w_transposed_b0[wi] = 0;
        for (wj=0; wj<row; wj=wj+1) begin
          w_nibble = (w_lines_b0[wj] >> (4*wi)) & 4'hF;
          w_transposed_b0[wi] = w_transposed_b0[wi] | (w_nibble << (4*wj));
        end
      end

      for (wi=0; wi<col; wi=wi+1) begin
        w_transposed_b1[wi] = 0;
        for (wj=0; wj<row; wj=wj+1) begin
          w_nibble = (w_lines_b1[wj] >> (4*wi)) & 4'hF;
          w_transposed_b1[wi] = w_transposed_b1[wi] | (w_nibble << (4*wj));
        end
      end

      for (wi=0; wi<col; wi=wi+1) begin
        w_interleaved[wi*2]     = w_transposed_b0[wi];
        w_interleaved[wi*2 + 1] = w_transposed_b1[wi];
      end

      A_xmem = 11'b10000000000;
      for (t=0; t<col*2; t=t+1) begin
        #0.5 clk = 1'b0; D_xmem = w_interleaved[t]; WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;
      end

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Kernel data writing to L0 (16 weights for 2-bit mode) ///////
    A_xmem = 11'b10000000000;

    // Prime XMEM with first address
    #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 0;
    #0.5 clk = 1'b1;

    // Read from XMEM while writing to L0 (16 weights)
    for (t=0; t<col*2; t=t+1) begin
      #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 1; A_xmem = 11'b10000000000 + t + 1;
      #0.5 clk = 1'b1;
    end

    // One more L0 write to capture last data
    #0.5 clk = 1'b0; l0_wr = 1; CEN_xmem = 1; WEN_xmem = 1;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Kernel loading to PEs (16 weights for 2-bit mode: 8 for b0, 8 for b1) ///////
    for (t=0; t<col*2; t=t+1) begin
      #0.5 clk = 1'b0; load = 1; l0_rd = 1;
      #0.5 clk = 1'b1;
    end

    // Extra cycles to let instruction propagate through all columns
    for (t=0; t<col+4; t=t+1) begin
      #0.5 clk = 1'b0; load = 1; l0_rd = 0;
      #0.5 clk = 1'b1;
    end
    /////////////////////////////////////



    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;


    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end
    /////////////////////////////////////



    /////// Activation data writing to L0 ///////
    A_xmem = 0;

    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 1; if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; WEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Execution ///////
    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; execute = 1; l0_rd = 1;
      #0.5 clk = 1'b1;
    end

    // Drain the pipeline
    for (t=0; t<row+col; t=t+1) begin
      #0.5 clk = 1'b0; execute = 1; l0_rd = 0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; execute = 0;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////


    //////// OFIFO READ ////////
    // Prime the OFIFO read pipeline
    #0.5 clk = 1'b0; ofifo_rd = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;

    // Now read and capture len_nij entries
    for (t=0; t<len_nij; t=t+1) begin
      pmem_shadow[kij*len_nij + t] = core_instance.ofifo_out;
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; ofifo_rd = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////

    $display("2b: kij %0d captured %0d entries from OFIFO", kij, len_nij);
    /////////////////////////////////////


  end  // end of kij loop


  ////////// 2-bit SIMD Verification against golden output.txt /////////
  out_file = $fopen("../datafiles/output.txt", "r");
  if (out_file == 0) begin
    $display("WARNING: Could not open Part2 output.txt for golden comparison");
  end else begin
    out_scan_file = $fscanf(out_file,"%s", answer);
    out_scan_file = $fscanf(out_file,"%s", answer);
    out_scan_file = $fscanf(out_file,"%s", answer);

    err_golden = 0;
    $display("############ Verifying against Part2 output.txt (lower 128 bits) #############");

    for (i=1; i<len_onij+1; i=i+1) begin
      out_scan_file = $fscanf(out_file,"%256b", golden_256b);
      golden_128b = golden_256b[127:0];

      golden_relu = 0;
      for (k=0; k<col; k=k+1) begin
        golden_ch = golden_128b[k*16 +: 16];
        if (golden_ch[15] == 1'b1)
          golden_relu[k*16 +: 16] = 16'b0;
        else
          golden_relu[k*16 +: 16] = golden_ch;
      end

      for (k=0; k<col; k=k+1) psum_2b[k] = 0;

      for (kij=0; kij<len_kij; kij=kij+1) begin
        for (k=0; k<col; k=k+1) begin
          o_nij_g = i - 1;
          psum_nij_g = (o_nij_g / 4) * 6 + (o_nij_g % 4) + (kij / 3) * 6 + (kij % 3);
          idx_g = kij * len_nij + ((psum_nij_g + len_nij - (5 - k)) % len_nij);
          slice_2b = (pmem_shadow[idx_g] >> (k*psum_bw));
          psum_2b[k] = psum_2b[k] + slice_2b;
        end
      end

      computed_2b = 0;
      for (k=0; k<col; k=k+1) begin
        if (psum_2b[k][psum_bw-1] == 1'b1)
          computed_2b = computed_2b | ({psum_bw{1'b0}} << (k*psum_bw));
        else
          computed_2b = computed_2b | (psum_2b[k] << (k*psum_bw));
      end

      if (computed_2b == golden_relu)
        $display("%2d-th 2-bit vs golden Data matched! :D", i);
      else begin
        $display("%2d-th 2-bit vs golden Data MISMATCH", i);
        $display("  HW computed: %h", computed_2b);
        $display("  Golden+ReLU: %h", golden_relu);
        err_golden = 1;
      end
    end

    $fclose(out_file);

    if (err_golden == 0) begin
      $display("############ 2-bit mode matches Part2 golden output! ##############");
      $display("########### Part2 2-bit SIMD Test FULLY Verified !! ############");
    end else begin
      $display("WARNING: Hardware output differs from Part2 golden - investigation needed");
    end
  end
  //////////////////////////////////

  mode_2b = 0;  // Disable 2-bit SIMD mode

  for (t=0; t<10; t=t+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
  end

  #10 $finish;

end

always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   A_xmem_q   <= A_xmem;
   ofifo_rd_q <= ofifo_rd;
   acc_q      <= acc;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
   mode_2b_q  <= mode_2b;
end


endmodule
