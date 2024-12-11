`timescale 1ns/1ps
`include "top.v"


module test_top();
	reg  [	3	:	0	]	a;
	reg  [	3	:	0	]	b;
	reg 	cin;
	wire [	3	:	0	]	sum;
	wire	cout;
	top_module top_inst(
		.a		(		a),
		.b		(		b),
		.cin		(		cin),
		.sum		(		sum),
		.cout		(		cout)
	);

	integer a_tbInst_iter, b_tbInst_iter, cin_tbInst_iter;

	initial begin
		a = 4'b0;
		for(a_tbInst_iter = 0; a_tbInst_iter < 16; a_tbInst_iter = a_tbInst_iter + 1) begin
			b = 4'b0;
			for(b_tbInst_iter = 0; b_tbInst_iter < 16; b_tbInst_iter = b_tbInst_iter + 1) begin
				cin = 1'b0;
				for(cin_tbInst_iter = 0; cin_tbInst_iter < 2; cin_tbInst_iter = cin_tbInst_iter + 1) begin
					#5;
					cin = cin + 1;
				end
				b = b + 1;
			end
			a = a + 1;
		end
	end
endmodule