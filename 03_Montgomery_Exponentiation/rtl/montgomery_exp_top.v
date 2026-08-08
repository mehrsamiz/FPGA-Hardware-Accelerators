
module montgomery_exp_top #(
    parameter WIDTH = 16
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [WIDTH-1:0] A,
    input wire [WIDTH-1:0] E,
    input wire [WIDTH-1:0] N,
    output reg [WIDTH-1:0] result,
    output reg done
);

    // حالات FSM
    localparam IDLE = 4'd0, 
               INV_START = 4'd1, INV_WAIT = 4'd2, 
               ABAR_START = 4'd3, ABAR_WAIT = 4'd4, 
               RESINIT_START = 4'd5, RESINIT_WAIT = 4'd6,
               LOOP_SQ_START = 4'd7, LOOP_SQ_WAIT = 4'd8,
               LOOP_MUL_START = 4'd9, LOOP_MUL_WAIT = 4'd10,
               POST_START = 4'd11, POST_WAIT = 4'd12, FINISH = 4'd13;
               
    reg [3:0] state;
    reg signed [31:0] idx; // شمارنده حلقه (از WIDTH-1 تا 0)
    

    reg [WIDTH-1:0] N_inv_reg, N_prime_reg;
    reg [WIDTH-1:0] A_bar, res_reg;
    
    // سیگنال‌های Modular Inverse (نیاز به WIDTH+1 بیت برای ارسال R)
    reg inv_start;
    wire inv_done;
    wire [WIDTH:0] inv_out;
    
    modular_inverse #(.WIDTH(WIDTH+1)) inv_inst (
        .clk(clk), .rst(rst), .start(inv_start),
        .a({1'b0, N}), .m({1'b1, {WIDTH{1'b0}}}), // m = 2^WIDTH
        .inverse(inv_out), .done(inv_done)
    );

    // سیگنال‌های Divider دوبرابری (برای تبدیل‌های فرم مونتگومری)
    reg div_start;
    wire div_done;
    reg [2*WIDTH-1:0] div_dividend;
    wire [2*WIDTH-1:0] div_rem;
    
    non_restoring_div #(.WIDTH(2*WIDTH)) div_inst (
        .clk(clk), .rst(rst), .start(div_start),
        .dividend(div_dividend), .divisor({ {WIDTH{1'b0}}, N }),
        .quotient(), .remainder(div_rem), .done(div_done)
    );

    // سیگنال‌های Montgomery Multiplier
    reg mont_start;
    wire mont_done;
    reg [WIDTH-1:0] mont_a, mont_b;
    wire [WIDTH-1:0] mont_out;
    
    montgomery_mul #(.WIDTH(WIDTH)) mont_inst (
        .clk(clk), .rst(rst), .start(mont_start),
        .a(mont_a), .b(mont_b), .N(N), .N_prime(N_prime_reg),
        .result(mont_out), .done(mont_done)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 0; result <= 0;
            inv_start <= 0; div_start <= 0; mont_start <= 0;
            div_dividend <= 0; mont_a <= 0; mont_b <= 0;
            N_inv_reg <= 0; N_prime_reg <= 0;
            A_bar <= 0; res_reg <= 0; idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        inv_start <= 1;
                        state <= INV_WAIT;
                    end
                end
                
                // 1. محاسبه N_inv و N_prime
                INV_WAIT: begin
                    inv_start <= 0;
                    if (inv_done) begin
                        N_inv_reg <= inv_out[WIDTH-1:0];
                        N_prime_reg <= -inv_out[WIDTH-1:0]; // -N_inv mod R
                        
                        // آماده‌سازی برای A_bar = (A << WIDTH) mod N
                        div_dividend <= {A, {WIDTH{1'b0}}};
                        div_start <= 1;
                        state <= ABAR_WAIT;
                    end
                end
                
                ABAR_WAIT: begin
                    div_start <= 0;
                    if (div_done) begin
                        A_bar <= div_rem[WIDTH-1:0];
                        
                        // آماده‌سازی برای مقدار اولیه نتیجه = (1 << WIDTH) mod N
                        div_dividend <= { {WIDTH-1{1'b0}}, 1'b1, {WIDTH{1'b0}} };
                        div_start <= 1;
                        state <= RESINIT_WAIT;
                    end
                end
                
                RESINIT_WAIT: begin
                    div_start <= 0;
                    if (div_done) begin
                        res_reg <= div_rem[WIDTH-1:0];
                        idx <= WIDTH - 1; // شروع حلقه
                        state <= LOOP_SQ_START;
end
                end
                
                LOOP_SQ_START: begin
                    mont_a <= res_reg;
                    mont_b <= res_reg;
                    mont_start <= 1;
                    state <= LOOP_SQ_WAIT;
                end
                
                LOOP_SQ_WAIT: begin
                    mont_start <= 0;
                    if (mont_done) begin
                        res_reg <= mont_out; // Square انجام شد
                        if (E[idx] == 1'b1) begin
                            state <= LOOP_MUL_START;
                        end else begin
                            // عبور به بیت بعدی
                            if (idx == 0) state <= POST_START;
                            else begin
                                idx <= idx - 1;
                                state <= LOOP_SQ_START;
                            end
                        end
                    end
                end
                
                LOOP_MUL_START: begin
                    mont_a <= res_reg;
                    mont_b <= A_bar;
                    mont_start <= 1;
                    state <= LOOP_MUL_WAIT;
                end
                
                LOOP_MUL_WAIT: begin
                    mont_start <= 0;
                    if (mont_done) begin
                        res_reg <= mont_out; // Multiply انجام شد
                        if (idx == 0) state <= POST_START;
                        else begin
                            idx <= idx - 1;
                            state <= LOOP_SQ_START;
                        end
                    end
                end
                
                POST_START: begin
                    mont_a <= res_reg;
                    mont_b <= {{WIDTH-1{1'b0}}, 1'b1};
                    mont_start <= 1;
                    state <= POST_WAIT;
                end
                
                POST_WAIT: begin
                    mont_start <= 0;
                    if (mont_done) begin
                        result <= mont_out;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule