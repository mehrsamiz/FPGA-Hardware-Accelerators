`timescale 1ns / 1ps

module tb_karatsuba_mul;
    parameter WIDTH = 16;

    reg [WIDTH-1:0] x;
    reg [WIDTH-1:0] y;
    wire [2*WIDTH-1:0] p;

    // نمونه‌سازی ماژول ضرب
    karatsuba_mul #(.WIDTH(WIDTH), .BASE_WIDTH(4)) uut (
        .x(x), .y(y), .p(p)
    );

    initial begin
        // تست ۱: ضرب دو عدد کوچک
        x = 16'd12; y = 16'd10;
        #10;
        $display("[MUL TEST 1] 12 * 10 = %0d (Expected: 120)", p);

        // تست ۲: ضرب اعداد بزرگتر برای درگیر شدن ساختار بازگشتی
        x = 16'd255; y = 16'd400;
        #10;
        $display("[MUL TEST 2] 255 * 400 = %0d (Expected: 102000)", p);
        
        // تست ۳: لبه محدوده ۱۶ بیتی
        x = 16'd1000; y = 16'd50;
        #10;
        $display("[MUL TEST 3] 1000 * 50 = %0d (Expected: 50000)", p);

        $stop;
    end
endmodule