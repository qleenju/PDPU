// 3:2 compressor, compressing 3 inputs into sum and carry
module compressor_3to2 #(
    parameter int unsigned WIDTH_I = 8,
    parameter int unsigned WIDTH_O = WIDTH_I + pdpu_pkg::clog2(3)
)(
    input logic [2:0][WIDTH_I-1:0] operands_i,
    output logic [WIDTH_O-1:0] sum_o,
    output logic [WIDTH_O-1:0] carry_o
);
    logic [WIDTH_I-1:0] sum;
    logic [WIDTH_I-1:0] carry;
    generate
        genvar i;
        for(i=0;i<WIDTH_I;i++) begin
            fulladder u_fulladder(
                .x(operands_i[0][i]),
                .y(operands_i[1][i]),
                .z(operands_i[2][i]),
                .s(sum[i]),
                .c(carry[i])
            );
        end
    endgenerate

    assign sum_o = sum;
    assign carry_o = {1'b0,carry,1'b0};
endmodule