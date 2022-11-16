//Author: Qiong Li
//Date: 2022-03-01
//功能：Posit译码器，提取输入数据的Regime/Exponent/Mantissa值

module posit_decoder #(
    parameter int unsigned n = 16,
    parameter int unsigned es = 1,
    //don't change
    parameter int unsigned LZC_WIDTH = posit_pkg::clog2(n-1),
    parameter int unsigned MANT_WIDTH = n-es-3     //not include "hidden bit"
)(
    input logic [n-1:0] operand_i,
    output logic sign_o,
    output logic signed [LZC_WIDTH:0] k_sgn_o,
    output logic [es:0] exp_o,
    output logic [MANT_WIDTH:0] mant_norm_o
);
    //---------------
    //special cases (not include NaR(100...000))
    //---------------
    logic input_is_zero;
    assign input_is_zero = ~(|operand_i);

    //---------------
    //two's complementation if negative
    //---------------
    logic sign;
    logic [n-2:0] operand_value;
    assign sign = operand_i[n-1];
    assign operand_value = sign ? (~operand_i[n-2:0]+1) : operand_i[n-2:0];
    
    //---------------
    //Leading Zero Count
    //---------------
    logic regS;
    logic [n-2:0] sum_lower;
    logic [LZC_WIDTH-1:0] leading_zero_count;
    logic lzc_zeroes;

    assign regS = operand_value[n-2];
    assign sum_lower = regS ? (~operand_value) : operand_value;

    lzc #(
        .WIDTH(n-1),
        .MODE(1)    //mode=1 means "counting leading zeroes"
    ) u_lzc(
        .in_i(sum_lower),
        .cnt_o(leading_zero_count),
        .empty_o(lzc_zeroes)
    );

    logic [LZC_WIDTH-1:0] runlength;
    assign runlength = lzc_zeroes ? n-1 : leading_zero_count;   //lzc模块针对非2幂次的全0存在BUG

    //---------------
    //Extract Sign/Regime/Exponent/Mantissa
    //---------------
    //移除Regime部分
    logic [LZC_WIDTH-1:0] shift_amount;
    logic [n-2:0] shift_result;
    logic [MANT_WIDTH+es-1:0] exp_mant; //(n-es-3+es)=n-3
    
    assign shift_amount = runlength-1;
    barrel_shifter #(
        .WIDTH(n-1),
        .SHIFT_WIDTH(LZC_WIDTH),
        .MODE(1'b0)
    ) u_barrel_shifter(
        .operand_i(operand_value),
        .shift_amount(shift_amount),
        .result_o(shift_result)
    );
    assign exp_mant = shift_result[MANT_WIDTH+es-1:0];

    //---------------
    //Output
    //---------------
    assign sign_o = sign;
    assign k_sgn_o = regS ? ({1'b0,runlength-1}) : ({1'b1,~runlength+1});
    assign exp_o = exp_mant >> MANT_WIDTH;
    assign mant_norm_o = (input_is_zero) ? '0 : {1'b1,exp_mant[MANT_WIDTH-1:0]};
endmodule