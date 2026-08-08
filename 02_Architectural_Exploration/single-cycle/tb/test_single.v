`timescale 1ns/1ps
`include "../rtl/TopSingle.v"

module test_single;
    reg clk, nrst, start;
    reg [1:0] mode;
    reg [255:0] data_in;
    reg [127:0] key;
    reg [63:0] iv;
    wire [255:0] data_out;
    wire done, busy;

    TopSingle #(.DATA_W(256), .OUT_W(256)) uut (
        .clk, .nrst, .start, .mode,
        .data_in, .key, .iv,
        .data_out, .done, .busy
    );

    always #5 clk = ~clk;

    task reset_all;
        begin
            nrst = 0;
            start = 0;
            data_in = 0;
            key = 0;
            iv = 0;
            mode = 0;
            repeat(2) @(posedge clk);
            nrst = 1;
            @(posedge clk);
        end
    endtask

    task run_test(
        input [1:0] m,
        input [255:0] pt,
        input [127:0] k,
        input [63:0] iv_in,
        input [255:0] exp
    );
        begin
            reset_all();

            mode = m;
            data_in = pt;
            key = k;
            iv = iv_in;

            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            while (!done) @(posedge clk);

            $display("\n=== Mode %0d result ===", m);
            $display("Output ciphertext: %h", data_out);

            if (data_out === exp)
                $display("PASS");
            else begin
                $display("FAIL!");
                $display("Expected: %h", exp);
            end

            @(posedge clk);
        end
    endtask

    initial begin
        clk = 0;

        // ============================
        // Test Vector 1 — ECB
        // ============================
        run_test(
            2'b00,
            256'h12BB6F8DF45EF216BA7BDE0C26FBA7DCD1BF4B48A0F028549947E3E0C209EE51,
            {64'hA4E9432CE07AD076, 64'h572F7C1513DA495E},
            64'h0,
            256'h307D644D19BEB55759C0DC3E862B82387EB35CC8ECE07C780B8762E0708F1DF1
        );

        // ============================
        // Test Vector 2 — CBC
        // ============================
        run_test(
            2'b01,
            256'h81A239C31A85555472558978F41CA01A6D841401ED8661BB3222EAA63D9E44A5,
            {64'hFDDF34345EEF082F, 64'hA42AAB494576EC94},
            64'h2B0A1D10B06D3A2C,
            256'h297AB4B44A9BC2FCE63817B28BDDAFD334AC5E9E57AA9A51F07839AFEB067989
        );


        // ============================
        // Test Vector 3 — OFB
        // ============================
        run_test(
            2'b10,
            256'h8D166A08A65AA998781AA16D615C9BA02F66D7EEB7001EAE4D9CA6F1A93FAD05,
            {64'h79AD455EADF8B6D9, 64'h20BADAD96110683D},
            64'h3D1EF94987749B72,
            256'h54E4ABC45BA14D1DE80E5F020DBF64CF9EF1A890E81103AEA54DBF8F287FFEBD
        );

        $display("\nAll ECB / CBC / OFB tests complete.\n");
        $finish;
    end
endmodule
