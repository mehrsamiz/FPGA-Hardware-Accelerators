module modular_inverse #(
    parameter WIDTH = 16,
    parameter COEFF_WIDTH = 2*WIDTH
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] m,
    output reg [WIDTH-1:0] inverse,
    output reg done
);

    reg gcd_start;
    wire gcd_done;
    wire [WIDTH-1:0] gcd_out;
    wire signed [COEFF_WIDTH-1:0] x_out, y_out;
    
    reg [1:0] state;

    extended_gcd #(
        .WIDTH(WIDTH), .COEFF_WIDTH(COEFF_WIDTH)
    ) ext_gcd_inst (
        .clk(clk), .rst(rst), .start(gcd_start),
        .a_in(a), .b_in(m),
        .gcd(gcd_out), .x(x_out), .y(y_out), .done(gcd_done)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            done <= 0;
            gcd_start <= 0;
            inverse <= 0;
        end else begin
            case (state)
                0: begin
                    done <= 0;
                    if (start) begin
                        gcd_start <= 1;
                        state <= 1;
                    end
                end
                1: begin
                    gcd_start <= 0;
                    if (gcd_done) begin
                        if (gcd_out != 1) begin
                            inverse <= 0; 
                        end else begin
                            // اگر منفی بود، با پیمانه جمع می‌شود
                            if (x_out[COEFF_WIDTH-1]) 
                                inverse <= x_out[WIDTH-1:0] + m;
                            else 
                                inverse <= x_out[WIDTH-1:0];
                        end
                        state <= 2;
                    end
                end
                2: begin
                    done <= 1;
                    if (!start) state <= 0;
                end
            endcase
        end
    end
endmodule