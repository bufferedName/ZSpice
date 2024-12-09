module top_module(
	input a_0 ,b_0,
	input a_1 ,b_1,
	input a_2 ,b_2,
	input a_3 ,b_3,
input cin,                  
	output sum_0,
	output sum_1,
	output sum_2,
	output sum_3,
output cout

);
    wire [3:0]carry_out,carry_in;
    assign cout = carry_out_3;

    assign carry_in_0 = cin;

    assign carry_in_1 = carry_out_0;
    assign carry_in_2 = carry_out_1;
    assign carry_in_3 = carry_out_2;

    add1 add_0(
    	.cout(carry_out_0),
    	.b(b_0),
    	.sum(sum_0),
    	.a(a_0),
    	.cin(carry_in_0)
    );
    add1 add_1(
    	.cout(carry_out_1),
    	.b(b_1),
    	.sum(sum_1),
    	.a(a_1),
    	.cin(carry_in_1)
    );
    add1 add_2(
    	.cout(carry_out_2),
    	.b(b_2),
    	.sum(sum_2),
    	.a(a_2),
    	.cin(carry_in_2)
    );
    add1 add_3(
    	.cout(carry_out_3),
    	.b(b_3),
    	.sum(sum_3),
    	.a(a_3),
    	.cin(carry_in_3)
    );


endmodule


