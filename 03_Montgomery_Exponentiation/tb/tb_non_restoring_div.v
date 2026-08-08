`timescale 1ns / 1ps

module tb_non_restoring_div;
    parameter WIDTH = 16;

    reg clk;
    reg rst;
    reg start;
    reg [WIDTH-1:0] dividend;
    reg [WIDTH-1:0] divisor;
    
    wire [WIDTH-1:0] quotient;
    wire [WIDTH-1:0] remainder;
    wire done;

    // نمونه‌سازی ماژول تقسیم
    non_restoring_div #(.WIDTH(WIDTH)) uut (
        .clk(clk), .rst(rst), .start(start),
        .dividend(dividend), .divisor(divisor),
        .quotient(quotient), .remainder(remainder), .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; start = 0; dividend = 0; divisor = 0;
        #20; rst = 0; #20;

        // تست ۱: ۱۳ تقسیم بر ۵ (خارج قسمت ۲، باقیمانده ۳)
        dividend = 16'd13; divisor = 16'd5;
        @(posedge clk); start = 1;
        @(posedge clk); start = 0;
        
        while (!done) @(posedge clk);
        $display("[DIV TEST 1] 13 / 5 -> Q=%0d (Exp: 2), R=%0d (Exp: 3) | Done=%b", quotient, remainder, done);
        
        #40;
        // تست ۲: ۱۰۰ تقسیم بر ۷ (خارج قسمت ۱۴، باقیمانده ۲)
        dividend = 16'd100; divisor = 16'd7;
        @(posedge clk); start = 1;
        @(posedge clk); start = 0;
        
        while (!done) @(posedge clk);
        $display("[DIV TEST 2] 100 / 7 -> Q=%0d (Exp: 14), R=%0d (Exp: 2) | Done=%b", quotient, remainder, done);

        $stop;
    end
endmodule