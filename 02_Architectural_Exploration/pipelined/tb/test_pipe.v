`timescale 1ns/1ps
`include "../rtl/TopPipe.v"

module test_pipe;
    reg         clk, nrst, start;
    reg  [255:0] data_in;
    reg  [127:0] key;
    wire [255:0] data_out;
    wire        done, busy;

    // DUT: 4 * 64-bit blocks
    TopPipe #(.DATA_W(256), .OUT_W(256)) uut (
        .clk(clk),
        .nrst(nrst),
        .start(start),
        .data_in(data_in),
        .key(key),
        .data_out(data_out),
        .done(done),
        .busy(busy)
    );

    // Clock
    always #5 clk = ~clk;

    // Known-good ciphertext for the 4 blocks
    localparam [255:0] EXPECTED_CT =
        256'h307D644D19BEB55759C0DC3E862B82387EB35CC8ECE07C780B8762E0708F1DF1;

    initial begin
        clk   = 0;
        nrst  = 0;
        start = 0;

        // Keys: {K1, K2}
        key = {64'hA4E9432CE07AD076, 64'h572F7C1513DA495E};

        // Plaintext blocks: {P0, P1, P2, P3}
        data_in = {
            64'h12BB6F8DF45EF216, // P0 (MSB)
            64'hBA7BDE0C26FBA7DC, // P1
            64'hD1BF4B48A0F02854, // P2
            64'h9947E3E0C209EE51  // P3 (LSB)
        };

        // Reset
        #20;
        nrst = 1;
        #20;

        // Start one 256-bit ECB encryption
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait until engine finishes all 4 blocks (done pulses)
        while (!done) @(posedge clk);

        $display("Expected CT : %h", EXPECTED_CT);
        $display("Got      CT : %h", data_out);

        if (data_out === EXPECTED_CT)
            $display("ECB 4-block test: PASS");
        else
            $display("ECB 4-block test: FAIL");

        $finish;
    end
endmodule
