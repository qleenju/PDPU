//Author: Qiong Li
//Date: 2022-04-08
//功能：产生部分积（应用改进radix-4的符号位扩展优化方法）

module gen_product #(
    parameter int unsigned WIDTH = 16    //Bitwidth of the multiplicand
)(
    input logic [WIDTH-1:0] multiplicand_i,
    input logic [2:0] code,
    output logic [WIDTH:0] partial_prod,
    output sign
);
    logic neg,zero,one,two;
    booth_encoder u_booth_encoder(
        .code(code),
        .neg(neg),
        .zero(zero),
        .one(one),
        .two(two)
    );

    logic [WIDTH:0] prod_pre;
    always_comb begin
        if(one) begin
            prod_pre = multiplicand_i;
        end
        else if(two) begin
            prod_pre = multiplicand_i << 1;
        end
        else begin
            prod_pre = '0;
        end
    end
    //减少的主要是符号位扩展的工作，取反依旧需要进行
    assign partial_prod = neg ? (~prod_pre) : prod_pre;
    assign sign = neg;
endmodule