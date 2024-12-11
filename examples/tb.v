`timescale 1ns / 1ps
`include "top.v"

module tb_top_module ();
    reg [3:0] a, b;
    reg        cin;
    wire [3:0] sum;
    wire       cout;
    top_module top_module_inst (
        .a   (a),
        .b   (b),
        .sum (sum),
        .cin (cin),
        .cout(cout)
    );
    integer i, j;
    initial begin
        cin = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                #5;
                a = i;
                b = j;
            end
        end
        cin = 1'b1;
        for (i = 0; i < 16; i = i + 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                #5;
                a = i;
                b = j;
            end
        end
    end

endmodule
