`timescale 1ns/1ps
`include "../rtl/TopMode.v"

module tb_TopMode;
  reg clk, nrst, start;
  reg [1:0] mode;
  reg [255:0] data_in;
  reg [127:0] key;
  reg [63:0] iv;
  wire [255:0] data_out;
  wire done, busy;

  TopMode uut(
    .clk(clk), .nrst(nrst), .start(start), .mode(mode),
    .data_in(data_in), .key(key), .iv(iv),
    .data_out(data_out), .done(done), .busy(busy)
  );

  always #5 clk = ~clk;   // 100 MHz clock

  // Helper task: wait for 'done' to be asserted
  task wait_done;
    begin
      @(posedge clk);
      while (!done) @(posedge clk);
    end
  endtask

  // --------------------------------------------------------------
  // Test Vector 1 – ECB mode
  // --------------------------------------------------------------
  task test_ecb;
    reg [255:0] expected;
    begin
      $display("\n--- Testing ECB mode ---");
      mode = 2'b00;
      key  = 128'hA4E9432CE07AD076572F7C1513DA495E;
      iv   = 64'h0;
      data_in = {
        64'h12BB6F8DF45EF216,
        64'hBA7BDE0C26FBA7DC,
        64'hD1BF4B48A0F02854,
        64'h9947E3E0C209EE51
      };
      expected = {
        64'h307D644D19BEB557,
        64'h59C0DC3E862B8238,
        64'h7EB35CC8ECE07C78,
        64'h0B8762E0708F1DF1
      };
      start = 1;
      @(posedge clk);
      start = 0;
      wait_done();
      if (data_out === expected)
        $display("ECB test PASSED");
      else begin
        $display("ECB test FAILED");
        $display("Expected: %h", expected);
        $display("Got:      %h", data_out);
        $finish;
      end
    end
  endtask

  // --------------------------------------------------------------
  // Test Vector 2 – CBC mode
  // --------------------------------------------------------------
  task test_cbc;
    reg [255:0] expected;
    begin
      $display("\n--- Testing CBC mode ---");
      mode = 2'b01;
      key  = 128'hFDDF34345EEF082FA42AAB494576EC94;
      iv   = 64'h2B0A1D10B06D3A2C;
      data_in = {
        64'h81A239C31A855554,
        64'h72558978F41CA01A,
        64'h6D841401ED8661BB,
        64'h3222EAA63D9E44A5
      };
      expected = {
        64'h297AB4B44A9BC2FC,
        64'hE63817B28BDDAFD3,
        64'h34AC5E9E57AA9A51,
        64'hF07839AFEB067989
      };
      start = 1;
      @(posedge clk);
      start = 0;
      wait_done();
      if (data_out === expected)
        $display("CBC test PASSED");
      else begin
        $display("CBC test FAILED");
        $display("Expected: %h", expected);
        $display("Got:      %h", data_out);
        $finish;
      end
    end
  endtask

  // --------------------------------------------------------------
  // Test Vector 3 – OFB mode
  // --------------------------------------------------------------
  task test_ofb;
    reg [255:0] expected;
    begin
      $display("\n--- Testing OFB mode ---");
      mode = 2'b10;
      key  = 128'h79AD455EADF8B6D920BADAD96110683D;
      iv   = 64'h3D1EF94987749B72;
      data_in = {
        64'h8D166A08A65AA998,
        64'h781AA16D615C9BA0,
        64'h2F66D7EEB7001EAE,
        64'h4D9CA6F1A93FAD05
      };
      expected = {
        64'h54E4ABC45BA14D1D,
        64'hE80E5F020DBF64CF,
        64'h9EF1A890E81103AE,
        64'hA54DBF8F287FFEBD
      };
      start = 1;
      @(posedge clk);
      start = 0;
      wait_done();
      if (data_out === expected)
        $display("OFB test PASSED");
      else begin
        $display("OFB test FAILED");
        $display("Expected: %h", expected);
        $display("Got:      %h", data_out);
        $finish;
      end
    end
  endtask

  // --------------------------------------------------------------
  // Main test sequence
  // --------------------------------------------------------------
  initial begin
    clk = 0;
    nrst = 0;
    #10 nrst = 1;
    #10;
    test_ecb();
    test_cbc();
    test_ofb();
    $display("\nAll tests passed successfully.");
    $finish;
  end

  initial $monitor($time, " busy=%b done=%b data_out=%h", busy, done, data_out);
endmodule