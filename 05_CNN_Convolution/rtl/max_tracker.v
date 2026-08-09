// =============================================================
// max_tracker.v
// Keeps a running max convolution value and the (x,y) at which it
// occurred. This is the whole reason you never have to store the
// 53x57 output map -- just this one register set per kernel.
// =============================================================
module max_tracker #(
    parameter ACC_W   = 24,
    parameter COORD_W = 6
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear,     // pulse: start a fresh frame
    input  wire                     valid,     // conv_sum is a completed dot product this cycle
    input  wire signed [ACC_W-1:0]  conv_sum,
    input  wire [COORD_W-1:0]       cur_x,
    input  wire [COORD_W-1:0]       cur_y,
    output reg  signed [ACC_W-1:0]  max_val,
    output reg  [COORD_W-1:0]       max_x,
    output reg  [COORD_W-1:0]       max_y
);
    localparam signed [ACC_W-1:0] MOST_NEG = {1'b1, {(ACC_W-1){1'b0}}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_val <= MOST_NEG;
            max_x   <= {COORD_W{1'b0}};
            max_y   <= {COORD_W{1'b0}};
        end else if (clear) begin
            max_val <= MOST_NEG;
            max_x   <= {COORD_W{1'b0}};
            max_y   <= {COORD_W{1'b0}};
        end else if (valid && (conv_sum > max_val)) begin
            max_val <= conv_sum;
            max_x   <= cur_x;
            max_y   <= cur_y;
        end
    end
endmodule
