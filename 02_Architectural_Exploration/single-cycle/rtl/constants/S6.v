module S6(input [6:1] in, output reg [4:1] out);
  always @* begin
    casez ({in[6], in[1]})
      2'b00:
        case (in[5:2])
          4'b0000: out = 12;
          4'b0001: out = 1;
          4'b0010: out = 10;
          4'b0011: out = 15;
          4'b0100: out = 9;
          4'b0101: out = 2;
          4'b0110: out = 6;
          4'b0111: out = 8;
          4'b1000: out = 0;
          4'b1001: out = 13;
          4'b1010: out = 3;
          4'b1011: out = 4;
          4'b1100: out = 14;
          4'b1101: out = 7;
          4'b1110: out = 5;
          4'b1111: out = 11;
        endcase
      2'b01:
        case (in[5:2])
          4'b0000: out = 10;
          4'b0001: out = 15;
          4'b0010: out = 4;
          4'b0011: out = 2;
          4'b0100: out = 7;
          4'b0101: out = 12;
          4'b0110: out = 9;
          4'b0111: out = 5;
          4'b1000: out = 6;
          4'b1001: out = 1;
          4'b1010: out = 13;
          4'b1011: out = 14;
          4'b1100: out = 0;
          4'b1101: out = 11;
          4'b1110: out = 3;
          4'b1111: out = 8;
        endcase
      2'b10:
        case (in[5:2])
          4'b0000: out = 9;
          4'b0001: out = 14;
          4'b0010: out = 15;
          4'b0011: out = 5;
          4'b0100: out = 2;
          4'b0101: out = 8;
          4'b0110: out = 12;
          4'b0111: out = 3;
          4'b1000: out = 7;
          4'b1001: out = 0;
          4'b1010: out = 4;
          4'b1011: out = 10;
          4'b1100: out = 1;
          4'b1101: out = 13;
          4'b1110: out = 11;
          4'b1111: out = 6;
        endcase
      2'b11:
        case (in[5:2])
          4'b0000: out = 4;
          4'b0001: out = 3;
          4'b0010: out = 2;
          4'b0011: out = 12;
          4'b0100: out = 9;
          4'b0101: out = 5;
          4'b0110: out = 15;
          4'b0111: out = 10;
          4'b1000: out = 11;
          4'b1001: out = 14;
          4'b1010: out = 1;
          4'b1011: out = 7;
          4'b1100: out = 6;
          4'b1101: out = 0;
          4'b1110: out = 8;
          4'b1111: out = 13;
        endcase
    endcase
  end
endmodule