module add1(
input a,             
input b,             
input cin,             
output sum,             
output cout

);
    wire s,c1,c2;
    hadd hadd1(
    	.a(a),
    	.b(b),
    	.s(s),
    	.c(c1)
    );
    hadd hadd2(
    	.a(s),
    	.b(cin),
    	.s(sum),
    	.c(c2)
    );
    assign cout = c1 | c2;


endmodule


module hadd(
input a,
input b,
output s,
output c

);
    assign s = a ^ b;

    assign c = a & b;


endmodule


