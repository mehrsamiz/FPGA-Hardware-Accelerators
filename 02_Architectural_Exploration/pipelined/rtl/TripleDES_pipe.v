`include "DES_round_step.v"
`include "IP.v"
`include "IP_inv.v"
`include "key_pipe_stage.v"
`include "PC2.v"

module TripleDES_pipe(
    input  wire        clk,
    input  wire        nrst,
    input  wire        start,
    input  wire [1:64] block_in,
    input  wire [27:0] C_init,
    input  wire [27:0] D_init,
    input  wire        decrypt,
    output wire [1:64] block_out,
    output wire        done
);

    localparam STAGES = 16;

    reg [32:1] L [0:STAGES];
    reg [32:1] R [0:STAGES];
    reg [27:0] C [0:STAGES];
    reg [27:0] D [0:STAGES];
    reg valid [0:STAGES];

    wire [32:1] L_next [1:STAGES];
    wire [32:1] R_next [1:STAGES];
    wire [27:0] C_next [1:STAGES];
    wire [27:0] D_next [1:STAGES];
    wire [1:48] round_key [1:STAGES];

    // Encrypt and decrypt key paths
    wire [27:0] C_enc [1:STAGES], D_enc [1:STAGES];
    wire [1:48] key_enc [1:STAGES];
    wire [27:0] C_dec [1:STAGES], D_dec [1:STAGES];
    wire [1:48] key_dec [1:STAGES];

    wire [1:64] ip_out, fp_out;
    IP ip_u(.in(block_in), .out(ip_out));
    IP_inv fp_u(.in({R[STAGES], L[STAGES]}), .out(fp_out));

    assign block_out = fp_out;
    assign done = valid[STAGES];

    genvar s;
    generate
    for (s = 1; s <= STAGES; s = s + 1) begin : stage
        // Encrypt key path (always present)
        key_pipe_stage #(.ROUND_NUM(s), .DECRYPT(0)) kp_enc(
            .C_in(C[s-1]), .D_in(D[s-1]),
            .C_out(C_enc[s]), .D_out(D_enc[s]),
            .round_key(key_enc[s])
        );

        // Decrypt key path (always present)
        if (s == 1) begin : dec_first
            assign C_dec[s] = C[s-1];
            assign D_dec[s] = D[s-1];
            PC2 pc2_d0(.in({C[s-1], D[s-1]}), .out(key_dec[s]));
        end else begin : dec_rest
            key_pipe_stage #(.ROUND_NUM(18-s), .DECRYPT(1)) kp_dec(
                .C_in(C[s-1]), .D_in(D[s-1]),
                .C_out(C_dec[s]), .D_out(D_dec[s]),
                .round_key(key_dec[s])
            );
        end

        // Mux between encrypt and decrypt
        assign C_next[s] = decrypt ? C_dec[s] : C_enc[s];
        assign D_next[s] = decrypt ? D_dec[s] : D_enc[s];
        assign round_key[s] = decrypt ? key_dec[s] : key_enc[s];

        DES_round_step round_step(
            .L_in(L[s-1]), .R_in(R[s-1]),
            .round_key(round_key[s]),
            .L_out(L_next[s]), .R_out(R_next[s])
        );
    end
    endgenerate

    integer i;
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            for (i = 0; i <= STAGES; i = i + 1) begin
                L[i] <= 0; R[i] <= 0; C[i] <= 0; D[i] <= 0; valid[i] <= 0;
            end
        end else begin
            if (start) begin
                L[0] <= ip_out[1:32]; R[0] <= ip_out[33:64];
                C[0] <= C_init; D[0] <= D_init;
                valid[0] <= 1;
            end else begin
                valid[0] <= 0;
            end
            for (i = 1; i <= STAGES; i = i + 1) begin
                L[i] <= L_next[i]; R[i] <= R_next[i];
                C[i] <= C_next[i]; D[i] <= D_next[i];
                valid[i] <= valid[i-1];
            end
        end
    end
endmodule
