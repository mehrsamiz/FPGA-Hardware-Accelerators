`timescale 1ns/1ps
`include "../rtl/TopSingle.v"

module test_single_padd;
    reg clk, nrst, start;
    reg [1:0] mode;
    reg [299:0] data_in;
    reg [127:0] key;
    reg [63:0] iv;
    wire [319:0] data_out;
    wire done, busy;

    TopSingle #(.DATA_W(300), .OUT_W(320)) uut (
        .clk, .nrst, .start, .mode,
        .data_in, .key, .iv,
        .data_out, .done, .busy
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        nrst = 0;
        start = 0;
        mode = 0;
        key = 0;
        iv = 0;
        data_in = 0;
        
        // Apply reset
        repeat(2) @(posedge clk);
        nrst = 1;
        @(posedge clk);
        
        // ====================
        // Test 1: ECB 300-bit
        // ====================
        $display("=== Test 1: ECB 300-bit ===");
        mode = 2'b00;
        key = {64'hA4E9432CE07AD076, 64'h572F7C1513DA495E};
        iv = 64'h0;
        data_in = {64'h12BB6F8DF45EF216, 64'hBA7BDE0C26FBA7DC,
                   64'hD1BF4B48A0F02854, 64'h9947E3E0C209EE51,
                   44'h9A4EF286214};
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        while (!done) @(posedge clk);
        
        $display("ECB Output: %h", data_out);
        $display("  Block 0: %h (expected: 307d644d19beb557) %s", 
                 data_out[319:256], 
                 data_out[319:256] === 64'h307d644d19beb557 ? "OK" : "FAIL");
        $display("  Block 1: %h (expected: 59c0dc3e862b8238) %s", 
                 data_out[255:192], 
                 data_out[255:192] === 64'h59c0dc3e862b8238 ? "OK" : "FAIL");
        $display("  Block 2: %h (expected: 7eb35cc8ece07c78) %s", 
                 data_out[191:128], 
                 data_out[191:128] === 64'h7eb35cc8ece07c78 ? "OK" : "FAIL");
        $display("  Block 3: %h (expected: 0b8762e0708f1df1) %s", 
                 data_out[127:64], 
                 data_out[127:64] === 64'h0b8762e0708f1df1 ? "OK" : "FAIL");
        $display("  Block 4: %h (padded input: 9a4ef28621400000)", data_out[63:0]);
        
        // ====================
        // Test 2: CBC 300-bit
        // ====================
        $display("\n=== Test 2: CBC 300-bit ===");
        
        // Reset between tests
        nrst = 0;
        mode = 0;
        key = 0;
        iv = 0;
        data_in = 0;
        start = 0;
        repeat(2) @(posedge clk);
        nrst = 1;
        @(posedge clk);
        
        mode = 2'b01;
        key = {64'hFDDF34345EEF082F, 64'hA42AAB494576EC94};
        iv = 64'h2B0A1D10B06D3A2C;
        data_in = {64'h81A239C31A855554, 64'h72558978F41CA01A,
                   64'h6D841401ED8661BB, 64'h3222EAA63D9E44A5,
                   44'h9A4EF286214};
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        while (!done) @(posedge clk);
        
        $display("CBC Output: %h", data_out);
        $display("  Block 0: %h (expected: 297ab4b44a9bc2fc) %s", 
                 data_out[319:256],
                 data_out[319:256] === 64'h297ab4b44a9bc2fc ? "OK" : "FAIL");
        $display("  Block 1: %h (expected: e63817b28bddafd3) %s", 
                 data_out[255:192],
                 data_out[255:192] === 64'he63817b28bddafd3 ? "OK" : "FAIL");
        $display("  Block 2: %h (expected: 34ac5e9e57aa9a51) %s", 
                 data_out[191:128],
                 data_out[191:128] === 64'h34ac5e9e57aa9a51 ? "OK" : "FAIL");
        $display("  Block 3: %h (expected: f07839afeb067989) %s", 
                 data_out[127:64],
                 data_out[127:64] === 64'hf07839afeb067989 ? "OK" : "FAIL");
        $display("  Block 4: %h (padded input: 9a4ef28621400000 XOR C3)", data_out[63:0]);
        
        // ====================
        // Test 3: OFB 300-bit
        // ====================
        $display("\n=== Test 3: OFB 300-bit ===");
        
        // Reset between tests
        nrst = 0;
        mode = 0;
        key = 0;
        iv = 0;
        data_in = 0;
        start = 0;
        repeat(2) @(posedge clk);
        nrst = 1;
        @(posedge clk);
        
        mode = 2'b10;
        key = {64'h79AD455EADF8B6D9, 64'h20BADAD96110683D};
        iv = 64'h3D1EF94987749B72;
        data_in = {64'h8D166A08A65AA998, 64'h781AA16D615C9BA0,
                   64'h2F66D7EEB7001EAE, 64'h4D9CA6F1A93FAD05,
                   44'h9A4EF286214};
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        while (!done) @(posedge clk);
        
        $display("OFB Output: %h", data_out);
        $display("  Block 0: %h (expected: 54e4abc45ba14d1d) %s", 
                 data_out[319:256],
                 data_out[319:256] === 64'h54e4abc45ba14d1d ? "OK" : "FAIL");
        $display("  Block 1: %h (expected: e80e5f020dbf64cf) %s", 
                 data_out[255:192],
                 data_out[255:192] === 64'he80e5f020dbf64cf ? "OK" : "FAIL");
        $display("  Block 2: %h (expected: 9ef1a890e81103ae) %s", 
                 data_out[191:128],
                 data_out[191:128] === 64'h9ef1a890e81103ae ? "OK" : "FAIL");
        $display("  Block 3: %h (expected: a54dbf8f287ffebd) %s", 
                 data_out[127:64],
                 data_out[127:64] === 64'ha54dbf8f287ffebd ? "OK" : "FAIL");
        $display("  Block 4: %h (padded input: 9a4ef28621400000 XOR keystream4)", data_out[63:0]);
        
        $finish;
    end
endmodule