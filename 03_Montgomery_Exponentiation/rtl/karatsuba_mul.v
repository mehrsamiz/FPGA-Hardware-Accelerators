module karatsuba_mul #(
    parameter WIDTH = 16,
    parameter BASE_WIDTH = 16
)(
    input wire [WIDTH-1:0] x,
    input wire [WIDTH-1:0] y,
    output wire [2*WIDTH-1:0] p
);

    generate
        if (WIDTH <= BASE_WIDTH) begin : base_case
            // استفاده از عملگر ضرب مجاز فقط در سطح پایه
            assign p = x * y;
        end else begin : recursive_case
            localparam M = WIDTH / 2;
            
            wire [M-1:0] x_low  = x[M-1:0];
            wire [WIDTH-M-1:0] x_high = x[WIDTH-1:M];
            wire [M-1:0] y_low  = y[M-1:0];
            wire [WIDTH-M-1:0] y_high = y[WIDTH-1:M];
            
            wire [2*M-1:0] z0;
            wire [2*(WIDTH-M)-1:0] z2;
            wire [2*(WIDTH-M)+1:0] z1; // پهنای بیت بیشتر برای سرریز جمع
            
            karatsuba_mul #( .WIDTH(M), .BASE_WIDTH(BASE_WIDTH) )
                mul_z0 ( .x(x_low), .y(y_low), .p(z0) );
                
            karatsuba_mul #( .WIDTH(WIDTH-M), .BASE_WIDTH(BASE_WIDTH) )
                mul_z2 ( .x(x_high), .y(y_high), .p(z2) );
                
            wire [WIDTH-M:0] x_sum = x_low + x_high;
            wire [WIDTH-M:0] y_sum = y_low + y_high;
            wire [2*(WIDTH-M)+1:0] z1_temp;
            
            karatsuba_mul #( .WIDTH(WIDTH-M+1), .BASE_WIDTH(BASE_WIDTH) )
                mul_z1 ( .x(x_sum), .y(y_sum), .p(z1_temp) );
                
            assign z1 = z1_temp - z0 - z2;
            
            assign p = z0 + (z1 << M) + (z2 << (2*M));
        end
    endgenerate
endmodule