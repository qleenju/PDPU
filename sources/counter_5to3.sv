// 5:3 counter, the basic module that constitutes the 4:2 compressor
module counter_5to3(
    input logic x1,x2,x3,x4,cin,
    output logic sum,carry,cout
);
    assign sum = x1 ^ x2 ^ x3 ^ x4 ^ cin;
    assign cout = (x1 ^ x2) & x3 | ~(x1 ^ x2) & x1;
    assign carry = (x1 ^ x2 ^ x3 ^ x4) & cin | ~(x1 ^ x2 ^ x3 ^ x4) & x4;
endmodule