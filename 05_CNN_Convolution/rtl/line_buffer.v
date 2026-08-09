// =============================================================
// line_buffer.v
// Circular 12-row x 64-col line buffer for streaming convolution.
// Stores RAW (non-inverted) 8-bit grayscale pixels as they arrive,
// one byte per clock when pixel_wr_en is asserted. Only the most
// recent KH image rows are kept on-chip (no full-frame storage).
//
// Read port returns one KW-wide (8 pixel) horizontal slice of a
// chosen logical row (row_sel = 0..KH-1; 0 = oldest/top of the
// current window, KH-1 = newest/bottom) starting at column win_col.
// The read is combinational and uses a rotating pointer instead of
// physically shifting 768 bytes every row -- much cheaper on a
// small device like the XC7Z010.
// =============================================================
module line_buffer #(
    parameter IMG_W = 64,
    parameter KH    = 12,
    parameter KW    = 8,
    parameter PW    = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  frame_start,   // pulse: clear buffer, start new frame

    // Streaming pixel write port
    input  wire                  pixel_wr_en,
    input  wire [PW-1:0]         pixel_in,
    output reg                   row_complete,  // 1-cycle pulse: a full IMG_W-pixel row just landed
    output reg  [3:0]            rows_buffered, // saturates at KH
    output reg  [5:0]            cur_img_row,   // image row index of the row that just completed

    // Random-access read port (combinational)
    input  wire [3:0]            row_sel,       // 0..KH-1, logical row within current window
    input  wire [5:0]            win_col,       // 0..IMG_W-KW, base column of the KW-wide slice
    output wire [KW*PW-1:0]      row_slice      // KW packed pixels; row_slice[0+:PW] = leftmost
);

    localparam COLW = 6; // clog2(64)

    // Physical storage: KH rows x IMG_W columns, distributed RAM
    reg [PW-1:0] mem [0:KH-1][0:IMG_W-1];

    reg [3:0]        newest_row_ptr;  // physical index of the most-recently-written row
    reg [3:0]        write_slot;      // physical index currently being filled
    reg [COLW-1:0]   col_cnt;

    // mod-KH helper (KH assumed <= 16)
    function [3:0] mod_kh;
        input [4:0] val;
        begin
            mod_kh = (val >= KH) ? (val - KH) : val[3:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            newest_row_ptr <= KH-1;
            write_slot     <= 0;
            col_cnt        <= 0;
            rows_buffered  <= 0;
            cur_img_row    <= 6'd63;   // wraps to 0 on first completed row
            row_complete   <= 1'b0;
        end else if (frame_start) begin
            newest_row_ptr <= KH-1;
            write_slot     <= 0;
            col_cnt        <= 0;
            rows_buffered  <= 0;
            cur_img_row    <= 6'd63;
            row_complete   <= 1'b0;
        end else begin
            row_complete <= 1'b0;
            if (pixel_wr_en) begin
                mem[write_slot][col_cnt] <= pixel_in;
                if (col_cnt == IMG_W-1) begin
                    col_cnt        <= 0;
                    newest_row_ptr <= write_slot;
                    write_slot     <= mod_kh(write_slot + 5'd1);
                    row_complete   <= 1'b1;
                    cur_img_row    <= cur_img_row + 6'd1;
                    if (rows_buffered < KH)
                        rows_buffered <= rows_buffered + 4'd1;
                end else begin
                    col_cnt <= col_cnt + 1'b1;
                end
            end
        end
    end

    // Combinational window read: logical row_sel -> physical row -> KW pixel slice
    wire [3:0] phys_row = mod_kh(newest_row_ptr + 5'd1 + row_sel);

    genvar j;
    generate
        for (j = 0; j < KW; j = j + 1) begin : GEN_SLICE
            assign row_slice[j*PW +: PW] = mem[phys_row][win_col + j];
        end
    endgenerate

endmodule
