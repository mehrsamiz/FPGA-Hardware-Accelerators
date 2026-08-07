`include "TripleDES_enc.v"

module TopMode(
  input wire clk,
  input wire nrst,
  input wire start,
  input wire [1:0] mode,
  input wire [255:0] data_in,
  input wire [127:0] key,
  input wire [63:0] iv,
  output reg [255:0] data_out,
  output reg done,
  output reg busy
);

  reg [1:0] state;
  reg [1:0] blk_cnt;
  reg [255:0] out_buf;
  reg [63:0] fb;
  reg [127:0] key_reg;
  reg [63:0] iv_reg;
  reg [1:0] mode_reg;

  localparam IDLE    = 2'b00,
             PROCESS = 2'b01,
             DONE    = 2'b10;

  // Extract 64‑bit blocks as 64‑bit numbers (big‑endian, MSB first)
  reg [63:0] plain_blocks [0:3];
  reg [63:0] K1_val, K2_val;

  always @(*) begin
    plain_blocks[0] = data_in[255:192];
    plain_blocks[1] = data_in[191:128];
    plain_blocks[2] = data_in[127:64];
    plain_blocks[3] = data_in[63:0];
    K1_val = key_reg[127:64];
    K2_val = key_reg[63:0];
  end

  // Map 64‑bit numbers directly to DES [64:1] (MSB -> bit 64)
  wire [64:1] cur_plain, K1, K2;
  assign cur_plain = plain_blocks[blk_cnt];
  assign K1 = K1_val;
  assign K2 = K2_val;

  // Triple DES cores
  wire [64:1] cur_cipher, keystream, cbc_out;
  TripleDES_enc tde_enc(cur_plain, K1, K2, cur_cipher);
  TripleDES_enc tde_keystream(fb, K1, K2, keystream);
  wire [64:1] cbc_input = cur_plain ^ fb;
  TripleDES_enc tde_cbc(cbc_input, K1, K2, cbc_out);

  wire [64:1] ofb_out = cur_plain ^ keystream;
  wire [64:1] ecb_out = cur_cipher;
  wire [64:1] result_cipher;
  assign result_cipher = (mode_reg == 2'b00) ? ecb_out :
                         (mode_reg == 2'b01) ? cbc_out : ofb_out;

  wire [63:0] next_fb = (mode_reg == 2'b01) ? result_cipher :
                        (mode_reg == 2'b10) ? keystream : 64'b0;

  // Map DES output [64:1] back to 64‑bit number (MSB at bit 63)
  wire [63:0] out_seg;
  assign out_seg = result_cipher;

  // FSM
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      state <= IDLE;
      busy <= 0;
      done <= 0;
      out_buf <= 0;
      blk_cnt <= 0;
      fb <= 0;
      key_reg <= 0;
      iv_reg <= 0;
      mode_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            key_reg <= key;
            iv_reg <= iv;
            mode_reg <= mode;
            busy <= 1;
            done <= 0;
            blk_cnt <= 0;
            if (mode == 2'b01 || mode == 2'b10) fb <= iv;
            else fb <= 0;
            out_buf <= 0;
            state <= PROCESS;
          end
        end
        PROCESS: begin
          case (blk_cnt)
            2'b00: out_buf[255:192] <= out_seg;
            2'b01: out_buf[191:128] <= out_seg;
            2'b10: out_buf[127:64]  <= out_seg;
            2'b11: out_buf[63:0]    <= out_seg;
          endcase
          fb <= next_fb;
          if (blk_cnt == 2'b11) state <= DONE;
          else blk_cnt <= blk_cnt + 1;
        end
        DONE: begin
          done <= 1;
          busy <= 0;
          data_out <= out_buf;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule