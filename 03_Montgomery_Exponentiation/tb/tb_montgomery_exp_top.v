`timescale 1ns / 1ps

module tb_montgomery_exp_top;

    parameter WIDTH = 16;

    reg clk;
    reg rst;
    reg start;
    reg [WIDTH-1:0] A;
    reg [WIDTH-1:0] E;
    reg [WIDTH-1:0] N;

    wire [WIDTH-1:0] result;
    wire done;

    montgomery_exp_top #(.WIDTH(WIDTH)) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .A(A),
        .E(E),
        .N(N),
        .result(result),
        .done(done)
    );


    always #5 clk = ~clk;

    task run_test(
        input [WIDTH-1:0] test_A,
        input [WIDTH-1:0] test_E,
        input [WIDTH-1:0] test_N,
        input [WIDTH-1:0] expected_res
    );
        begin
            A = test_A;
            E = test_E;
            N = test_N;
            
            @(posedge clk);
            start = 1; 
            
            @(posedge clk);
            start = 0; 
            
            while (!done) begin
                @(posedge clk);
            end
            if (result == expected_res) begin
                $display("[PASS] A=%0d, E=%0d, N=%0d | Result=%0d (Expected=%0d)", test_A, test_E, test_N, result, expected_res);
            end else begin
                $display("[FAIL] A=%0d, E=%0d, N=%0d | Result=%0d (Expected=%0d) <--- ERROR", test_A, test_E, test_N, result, expected_res);
            end
            
            // ایجاد یک فاصله زمانی کوتاه بین تست‌ها
            #20;
        end
    endtask


    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        A = 0;
        E = 0;
        N = 0;

        #20;
        rst = 0;
        #20;

        $display("======= STARTING MONTGOMERY MODULAR EXPONENTIATION TESTS =======");

        // تست شماره ۱: حالت ساده و کلاسیک (5^3 mod 13 = 125 mod 13 = 8)
        run_test(16'd5, 16'd3, 16'd13, 16'd8);

        // تست شماره ۲: پایه بزرگتر (7^5 mod 11 = 16807 mod 11 = 10)
        run_test(16'd7, 16'd5, 16'd11, 16'd10);

        // تست شماره ۳: توان زوج و پیمانه بزرگتر (3^4 mod 17 = 81 mod 17 = 13)
        run_test(16'd3, 16'd4, 16'd17, 16'd13);

        // تست شماره ۴: تست توان صفر (هر عددی به توان 0 برابر 1 است)
        run_test(16'd12, 16'd0, 16'd19, 16'd1);

        // تست شماره ۵: مقدار دهی حداکثری بیتی (مقادیر فرضی در محدوده ۱۶ بیت فرد)
        // 2^10 mod 101 = 1024 mod 101 = 14
        run_test(16'd2, 16'd10, 16'd101, 16'd14);

        $display("======= ALL TESTS EXECUTED =======");
        $stop;
    end

endmodule