`include "DES.v"      // original encryption
`include "DES_dec.v"  // decryption from Step 2


module TripleDES_enc(
  input [64:1] plain,
  input [64:1] K1,
  input [64:1] K2,
  output [64:1] cipher
);

  wire [64:1] tmp1, tmp2;
  DES enc1(plain, K1, tmp1);
  DES_dec dec(tmp1, K2, tmp2);
  DES enc2(tmp2, K1, cipher);
endmodule




//e, k1 (d , k2(e , k1(plaintext) ))