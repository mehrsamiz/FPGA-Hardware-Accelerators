`timescale 1ns / 1ps

module conv_axi_adaptor #(
    parameter BURST_REGS = 32,                 // 32 Registers
    parameter IMG_BYTES  = 4096                // 64x64 frame size
)(
    input  wire                         ACLK,
    input  wire                         ARESETN,
    input  wire                         start,
    input  wire [(BURST_REGS*32)-1 : 0] reg_flat,  // 1024-bit packed vector
    output wire                         busy,
    output wire                         done,
    output wire [5:0]                   x7, y7,
    output wire signed [23:0]           val7,
    output wire [5:0]                   x8, y8,
    output wire signed [23:0]           val8
);

    localparam BYTES_PER_BURST = BURST_REGS * 4;           // 128 Bytes
    localparam NUM_BURSTS      = IMG_BYTES / BYTES_PER_BURST; // 32 Bursts

    reg       draining;
    reg [4:0] reg_idx;     // 0..31 register counter
    reg [1:0] byte_idx;    // 0..3 byte counter within register
    reg [5:0] burst_cnt;   // 0..31 burst counter

    wire pixel_ready;
    wire pixel_valid = draining;

    // Standard Verilog-2001 variable indexed part-select
    wire [7:0] pixel_data = reg_flat[(reg_idx * 32 + byte_idx * 8) +: 8];

    // Assert frame_start ONLY on the very first byte of burst 0
    wire frame_start = start && (burst_cnt == 6'd0);

    assign busy = draining;

    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            draining  <= 1'b0;
            reg_idx   <= 5'd0;
            byte_idx  <= 2'd0;
            burst_cnt <= 6'd0;
        end else if (start && !draining) begin
            draining  <= 1'b1;
            reg_idx   <= 5'd0;
            byte_idx  <= 2'd0;
        end else if (draining && pixel_valid && pixel_ready) begin
            if (byte_idx == 2'd3) begin
                byte_idx <= 2'd0;
                if (reg_idx == BURST_REGS - 1) begin
                    draining  <= 1'b0;
                    burst_cnt <= (burst_cnt == NUM_BURSTS - 1) ? 6'd0 : (burst_cnt + 1'b1);
                end else begin
                    reg_idx <= reg_idx + 1'b1;
                end
            end else begin
                byte_idx <= byte_idx + 1'b1;
            end
        end
    end

    // Direct instantiation of working convolution core
    conv_top u_conv (
        .clk         (ACLK),
        .rst_n       (ARESETN),
        .frame_start (frame_start),
        .pixel_valid (pixel_valid),
        .pixel_data  (pixel_data),
        .pixel_ready (pixel_ready),
        .done        (done),
        .x7          (x7),
        .y7          (y7),
        .val7        (val7),
        .x8          (x8),
        .y8          (y8),
        .val8        (val8)
    );

endmodule