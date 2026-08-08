module extended_gcd #(
    parameter WIDTH = 16,
    parameter COEFF_WIDTH = 2*WIDTH
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [WIDTH-1:0] a_in,
    input wire [WIDTH-1:0] b_in,
    output reg [WIDTH-1:0] gcd,
    output reg signed [COEFF_WIDTH-1:0] x,
    output reg signed [COEFF_WIDTH-1:0] y,
    output reg done
);

    localparam IDLE = 3'd0, EVAL = 3'd1, DIVIDE = 3'd2, WAIT_DIV = 3'd3, UPDATE = 3'd4, FINISH = 3'd5;
    reg [2:0] state;

    reg [WIDTH-1:0] a_reg, b_reg;
    reg signed [COEFF_WIDTH-1:0] x0, x1, y0, y1;
    
    // سیگنال‌های مربوط به ماژول تقسیم
    reg div_start;
    wire div_done;
    wire [WIDTH-1:0] q_out, r_out;
    
    // متغیرهای کمکی برای ضرب کاراتسوبا و اعمال علامت
    wire [COEFF_WIDTH-1:0] q_padded;
    wire [COEFF_WIDTH-1:0] abs_x1, abs_y1;
    wire [2*COEFF_WIDTH-1:0] kx_out, ky_out;
    wire signed [COEFF_WIDTH-1:0] q_x1, q_y1;

    // نمونه‌سازی تقسیم‌کننده
    non_restoring_div #(.WIDTH(WIDTH)) div_inst (
        .clk(clk), .rst(rst), .start(div_start),
        .dividend(a_reg), .divisor(b_reg),
        .quotient(q_out), .remainder(r_out), .done(div_done)
    );

    // آماده‌سازی ورودی‌ها برای کاراتسوبا (بدون علامت)
    assign q_padded = { {(COEFF_WIDTH-WIDTH){1'b0}}, q_out };
    assign abs_x1 = (x1[COEFF_WIDTH-1]) ? -x1 : x1;
    assign abs_y1 = (y1[COEFF_WIDTH-1]) ? -y1 : y1;

    // ضرب q در x1 و y1
    karatsuba_mul #(.WIDTH(COEFF_WIDTH), .BASE_WIDTH(16)) mul_x (
        .x(q_padded), .y(abs_x1), .p(kx_out)
    );
    karatsuba_mul #(.WIDTH(COEFF_WIDTH), .BASE_WIDTH(16)) mul_y (
        .x(q_padded), .y(abs_y1), .p(ky_out)
    );

    // بازگردانی علامت به نتیجه ضرب
    assign q_x1 = (x1[COEFF_WIDTH-1]) ? -kx_out[COEFF_WIDTH-1:0] : kx_out[COEFF_WIDTH-1:0];
    assign q_y1 = (y1[COEFF_WIDTH-1]) ? -ky_out[COEFF_WIDTH-1:0] : ky_out[COEFF_WIDTH-1:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            div_start <= 0;
            gcd <= 0; x <= 0; y <= 0;
            a_reg <= 0; b_reg <= 0;
            x0 <= 0; x1 <= 0; y0 <= 0; y1 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        a_reg <= a_in;
                        b_reg <= b_in;
                        x0 <= 1; x1 <= 0; // x0=1, x1=0 for a
                        y0 <= 0; y1 <= 1; // y0=0, y1=1 for b
                        state <= EVAL;
                    end
                end
                EVAL: begin
                    if (b_reg == 0) state <= FINISH;
                    else begin
                        div_start <= 1;
                        state <= WAIT_DIV;
                    end
                end
                WAIT_DIV: begin
                    div_start <= 0;
                    if (div_done) state <= UPDATE;
                end
                UPDATE: begin
                    // بروزرسانی متغیرها طبق الگوریتم
                    a_reg <= b_reg;
                    b_reg <= r_out;
                    x0 <= x1;
                    x1 <= x0 - q_x1;
                    y0 <= y1;
                    y1 <= y0 - q_y1;
                    state <= EVAL;
                end
                FINISH: begin
                    gcd <= a_reg;
                    x <= x0;
                    y <= y0;
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule