// ==============================================================================
// TEA Cryptography Core
// ==============================================================================

`timescale 1ns / 1ps

module tea_core (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] v0_in,
    input wire [31:0] v1_in,
    input wire [31:0] k0,
    input wire [31:0] k1,
    input wire [31:0] k2,
    input wire [31:0] k3,
    output reg [31:0] v0_out,
    output reg [31:0] v1_out,
    output reg done
);

    localparam DELTA = 32'h9e3779b9;

    // FSM States
    localparam IDLE    = 2'd0;
    localparam CALC_V0 = 2'd1;
    localparam CALC_V1 = 2'd2;
    localparam FINISH  = 2'd3;

    reg [1:0] state;
    reg [31:0] v0_reg, v1_reg;
    reg [31:0] sum;
    reg [5:0] round_count;

    // Combinational wire for the next sum
    wire [31:0] next_sum = sum + DELTA;

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            v0_reg      <= 32'd0;
            v1_reg      <= 32'd0;
            sum         <= 32'd0;
            round_count <= 6'd0;
            done        <= 1'b0;
            v0_out      <= 32'd0;
            v1_out      <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        v0_reg      <= v0_in;
                        v1_reg      <= v1_in;
                        sum         <= 32'd0;
                        round_count <= 6'd0;
                        state       <= CALC_V0;
                    end
                end

                CALC_V0: begin
                    sum <= next_sum;
                    v0_reg <= v0_reg + (((v1_reg << 4) + k0) ^ (v1_reg + next_sum) ^ ((v1_reg >> 5) + k1));
                    state <= CALC_V1;
                end

                CALC_V1: begin
                    v1_reg <= v1_reg + (((v0_reg << 4) + k2) ^ (v0_reg + sum) ^ ((v0_reg >> 5) + k3));
                    
                    if (round_count == 6'd31) begin
                        state <= FINISH;
                    end else begin
                        round_count <= round_count + 1'b1;
                        state       <= CALC_V0;
                    end
                end

                FINISH: begin
                    v0_out <= v0_reg;
                    v1_out <= v1_reg;
                    done   <= 1'b1;
                    
                    // AXI Handshake: Software must write 0 to the start register
                    // before the core will return to IDLE for the next run.
                    if (!start) begin 
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule