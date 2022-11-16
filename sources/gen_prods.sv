//Author: Qiong Li
//Date: 2022-04-08
//功能：输入乘数及被乘数，利用radix-4 booth原理及改进的符号位扩展方法输出所有部分积
//备注：本设计适用于基于符号扩展改进的无符号乘法运算，可参考论文"Sign Extension in Booth Multipliers"

module gen_prods #(
    parameter int unsigned WIDTH_A = 16,
    parameter int unsigned WIDTH_B = 16,
    //don't change
    parameter int unsigned COUNT = (WIDTH_B+2)/2,
    parameter int unsigned WIDTH_O = WIDTH_A + WIDTH_B
)(
    input logic [WIDTH_A-1:0] operand_a,
    input logic [WIDTH_B-1:0] operand_b,
    //[Note]:很多部分积前面都是补0，后续是否可以优化？
    output [COUNT-1:0][WIDTH_O-1:0] partial_prods
);
    logic [WIDTH_B+2:0] multiplier;
    logic [COUNT-1:0][2:0] codes;
    logic [COUNT-1:0][WIDTH_A:0] temp_prods;
    logic [COUNT-1:0] signs;

    assign multiplier = {2'b00,operand_b,1'b0};
    assign codes[0] = multiplier[2:0];
    gen_product #(
        .WIDTH(WIDTH_A)
    ) u0_gen_product(
        .multiplicand_i(operand_a),
        .code(codes[0]),
        .partial_prod(temp_prods[0]),
        .sign(signs[0])
    );
    assign partial_prods[0] = {~signs[0], signs[0], signs[0], temp_prods[0]};

    generate
        genvar i;
        for(i=1;i<COUNT-1;i++) begin
            assign codes[i] = multiplier[2*i+2:2*i];
            gen_product #(
                .WIDTH(WIDTH_A)
            ) u_gen_product(
                .multiplicand_i(operand_a),
                .code(codes[i]),
                .partial_prod(temp_prods[i]),
                .sign(signs[i])
            );
            assign partial_prods[i] = {1'b1,~signs[i],temp_prods[i],1'b0,signs[i-1]} << (2*i-2);
        end
    endgenerate

    assign codes[COUNT-1] = multiplier[2*COUNT:2*COUNT-2];
    gen_product #(
        .WIDTH(WIDTH_A)
    ) u2_gen_product(
        .multiplicand_i(operand_a),
        .code(codes[COUNT-1]),
        .partial_prod(temp_prods[COUNT-1]),
        .sign(signs[COUNT-1])
    );
    assign partial_prods[COUNT-1] = {temp_prods[COUNT-1],1'b0,signs[COUNT-2]} << (2*COUNT-4);

endmodule