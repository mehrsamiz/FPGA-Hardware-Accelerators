`include "TripleDES_pipe.v"
`include "PC1.v"

module TopPipe #(
    parameter DATA_W = 256,
    parameter OUT_W  = 64 * ((DATA_W + 63) / 64)
)(
    input  wire clk,
    input  wire nrst,
    input  wire start,
    input  wire [DATA_W-1:0] data_in,
    input  wire [127:0] key,
    output wire [OUT_W-1:0] data_out,
    output reg  done,
    output reg  busy,
    output wire ready   // NEW: goes high one cycle before the last block of the
                         // current message is fed, so the caller can issue the
                         // next `start` with zero gap (true back-to-back pipelining)
);

    localparam NUM_BLOCKS = (DATA_W + 63) / 64;
    localparam BLK_W = (NUM_BLOCKS <= 1) ? 1 : $clog2(NUM_BLOCKS);

    // ---------------------------------------------------------------
    // FEED SIDE — independent of collection/draining of previous msg
    // ---------------------------------------------------------------
    reg [OUT_W-1:0] padded_data;
    reg [127:0]     key_reg;
    reg [BLK_W-1:0] feed_idx;
    reg             feeding;
    reg [63:0]      current_block;
    reg             load_block;

    wire [OUT_W-1:0] padded_wire = {data_in, {(OUT_W-DATA_W){1'b0}}};

    // A new message may be accepted as soon as we're idle, OR while the
    // LAST block of the message currently being fed is going out this cycle.
    assign ready = (!feeding) || (feed_idx == NUM_BLOCKS-1);

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            feeding       <= 0;
            feed_idx      <= 0;
            current_block <= 0;
            load_block    <= 0;
            padded_data   <= 0;
            key_reg       <= 0;
        end else begin
            load_block <= 0; // default: pulse

            if (start && ready) begin
                // Covers both "was idle" and "overlapping with tail of
                // previous message's feed" cases.
                key_reg       <= key;
                padded_data   <= padded_wire;
                current_block <= padded_wire[OUT_W-1 -: 64];
                load_block    <= 1;
                feed_idx      <= 0;
                feeding       <= 1;
            end else if (feeding && (feed_idx < NUM_BLOCKS-1)) begin
                feed_idx      <= feed_idx + 1;
                current_block <= padded_data[(OUT_W-1) - ((feed_idx+1)*64) -: 64];
                load_block    <= 1;
            end else if (feeding) begin
                // Last block already issued last cycle, nothing new queued.
                feeding <= 0;
            end
        end
    end

    // ---------------------------------------------------------------
    // Key schedule seeds (PC1) — recomputed only when a new key loads
    // ---------------------------------------------------------------
    wire [63:0] K1 = key_reg[127:64];
    wire [63:0] K2 = key_reg[63:0];

    wire [1:56] pc1_K1, pc1_K2;
    PC1 pc1_K1_u(.in(K1), .out(pc1_K1));
    PC1 pc1_K2_u(.in(K2), .out(pc1_K2));

    wire [27:0] C_K1, D_K1, C_K2, D_K2;
    assign {C_K1, D_K1} = pc1_K1;
    assign {C_K2, D_K2} = pc1_K2;

    // ---------------------------------------------------------------
    // Three chained pipelined DES engines (E_K1 -> D_K2 -> E_K1)
    // ---------------------------------------------------------------
    wire [1:64] eng0_in, eng1_in, eng2_in;
    wire [1:64] eng0_out, eng1_out, eng2_out;
    wire eng0_done, eng1_done, eng2_done;

    assign eng0_in = current_block;
    assign eng1_in = eng0_out;
    assign eng2_in = eng1_out;

    TripleDES_pipe eng0(
        .clk(clk), .nrst(nrst), .start(load_block),
        .block_in(eng0_in), .C_init(C_K1), .D_init(D_K1), .decrypt(1'b0),
        .block_out(eng0_out), .done(eng0_done)
    );

    TripleDES_pipe eng1(
        .clk(clk), .nrst(nrst), .start(eng0_done),
        .block_in(eng1_in), .C_init(C_K2), .D_init(D_K2), .decrypt(1'b1),
        .block_out(eng1_out), .done(eng1_done)
    );

    TripleDES_pipe eng2(
        .clk(clk), .nrst(nrst), .start(eng1_done),
        .block_in(eng2_in), .C_init(C_K1), .D_init(D_K1), .decrypt(1'b0),
        .block_out(eng2_out), .done(eng2_done)
    );

    // ---------------------------------------------------------------
    // COLLECT SIDE — independent of feed side. Because every block has
    // the SAME fixed latency through eng0->eng1->eng2, and blocks are
    // fed strictly in order, message B's first output can never arrive
    // before message A's last output. That fact is what makes a single
    // out_buf/counter safe to reuse across overlapping messages.
    // ---------------------------------------------------------------
    reg [OUT_W-1:0] out_buf;
    reg [OUT_W-1:0] data_out_r;
    reg [BLK_W-1:0] collect_idx;
    reg [BLK_W:0]   in_flight; // blocks fed but not yet collected

    assign data_out = data_out_r;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            out_buf     <= 0;
            data_out_r  <= 0;
            collect_idx <= 0;
            done        <= 0;
            busy        <= 0;
            in_flight   <= 0;
        end else begin
            done <= 0;

            // Track outstanding blocks (fed but not yet collected).
            if (load_block && !eng2_done)
                in_flight <= in_flight + 1;
            else if (!load_block && eng2_done)
                in_flight <= in_flight - 1;
            // if both or neither fire this cycle, in_flight is unchanged

            busy <= feeding || load_block || (in_flight != 0);

            if (eng2_done) begin
                out_buf[(OUT_W-1) - (collect_idx*64) -: 64] <= eng2_out;

                if (collect_idx == NUM_BLOCKS-1) begin
                    // Merge the just-arrived last word directly from
                    // eng2_out (avoids reading the stale out_buf value).
                    if (NUM_BLOCKS == 1)
                        data_out_r <= eng2_out;
                    else
                        data_out_r <= {out_buf[OUT_W-1:64], eng2_out};

                    done        <= 1;
                    collect_idx <= 0;
                end else begin
                    collect_idx <= collect_idx + 1;
                end
            end
        end
    end

endmodule
