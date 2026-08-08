module montgomery_mul #(
    parameter WIDTH = 16
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire [WIDTH-1:0] N,
    input wire [WIDTH-1:0] N_prime,
    output reg [WIDTH-1:0] result,
    output reg done
);
    
    wire [2*WIDTH-1:0] T;
    wire [2*WIDTH-1:0] m_N;
    wire [WIDTH-1:0] m;
    
    // New wire to hold the full 2*WIDTH result of the intermediate multiplication
    wire [2*WIDTH-1:0] m_full; 
    
    reg [2*WIDTH:0] temp_t; 

    // 1. T = a * b (using Karatsuba)
    karatsuba_mul #( .WIDTH(WIDTH) ) mul_ab ( .x(a), .y(b), .p(T) );
    
    // 2. T[WIDTH-1:0] * N_prime (using Karatsuba to replace the '*' operator)
    karatsuba_mul #( .WIDTH(WIDTH) ) mul_m_calc ( .x(T[WIDTH-1:0]), .y(N_prime), .p(m_full) );
    
    // m = m_full mod R (take only the lower WIDTH bits)
    assign m = m_full[WIDTH-1:0]; 
    
    // 3. m * N (using Karatsuba)
    karatsuba_mul #( .WIDTH(WIDTH) ) mul_mN ( .x(m), .y(N), .p(m_N) );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 0;
            done <= 0;
            temp_t <= 0;
        end else if (start) begin
            temp_t = (T + m_N) >> WIDTH;
            
            if (temp_t >= N) begin
                result <= temp_t - N;
            end else begin
                result <= temp_t;
            end
            done <= 1;
        end else begin
            done <= 0;
        end
    end
endmodule