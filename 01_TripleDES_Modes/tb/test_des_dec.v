`timescale 1ns/1ps
`include "../rtl/DES.v"
`include "../rtl/DES_dec.v"

module test_des_dec;
  reg [64:1] key, plain, cipher;
  wire [64:1] enc_out, dec_out;

  DES enc(plain, key, enc_out);
  DES_dec dec(enc_out, key, dec_out);

  initial begin
    key = 64'hA4E9432CE07AD076;
    plain = 64'h12BB6F8DF45EF216;
    #1;
    $display("Encrypted: %h", enc_out);
    $display("Decrypted: %h", dec_out);
    if (enc_out === 64'h307D644D19BEB557 && dec_out === plain)
      $display("DES_dec: PASS");
    else
      $display("DES_dec: FAIL (enc= %h dec= %h)", enc_out, dec_out);
    $finish;
  end
endmodule
