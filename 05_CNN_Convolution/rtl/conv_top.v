// =============================================================
// conv_top.v
// Top-level streaming convolution engine, Group 7 (digits 7 & 8).
//
// Consumes one raw grayscale pixel byte per pixel_valid pulse,
// row-major, top-left first (NO 255-x inversion needed -- see
// README). Maintains a 12-row line buffer. For every fully
// buffered 12x64 window, sweeps all 57 column positions, computing
// both kernels' dot products in parallel: 8 taps (one kernel row)
// per clock, 12 clocks per window, +1 "flush" clock to latch the
// result into the max trackers. 13 cycles/window x 57 columns x 53
// rows = ~39.3k cycles/frame -- negligible next to UART transfer
// time, and only ~16 DSP48E1 slices used (out of 80 on XC7Z010).
// =============================================================
module conv_top #(
    parameter IMG_W   = 64,
    parameter IMG_H   = 64,
    parameter KH      = 12,
    parameter KW      = 8,
    parameter PW      = 8,
    parameter WW      = 8,
    parameter ACC_W   = 24,
    parameter COORD_W = 6
)(
    input  wire clk,
    input  wire rst_n,

    // Streaming pixel input from your AXI/UART receive core
    input  wire               frame_start,   // pulse: begin a new 64x64 frame
    input  wire                pixel_valid,
    input  wire [PW-1:0]       pixel_data,
    output wire                pixel_ready,   // low while sweeping a window row (backpressure)

    // Results -- valid and held once 'done' is asserted
    output wire                     done,
    output wire [COORD_W-1:0]       x7, y7,
    output wire signed [ACC_W-1:0]  val7,
    output wire [COORD_W-1:0]       x8, y8,
    output wire signed [ACC_W-1:0]  val8
);

    localparam OUT_W = IMG_W - KW + 1;   // 57

    localparam S_IDLE   = 2'd0,
               S_STREAM = 2'd1,
               S_SWEEP  = 2'd2,
               S_DONE   = 2'd3;

    reg [1:0]  state;
    reg [3:0]  krow;                 // 0..KH (KH == "flush/compare" cycle)
    reg [5:0]  col_sweep;            // 0..OUT_W-1
    reg [COORD_W-1:0] sweep_row_y;
    reg signed [ACC_W-1:0] acc7, acc8;

    // ---------------- line buffer ----------------
    wire row_complete;
    wire [3:0] rows_buffered;
    wire [5:0] cur_img_row;
    wire [KW*PW-1:0] row_slice;

    assign pixel_ready = (state == S_IDLE) || (state == S_STREAM);
    wire lb_wr_en = pixel_valid && pixel_ready;

    line_buffer #(.IMG_W(IMG_W), .KH(KH), .KW(KW), .PW(PW)) u_linebuf (
        .clk(clk), .rst_n(rst_n), .frame_start(frame_start),
        .pixel_wr_en(lb_wr_en), .pixel_in(pixel_data),
        .row_complete(row_complete), .rows_buffered(rows_buffered),
        .cur_img_row(cur_img_row),
        .row_sel(krow), .win_col(col_sweep),
        .row_slice(row_slice)
    );

    // ---------------- kernel ROMs ----------------
    wire signed [KW*WW-1:0] wt7_row, wt8_row;
    kernel_rom #(.KH(KH), .KW(KW), .WW(WW), .HEXFILE("kernel7_neg.hex")) u_krom7 (
        .krow(krow), .wt_row(wt7_row)
    );
    kernel_rom #(.KH(KH), .KW(KW), .WW(WW), .HEXFILE("kernel8_neg.hex")) u_krom8 (
        .krow(krow), .wt_row(wt8_row)
    );

    // ---------------- row MACs ----------------
    wire signed [18:0] part7, part8;
    row_mac8 #(.PW(PW), .WW(WW), .SUM_W(19)) u_mac7 (
        .pix_row(row_slice), .wt_row(wt7_row), .partial_sum(part7)
    );
    row_mac8 #(.PW(PW), .WW(WW), .SUM_W(19)) u_mac8 (
        .pix_row(row_slice), .wt_row(wt8_row), .partial_sum(part8)
    );

    // ---------------- max trackers ----------------
    wire flush = (state == S_SWEEP) && (krow == KH);

    max_tracker #(.ACC_W(ACC_W), .COORD_W(COORD_W)) u_max7 (
        .clk(clk), .rst_n(rst_n), .clear(frame_start),
        .valid(flush), .conv_sum(acc7),
        .cur_x(col_sweep), .cur_y(sweep_row_y),
        .max_val(val7), .max_x(x7), .max_y(y7)
    );
    max_tracker #(.ACC_W(ACC_W), .COORD_W(COORD_W)) u_max8 (
        .clk(clk), .rst_n(rst_n), .clear(frame_start),
        .valid(flush), .conv_sum(acc8),
        .cur_x(col_sweep), .cur_y(sweep_row_y),
        .max_val(val8), .max_x(x8), .max_y(y8)
    );

    assign done = (state == S_DONE);

    // ---------------- control FSM ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            krow        <= 0;
            col_sweep   <= 0;
            sweep_row_y <= 0;
            acc7        <= 0;
            acc8        <= 0;
        end else if (frame_start) begin
            state       <= S_STREAM;
            krow        <= 0;
            col_sweep   <= 0;
            sweep_row_y <= 0;
            acc7        <= 0;
            acc8        <= 0;
        end else begin
            case (state)

                S_IDLE: begin
                    // wait for frame_start
                end

                S_STREAM: begin
                    if (row_complete && (rows_buffered == KH)) begin
                        // a full 12-row window is now available: start sweeping columns
                        sweep_row_y <= cur_img_row - (KH-1);
                        col_sweep   <= 0;
                        krow        <= 0;
                        acc7        <= 0;
                        acc8        <= 0;
                        state       <= S_SWEEP;
                    end
                end

                S_SWEEP: begin
                    if (krow < KH) begin
                        acc7 <= acc7 + part7;
                        acc8 <= acc8 + part8;
                        krow <= krow + 1'b1;
                    end else begin
                        // krow == KH: "flush" cycle -- max_tracker samples acc7/acc8 now
                        acc7 <= 0;
                        acc8 <= 0;
                        krow <= 0;
                        if (col_sweep == OUT_W-1) begin
                            if (cur_img_row == IMG_H-1)
                                state <= S_DONE;
                            else
                                state <= S_STREAM;
                        end else begin
                            col_sweep <= col_sweep + 1'b1;
                        end
                    end
                end

                S_DONE: begin
                    // hold; results are stable on x7,y7,val7,x8,y8,val8
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
