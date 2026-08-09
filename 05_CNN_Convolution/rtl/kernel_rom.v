// =============================================================
// kernel_rom.v
// Stores one 12x8 kernel (96 signed 8-bit taps), loaded from a
// $readmemh hex file at elaboration time. Outputs the 8-wide
// weight row addressed by krow (0..11).
//
// IMPORTANT: the .hex files this points to must contain the
// NEGATED kernel (see README.md "why negate the kernel" section) --
// that's what lets conv_top stream raw, non-inverted pixel bytes.
// =============================================================
module kernel_rom #(
    parameter KH      = 12,
    parameter KW      = 8,
    parameter WW      = 8,
    parameter HEXFILE = "kernel7_neg.hex"
)(
    input  wire [3:0]              krow,
    output wire signed [KW*WW-1:0] wt_row
);
    reg signed [WW-1:0] kmem [0:KH*KW-1];

    initial begin
        $readmemh(HEXFILE, kmem);
    end

    genvar j;
    generate
        for (j = 0; j < KW; j = j + 1) begin : GEN_W
            assign wt_row[j*WW +: WW] = kmem[krow*KW + j];
        end
    endgenerate
endmodule
