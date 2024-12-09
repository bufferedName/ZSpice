module top_module(input [3:0] a,b,
                  input cin,
                  output[3:0] sum,
                  output cout);
    wire [3:0]carry_out,carry_in;
    assign cout          = carry_out[3];
    assign carry_in[0]   = cin;
    assign carry_in[3:1] = carry_out[2:0];
    add1 add[3:0](.a(a),.b(b),.cin(carry_in),.cout(carry_out),.sum(sum));
endmodule