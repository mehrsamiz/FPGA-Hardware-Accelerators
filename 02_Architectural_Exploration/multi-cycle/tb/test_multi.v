`timescale 1ns/1ps
`include "../rtl/TopMulti.v"

module test_multi;
    reg clk, nrst, start;
    reg [1:0] mode;
    reg [255:0] data_in;
    reg [63:0] key1, key2, iv;
    wire [255:0] data_out;
    wire done, busy;

    TopMulti #(.DATA_W(256)) uut (
        .clk, .nrst, .start,
        .data_in, .key1, .key2, .iv,
        .mode, .done, .busy, .data_out
    );

    always #5 clk = ~clk;

    task run_test;
        input [1:0] t_mode;
        input [63:0] t_k1, t_k2, t_iv;
        input [255:0] t_plain;
        input [255:0] t_expected;
        input [80:0] name;
        begin
            @(posedge clk);
            nrst <= 0;
            start <= 0;
            @(posedge clk);
            nrst <= 1;
            
            mode = t_mode;
            key1 = t_k1;
            key2 = t_k2;
            iv = t_iv;
            data_in = t_plain;
            
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            while (!done) @(posedge clk);
            
            if (data_out === t_expected) begin
                $display("PASS: %0s", name);
                $display("  %h", data_out);
            end else begin
                $display("FAIL: %0s", name);
                $display("  Expected: %h", t_expected);
                $display("  Got:      %h", data_out);
            end
        end
    endtask

    initial begin
        clk = 0;
        nrst = 0;
        start = 0;
        repeat(2) @(posedge clk);
        nrst = 1;
        
        // ECB
        run_test(2'b00,
            64'hA4E9432CE07AD076, 64'h572F7C1513DA495E, 64'h0,
            {64'h12BB6F8DF45EF216, 64'hBA7BDE0C26FBA7DC,
             64'hD1BF4B48A0F02854, 64'h9947E3E0C209EE51},
            256'h307D644D19BEB55759C0DC3E862B82387EB35CC8ECE07C780B8762E0708F1DF1,
            "ECB 256-bit");
        
        // CBC
        run_test(2'b01,
            64'hFDDF34345EEF082F, 64'hA42AAB494576EC94, 64'h2B0A1D10B06D3A2C,
            {64'h81A239C31A855554, 64'h72558978F41CA01A,
             64'h6D841401ED8661BB, 64'h3222EAA63D9E44A5},
            256'h297AB4B44A9BC2FCE63817B28BDDAFD334AC5E9E57AA9A51F07839AFEB067989,
            "CBC 256-bit");
        
        // OFB
        run_test(2'b10,
            64'h79AD455EADF8B6D9, 64'h20BADAD96110683D, 64'h3D1EF94987749B72,
            {64'h8D166A08A65AA998, 64'h781AA16D615C9BA0,
             64'h2F66D7EEB7001EAE, 64'h4D9CA6F1A93FAD05},
            256'h54E4ABC45BA14D1DE80E5F020DBF64CF9EF1A890E81103AEA54DBF8F287FFEBD,
            "OFB 256-bit");
        
        $finish;
    end
endmodule