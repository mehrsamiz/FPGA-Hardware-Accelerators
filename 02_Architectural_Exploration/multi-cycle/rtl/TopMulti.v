`include "TripleDES_mc.v"
`include "DES_key_schedule_step.v"

module TopMulti
#(
    parameter DATA_W = 256,
    parameter OUT_W  = 64 * ((DATA_W + 63) / 64)
)
(
    input clk,
    input nrst,
    input start,

    input [DATA_W-1:0] data_in,
    input [63:0] key1,
    input [63:0] key2,
    input [63:0] iv,

    input [1:0] mode,   // 00=ECB 01=CBC 10=OFB

    output reg done,
    output reg busy,
    output reg [OUT_W-1:0] data_out
);

localparam NUM_BLOCKS = (DATA_W + 63) / 64;
localparam BLK_CNT_W = (NUM_BLOCKS <= 1) ? 1 : $clog2(NUM_BLOCKS);

reg [2:0] state;
localparam IDLE    = 3'b000,
           LOAD    = 3'b001,
           COMPUTE = 3'b010,
           STORE   = 3'b011,
           DONE_S  = 3'b100;

reg [BLK_CNT_W-1:0] block_idx;
reg engine_start;
wire engine_done;
wire engine_busy;

reg [63:0] engine_in_0based;
wire [63:0] engine_out_0based;
reg [63:0] feedback;
reg [63:0] key1_reg, key2_reg;
reg [63:0] iv_reg;
reg [1:0] mode_reg;
reg [OUT_W-1:0] padded_data;
reg [OUT_W-1:0] out_buf;

// Padding
wire [OUT_W-1:0] padded_data_wire;
assign padded_data_wire = {data_in, {(OUT_W-DATA_W){1'b0}}};

// Convert 0-based to 1-based
wire [1:64] engine_in_1based;
wire [1:64] engine_out_1based;
wire [1:64] key1_1based, key2_1based;

assign engine_in_1based = engine_in_0based;
assign engine_out_0based = engine_out_1based;
assign key1_1based = key1_reg;
assign key2_1based = key2_reg;

// Current block from padded data
wire [63:0] current_block;
assign current_block = padded_data[(OUT_W-1) - (block_idx*64) -: 64];

// TripleDES signals
wire [1:48] round_key;
wire use_key2;
wire decrypt_mode;
wire key_valid;
wire key_req;

TripleDES_mc engine(
    .clk(clk), .nrst(nrst), .start(engine_start),
    .block_in(engine_in_1based),
    .round_key(round_key), .key_valid(key_valid),
    .key_req(key_req), .use_key2(use_key2),
    .decrypt_mode(decrypt_mode),
    .block_out(engine_out_1based),
    .busy(engine_busy), .done(engine_done)
);

DES_key_schedule_step key_sched(
    .clk(clk), .nrst(nrst), .start(key_req),
    .key(use_key2 ? key2_1based : key1_1based),
    .decrypt(decrypt_mode),
    .round_key(round_key), .valid(key_valid),
    .ready(), .done()
);

wire [63:0] engine_input_mux;
assign engine_input_mux = 
    (mode_reg == 2'b00) ? current_block :
    (mode_reg == 2'b01) ? current_block ^ feedback :
                          feedback;

always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
        state <= IDLE;
        block_idx <= 0;
        engine_start <= 0;
        done <= 0;
        busy <= 0;
        feedback <= 0;
        engine_in_0based <= 0;
        key1_reg <= 0;
        key2_reg <= 0;
        iv_reg <= 0;
        mode_reg <= 0;
        padded_data <= 0;
        out_buf <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                done <= 0;
                busy <= 0;
                engine_start <= 0;
                
                if (start) begin
                    key1_reg <= key1;
                    key2_reg <= key2;
                    iv_reg <= iv;
                    mode_reg <= mode;
                    padded_data <= padded_data_wire;
                    block_idx <= 0;
                    out_buf <= 0;
                    
                    if (mode == 2'b01 || mode == 2'b10)
                        feedback <= iv;
                    else
                        feedback <= 0;
                    
                    busy <= 1;
                    state <= LOAD;
                end
            end
            
            LOAD: begin
                engine_in_0based <= engine_input_mux;
                engine_start <= 1;
                $display("Block %0d input: %h", block_idx, engine_input_mux);
                state <= COMPUTE;
            end
            
            COMPUTE: begin
                engine_start <= 0;
                if (engine_done) begin
                    state <= STORE;
                end
            end
            
            STORE: begin
                if (mode_reg == 2'b10)
                    out_buf[(OUT_W-1) - (block_idx*64) -: 64] <= 
                        current_block ^ engine_out_0based;
                else
                    out_buf[(OUT_W-1) - (block_idx*64) -: 64] <= engine_out_0based;
                
                if (mode_reg == 2'b01)
                    feedback <= engine_out_0based;
                else if (mode_reg == 2'b10)
                    feedback <= engine_out_0based;
                
                if (block_idx == NUM_BLOCKS-1) begin
                    state <= DONE_S;
                end
                else begin
                    block_idx <= block_idx + 1;
                    state <= LOAD;
                end
            end
            
            DONE_S: begin
                data_out <= out_buf;
                done <= 1;
                busy <= 0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule