
module DES_round_step(
    input  [32:1] L_in,
    input  [32:1] R_in,
    input  [1:48] round_key,
    output [32:1] L_out,
    output [32:1] R_out
);

wire [32:1] f_out;

f f_unit(
    .R(R_in),
    .K(round_key),
    .OUT(f_out)
);

assign L_out = R_in;
assign R_out = L_in ^ f_out;

endmodule

