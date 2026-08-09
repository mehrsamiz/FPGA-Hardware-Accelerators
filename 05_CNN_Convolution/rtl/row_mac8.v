// =============================================================
// row_mac8.v
// One kernel-row's worth of multiply-accumulate, computed in a
// single cycle: 8 unsigned pixels x 8 signed kernel weights,
// summed into one signed partial-sum output. Synthesizes onto a
// handful of DSP48E1 slices on 7-series parts.
// =============================================================
module row_mac8 #(
    parameter PW    = 8,
    parameter WW    = 8,
    parameter SUM_W = 19   // enough headroom for 8 x (255*127) worst case
)(
    input  wire [PW*8-1:0]         pix_row,     // 8 packed unsigned pixels
    input  wire signed [WW*8-1:0]  wt_row,      // 8 packed signed weights
    output wire signed [SUM_W-1:0] partial_sum
);
    genvar i;
    wire signed [PW:0]    pix_s [0:7];   // zero-extended, 1 extra bit for signed math
    wire signed [WW-1:0]  wt    [0:7];
    wire signed [PW+WW:0] prod  [0:7];   // 17-bit product

    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_TAP
            assign pix_s[i] = {1'b0, pix_row[i*PW +: PW]};
            assign wt[i]    = wt_row[i*WW +: WW];
            assign prod[i]  = pix_s[i] * wt[i];
        end
    endgenerate

    assign partial_sum = prod[0] + prod[1] + prod[2] + prod[3]
                        + prod[4] + prod[5] + prod[6] + prod[7];

endmodule
