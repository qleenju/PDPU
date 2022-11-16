//Author: Qiong Li
//Date: 2022-09-24
//Intro: 在posit_decoder.sv的基础上改进

module pdpu_posit_decoder #(
    parameter int unsigned n = 16,
    parameter int unsigned es = 1,
    //don't change
    parameter int unsigned nd = posit_pkg::clog2(n-1),
    parameter int unsigned EXP_WIDTH = nd+es,       // not include sign bit
    parameter int unsigned MANT_WIDTH = n-es-3      // not include implicit bit
)(
    input logic [n-1:0] operand_i,
    output logic sign_o,
    output logic signed [EXP_WIDTH:0] rg_exp_o,  
    output logic [MANT_WIDTH:0] mant_norm_o
);

    // ---------------
    // two's complement if negative
    // ---------------
    logic sign;
    logic [n-2:0] operand_value;

    assign sign = operand_i[n-1];
    assign operand_value = sign ? (~operand_i[n-2:0]+1) : operand_i[n-2:0];
    
    // ---------------
    // Leading Zero Count
    // ---------------
    logic regS;
    logic [n-2:0] lzc_operand;
    logic [nd-1:0] leading_zero_count;
    // lzc_zeroes = 1 if input is all 0s
    logic lzc_zeroes;

    assign regS = operand_value[n-2];
    assign lzc_operand = regS ? (~operand_value) : operand_value;

    lzc #(
        .WIDTH(n-1),
        .MODE(1'b1)    //mode=1 means "counting leading zeroes"
    ) u_lzc(
        .in_i(lzc_operand),
        .cnt_o(leading_zero_count),
        .empty_o(lzc_zeroes)
    );

    logic [nd-1:0] runlength;
    // bitwidth of regime field
    logic [nd-1:0] regime_bits;
    // k value represented by regime field
    logic signed [nd:0] regime_k;

    assign runlength = lzc_zeroes ? (n-1) : leading_zero_count;
    assign regime_bits = lzc_zeroes ? (n-1) : (leading_zero_count+1);
    assign regime_k = regS ? ({1'b0,runlength-1}) : ({1'b1,~runlength+1});

    // ---------------
    // left Shift regime field
    // ---------------
    logic [n-2:0] op_no_rg;

    barrel_shifter #(
        .WIDTH(n-1),
        .SHIFT_WIDTH(nd),
        .MODE(1'b0)
    ) u_barrel_shifter(
        .operand_i(operand_value),
        .shift_amount(regime_bits),
        .result_o(op_no_rg)
    );

    // ---------------
    // Sign
    // ---------------
    assign sign_o = sign;

    // ---------------
    // Exponent
    // ---------------
    logic [es:0] exp;
    if(es==0) begin
        assign exp = 0;
    end
    else begin
        assign exp = op_no_rg[n-2:n-2-es+1];
    end
    
    assign rg_exp_o = regime_k << es | exp;

    // ---------------
    // Mantissa
    // ---------------
    logic implicit_bit;
    
    assign implicit_bit = |operand_i[n-2:0];
    assign mant_norm_o = {implicit_bit, op_no_rg[n-2-es:2]};

endmodule