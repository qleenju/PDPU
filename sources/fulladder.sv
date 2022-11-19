// full adder, the basic module that constitutes the 3:2 compressor
module fulladder(
    input logic x,y,z,
    output logic sum,carry
);
    assign sum = (x ^ y ) ^ z;
    assign carry = ((x ^ y) & z) | (x & y);
endmodule