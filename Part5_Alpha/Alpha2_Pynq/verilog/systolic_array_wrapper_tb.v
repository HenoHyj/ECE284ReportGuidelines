// systolic_array_wrapper_tb.v
// Testbench for AXI-Lite wrapped systolic array
// Verifies the wrapper produces correct output using AXI transactions

`timescale 1ns/1ps

module systolic_array_wrapper_tb;

    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter C_S_AXI_ADDR_WIDTH = 12;
    parameter psum_bw = 16;
    parameter col = 8;
    parameter len_onij = 16;

    // Clock and reset
    reg s_axi_aclk = 0;
    reg s_axi_aresetn = 0;

    // AXI-Lite Write Address Channel
    reg [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    reg [2:0] s_axi_awprot;
    reg s_axi_awvalid;
    wire s_axi_awready;

    // AXI-Lite Write Data Channel
    reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg s_axi_wvalid;
    wire s_axi_wready;

    // AXI-Lite Write Response Channel
    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    reg s_axi_bready;

    // AXI-Lite Read Address Channel
    reg [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    reg [2:0] s_axi_arprot;
    reg s_axi_arvalid;
    wire s_axi_arready;

    // AXI-Lite Read Data Channel
    wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    reg s_axi_rready;

    // Test data
    reg [31:0] activation_data [0:35];  // 36 activations
    reg [127:0] expected_output [0:15];  // 16 expected outputs
    reg [127:0] actual_output [0:15];    // Captured outputs
    reg [31:0] read_data;

    // For file reading
    integer act_file, out_file;
    integer scan_result;
    integer i, j, k;
    integer error_count;
    reg [127:0] temp_128;

    // DUT instantiation
    systolic_array_wrapper #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // Clock generation
    always #5 s_axi_aclk = ~s_axi_aclk;  // 100 MHz

    // AXI Write Task
    task axi_write;
        input [C_S_AXI_ADDR_WIDTH-1:0] addr;
        input [C_S_AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge s_axi_aclk);
            s_axi_awaddr <= addr;
            s_axi_awvalid <= 1;
            s_axi_wdata <= data;
            s_axi_wstrb <= 4'hF;
            s_axi_wvalid <= 1;
            s_axi_bready <= 1;

            // Wait for both ready
            @(posedge s_axi_aclk);
            while (!(s_axi_awready && s_axi_wready)) @(posedge s_axi_aclk);

            // Clear valid signals
            @(posedge s_axi_aclk);
            s_axi_awvalid <= 0;
            s_axi_wvalid <= 0;

            // Wait for response
            while (!s_axi_bvalid) @(posedge s_axi_aclk);
            @(posedge s_axi_aclk);
            s_axi_bready <= 0;
        end
    endtask

    // AXI Read Task
    task axi_read;
        input [C_S_AXI_ADDR_WIDTH-1:0] addr;
        output [C_S_AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge s_axi_aclk);
            s_axi_araddr <= addr;
            s_axi_arvalid <= 1;
            s_axi_rready <= 1;

            // Wait for ready
            @(posedge s_axi_aclk);
            while (!s_axi_arready) @(posedge s_axi_aclk);

            // Clear valid
            @(posedge s_axi_aclk);
            s_axi_arvalid <= 0;

            // Wait for data
            while (!s_axi_rvalid) @(posedge s_axi_aclk);
            data = s_axi_rdata;
            @(posedge s_axi_aclk);
            s_axi_rready <= 0;
        end
    endtask

    // Debug: track internal state
    wire [4:0] fsm_state = dut.state;
    wire [7:0] fsm_counter = dut.counter;
    wire start_pulse_dbg = dut.start_pulse;
    wire [31:0] ctrl_reg_dbg = dut.ctrl_reg;

    // Debug: accumulation tracking
    wire [4:0] acc_o_nij_dbg = dut.acc_o_nij;
    wire [3:0] acc_kij_dbg = dut.acc_kij;
    wire [2:0] acc_col_dbg = dut.acc_col;
    wire [8:0] psum_raddr_dbg = dut.psum_raddr;
    wire [127:0] psum_rdata_dbg = dut.psum_rdata;
    wire [5:0] psum_nij_dbg = dut.psum_nij_cur;

    // Debug: BRAM write tracking
    wire psum_we_dbg = dut.psum_we;
    wire [8:0] psum_waddr_dbg = dut.psum_waddr;
    wire [127:0] psum_wdata_dbg = dut.psum_wdata;
    wire [127:0] ofifo_out_dbg = dut.ofifo_out;
    wire [3:0] kij_dbg = dut.kij;

    // State change detection
    reg [4:0] prev_state;
    always @(posedge s_axi_aclk) begin
        prev_state <= fsm_state;
        if (fsm_state != prev_state) begin
            $display("[%t] State change: %0d -> %0d (counter=%0d, ctrl[0]=%b, start_pulse=%b)",
                     $time, prev_state, fsm_state, fsm_counter, ctrl_reg_dbg[0], start_pulse_dbg);
        end
        // Debug BRAM writes during OFIFO_READ (state 19) - show all writes for kij=0
        if (fsm_state == 19 && psum_we_dbg && kij_dbg == 0) begin
            $display("[BRAM_WR] kij=%0d counter=%0d addr=%0d data=%032h",
                     kij_dbg, fsm_counter, psum_waddr_dbg, psum_wdata_dbg);
        end
        // Debug OFIFO during prime phase (state 18 = S_OFIFO_PRIME) and read phase
        if ((fsm_state == 18 || fsm_state == 19) && kij_dbg == 0 && fsm_counter < 5) begin
            $display("[OFIFO] state=%0d counter=%0d ofifo_valid=%b rd=%b ofifo_out=%032h",
                     fsm_state, fsm_counter, dut.ofifo_valid, dut.ofifo_rd, ofifo_out_dbg);
        end
        // Debug OFIFO writes during EXECUTE and DRAIN (states 15, 16)
        if ((fsm_state == 15 || fsm_state == 16) && kij_dbg == 0 && dut.core_inst.ofifo_wr[0]) begin
            $display("[OFIFO_WR] state=%0d counter=%0d sfp_out=%032h",
                     fsm_state, fsm_counter, dut.core_inst.sfp_out);
        end
        // Debug accumulation for output 0 only
        if (fsm_state == 25 && acc_o_nij_dbg == 0 && acc_col_dbg == 0) begin  // S_ACC_ADD = 25
            $display("[ACC_ADD] o_nij=%0d kij=%0d col=%0d psum_nij=%0d addr=%0d slice=%04h data=%032h",
                     acc_o_nij_dbg, acc_kij_dbg, acc_col_dbg, psum_nij_dbg, psum_raddr_dbg,
                     psum_rdata_dbg[0*16 +: 16], psum_rdata_dbg);
        end
    end

    // Main test sequence
    initial begin
        $dumpfile("systolic_array_wrapper_tb.vcd");
        $dumpvars(0, systolic_array_wrapper_tb);

        // Initialize AXI signals
        s_axi_awaddr = 0;
        s_axi_awprot = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arprot = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;

        // Load activation data
        act_file = $fopen("../../../software/part1/activation.txt", "r");
        if (act_file == 0) begin
            $display("ERROR: Could not open activation.txt");
            $finish;
        end
        // Skip header comments
        scan_result = $fscanf(act_file, "%s", read_data);
        scan_result = $fscanf(act_file, "%s", read_data);
        scan_result = $fscanf(act_file, "%s", read_data);
        // Read 36 activation values
        for (i = 0; i < 36; i = i + 1) begin
            scan_result = $fscanf(act_file, "%32b", activation_data[i]);
        end
        $fclose(act_file);
        $display("Loaded 36 activation values");

        // Load expected output
        out_file = $fopen("../../../software/part1/output.txt", "r");
        if (out_file == 0) begin
            $display("WARNING: Could not open output.txt, will skip verification");
        end else begin
            // Skip header comments
            scan_result = $fscanf(out_file, "%s", read_data);
            scan_result = $fscanf(out_file, "%s", read_data);
            scan_result = $fscanf(out_file, "%s", read_data);
            // Read 16 expected outputs
            for (i = 0; i < 16; i = i + 1) begin
                scan_result = $fscanf(out_file, "%128b", expected_output[i]);
            end
            $fclose(out_file);
            $display("Loaded 16 expected output values");
        end

        // Reset
        $display("\n=== Starting Reset ===");
        s_axi_aresetn = 0;
        #100;
        s_axi_aresetn = 1;
        #100;

        // Check idle state
        axi_read(12'h000, read_data);
        $display("CTRL register after reset: 0x%08x (idle=%b)", read_data, read_data[2]);

        // Write activation data to registers (addresses 0x008 - 0x094)
        $display("\n=== Writing Activation Data ===");
        for (i = 0; i < 36; i = i + 1) begin
            axi_write(12'h008 + i*4, activation_data[i]);
        end
        $display("Wrote 36 activation registers");

        // Start the computation
        $display("\n=== Starting Computation ===");
        axi_write(12'h000, 32'h1);  // Set start bit

        // Poll for completion
        $display("Waiting for completion...");
        read_data = 0;
        i = 0;  // Timeout counter
        while (read_data[1] == 0 && i < 20000) begin  // done bit, with timeout
            #1000;  // Wait 1us between polls
            axi_read(12'h000, read_data);  // CTRL register (done is bit 1)
            if (i % 100 == 0) begin
                axi_read(12'h004, read_data);  // STATUS register for debug
                $display("  Status: state=%0d, kij=%0d (i=%0d)", read_data[7:0], read_data[11:8], i);
                axi_read(12'h000, read_data);  // Read CTRL again
            end
            i = i + 1;
        end

        if (i >= 20000) begin
            $display("TIMEOUT: Computation did not complete in time");
            axi_read(12'h004, read_data);
            $display("  Final Status: state=%0d, kij=%0d", read_data[7:0], read_data[11:8]);
        end

        axi_read(12'h000, read_data);
        $display("Computation complete! CTRL=0x%08x (done=%b, idle=%b)", read_data, read_data[1], read_data[2]);

        // Read output registers (addresses 0x100 - 0x1FC, 16 x 128-bit = 64 x 32-bit)
        $display("\n=== Reading Output Data ===");
        for (i = 0; i < 16; i = i + 1) begin
            // Each 128-bit output spans 4 addresses
            axi_read(12'h100 + i*16 + 0, read_data);
            actual_output[i][31:0] = read_data;
            axi_read(12'h100 + i*16 + 4, read_data);
            actual_output[i][63:32] = read_data;
            axi_read(12'h100 + i*16 + 8, read_data);
            actual_output[i][95:64] = read_data;
            axi_read(12'h100 + i*16 + 12, read_data);
            actual_output[i][127:96] = read_data;
        end

        // Verify outputs
        $display("\n=== Verification ===");
        if (out_file != 0) begin
            error_count = 0;
            for (i = 0; i < 16; i = i + 1) begin
                if (actual_output[i] == expected_output[i]) begin
                    $display("Output %2d: PASS", i);
                end else begin
                    $display("Output %2d: FAIL", i);
                    $display("  Expected: %032h", expected_output[i]);
                    $display("  Actual:   %032h", actual_output[i]);
                    // Show per-column comparison
                    for (k = 0; k < col; k = k + 1) begin
                        $display("    Col %0d: exp=%04h act=%04h %s", k,
                                 expected_output[i][k*psum_bw +: psum_bw],
                                 actual_output[i][k*psum_bw +: psum_bw],
                                 (expected_output[i][k*psum_bw +: psum_bw] == actual_output[i][k*psum_bw +: psum_bw]) ? "OK" : "MISMATCH");
                    end
                    error_count = error_count + 1;
                end
            end

            if (error_count == 0) begin
                $display("\n############ All outputs matched! ##############");
                $display("########### Wrapper Verified! ############");
            end else begin
                $display("\n############ %0d errors detected ##############", error_count);
            end
        end else begin
            $display("Verification skipped (no output.txt)");
            // Just print the outputs for manual inspection
            for (i = 0; i < 16; i = i + 1) begin
                $display("Output %2d: %032h", i, actual_output[i]);
            end
        end

        #1000;
        $finish;
    end

endmodule
