//Author: Qiong Li
//Date: 2022-03-02
//功能：根据结果的sign/k_sgn/exp/mant值重新编码为格式为(n, es)的posit数据

module posit_encoder #(
    parameter int unsigned n = 16,
    parameter int unsigned es = 1,
    parameter int unsigned MANT_WIDTH = n-es-3,
    parameter int unsigned K_WIDTH = posit_pkg::clog2(n-1)
) (
    input logic sign_i,
    input logic signed [K_WIDTH:0] k_sgn_i,
    input logic [es:0] exp_i,
    input logic [MANT_WIDTH:0] mant_norm_i,    //include "hidden bit"

    output logic [n-1:0] result_o
);
    //special case
    logic input_is_zero;
    assign input_is_zero = ~mant_norm_i[MANT_WIDTH];

    //remove hidden bit
    logic [MANT_WIDTH-1:0] mantissa;
    assign mantissa = mant_norm_i[MANT_WIDTH-1:0];

    //determine regime
    logic sign_k;
    logic [K_WIDTH:0] regime_bits;
    logic [n-2:0] regime,regime_temp;

    assign sign_k = k_sgn_i[K_WIDTH];
    assign regime_bits = sign_k ? (-k_sgn_i+1) : (k_sgn_i+2);
    assign regime_temp = 1;
    assign regime = sign_k ? regime_temp : ~regime_temp; 

    //consider overflow of regime
    logic value_is_special;
    logic [n-2:0] special_value;
    logic [K_WIDTH:0] regime_bits_new;
    always_comb begin
        if(regime_bits>n-1) begin
            value_is_special = 1'b1;
            special_value = sign_k ? 1 : '1;
            regime_bits_new = n-1;
        end
        else begin
            value_is_special = 1'b0;
            special_value = '0;
            regime_bits_new = regime_bits;
        end
    end

    //Regime-Exp-Mantissa
    localparam int unsigned REM_WIDTH = (n-1) + es + MANT_WIDTH;
    localparam int unsigned LZC_WIDTH = posit_pkg::clog2(n-1);
    localparam int unsigned ROUND_WIDTH = REM_WIDTH - (n-1);    //舍入的位宽
    
    logic [n-2+es:0] regime_exp;
    assign regime_exp = (regime<<es) | exp_i;

    logic [REM_WIDTH-1:0] rem,rem_shifted;
    assign rem = {regime_exp, mantissa};

    logic [LZC_WIDTH-1:0] shift_amount;
    assign shift_amount = n - 1 - regime_bits_new;
    barrel_shifter #(
        .WIDTH(REM_WIDTH),
        .SHIFT_WIDTH(LZC_WIDTH),
        .MODE(1'b0)
    ) u_barrel_shifter(
        .operand_i(rem),
        .shift_amount(shift_amount),
        .result_o(rem_shifted)
    );

    //Absolute Value
    logic [n-2:0] abs_value;
    assign abs_value = rem_shifted[REM_WIDTH-1:ROUND_WIDTH];
    
    //rounding
    logic [ROUND_WIDTH-1:0] overflow;
    logic bitsNPlusOne,bitsMore,round_value;

    assign overflow = rem_shifted[ROUND_WIDTH-1:0];
    assign bitsNPlusOne = overflow[ROUND_WIDTH-1];
    assign bitsMore = |overflow[ROUND_WIDTH-2:0];
    assign round_value = (bitsNPlusOne & bitsMore) | (bitsNPlusOne & abs_value[0]);
    
    //if regime overflow
    logic [n-2:0] abs_value_new;
    assign abs_value_new = value_is_special ? special_value : (abs_value+round_value);

    //two's complement
    logic [n-1:0] normal_result;
    assign normal_result = sign_i ? {sign_i,~abs_value_new+1} : {sign_i,abs_value_new};
    assign result_o = input_is_zero ? '0 : normal_result;
endmodule