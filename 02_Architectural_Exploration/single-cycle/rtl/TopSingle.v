`include "TripleDES_enc.v"

module TopSingle
#(
    parameter DATA_W = 256,
    parameter OUT_W  = 64 * ((DATA_W + 63) / 64)
)
(
    input  wire clk,
    input  wire nrst,
    input  wire start,
    input  wire [1:0] mode,
    input  wire [DATA_W-1:0] data_in,
    input  wire [127:0] key,
    input  wire [63:0] iv,
    output reg  [OUT_W-1:0] data_out,
    output reg  done,
    output reg  busy
);

    localparam NUM_BLOCKS = (DATA_W + 63) / 64;

    // Internal registers
    reg [OUT_W-1:0] padded_data_reg;
    reg [OUT_W-1:0] out_buf;
    reg [63:0] fb;
    reg [127:0] key_reg;
    reg [1:0] mode_reg;
    reg [1:0] state;
    
    // Counter 
    reg [$clog2(NUM_BLOCKS):0] blk_cnt;

    localparam IDLE    = 2'b00,
               PROCESS = 2'b01,
               DONE    = 2'b10;

    // ==============================
    // Pad data at start and register it
    // ==============================
    wire [OUT_W-1:0] padded_data_wire;
    assign padded_data_wire = {data_in, {(OUT_W-DATA_W){1'b0}}};

    // ==============================
    // Combinational block extraction using registered blk_cnt
    // ==============================
    reg [63:0] cur_block;
    
    integer i;
    always @(*) begin
        cur_block = 64'b0;
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
            if (blk_cnt == i) begin
                cur_block = padded_data_reg[(OUT_W - (i*64) - 1) -: 64];
            end
        end
    end

    wire [64:1] cur_plain = cur_block;
    wire [64:1] K1 = key_reg[127:64];
    wire [64:1] K2 = key_reg[63:0];

    // ==============================
    // Mode Logic (all combinational)
    // ==============================
    wire [64:1] ecb_out, cbc_out, keystream, ofb_out;
    
    // ECB
    TripleDES_enc TDE_ECB(cur_plain, K1, K2, ecb_out);
    
    // CBC
    wire [64:1] cbc_input = cur_plain ^ fb;
    TripleDES_enc TDE_CBC(cbc_input, K1, K2, cbc_out);
    
    // OFB
    TripleDES_enc TDE_OFB(fb, K1, K2, keystream);
    assign ofb_out = cur_plain ^ keystream;

    wire [64:1] result = (mode_reg == 2'b00) ? ecb_out :
                         (mode_reg == 2'b01) ? cbc_out :
                                               ofb_out;

    wire [63:0] out_seg = result;
    
    wire [63:0] next_fb = (mode_reg == 2'b01) ? out_seg :
                          (mode_reg == 2'b10) ? keystream :
                                                64'b0;

    // ==============================
    // FSM
    // ==============================
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            state <= IDLE;
            busy <= 0;
            done <= 0;
            blk_cnt <= 0;
            out_buf <= 0;
            fb <= 0;
            key_reg <= 0;
            mode_reg <= 0;
            padded_data_reg <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    if (start) begin
                        busy <= 1;
                        done <= 0;
                        blk_cnt <= 0;
                        out_buf <= 0;
                        key_reg <= key;
                        mode_reg <= mode;
                        padded_data_reg <= padded_data_wire;  // Register padded data
                        
                        if (mode == 2'b01 || mode == 2'b10)
                            fb <= iv;
                        else
                            fb <= 0;
                            
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    // Store result at correct position
                    out_buf[(OUT_W - (blk_cnt*64) - 1) -: 64] <= out_seg;
                    
                    // Update feedback
                    fb <= next_fb;
                    
                    // Move to next block or finish
                    if (blk_cnt == NUM_BLOCKS-1) begin
                        state <= DONE;
                    end else begin
                        blk_cnt <= blk_cnt + 1;
                    end
                end

                DONE: begin
                    busy <= 0;
                    done <= 1;
                    data_out <= out_buf;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
