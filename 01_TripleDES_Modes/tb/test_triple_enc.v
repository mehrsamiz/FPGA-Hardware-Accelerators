`timescale 1ns/1ps
`include "../rtl/TripleDES_enc.v"

module test_triple_enc;
  reg [64:1] plain, K1, K2;
  wire [64:1] cipher;

  TripleDES_enc uut(plain, K1, K2, cipher);

  initial begin
    // ECB test vector, first block
    plain = 64'h12BB6F8DF45EF216;
    K1 = 64'hA4E9432CE07AD076;
    K2 = 64'h572F7C1513DA495E;
    #1;
    $display("Plaintext: %h", plain);
    $display("K1: %h", K1);
    $display("K2: %h", K2);
    $display("Ciphertext: %h", cipher);
    if (cipher === 64'h307D644D19BEB557)
      $display("TripleDES_enc: PASS");
    else
      $display("TripleDES_enc: FAIL (got %h)", cipher);
    $finish;
  end
endmodule
