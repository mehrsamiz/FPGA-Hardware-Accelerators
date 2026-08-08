`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter ADDRESS = 32,
    parameter DATA_WIDTH = 32
) (
    // Global Signals
    input                           ACLK,
    input                           ARESETN,

    // Read Address Channel INPUTS
    input           [ADDRESS-1:0]   S_ARADDR,
    input                           S_ARVALID,
    // Read Data Channel INPUTS
    input                           S_RREADY,
    // Write Address Channel INPUTS
    /* verilator lint_off UNUSED */
    input           [ADDRESS-1:0]   S_AWADDR,
    input                           S_AWVALID,
    // Write Data Channel INPUTS
    input          [DATA_WIDTH-1:0] S_WDATA,
    input          [3:0]            S_WSTRB,
    input                           S_WVALID,
    // Write Response Channel INPUTS
    input                           S_BREADY,   

    // Read Address Channel OUTPUTS
    output                     S_ARREADY,
    // Read Data Channel OUTPUTS
    output     [DATA_WIDTH-1:0]S_RDATA,
    output          [1:0]      S_RRESP,
    output                     S_RVALID,
    // Write Address Channel OUTPUTS
    output                     S_AWREADY,
    output                     S_WREADY,
    // Write Response Channel OUTPUTS
    output          [1:0]      S_BRESP,
    output                     S_BVALID,
    output                     ledout
);

    localparam REG_NUM       = 33; // Register 0-31 for data, 32 for control
    localparam IDLE          = 0;
    localparam WRITE_CHANNEL = 1;
    localparam WRESP_CHANNEL = 2;
    localparam RADDR_CHANNEL = 3;
    localparam RDATA_CHANNEL = 4;
   
    reg  [DATA_WIDTH-1 : 0] register [0 : REG_NUM-1];
    reg  [ADDRESS-1 : 0]    read_addr;
    wire [ADDRESS-1 : 0]    S_ARADDR_T;
    wire [ADDRESS-1 : 0]    S_AWADDR_T;
    wire write_addr;
    wire write_data;
    
    // START signal mapped to Register 32, Bit 0
    wire start = register[32][0]; 
    
    wire done;
    wire [DATA_WIDTH-1 : 0] result_v0;
    wire [DATA_WIDTH-1 : 0] result_v1;
    reg  [2:0] state, next_state;
    
    // Address Read
    assign S_ARREADY = (state == RADDR_CHANNEL) ? 1'b1 : 1'b0;
    
    // Read Data
    assign S_RVALID = (state == RDATA_CHANNEL) ? 1'b1 : 1'b0;
    
    // Memory Map Multiplexer for Reads
    assign S_RDATA  = (state == RDATA_CHANNEL) ? 
                          ((read_addr == 33) ? {31'd0, done} : 
                          ((read_addr == 34) ? result_v0 : 
                          ((read_addr == 35) ? result_v1 : 
                          register[read_addr]))) : 32'd0;

    assign S_RRESP  = (state == RDATA_CHANNEL) ? 2'b00 : 2'b00;
    
    // Address Write
    assign S_AWREADY = (state == WRITE_CHANNEL) ? 1'b1 : 1'b0;
    
    // Data Write
    assign S_WREADY = (state == WRITE_CHANNEL) ? 1'b1 : 1'b0;
    assign write_addr = S_AWVALID && S_AWREADY;
    assign write_data = S_WREADY && S_WVALID;
    
    // Response
    assign S_BVALID = (state == WRESP_CHANNEL) ? 1'b1 : 1'b0;
    assign S_BRESP  = (state == WRESP_CHANNEL) ? 2'b00 : 2'b00;

    assign S_ARADDR_T = S_ARADDR[7 : 2];
    assign S_AWADDR_T = S_AWADDR[7 : 2];
    
    integer i;
    reg [31:0] cntr;
    
    always @(posedge ACLK) begin
        if (~ARESETN) begin
            state <= IDLE;
            cntr <= 0;
            for (i = 0; i < REG_NUM; i = i + 1) begin
                register[i] <= 32'd0;
            end
        end else begin
            cntr <= cntr + 1'b1;
            state <= next_state;
            
            if (state == WRITE_CHANNEL) begin
                if (S_AWADDR_T <= 32) 
                    register[S_AWADDR_T] <= S_WDATA;                  
            end else if (state == RADDR_CHANNEL) begin
                read_addr <= S_ARADDR_T;
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE : begin
                if (S_AWVALID) begin
                    next_state = WRITE_CHANNEL;
                end else if (S_ARVALID) begin
                    next_state = RADDR_CHANNEL;
                end else begin
                    next_state = IDLE;
                end
            end
            RADDR_CHANNEL  : if (S_ARVALID && S_ARREADY) next_state = RDATA_CHANNEL;
            RDATA_CHANNEL  : if (S_RVALID  && S_RREADY)  next_state = IDLE;
            WRITE_CHANNEL  : if (write_addr && write_data) next_state = WRESP_CHANNEL;
            WRESP_CHANNEL  : if (S_BVALID  && S_BREADY)  next_state = IDLE;
            default        : next_state = IDLE;
        endcase
    end
  
    // TEA Engine Instantiation
    tea_core u_tea_engine (
        .clk(ACLK),
        .rst_n(ARESETN),
        .start(start),
        .v0_in(register[0]),   
        .v1_in(register[1]),   
        .k0(register[2]),      
        .k1(register[3]),      
        .k2(register[4]),      
        .k3(register[5]),      
        .v0_out(result_v0),    
        .v1_out(result_v1),    
        .done(done)
    );
  
    assign ledout = cntr[25];
endmodule