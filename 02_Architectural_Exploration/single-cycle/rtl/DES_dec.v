`include "constants/E.v"
`include "constants/P.v"
`include "constants/S1.v"
`include "constants/S2.v"
`include "constants/S3.v"
`include "constants/S4.v"
`include "constants/S5.v"
`include "constants/S6.v"
`include "constants/S7.v"
`include "constants/S8.v"
`include "constants/IP.v"
`include "constants/IP_inv.v"
`include "constants/PC1.v"
`include "constants/PC2.v"

module DES_dec(input [64:1] in, input [64:1] key, output [64:1] out);
  wire [64:1] in_ip;
  IP ip_inst(in, in_ip);

  wire [32:1] l [0:16];
  wire [32:1] r [0:16];
  wire [32:1] f_val [1:16];
  assign {l[0], r[0]} = in_ip;

  wire [48:1] k [1:16];
  KS ks_inst(key, k[1], k[2], k[3], k[4], k[5], k[6], k[7], k[8],
             k[9], k[10], k[11], k[12], k[13], k[14], k[15], k[16]);

  genvar i;
  generate
    for (i = 1; i <= 16; i = i + 1) begin
      assign l[i] = r[i-1];
      // Use keys in reverse order for decryption
      f f_inst(r[i-1], k[17-i], f_val[i]);
      assign r[i] = l[i-1] ^ f_val[i];
    end
  endgenerate

  IP_inv ip_inv_inst({r[16], l[16]}, out);
endmodule
