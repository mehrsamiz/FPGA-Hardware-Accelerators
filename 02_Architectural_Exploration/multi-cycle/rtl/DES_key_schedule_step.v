`include "constants/PC1.v"
`include "constants/PC2.v"

module DES_key_schedule_step (
    input  wire        clk,
    input  wire        nrst,
    input  wire        start,
    input  wire [64:1] key,
    input  wire        decrypt,

    output reg  [1:48] round_key,
    output reg         valid,
    output reg         ready,
    output reg         done
);

    reg [27:0] C, D;
    reg [4:0]  round_cnt;
    reg        running;

    wire [27:0] C_next;
    wire [27:0] D_next;


    wire [1:56] key56;

    PC1 pc1_inst (
        .in(key),
        .out(key56)
    );

    wire [1:56] cd56;
    assign cd56 = {C_next, D_next};

    wire [1:48] pc2_out;

    PC2 pc2_inst (
        .in(cd56),
        .out(pc2_out)
    );


    function [1:0] shift_amt;
        input [4:0] r;
        begin
            case (r)
                5'd1, 5'd2, 5'd9, 5'd16: shift_amt = 2'd1;
                default:                 shift_amt = 2'd2;
            endcase
        end
    endfunction

    function [27:0] rol28;
        input [27:0] x;
        input [1:0]  s;
        begin
            case (s)
                2'd1: rol28 = {x[26:0], x[27]};
                2'd2: rol28 = {x[25:0], x[27:26]};
                default: rol28 = x;
            endcase
        end
    endfunction

    function [27:0] ror28;
        input [27:0] x;
        input [1:0]  s;
        begin
            case (s)
                2'd1: ror28 = {x[0],   x[27:1]};
                2'd2: ror28 = {x[1:0], x[27:2]};
                default: ror28 = x;
            endcase
        end
    endfunction

assign C_next =
    (!decrypt) ?
        rol28(C, shift_amt(round_cnt + 1)) :
        (round_cnt == 0) ? C : ror28(C, shift_amt(17 - round_cnt));

assign D_next =
    (!decrypt) ?
        rol28(D, shift_amt(round_cnt + 1)) :
        (round_cnt == 0) ? D : ror28(D, shift_amt(17 - round_cnt));

    always @(posedge clk) begin
        if (start)
            $display("KS: start=1, ready=%b, running=%b, round_cnt=%0d", ready, running, round_cnt);
        if (valid)
            $display("  Key round %0d: %h (decrypt=%b)", round_cnt, round_key, decrypt);
    end


    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            C         <= 0;
            D         <= 0;
            round_cnt <= 0;
            running   <= 0;
            ready     <= 1;
            valid     <= 0;
            done      <= 0;
        end
        else begin
            valid <= 0;
            done  <= 0;

            if (start && ready) begin
                {C, D}    <= key56;
                round_cnt <= 0;
                running   <= 1;
                ready     <= 0;

            end
            else if (running) begin

                C <= C_next;
                D <= D_next;

                round_key <= pc2_out;
                valid <= 1;

                if (round_cnt == 15) begin
                    running <= 0;
                    ready   <= 1;
                    done    <= 1;
                end
                if (round_cnt == 15) begin
                    running <= 0;
                    ready <= 1;
                    done <= 1;
                end
                else begin
                    round_cnt <= round_cnt + 1;  // Only increment if not done
                end

            end

        end
    end

endmodule
