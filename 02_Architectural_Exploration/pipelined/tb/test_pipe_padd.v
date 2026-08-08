`timescale 1ns/1ps
`include "../rtl/TopPipe.v"

module test_pipe_padd;
    reg clk, nrst, start;
    reg [299:0] data_in;     // 300 bits
    reg [127:0] key;
    wire [319:0] data_out;   // 5 blocks = 320 bits
    wire done, busy;

    TopPipe #(.DATA_W(300), .OUT_W(320)) uut (
        .clk(clk), .nrst(nrst), .start(start),
        .data_in(data_in),
        .key(key),
        .data_out(data_out),
        .done(done), .busy(busy)
    );

    always #5 clk = ~clk;

    // Known ciphertext for first 4 blocks (256 bits)
    localparam [255:0] EXPECTED_C0_C3 =
        256'h307D644D19BEB55759C0DC3E862B82387EB35CC8ECE07C780B8762E0708F1DF1;

    // P4 is 44 bits: 0x9A4EF286214
    localparam [43:0] P4_44 = 44'h9A4EF286214;

    initial begin
        clk=0; nrst=0; start=0;

        key = {64'hA4E9432CE07AD076, 64'h572F7C1513DA495E};

        // Compose exactly 300 bits of real data:
        // {P0,P1,P2,P3,P4(44 bits)}
        data_in = {
            64'h12BB6F8DF45EF216,
            64'hBA7BDE0C26FBA7DC,
            64'hD1BF4B48A0F02854,
            64'h9947E3E0C209EE51,
            P4_44
        };

        #20; nrst=1; #20;

        @(posedge clk); start=1;
        @(posedge clk); start=0;

        while(!done) @(posedge clk);

        // data_out is 320 bits: {C0,C1,C2,C3,C4}
        $display("C0..C3 expected: %h", EXPECTED_C0_C3);
        $display("C0..C3 got     : %h", data_out[319:64]);

        if (data_out[319:64] === EXPECTED_C0_C3)
            $display("First 4 blocks: PASS");
        else
            $display("First 4 blocks: FAIL");

        $display("C4 (last block, padded P4): %h", data_out[63:0]);

        // Also print the actual padded plaintext block for sanity:
        // expected padded block = 0x9A4EF28621400000
        $display("Expected P4 padded block  : %h", 64'h9A4EF28621400000);

        $finish;
    end
endmodule
