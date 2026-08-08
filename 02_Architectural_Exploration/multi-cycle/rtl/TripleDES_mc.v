`include "DES.v"

`include "DES_round_step.v"
`include "constants/IP.v"
`include "constants/IP_inv.v"

module TripleDES_mc(
    input wire clk,
    input wire nrst,
    input wire start,

    input wire [1:64] block_in,

    input wire [1:48] round_key,
    input wire key_valid,

    output reg key_req,
    output reg use_key2,
    output reg decrypt_mode,

    output reg [1:64] block_out,
    output reg busy,
    output reg done
);

    reg [32:1] L;
    reg [32:1] R;
    reg [5:0] round_cnt;
    reg [1:0] phase;
    reg [2:0] state;  // Extra bit for more states
    
    reg [1:64] current_block;

    localparam S_IDLE        = 3'd0;
    localparam S_LOAD        = 3'd1;
    localparam S_ROUND       = 3'd2;
    localparam S_LAST_ROUND  = 3'd3;  // New: wait for final round to settle
    localparam S_PHASE_DONE  = 3'd4;  // New: capture fp_out
    localparam S_DONE        = 3'd5;

    localparam PH_E1 = 2'd0;
    localparam PH_D2 = 2'd1;
    localparam PH_E3 = 2'd2;

    wire [32:1] next_L;
    wire [32:1] next_R;
    wire [1:64] ip_out;
    wire [1:64] fp_out;

    IP ip_inst(.in(current_block), .out(ip_out));
    IP_inv fp_inst(.in({R, L}), .out(fp_out));

    DES_round_step round_unit(
        .L_in(L), .R_in(R),
        .round_key(round_key),
        .L_out(next_L), .R_out(next_R)
    );

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            state <= S_IDLE;
            busy <= 0;
            done <= 0;
            key_req <= 0;
            round_cnt <= 0;
            phase <= PH_E1;
            L <= 0;
            R <= 0;
            use_key2 <= 0;
            decrypt_mode <= 0;
            block_out <= 0;
            current_block <= 0;
        end
        else begin
            case(state)
                S_IDLE: begin
                    done <= 0;
                    key_req <= 0;
                    if (start) begin
                        busy <= 1;
                        current_block <= block_in;
                        phase <= PH_E1;
                        use_key2 <= 0;
                        decrypt_mode <= 0;
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    {L, R} = ip_out;
                    round_cnt <= 0;
                    key_req <= 1;
                    state <= S_ROUND;
                end

                S_ROUND: begin
                    key_req <= 0;
                    
                    if (key_valid) begin
                        L <= next_L;
                        R <= next_R;
                        
                        if (round_cnt == 15) begin
                            state <= S_LAST_ROUND;  // Wait one cycle for L,R to update
                        end
                        else begin
                            round_cnt <= round_cnt + 1;
                        end
                    end
                end
                
                S_LAST_ROUND: begin
                    // L and R now have the values after round 16
                    // fp_out is combinational, so it reflects the new {R, L}
                    state <= S_PHASE_DONE;
                end
                
                S_PHASE_DONE: begin
                    // Now capture the correct fp_out
                    if (phase == PH_E1) begin
                        current_block <= fp_out;
                        phase <= PH_D2;
                        use_key2 <= 1;
                        decrypt_mode <= 1;
                        state <= S_LOAD;
                    end
                    else if (phase == PH_D2) begin
                        current_block <= fp_out;
                        phase <= PH_E3;
                        use_key2 <= 0;
                        decrypt_mode <= 0;
                        state <= S_LOAD;
                    end
                    else begin
                        // PH_E3 complete
                        block_out <= fp_out;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    busy <= 0;
                    done <= 1;
                    key_req <= 0;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule