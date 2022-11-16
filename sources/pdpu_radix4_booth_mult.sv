//Author: Qiong Li
//Date: 2022-04-08
//功能：乘法器，基于：
//1. 改进符号位扩展的radix-4 booth multiplier
//2. 3:2 CSA&4:2 CSA迭代的wallace tree

module pdpu_radix4_booth_mult #(
    parameter int unsigned WIDTH_A = 16,
    parameter int unsigned WIDTH_B = 16,
    //don't change
    parameter int unsigned WIDTH_O = WIDTH_A + WIDTH_B
)(
    input logic [WIDTH_A-1:0] operand_a,
    input logic [WIDTH_B-1:0] operand_b,
    output logic [WIDTH_O-1:0] sum,
    output logic [WIDTH_O-1:0] carry
);
    localparam int unsigned COUNT = (WIDTH_B+2)/2;
    
    logic [COUNT-1:0][WIDTH_O-1:0] partial_prods;
    gen_prods #(
        .WIDTH_A(WIDTH_A),
        .WIDTH_B(WIDTH_B)
    ) u_gen_prods(
        .operand_a(operand_a),
        .operand_b(operand_b),
        .partial_prods(partial_prods)
    );

    csa_tree #(
        .N(COUNT),
        .IN_WIDTH(WIDTH_O),
        .OUT_WIDTH(WIDTH_O)
    ) u_csa_tree(
        .operands_i(partial_prods),
        .sum_o(sum),
        .carry_o(carry)
    );
endmodule