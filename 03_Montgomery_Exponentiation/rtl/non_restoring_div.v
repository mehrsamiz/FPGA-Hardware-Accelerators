module non_restoring_div #(
    parameter WIDTH = 16
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [WIDTH-1:0] dividend,
    input wire [WIDTH-1:0] divisor,
    output reg [WIDTH-1:0] quotient,
    output reg [WIDTH-1:0] remainder,
    output reg done
);

    localparam IDLE = 2'b00, CALC = 2'b01, CORR = 2'b10, DONE = 2'b11;
    reg [1:0] state;
    
    reg signed [WIDTH:0] rem; 
    reg [WIDTH-1:0] quo;
    reg [$clog2(WIDTH):0] count;

   
    reg signed [WIDTH:0] next_rem;
    reg signed [WIDTH:0] actual_rem;
    reg [WIDTH-1:0] next_quo;
    reg quo_bit;

    always @(*) begin
        //شیفتی
        next_rem = (rem << 1) | { {WIDTH{1'b0}}, quo[WIDTH-1] };
        next_quo = quo << 1;
        
        
        if (rem[WIDTH] == 1'b0) begin
            actual_rem = next_rem - {1'b0, divisor};
        end else begin
            actual_rem = next_rem + {1'b0, divisor};
        end
        
        
        if (actual_rem[WIDTH] == 1'b0) begin
            quo_bit = 1'b1;
        end else begin
            quo_bit = 1'b0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            quotient <= 0;
            remainder <= 0;
            rem <= 0;
            quo <= 0;
            count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        rem <= 0;
                        quo <= dividend;
                        count <= 0;
                        state <= CALC;
                    end
                end

                CALC: begin
                    rem <= actual_rem;
                    quo <= next_quo | quo_bit;
                    count <= count + 1;
                    
                    
                    if (count == WIDTH - 1) begin
                        state <= CORR;
                    end
                end

                CORR: begin
                
                    if (rem[WIDTH] == 1'b1) begin
                        remainder <= rem + {1'b0, divisor};
                    end else begin
                        remainder <= rem[WIDTH-1:0];
                    end
                    quotient <= quo;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule