module key_pipe_stage (
    input  wire [27:0] C_in,
    input  wire [27:0] D_in,
    output wire [27:0] C_out,
    output wire [27:0] D_out,
    output wire [48:1] round_key
);
    parameter ROUND_NUM = 1;
    parameter DECRYPT = 0;

    // 1. Determine shift amount
    localparam shift = (ROUND_NUM == 1 || ROUND_NUM == 2 || ROUND_NUM == 9 || ROUND_NUM == 16) ? 1 : 2;

    // 2. Perform rotation
    wire [27:0] C_rot, D_rot;
    assign C_rot = DECRYPT ? {C_in[shift-1:0], C_in[27:shift]} : {C_in[27-shift:0], C_in[27:28-shift]};
    assign D_rot = DECRYPT ? {D_in[shift-1:0], D_in[27:shift]} : {D_in[27-shift:0], D_in[27:28-shift]};

    assign C_out = C_rot;
    assign D_out = D_rot;

    // 3. Generate Round Key (using PC2 logic)
    // You should have a pure combinational PC2 module
    PC2 pc2_u(.in({C_rot, D_rot}), .out(round_key));

endmodule

