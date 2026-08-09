`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter ADDRESS    = 32,
    parameter DATA_WIDTH = 32
)(
    // Global Signals
    input  wire                  ACLK,
    input  wire                  ARESETN,

    // Read Address Channel INPUTS
    input  wire [ADDRESS-1:0]    S_ARADDR,
    input  wire                  S_ARVALID,
    // Read Data Channel INPUTS
    input  wire                  S_RREADY,
    // Write Address Channel INPUTS
    input  wire [ADDRESS-1:0]    S_AWADDR,
    input  wire                  S_AWVALID,
    // Write Data Channel INPUTS
    input  wire [DATA_WIDTH-1:0] S_WDATA,
    input  wire [3:0]            S_WSTRB,
    input  wire                  S_WVALID,
    // Write Response Channel INPUTS
    input  wire                  S_BREADY,   

    // Read Address Channel OUTPUTS
    output wire                  S_ARREADY,
    // Read Data Channel OUTPUTS
    output wire [DATA_WIDTH-1:0] S_RDATA,
    output wire [1:0]            S_RRESP,
    output wire                  S_RVALID,
    // Write Address Channel OUTPUTS
    output wire                  S_AWREADY,
    output wire                  S_WREADY,
    // Write Response Channel OUTPUTS
    output wire [1:0]            S_BRESP,
    output wire                  S_BVALID,
    output wire                  ledout
);

    localparam REG_NUM       = 33; // Regs 0..31 (Data), Reg 32 (Start Pulse)
    localparam IDLE          = 0;
    localparam WRITE_CHANNEL = 1;
    localparam WRESP_CHANNEL = 2;
    localparam RADDR_CHANNEL = 3;
    localparam RDATA_CHANNEL = 4;
   
    reg  [DATA_WIDTH-1 : 0] register [0 : REG_NUM-1];
    reg  [ADDRESS-1 : 0]    read_addr;
    reg  [ADDRESS-1 : 0]    write_addr_latched;
    
    reg  aw_done, w_done;
    
    wire [ADDRESS-1 : 0] S_ARADDR_T = S_ARADDR[8 : 2];
    wire [ADDRESS-1 : 0] S_AWADDR_T = S_AWADDR[8 : 2];
    
    // Pulse derived from Bit 0 of register 32
    wire start = register[32][0]; 
    
    // Core Outputs from conv_axi_adaptor
    wire        busy;
    wire        done;
    wire [5:0]  x7, y7;
    wire signed [23:0] val7;
    wire [5:0]  x8, y8;
    wire signed [23:0] val8;

    reg  [2:0] state, next_state;

    // Pack data registers 0..31 into a flat 1024-bit vector
    wire [1023:0] reg_flat;
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : PACK_REGS
            assign reg_flat[(gi * 32) +: 32] = register[gi];
        end
    endgenerate

    // Read Handshakes
    assign S_ARREADY = (state == RADDR_CHANNEL);
    assign S_RVALID  = (state == RDATA_CHANNEL);
    
    // Extended Read MUX (Registers 33 to 40)
    assign S_RDATA   = (state == RDATA_CHANNEL) ? 
                        ((read_addr == 33) ? {31'd0, done} :
                        ((read_addr == 34) ? {31'd0, busy} :
                        ((read_addr == 35) ? {26'd0, x7} :
                        ((read_addr == 36) ? {26'd0, y7} :
                        ((read_addr == 37) ? {{8{val7[23]}}, val7} :
                        ((read_addr == 38) ? {26'd0, x8} :
                        ((read_addr == 39) ? {26'd0, y8} :
                        ((read_addr == 40) ? {{8{val8[23]}}, val8} :
                        (read_addr < 33)   ? register[read_addr] : 32'd0)))))))) : 32'd0;

    assign S_RRESP   = 2'b00; 
    
    // Write Handshakes - Assert READY until phase completes
    assign S_AWREADY = (state == WRITE_CHANNEL) && !aw_done;
    assign S_WREADY  = (state == WRITE_CHANNEL) && !w_done;
    
    assign S_BVALID  = (state == WRESP_CHANNEL);
    assign S_BRESP   = 2'b00; 

    integer i;
    reg [31:0] cntr;

    always @(posedge ACLK) begin
        if (~ARESETN) begin
            state              <= IDLE;
            cntr               <= 32'd0;
            aw_done            <= 1'b0;
            w_done             <= 1'b0;
            write_addr_latched <= {ADDRESS{1'b0}};
            read_addr          <= {ADDRESS{1'b0}};
            for (i = 0; i < REG_NUM; i = i + 1) begin
                register[i] <= 32'd0;
            end
        end else begin
            cntr  <= cntr + 1'b1;
            state <= next_state;
            
            // Auto-clear start pulse register
            register[32] <= 32'd0;

            if (state == WRITE_CHANNEL) begin
                if (S_AWVALID && S_AWREADY) begin
                    aw_done            <= 1'b1;
                    write_addr_latched <= S_AWADDR_T;
                end
                if (S_WVALID && S_WREADY) begin
                    w_done <= 1'b1;
                end
                
                // Write to register once address and data have both arrived
                if ((S_AWVALID || aw_done) && (S_WVALID || w_done)) begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if ((aw_done ? write_addr_latched : S_AWADDR_T) < REG_NUM)
                        register[aw_done ? write_addr_latched : S_AWADDR_T] <= S_WDATA;
                end
            end else begin
                aw_done <= 1'b0;
                w_done  <= 1'b0;
            end

            if (state == RADDR_CHANNEL) begin
                read_addr <= S_ARADDR_T;
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (S_AWVALID || S_WVALID)
                    next_state = WRITE_CHANNEL;
                else if (S_ARVALID)
                    next_state = RADDR_CHANNEL;
                else
                    next_state = IDLE;
            end
            RADDR_CHANNEL : if (S_ARVALID && S_ARREADY) next_state = RDATA_CHANNEL;
            RDATA_CHANNEL : if (S_RVALID  && S_RREADY)  next_state = IDLE;
            WRITE_CHANNEL : if ((S_AWVALID || aw_done) && (S_WVALID || w_done)) next_state = WRESP_CHANNEL;
            WRESP_CHANNEL : if (S_BVALID  && S_BREADY)  next_state = IDLE;
            default       : next_state = IDLE;
        endcase
    end
  
    // Convolution Adaptor Controller Instance
    conv_axi_adaptor #(
        .BURST_REGS(32),
        .IMG_BYTES(4096)
    ) u_conv_ctrl (
        .ACLK     (ACLK),
        .ARESETN  (ARESETN),
        .start    (start),
        .reg_flat (reg_flat),
        .busy     (busy),
        .done     (done),
        .x7       (x7),
        .y7       (y7),
        .val7     (val7),
        .x8       (x8),
        .y8       (y8),
        .val8     (val8)
    );
  
    assign ledout = cntr[25];

endmodule