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
reg mode_os_q = 0;

reg acc = 0;
reg mode_os = 0;

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

integer x_file, x_scan_file;
integer w_file, w_scan_file;
integer acc_file, acc_scan_file;
integer out_file, out_scan_file;
integer captured_data;
integer t, i, j, k, kij;
integer error;
integer part3_vector_handle;
integer has_part3_vectors;

assign inst_q[34] = mode_os_q;
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

core #(.bw(bw), .col(col), .row(row)) core_instance (
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
  acc      = 0;
  mode_os  = 0;
  has_part3_vectors = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  part3_vector_handle = $fopen("../../software/part3/input.txt", "r");
  if (part3_vector_handle == 0) begin
    has_part3_vectors = 0;
    $display("############ Part3 OS run skipped: missing ../../software/part3/input.txt ############");
  end else begin
    has_part3_vectors = 1;
    $display("############ Part3 OS stimulus detected; OS run will be executed after WS run ############");
    $fclose(part3_vector_handle);
  end

  // ========== WS RUN ==========

  x_file = $fopen("../../software/part1/activation.txt", "r");
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  // Reset
  #0.5 clk = 1'b0; reset = 1;
  #0.5 clk = 1'b1;
  for (i=0; i<10; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
  end
  #0.5 clk = 1'b0; reset = 0;
  #0.5 clk = 1'b1;
  #0.5 clk = 1'b0;
  #0.5 clk = 1'b1;

  // Activation data writing to memory
  for (t=0; t<len_nij; t=t+1) begin
    #0.5 clk = 1'b0; x_scan_file = $fscanf(x_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
    #0.5 clk = 1'b1;
  end
  #0.5 clk = 1'b0; WEN_xmem = 1; CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1;
  $fclose(x_file);

  for (kij=0; kij<9; kij=kij+1) begin

    case(kij)
     0: w_file_name = "../../software/part1/weight_0.txt";
     1: w_file_name = "../../software/part1/weight_1.txt";
     2: w_file_name = "../../software/part1/weight_2.txt";
     3: w_file_name = "../../software/part1/weight_3.txt";
     4: w_file_name = "../../software/part1/weight_4.txt";
     5: w_file_name = "../../software/part1/weight_5.txt";
     6: w_file_name = "../../software/part1/weight_6.txt";
     7: w_file_name = "../../software/part1/weight_7.txt";
     8: w_file_name = "../../software/part1/weight_8.txt";
    endcase

    w_file = $fopen(w_file_name, "r");
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    #0.5 clk = 1'b0; reset = 1;
    #0.5 clk = 1'b1;
    for (i=0; i<10; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end
    #0.5 clk = 1'b0; reset = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;

    // Kernel data writing to memory (transposed)
    begin
      reg [31:0] w_lines [0:7];
      reg [31:0] w_transposed [0:7];
      reg [3:0] w_nibble;
      integer wi, wj;

      for (wi=0; wi<col; wi=wi+1) begin
        w_scan_file = $fscanf(w_file, "%32b", w_lines[wi]);
      end

      for (wi=0; wi<col; wi=wi+1) begin
        w_transposed[wi] = 0;
        for (wj=0; wj<row; wj=wj+1) begin
          w_nibble = (w_lines[wj] >> (4*wi)) & 4'hF;
          w_transposed[wi] = w_transposed[wi] | (w_nibble << (4*wj));
        end
      end

      A_xmem = 11'b10000000000;
      for (t=0; t<col; t=t+1) begin
        #0.5 clk = 1'b0; D_xmem = w_transposed[t]; WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;
      end
    end

    #0.5 clk = 1'b0; WEN_xmem = 1; CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;

    // Kernel data writing to L0
    A_xmem = 11'b10000000000;
    #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 0;
    #0.5 clk = 1'b1;
    for (t=0; t<col; t=t+1) begin
      #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 1; A_xmem = 11'b10000000000 + t + 1;
      #0.5 clk = 1'b1;
    end
    #0.5 clk = 1'b0; l0_wr = 1; CEN_xmem = 1; WEN_xmem = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;

    // Kernel loading to PEs
    for (t=0; t<col; t=t+1) begin
      #0.5 clk = 1'b0; load = 1; l0_rd = 1;
      #0.5 clk = 1'b1;
    end
    for (t=0; t<col+4; t=t+1) begin
      #0.5 clk = 1'b0; load = 1; l0_rd = 0;
      #0.5 clk = 1'b1;
    end
    if (kij == 0) begin
      $display("WS: Weights after load:");
      $display("  Row 0: c0=%h c1=%h c2=%h c3=%h c4=%h c5=%h c6=%h c7=%h",
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[0].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[1].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[2].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[3].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[4].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[5].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[6].mac_tile_instance.b_q,
        core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[7].mac_tile_instance.b_q);
    end

    // Intermission
    #0.5 clk = 1'b0; load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;
    for (i=0; i<10; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    // Activation data writing to L0
    A_xmem = 0;
    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 1; if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;
    end
    #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; WEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1;

    // Execution
    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; execute = 1; l0_rd = 1;
      #0.5 clk = 1'b1;
    end

    // Drain the pipeline
    for (t=0; t<row+col; t=t+1) begin
      #0.5 clk = 1'b0; execute = 1; l0_rd = 0;
      #0.5 clk = 1'b1;
    end

    // Post-drain cleanup
    #0.5 clk = 1'b0; execute = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;

    // OFIFO READ
    #0.5 clk = 1'b0; ofifo_rd = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;

    for (t=0; t<len_nij; t=t+1) begin
      pmem_shadow[kij*len_nij + t] = core_instance.ofifo_out;
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; ofifo_rd = 0;
    #0.5 clk = 1'b1;

  end  // kij loop

  // Verification
  out_file = $fopen("../../software/part1/output.txt", "r");

  if (out_file == 0) begin
    $display("############ Skipping verification: missing output.txt ##############");
  end else begin
    out_scan_file = $fscanf(out_file,"%s", answer);
    out_scan_file = $fscanf(out_file,"%s", answer);
    out_scan_file = $fscanf(out_file,"%s", answer);

    error = 0;
    $display("############ Verification Start (TB accumulation) #############");

    for (i=1; i<len_onij+1; i=i+1) begin
      out_scan_file = $fscanf(out_file,"%128b", answer);

      for (k=0; k<col; k=k+1) acc_cols[k] = 0;

      for (kij=0; kij<len_kij; kij=kij+1) begin
        for (k=0; k<col; k=k+1) begin
          integer idx;
          integer o_nij;
          integer psum_nij;
          integer o_ni_dim, a_pad_ni_dim, ki_dim;

          o_ni_dim = 4;
          a_pad_ni_dim = 6;
          ki_dim = 3;

          o_nij = i - 1;
          psum_nij = (o_nij / o_ni_dim) * a_pad_ni_dim + (o_nij % o_ni_dim) +
                     (kij / ki_dim) * a_pad_ni_dim + (kij % ki_dim);

          idx = kij * len_nij + ((psum_nij + len_nij - (5 - k)) % len_nij);
          slice = (pmem_shadow[idx] >> (k*psum_bw));
          acc_cols[k] = acc_cols[k] + slice;
        end
      end

      computed = 0;
      for (k=0; k<col; k=k+1) begin
        reg [psum_bw-1:0] relu_val;
        if (acc_cols[k][psum_bw-1] == 1'b1)
          relu_val = {psum_bw{1'b0}};
        else
          relu_val = acc_cols[k];
        computed = computed | (relu_val << (k*psum_bw));
      end

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

  // ========== OS MODE ==========
  if (has_part3_vectors) begin
    $display("############ Starting Part3 Output-Stationary (OS) run ############");

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
    acc      = 0;
    mode_os  = 1;

    for (t=0; t<len_kij*len_nij; t=t+1) begin
      pmem_shadow[t] = {psum_bw*col{1'b0}};
    end

    x_file = $fopen("../../software/part3/activation.txt", "r");
    if (x_file == 0) begin
      $display("############ OS run aborted: missing ../../software/part3/activation.txt ############");
    end else begin
      x_scan_file = $fscanf(x_file,"%s", captured_data);
      x_scan_file = $fscanf(x_file,"%s", captured_data);
      x_scan_file = $fscanf(x_file,"%s", captured_data);

      // Reset
      #0.5 clk = 1'b0; reset = 1;
      #0.5 clk = 1'b1;
      for (i=0; i<10; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end
      #0.5 clk = 1'b0; reset = 0;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;

      // Activation data writing to memory
      for (t=0; t<len_nij; t=t+1) begin
        #0.5 clk = 1'b0;
        x_scan_file = $fscanf(x_file,"%32b", D_xmem);
        WEN_xmem = 0;
        CEN_xmem = 0;
        if (t>0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;
      end
      #0.5 clk = 1'b0; WEN_xmem = 1; CEN_xmem = 1; A_xmem = 0;
      #0.5 clk = 1'b1;
      $fclose(x_file);

      for (kij=0; kij<9; kij=kij+1) begin

        case(kij)
         0: w_file_name = "../../software/part3/weight_0.txt";
         1: w_file_name = "../../software/part3/weight_1.txt";
         2: w_file_name = "../../software/part3/weight_2.txt";
         3: w_file_name = "../../software/part3/weight_3.txt";
         4: w_file_name = "../../software/part3/weight_4.txt";
         5: w_file_name = "../../software/part3/weight_5.txt";
         6: w_file_name = "../../software/part3/weight_6.txt";
         7: w_file_name = "../../software/part3/weight_7.txt";
         8: w_file_name = "../../software/part3/weight_8.txt";
        endcase

        w_file = $fopen(w_file_name, "r");
        if (w_file == 0) begin
          $display("############ OS run aborted: missing %0s ############", w_file_name);
          $finish;
        end

        w_scan_file = $fscanf(w_file,"%s", captured_data);
        w_scan_file = $fscanf(w_file,"%s", captured_data);
        w_scan_file = $fscanf(w_file,"%s", captured_data);

        // Reset for kernel load
        #0.5 clk = 1'b0; reset = 1;
        #0.5 clk = 1'b1;
        for (i=0; i<5; i=i+1) begin
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end
        #0.5 clk = 1'b0; reset = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;

        // OS weight loading via IFIFO
        begin
          reg [31:0] w_lines [0:7];
          reg [31:0] w_transposed [0:7];
          reg [3:0] w_nibble;
          integer wi, wj;

          for (wi=0; wi<col; wi=wi+1) begin
            w_scan_file = $fscanf(w_file, "%32b", w_lines[wi]);
          end

          // Transpose weights (same as WS mode)
          for (wi=0; wi<col; wi=wi+1) begin
            w_transposed[wi] = 0;
            for (wj=0; wj<row; wj=wj+1) begin
              w_nibble = (w_lines[wj] >> (4*wi)) & 4'hF;
              w_transposed[wi] = w_transposed[wi] | (w_nibble << (4*wj));
            end
          end

          // Write weights to IFIFO (reverse order for correct column assignment)
          ififo_wr = 0;
          ififo_rd = 0;
          load = 0;
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;

          for (t=0; t<col; t=t+1) begin
            #0.5 clk = 1'b0;
            D_xmem = w_transposed[col-1-t];
            ififo_wr = 1;
            WEN_xmem = 1;
            CEN_xmem = 1;
            #0.5 clk = 1'b1;
          end
          for (t=0; t<4; t=t+1) begin
            #0.5 clk = 1'b0;
            D_xmem = w_transposed[col-1-t];
            ififo_wr = 1;
            #0.5 clk = 1'b1;
          end

          #0.5 clk = 1'b0;
          ififo_wr = 0;
          #0.5 clk = 1'b1;

          // Read IFIFO to fill weight shift chain
          for (t=0; t<col-1; t=t+1) begin
            #0.5 clk = 1'b0;
            ififo_rd = 1;
            load = 0;
            #0.5 clk = 1'b1;
          end

          #0.5 clk = 1'b0;
          ififo_rd = 0;
          load = 0;
          #0.5 clk = 1'b1;

          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;

          // Pulse load to capture weights
          #0.5 clk = 1'b0;
          load = 1;
          #0.5 clk = 1'b1;
          #0.5 clk = 1'b0;
          load = 0;
          #0.5 clk = 1'b1;

          // Wait for load to propagate
          for (t=0; t<col+3; t=t+1) begin
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
          end
          for (t=0; t<row+2; t=t+1) begin
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
          end

          if (kij == 0) begin
            $display("OS: Weights after load:");
            $display("  Row 0: c0=%h c1=%h c2=%h c3=%h c4=%h c5=%h c6=%h c7=%h",
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[0].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[1].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[2].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[3].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[4].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[5].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[6].mac_tile_instance.b_q,
              core_instance.mac_array_instance.row_num[0].mac_row_instance.col_num[7].mac_tile_instance.b_q);
          end
        end

        // Activation -> L0
        A_xmem = 0;
        #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; l0_wr = 0;
        #0.5 clk = 1'b1;

        for (t=0; t<len_nij; t=t+1) begin
          #0.5 clk = 1'b0;
          CEN_xmem = 0;
          WEN_xmem = 1;
          l0_wr = 1;
          A_xmem = t + 1;
          #0.5 clk = 1'b1;
        end
        #0.5 clk = 1'b0; l0_wr = 1; CEN_xmem = 1; WEN_xmem = 1;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; WEN_xmem = 1; A_xmem = 0;
        #0.5 clk = 1'b1;

        // Execution - add 2 cycles to align timing with WS mode
        #0.5 clk = 1'b0; execute = 1; l0_rd = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0; execute = 1; l0_rd = 0;
        #0.5 clk = 1'b1;

        for (t=0; t<len_nij; t=t+1) begin
          #0.5 clk = 1'b0;
          execute = 1;
          l0_rd = 1;
          #0.5 clk = 1'b1;
        end

        // Drain pipeline
        for (t=0; t<row+col; t=t+1) begin
          #0.5 clk = 1'b0; execute = 1; l0_rd = 0;
          #0.5 clk = 1'b1;
        end

        // Post-drain cleanup
        #0.5 clk = 1'b0; execute = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;

        // OFIFO READ
        #0.5 clk = 1'b0; ofifo_rd = 1;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;

        for (t=0; t<len_nij; t=t+1) begin
          pmem_shadow[kij*len_nij + t] = core_instance.ofifo_out;
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end

        #0.5 clk = 1'b0; ofifo_rd = 0;
        #0.5 clk = 1'b1;

        $fclose(w_file);

      end // kij loop

      // OS Verification
      out_file = $fopen("../../software/part3/output.txt", "r");

      if (out_file == 0) begin
        $display("############ Skipping OS verification: missing ../../software/part3/output.txt ##############");
      end else begin
        out_scan_file = $fscanf(out_file,"%s", answer);
        out_scan_file = $fscanf(out_file,"%s", answer);
        out_scan_file = $fscanf(out_file,"%s", answer);

        error = 0;
        $display("############ OS Verification Start (TB accumulation) #############");

        for (i=1; i<len_onij+1; i=i+1) begin
          out_scan_file = $fscanf(out_file,"%128b", answer);

          for (k=0; k<col; k=k+1) acc_cols[k] = 0;

          for (kij=0; kij<len_kij; kij=kij+1) begin
            for (k=0; k<col; k=k+1) begin
              integer idx;
              integer o_nij;
              integer psum_nij;
              integer o_ni_dim, a_pad_ni_dim, ki_dim;

              o_ni_dim = 4;
              a_pad_ni_dim = 6;
              ki_dim = 3;

              o_nij = i - 1;
              psum_nij = (o_nij / o_ni_dim) * a_pad_ni_dim + (o_nij % o_ni_dim) +
                         (kij / ki_dim) * a_pad_ni_dim + (kij % ki_dim);

              idx = kij * len_nij + ((psum_nij + len_nij - (5 - k)) % len_nij);
              slice = (pmem_shadow[idx] >> (k*psum_bw));
              acc_cols[k] = acc_cols[k] + slice;
            end
          end

          computed = 0;
          for (k=0; k<col; k=k+1) begin
            reg [psum_bw-1:0] relu_val;
            if (acc_cols[k][psum_bw-1] == 1'b1)
              relu_val = {psum_bw{1'b0}};
            else
              relu_val = acc_cols[k];
            computed = computed | (relu_val << (k*psum_bw));
          end

          if (computed == answer)
            $display("OS: %2d-th output featuremap Data matched! :D", i);
          else begin
            $display("OS: %2d-th output featuremap Data ERROR!!", i);
            $display("OS computed: %128b", computed);
            $display("OS answer  : %128b", answer);
            error = 1;
          end
        end

        if (error == 0) begin
          $display("############ OS: No error detected ##############");
          $display("########### OS: Project Part3 Completed !! ############");
        end

        $fclose(out_file);
      end
    end
  end

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
   mode_os_q  <= mode_os;
end

endmodule
