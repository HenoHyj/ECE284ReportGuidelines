// systolic_array_wrapper.v
// AXI-Lite wrapper for Part1 systolic array core
// Targets RFSoC4x2 with PYNQ
//
// Features:
// - AXI-Lite slave interface for register access
// - FSM controlling the core (replicates testbench sequence)
// - Weight BRAM pre-loaded at synthesis
// - Hardware accumulator for 9 kernel positions
// - ReLU applied after full accumulation
//
// v2: Uses BRAM for psum_shadow to reduce resource usage

`timescale 1ns/1ps

module systolic_array_wrapper #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 12  // 4KB address space
)(
    // AXI-Lite Slave Interface
    input  wire                                s_axi_aclk,
    input  wire                                s_axi_aresetn,

    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [2:0]                          s_axi_awprot,
    input  wire                                s_axi_awvalid,
    output wire                                s_axi_awready,

    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb,
    input  wire                                s_axi_wvalid,
    output wire                                s_axi_wready,

    // Write response channel
    output wire [1:0]                          s_axi_bresp,
    output wire                                s_axi_bvalid,
    input  wire                                s_axi_bready,

    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [2:0]                          s_axi_arprot,
    input  wire                                s_axi_arvalid,
    output wire                                s_axi_arready,

    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output wire [1:0]                          s_axi_rresp,
    output wire                                s_axi_rvalid,
    input  wire                                s_axi_rready
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam BW = 4;           // Bit width
    localparam PSUM_BW = 16;     // Partial sum bit width
    localparam COL = 8;          // Columns
    localparam ROW = 8;          // Rows
    localparam LEN_NIJ = 36;     // Activation count per kernel
    localparam LEN_KIJ = 9;      // Kernel positions
    localparam LEN_ONIJ = 16;    // Output count

    // Register map offsets
    localparam ADDR_CTRL       = 12'h000;  // Control register
    localparam ADDR_STATUS     = 12'h004;  // Status register
    localparam ADDR_ACT_BASE   = 12'h008;  // Activations start (36 x 32-bit)
    localparam ADDR_ACT_END    = 12'h094;  // Activations end
    localparam ADDR_OUT_BASE   = 12'h100;  // Outputs start (16 x 128-bit = 64 x 32-bit)
    localparam ADDR_OUT_END    = 12'h1FC;  // Outputs end

    // FSM States - expanded for sequential accumulation
    localparam [4:0]
        S_IDLE            = 5'd0,
        S_RESET_CORE      = 5'd1,
        S_LOAD_ACT_XMEM   = 5'd2,
        S_WAIT_ACT        = 5'd3,
        S_KIJ_RESET       = 5'd4,
        S_LOAD_W_XMEM     = 5'd5,
        S_WAIT_W_XMEM     = 5'd6,
        S_LOAD_W_L0_PRIME = 5'd7,
        S_LOAD_W_L0       = 5'd8,
        S_LOAD_W_L0_LAST  = 5'd9,
        S_LOAD_W_PE       = 5'd10,
        S_LOAD_W_PE_PROP  = 5'd11,
        S_INTERMISSION    = 5'd12,
        S_LOAD_A_L0       = 5'd13,
        S_WAIT_A_L0       = 5'd14,
        S_EXECUTE         = 5'd15,
        S_DRAIN           = 5'd16,
        S_WAIT_DRAIN      = 5'd17,
        S_OFIFO_PRIME     = 5'd18,
        S_OFIFO_READ      = 5'd19,
        S_OFIFO_DONE      = 5'd20,
        S_NEXT_KIJ        = 5'd21,
        S_ACC_INIT        = 5'd22,  // Initialize accumulation for one output
        S_ACC_READ        = 5'd23,  // Read from BRAM (takes 1 cycle latency)
        S_ACC_WAIT        = 5'd24,  // Wait for BRAM read latency
        S_ACC_ADD         = 5'd25,  // Add to accumulators
        S_ACC_STORE       = 5'd26,  // Store accumulated value
        S_RELU            = 5'd27,
        S_DONE            = 5'd28;

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // AXI-Lite internal signals
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // Registers
    reg [31:0] ctrl_reg;        // [0]=start, [1]=done(ro), [2]=idle(ro), [3]=sw_reset
    reg [31:0] status_reg;      // [7:0]=state, [15:8]=kij_counter
    reg [31:0] act_regs [0:LEN_NIJ-1];  // 36 activation registers
    reg [127:0] out_regs [0:LEN_ONIJ-1]; // 16 output registers

    // FSM
    reg [4:0] state, next_state;
    reg [7:0] counter;
    reg [3:0] kij;  // Kernel position counter (0-8)

    // Core interface signals
    reg core_reset;
    reg [33:0] inst;
    reg [31:0] D_xmem;
    wire [127:0] sfp_out;
    wire [127:0] ofifo_out;
    wire ofifo_valid;

    // Instruction components
    reg acc_en;
    reg CEN_pmem, WEN_pmem;
    reg [10:0] A_pmem;
    reg CEN_xmem, WEN_xmem;
    reg [10:0] A_xmem;
    reg ofifo_rd;
    reg ififo_wr, ififo_rd;
    reg l0_rd, l0_wr;
    reg execute, load;

    // Weight BRAM - 9 kernels x 8 lines = 72 entries
    reg [31:0] weight_bram [0:71];

    // PSUM BRAM interface
    reg psum_we;
    reg [8:0] psum_waddr;
    reg [127:0] psum_wdata;
    reg psum_re;
    reg [8:0] psum_raddr;
    wire [127:0] psum_rdata;

    // Accumulation state
    reg [4:0] acc_o_nij;      // Current output position being accumulated (0-15)
    reg [3:0] acc_kij;        // Current kernel position being accumulated (0-8)
    reg [2:0] acc_col;        // Current column being accumulated (0-7)
    reg signed [PSUM_BW-1:0] acc_cols [0:COL-1];  // Accumulator registers
    reg [8:0] acc_bram_addr;  // Computed BRAM address for current read
    reg acc_read_valid;       // Indicates valid data from BRAM

    // Start pulse detection
    reg start_d;
    wire start_pulse;

    // Variables for output register read logic
    reg [5:0] out_idx;
    reg [1:0] word_idx;

    // Combinational address computation for accumulation
    // These use fixed dimensions from the algorithm
    // o_ni_dim = 4, a_pad_ni_dim = 6, ki_dim = 3

    // psum_nij = (o_nij / 4) * 6 + (o_nij % 4) + (kij / 3) * 6 + (kij % 3)
    wire [5:0] psum_nij_cur;
    assign psum_nij_cur = (acc_o_nij / 4) * 6 + (acc_o_nij % 4) +
                          (acc_kij / 3) * 6 + (acc_kij % 3);

    // Per-column address computation
    // idx[k] = acc_kij * 36 + ((psum_nij_cur + 36 - (5 - k)) % 36)
    //        = acc_kij * 36 + ((psum_nij_cur + 31 + k) % 36)
    wire [8:0] psum_addr_col [0:COL-1];

    genvar gc;
    generate
        for (gc = 0; gc < COL; gc = gc + 1) begin : addr_gen
            // Reference formula: idx[k] = acc_kij * 36 + ((psum_nij_cur + 36 - (5 - k)) % 36)
            //                           = acc_kij * 36 + ((psum_nij_cur + 31 + k) % 36)
            // Adjusted by -1 to account for OFIFO capture starting at entry 3 instead of entry 2
            // So we use (30 + gc) instead of (31 + gc)
            assign psum_addr_col[gc] = acc_kij * LEN_NIJ + ((psum_nij_cur + 30 + gc) % LEN_NIJ);
        end
    endgenerate

    // Current column's address (explicit mux to avoid array indexing issues)
    reg [8:0] psum_addr_cur;
    always @(*) begin
        case (acc_col)
            3'd0: psum_addr_cur = psum_addr_col[0];
            3'd1: psum_addr_cur = psum_addr_col[1];
            3'd2: psum_addr_cur = psum_addr_col[2];
            3'd3: psum_addr_cur = psum_addr_col[3];
            3'd4: psum_addr_cur = psum_addr_col[4];
            3'd5: psum_addr_cur = psum_addr_col[5];
            3'd6: psum_addr_cur = psum_addr_col[6];
            3'd7: psum_addr_cur = psum_addr_col[7];
            default: psum_addr_cur = psum_addr_col[0];
        endcase
    end

    // Loop variables
    integer i, k;

    // ReLU computation wires (combinational)
    wire signed [PSUM_BW-1:0] relu_in [0:LEN_ONIJ-1][0:COL-1];
    wire [PSUM_BW-1:0] relu_result [0:LEN_ONIJ-1][0:COL-1];

    // Generate ReLU logic for all outputs
    genvar gi, gj;
    generate
        for (gi = 0; gi < LEN_ONIJ; gi = gi + 1) begin : relu_out_gen
            for (gj = 0; gj < COL; gj = gj + 1) begin : relu_col_gen
                assign relu_in[gi][gj] = out_regs[gi][gj*PSUM_BW +: PSUM_BW];
                assign relu_result[gi][gj] = (relu_in[gi][gj][PSUM_BW-1]) ? {PSUM_BW{1'b0}} : relu_in[gi][gj];
            end
        end
    endgenerate

    // =========================================================================
    // Weight BRAM Initialization
    // =========================================================================
    initial begin
        $readmemb("../data/weight_0.mem", weight_bram, 0, 7);
        $readmemb("../data/weight_1.mem", weight_bram, 8, 15);
        $readmemb("../data/weight_2.mem", weight_bram, 16, 23);
        $readmemb("../data/weight_3.mem", weight_bram, 24, 31);
        $readmemb("../data/weight_4.mem", weight_bram, 32, 39);
        $readmemb("../data/weight_5.mem", weight_bram, 40, 47);
        $readmemb("../data/weight_6.mem", weight_bram, 48, 55);
        $readmemb("../data/weight_7.mem", weight_bram, 56, 63);
        $readmemb("../data/weight_8.mem", weight_bram, 64, 71);
    end

    // =========================================================================
    // PSUM BRAM Instance
    // =========================================================================
    psum_bram #(
        .DATA_WIDTH(128),
        .ADDR_WIDTH(9),
        .DEPTH(324)
    ) psum_bram_inst (
        .clk(s_axi_aclk),
        .we_a(psum_we),
        .addr_a(psum_waddr),
        .din_a(psum_wdata),
        .en_b(psum_re),
        .addr_b(psum_raddr),
        .dout_b(psum_rdata)
    );

    // =========================================================================
    // Core Instance
    // =========================================================================
    core #(
        .bw(BW),
        .psum_bw(PSUM_BW),
        .col(COL),
        .row(ROW)
    ) core_inst (
        .clk(s_axi_aclk),
        .reset(core_reset),
        .inst(inst),
        .D_xmem(D_xmem),
        .sfp_out(sfp_out),
        .ofifo_out_port(ofifo_out),
        .ofifo_valid(ofifo_valid)
    );

    // =========================================================================
    // AXI-Lite Interface
    // =========================================================================

    // Write address ready
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_awready <= 1'b0;
        end else begin
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awready <= 1'b1;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // Write address latch
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_awaddr <= 0;
        end else begin
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awaddr <= s_axi_awaddr;
            end
        end
    end

    // Write data ready
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && s_axi_wvalid && s_axi_awvalid) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // Write response
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b0;
        end else begin
            if (axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b0; // OKAY
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // Read address ready
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_arready <= 1'b0;
            axi_araddr <= 0;
        end else begin
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
                axi_araddr <= s_axi_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // Read data valid
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_rvalid <= 1'b0;
            axi_rresp <= 2'b0;
        end else begin
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b0; // OKAY
            end else if (axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // Register write
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            ctrl_reg <= 32'h0;
            for (i = 0; i < LEN_NIJ; i = i + 1) begin
                act_regs[i] <= 32'h0;
            end
        end else begin
            // Clear start bit when FSM leaves IDLE
            if (state != S_IDLE && ctrl_reg[0]) begin
                ctrl_reg[0] <= 1'b0;
            end

            // AXI write
            if (axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid) begin
                case (axi_awaddr[11:2])
                    10'd0: ctrl_reg <= s_axi_wdata;  // CTRL
                    default: begin
                        // Activation registers: 0x008-0x094 (addresses 2-37)
                        if (axi_awaddr >= ADDR_ACT_BASE && axi_awaddr < ADDR_ACT_END) begin
                            act_regs[(axi_awaddr - ADDR_ACT_BASE) >> 2] <= s_axi_wdata;
                        end
                    end
                endcase
            end
        end
    end

    // Register read
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axi_rdata <= 0;
        end else begin
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                case (axi_araddr[11:2])
                    10'd0: axi_rdata <= {28'b0,
                                         (state == S_IDLE), // [2] idle
                                         (state == S_DONE), // [1] done
                                         ctrl_reg[0]};       // [0] start
                    10'd1: axi_rdata <= {16'b0, kij[3:0], 4'b0, state};  // STATUS
                    default: begin
                        // Output registers: 0x100-0x1FC (16 x 128-bit = 64 x 32-bit)
                        if (axi_araddr >= ADDR_OUT_BASE && axi_araddr <= ADDR_OUT_END) begin
                            // Each 128-bit output spans 4 addresses
                            out_idx = (axi_araddr - ADDR_OUT_BASE) >> 4;  // Divide by 16
                            word_idx = (axi_araddr - ADDR_OUT_BASE) >> 2;  // Which 32-bit word
                            case (word_idx[1:0])
                                2'd0: axi_rdata <= out_regs[out_idx][31:0];
                                2'd1: axi_rdata <= out_regs[out_idx][63:32];
                                2'd2: axi_rdata <= out_regs[out_idx][95:64];
                                2'd3: axi_rdata <= out_regs[out_idx][127:96];
                            endcase
                        end else begin
                            axi_rdata <= 32'hDEADBEEF;
                        end
                    end
                endcase
            end
        end
    end

    // AXI output assignments
    assign s_axi_awready = axi_awready;
    assign s_axi_wready = axi_wready;
    assign s_axi_bresp = axi_bresp;
    assign s_axi_bvalid = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata = axi_rdata;
    assign s_axi_rresp = axi_rresp;
    assign s_axi_rvalid = axi_rvalid;

    // =========================================================================
    // Start pulse detection
    // =========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            start_d <= 1'b0;
        else
            start_d <= ctrl_reg[0];
    end
    assign start_pulse = ctrl_reg[0] && !start_d;

    // =========================================================================
    // Instruction assembly
    // =========================================================================
    always @(*) begin
        inst = {acc_en, CEN_pmem, WEN_pmem, A_pmem,
                CEN_xmem, WEN_xmem, A_xmem,
                ofifo_rd, ififo_wr, ififo_rd, l0_rd, l0_wr, execute, load};
    end

    // =========================================================================
    // Main FSM
    // =========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start_pulse)
                    next_state = S_RESET_CORE;
            end

            S_RESET_CORE: begin
                if (counter >= 10)
                    next_state = S_LOAD_ACT_XMEM;
            end

            S_LOAD_ACT_XMEM: begin
                if (counter >= LEN_NIJ - 1)
                    next_state = S_WAIT_ACT;
            end

            S_WAIT_ACT: begin
                next_state = S_KIJ_RESET;
            end

            S_KIJ_RESET: begin
                if (counter >= 10)
                    next_state = S_LOAD_W_XMEM;
            end

            S_LOAD_W_XMEM: begin
                if (counter >= COL - 1)
                    next_state = S_WAIT_W_XMEM;
            end

            S_WAIT_W_XMEM: begin
                next_state = S_LOAD_W_L0_PRIME;
            end

            S_LOAD_W_L0_PRIME: begin
                next_state = S_LOAD_W_L0;
            end

            S_LOAD_W_L0: begin
                if (counter >= COL - 1)
                    next_state = S_LOAD_W_L0_LAST;
            end

            S_LOAD_W_L0_LAST: begin
                next_state = S_LOAD_W_PE;
            end

            S_LOAD_W_PE: begin
                if (counter >= COL - 1)
                    next_state = S_LOAD_W_PE_PROP;
            end

            S_LOAD_W_PE_PROP: begin
                if (counter >= COL + 3)  // Extra cycles for propagation
                    next_state = S_INTERMISSION;
            end

            S_INTERMISSION: begin
                if (counter >= 10)
                    next_state = S_LOAD_A_L0;
            end

            S_LOAD_A_L0: begin
                if (counter >= LEN_NIJ - 1)
                    next_state = S_WAIT_A_L0;
            end

            S_WAIT_A_L0: begin
                next_state = S_EXECUTE;
            end

            S_EXECUTE: begin
                if (counter >= LEN_NIJ - 1)
                    next_state = S_DRAIN;
            end

            S_DRAIN: begin
                // Drain for ROW+COL+1 cycles to ensure exactly 36 OFIFO entries
                // Empirically tuned to match reference testbench output
                if (counter >= ROW + COL + 1)
                    next_state = S_WAIT_DRAIN;
            end

            S_WAIT_DRAIN: begin
                // Wait for all column FIFOs to have data (ofifo_valid)
                // Then wait for output to stabilize
                if (ofifo_valid && counter >= 3)
                    next_state = S_OFIFO_PRIME;
            end

            S_OFIFO_PRIME: begin
                // Prime phase: assert ofifo_rd but don't capture yet
                // With 3 prime cycles (counter 0,1,2), we capture starting from FIFO entry 3
                // Reference TB captures starting from entry 2, so we adjusted the accumulation
                // formula by -1 (30 + gc instead of 31 + gc) to compensate
                if (counter >= 2)
                    next_state = S_OFIFO_READ;
            end

            S_OFIFO_READ: begin
                // Need to write 36 entries (0-35). Counter runs 0→35 (36 cycles).
                // Transition when counter reaches 36 to allow write at counter=35
                if (counter >= LEN_NIJ)
                    next_state = S_OFIFO_DONE;
            end

            S_OFIFO_DONE: begin
                next_state = S_NEXT_KIJ;
            end

            S_NEXT_KIJ: begin
                if (kij >= LEN_KIJ - 1)
                    next_state = S_ACC_INIT;
                else
                    next_state = S_KIJ_RESET;
            end

            // Sequential accumulation states
            // Loop: For each o_nij -> For each kij -> For each col -> read and accumulate
            S_ACC_INIT: begin
                // Initialize accumulators, prepare first read for col=0, kij=0
                next_state = S_ACC_READ;
            end

            S_ACC_READ: begin
                // Issue BRAM read, transition to WAIT state
                next_state = S_ACC_WAIT;
            end

            S_ACC_WAIT: begin
                // Wait for BRAM read latency (1 cycle)
                next_state = S_ACC_ADD;
            end

            S_ACC_ADD: begin
                // Add BRAM data to accumulator for current column
                // Move to next column, or next kij, or next output
                if (acc_col >= COL - 1) begin
                    // Done with all columns for this kij
                    if (acc_kij >= LEN_KIJ - 1) begin
                        // Done with all kij for this output
                        next_state = S_ACC_STORE;
                    end else begin
                        // Move to next kij, reset col
                        next_state = S_ACC_READ;
                    end
                end else begin
                    // Move to next column
                    next_state = S_ACC_READ;
                end
            end

            S_ACC_STORE: begin
                // Store accumulated result, move to next output
                if (acc_o_nij >= LEN_ONIJ - 1) begin
                    next_state = S_RELU;
                end else begin
                    next_state = S_ACC_INIT;
                end
            end

            S_RELU: begin
                next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // =========================================================================
    // FSM Outputs, Counter, and PSUM BRAM Control
    // =========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            counter <= 0;
            kij <= 0;
            core_reset <= 1;
            D_xmem <= 0;
            A_xmem <= 0;
            CEN_xmem <= 1;
            WEN_xmem <= 1;
            A_pmem <= 0;
            CEN_pmem <= 1;
            WEN_pmem <= 1;
            acc_en <= 0;
            ofifo_rd <= 0;
            ififo_wr <= 0;
            ififo_rd <= 0;
            l0_rd <= 0;
            l0_wr <= 0;
            execute <= 0;
            load <= 0;
            psum_we <= 0;
            psum_waddr <= 0;
            psum_wdata <= 0;
            psum_re <= 0;
            psum_raddr <= 0;
            acc_o_nij <= 0;
            acc_kij <= 0;
            acc_col <= 0;
            acc_read_valid <= 0;
            acc_cols[0] <= 0;
            acc_cols[1] <= 0;
            acc_cols[2] <= 0;
            acc_cols[3] <= 0;
            acc_cols[4] <= 0;
            acc_cols[5] <= 0;
            acc_cols[6] <= 0;
            acc_cols[7] <= 0;
        end else begin
            // Default values
            core_reset <= 0;
            CEN_xmem <= 1;
            WEN_xmem <= 1;
            CEN_pmem <= 1;
            WEN_pmem <= 1;
            ofifo_rd <= 0;
            l0_wr <= 0;
            l0_rd <= 0;
            execute <= 0;
            load <= 0;
            psum_we <= 0;
            psum_re <= 0;
            acc_read_valid <= 0;

            case (state)
                S_IDLE: begin
                    counter <= 0;
                    kij <= 0;
                    acc_o_nij <= 0;
                    acc_kij <= 0;
                    acc_col <= 0;
                    if (start_pulse) begin
                        core_reset <= 1;
                    end
                end

                S_RESET_CORE: begin
                    core_reset <= 1;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                        core_reset <= 0;
                    end
                end

                S_LOAD_ACT_XMEM: begin
                    // Write activations to XMEM
                    CEN_xmem <= 0;
                    WEN_xmem <= 0;
                    A_xmem <= counter;
                    D_xmem <= act_regs[counter];
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_WAIT_ACT: begin
                    // One cycle wait
                end

                S_KIJ_RESET: begin
                    // Reset between kernel iterations
                    core_reset <= 1;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                        core_reset <= 0;
                    end
                end

                S_LOAD_W_XMEM: begin
                    // Write transposed weights to XMEM at address 0x400+
                    CEN_xmem <= 0;
                    WEN_xmem <= 0;
                    A_xmem <= 11'b10000000000 + counter;  // Start at 1024
                    D_xmem <= weight_bram[kij * 8 + counter];
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_WAIT_W_XMEM: begin
                    A_xmem <= 11'b10000000000;  // Prepare for read
                end

                S_LOAD_W_L0_PRIME: begin
                    // Prime XMEM read
                    CEN_xmem <= 0;
                    WEN_xmem <= 1;
                    l0_wr <= 0;
                    A_xmem <= 11'b10000000000;
                end

                S_LOAD_W_L0: begin
                    // Read from XMEM, write to L0
                    CEN_xmem <= 0;
                    WEN_xmem <= 1;
                    l0_wr <= 1;
                    A_xmem <= 11'b10000000000 + counter + 1;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_LOAD_W_L0_LAST: begin
                    // One more L0 write to capture last data
                    l0_wr <= 1;
                    CEN_xmem <= 1;
                    A_xmem <= 0;
                end

                S_LOAD_W_PE: begin
                    // Load weights into PEs
                    load <= 1;
                    l0_rd <= 1;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_LOAD_W_PE_PROP: begin
                    // Let load propagate through columns
                    load <= 1;
                    l0_rd <= 0;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_INTERMISSION: begin
                    // Clear up kernel loading
                    load <= 0;
                    l0_rd <= 0;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                        A_xmem <= 0;
                    end
                end

                S_LOAD_A_L0: begin
                    // Load activations from XMEM to L0
                    CEN_xmem <= 0;
                    WEN_xmem <= 1;
                    l0_wr <= 1;
                    A_xmem <= counter;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_WAIT_A_L0: begin
                    l0_wr <= 0;
                end

                S_EXECUTE: begin
                    // Execute MAC operations
                    execute <= 1;
                    l0_rd <= 1;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_DRAIN: begin
                    // Drain pipeline
                    execute <= 1;
                    l0_rd <= 0;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_WAIT_DRAIN: begin
                    execute <= 0;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_OFIFO_PRIME: begin
                    // Prime OFIFO read pipeline - assert rd to start reading
                    // Wait for FIFO output to become valid (rd_en latency + output latency)
                    ofifo_rd <= 1;  // Start reading to propagate rd_en
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_OFIFO_READ: begin
                    // Read partial sums and write to BRAM
                    ofifo_rd <= 1;
                    psum_we <= 1;
                    psum_waddr <= kij * LEN_NIJ + counter;
                    psum_wdata <= ofifo_out;
                    counter <= counter + 1;
                    if (next_state != state) begin
                        counter <= 0;
                    end
                end

                S_OFIFO_DONE: begin
                    ofifo_rd <= 0;
                end

                S_NEXT_KIJ: begin
                    if (kij < LEN_KIJ - 1) begin
                        kij <= kij + 1;
                    end
                end

                // Sequential accumulation
                // Loop: For each o_nij -> For each kij -> For each col -> read and accumulate
                S_ACC_INIT: begin
                    // Initialize accumulators for this output position
                    acc_cols[0] <= 0;
                    acc_cols[1] <= 0;
                    acc_cols[2] <= 0;
                    acc_cols[3] <= 0;
                    acc_cols[4] <= 0;
                    acc_cols[5] <= 0;
                    acc_cols[6] <= 0;
                    acc_cols[7] <= 0;
                    acc_kij <= 0;
                    acc_col <= 0;
                    // Don't issue read here - S_ACC_READ will do it
                end

                S_ACC_READ: begin
                    // Issue BRAM read and wait for latency
                    // psum_addr_cur is computed combinationally from current acc_kij, acc_col
                    psum_re <= 1;
                    psum_raddr <= psum_addr_cur;
                    acc_read_valid <= 0;  // Data not valid yet
                end

                S_ACC_WAIT: begin
                    // Wait for BRAM read latency (1 cycle)
                    // Keep read enabled, data will be valid on next clock edge
                    psum_re <= 1;
                    psum_raddr <= psum_addr_cur;  // Hold address stable
                end

                S_ACC_ADD: begin
                    // Add current column's data from BRAM to accumulator
                    // Extract only column acc_col from the 128-bit word
                    case (acc_col)
                        3'd0: acc_cols[0] <= acc_cols[0] + $signed(psum_rdata[0*PSUM_BW +: PSUM_BW]);
                        3'd1: acc_cols[1] <= acc_cols[1] + $signed(psum_rdata[1*PSUM_BW +: PSUM_BW]);
                        3'd2: acc_cols[2] <= acc_cols[2] + $signed(psum_rdata[2*PSUM_BW +: PSUM_BW]);
                        3'd3: acc_cols[3] <= acc_cols[3] + $signed(psum_rdata[3*PSUM_BW +: PSUM_BW]);
                        3'd4: acc_cols[4] <= acc_cols[4] + $signed(psum_rdata[4*PSUM_BW +: PSUM_BW]);
                        3'd5: acc_cols[5] <= acc_cols[5] + $signed(psum_rdata[5*PSUM_BW +: PSUM_BW]);
                        3'd6: acc_cols[6] <= acc_cols[6] + $signed(psum_rdata[6*PSUM_BW +: PSUM_BW]);
                        3'd7: acc_cols[7] <= acc_cols[7] + $signed(psum_rdata[7*PSUM_BW +: PSUM_BW]);
                    endcase

                    // Update indices (read happens in S_ACC_READ)
                    if (acc_col >= COL - 1) begin
                        // Done with all columns for this kij
                        acc_col <= 0;
                        if (acc_kij < LEN_KIJ - 1) begin
                            // Move to next kij
                            acc_kij <= acc_kij + 1;
                        end
                    end else begin
                        // Move to next column
                        acc_col <= acc_col + 1;
                    end
                end

                S_ACC_STORE: begin
                    // Store accumulated result to output register
                    out_regs[acc_o_nij] <= {acc_cols[7], acc_cols[6], acc_cols[5], acc_cols[4],
                                            acc_cols[3], acc_cols[2], acc_cols[1], acc_cols[0]};

                    // Move to next output position
                    if (acc_o_nij < LEN_ONIJ - 1) begin
                        acc_o_nij <= acc_o_nij + 1;
                    end
                end

                S_RELU: begin
                    // Apply ReLU to all outputs using generated combinational logic
                    out_regs[0]  <= {relu_result[0][7], relu_result[0][6], relu_result[0][5], relu_result[0][4],
                                     relu_result[0][3], relu_result[0][2], relu_result[0][1], relu_result[0][0]};
                    out_regs[1]  <= {relu_result[1][7], relu_result[1][6], relu_result[1][5], relu_result[1][4],
                                     relu_result[1][3], relu_result[1][2], relu_result[1][1], relu_result[1][0]};
                    out_regs[2]  <= {relu_result[2][7], relu_result[2][6], relu_result[2][5], relu_result[2][4],
                                     relu_result[2][3], relu_result[2][2], relu_result[2][1], relu_result[2][0]};
                    out_regs[3]  <= {relu_result[3][7], relu_result[3][6], relu_result[3][5], relu_result[3][4],
                                     relu_result[3][3], relu_result[3][2], relu_result[3][1], relu_result[3][0]};
                    out_regs[4]  <= {relu_result[4][7], relu_result[4][6], relu_result[4][5], relu_result[4][4],
                                     relu_result[4][3], relu_result[4][2], relu_result[4][1], relu_result[4][0]};
                    out_regs[5]  <= {relu_result[5][7], relu_result[5][6], relu_result[5][5], relu_result[5][4],
                                     relu_result[5][3], relu_result[5][2], relu_result[5][1], relu_result[5][0]};
                    out_regs[6]  <= {relu_result[6][7], relu_result[6][6], relu_result[6][5], relu_result[6][4],
                                     relu_result[6][3], relu_result[6][2], relu_result[6][1], relu_result[6][0]};
                    out_regs[7]  <= {relu_result[7][7], relu_result[7][6], relu_result[7][5], relu_result[7][4],
                                     relu_result[7][3], relu_result[7][2], relu_result[7][1], relu_result[7][0]};
                    out_regs[8]  <= {relu_result[8][7], relu_result[8][6], relu_result[8][5], relu_result[8][4],
                                     relu_result[8][3], relu_result[8][2], relu_result[8][1], relu_result[8][0]};
                    out_regs[9]  <= {relu_result[9][7], relu_result[9][6], relu_result[9][5], relu_result[9][4],
                                     relu_result[9][3], relu_result[9][2], relu_result[9][1], relu_result[9][0]};
                    out_regs[10] <= {relu_result[10][7], relu_result[10][6], relu_result[10][5], relu_result[10][4],
                                     relu_result[10][3], relu_result[10][2], relu_result[10][1], relu_result[10][0]};
                    out_regs[11] <= {relu_result[11][7], relu_result[11][6], relu_result[11][5], relu_result[11][4],
                                     relu_result[11][3], relu_result[11][2], relu_result[11][1], relu_result[11][0]};
                    out_regs[12] <= {relu_result[12][7], relu_result[12][6], relu_result[12][5], relu_result[12][4],
                                     relu_result[12][3], relu_result[12][2], relu_result[12][1], relu_result[12][0]};
                    out_regs[13] <= {relu_result[13][7], relu_result[13][6], relu_result[13][5], relu_result[13][4],
                                     relu_result[13][3], relu_result[13][2], relu_result[13][1], relu_result[13][0]};
                    out_regs[14] <= {relu_result[14][7], relu_result[14][6], relu_result[14][5], relu_result[14][4],
                                     relu_result[14][3], relu_result[14][2], relu_result[14][1], relu_result[14][0]};
                    out_regs[15] <= {relu_result[15][7], relu_result[15][6], relu_result[15][5], relu_result[15][4],
                                     relu_result[15][3], relu_result[15][2], relu_result[15][1], relu_result[15][0]};
                end

                S_DONE: begin
                    // Stay here until back to IDLE
                end
            endcase
        end
    end

endmodule
