//Author: Qiong Li
//Date: 2022-03-28
//功能: 64-bit浮点格式到Posit数据格式的转换，应用于仿真过程中

module float_to_posit#(
    parameter int unsigned n = 16,
    parameter int unsigned es = 1,

    //don't change
    parameter int unsigned FP_WIDTH = 64
)(
    input logic [FP_WIDTH-1:0] operand_i,
    output logic [n-1:0] result_o
);


    // ----------
    // Constants
    // ----------
    localparam int unsigned FP_EXP_WIDTH = 11;
    localparam int unsigned FP_MANT_WIDTH = 52;
    localparam int unsigned BIAS = 1023;


    // ----------------
    // Type definition
    // ----------------
    typedef struct packed {
        logic                sign;
        logic [FP_EXP_WIDTH-1:0] exponent;
        logic [FP_MANT_WIDTH-1:0] mantissa;
    } fp_t;

    fp_t operand;
    assign operand = operand_i;


    // ----------------
    // Special Cases
    // ----------------
    logic result_is_special;
    logic [n-1:0] special_result;
    always_comb begin
        result_is_special = 1'b0;
        special_result = 1<<(n-1);
        if (operand.exponent==0 && operand.mantissa==0) begin
            result_is_special = 1'b1;
            special_result = '0;
        end
        if(operand.exponent == '1) begin
            result_is_special = 1'b1;
        end
    end


    // ----------------
    // compute k/exp/mant
    // ----------------
    logic p_sign;
    logic signed [FP_EXP_WIDTH-1:0] f_exponent;
    logic signed [FP_EXP_WIDTH-1-es:0] k_sgn;
    logic [es:0] p_exponent;
    logic [FP_MANT_WIDTH-1:0] f_mantissa;

    assign p_sign = operand.sign;
    assign f_exponent = signed'({1'b0,operand.exponent}) - signed'({1'b0,BIAS});
    assign k_sgn = f_exponent[FP_EXP_WIDTH-1:es];
    assign p_exponent = f_exponent[es:0] & ~(1<<es);
    assign f_mantissa = operand.mantissa;
    

    // ----------------
    // compute regime
    // ----------------
    logic [n-2:0] p_regime;
    logic [FP_EXP_WIDTH-1-es:0] p_regime_bits, p_new_regime_bits;
    logic sign_k;
    //logic [n-2:0] regime_temp = 1;
    logic [n-2:0] regime_temp;
    assign regime_temp = 1;
    assign sign_k = k_sgn[FP_EXP_WIDTH-1-es];
    assign p_regime_bits = sign_k ? (-k_sgn+1) : (k_sgn+2);
    assign p_regime = sign_k ? regime_temp : ~regime_temp;

    // ----------------
    // consider overflow of regime
    // ----------------
    logic [n-2:0] p_special_value;
    logic value_is_special;
    always_comb begin
        if (p_regime_bits>n-1) begin
            value_is_special = 1'b1;
            p_special_value = sign_k ? 1 : '1;
            p_new_regime_bits = n-1;
        end
        else begin
            value_is_special = 1'b0;
            p_special_value = '0;
            p_new_regime_bits = p_regime_bits;
        end
    end

    // ----------------
    // compute normal result
    // ----------------
    localparam int unsigned TEMP_WIDTH = (n-1) + es + FP_MANT_WIDTH;
    localparam int unsigned OVER_WIDTH = TEMP_WIDTH - (n-1);
    logic [n+es-2:0] p_regime_exp;
    logic [TEMP_WIDTH-1:0] p_value_temp,p_value_temp2;
    logic [n-2:0] p_abs_value;

    assign p_regime_exp = (p_regime<<es) | p_exponent;
    assign p_value_temp = {p_regime_exp, f_mantissa};
    //[Note]动态移位
    assign p_value_temp2 = p_value_temp << (n-1-p_new_regime_bits);

    assign p_abs_value = p_value_temp2[TEMP_WIDTH-1:OVER_WIDTH];

    //rounding
    logic [OVER_WIDTH-1:0] p_overflow;
    logic round_value;
    logic bitsNPlusOne,bitsMore;

    assign p_overflow = p_value_temp2[OVER_WIDTH-1:0];  //regime溢出在上文已考虑过
    assign bitsNPlusOne = p_overflow[OVER_WIDTH-1];
    assign bitsMore = |p_overflow[OVER_WIDTH-2:0];

    always_comb begin
        round_value = 1'b0;
        //round to nearest, tie to even
        if ((bitsNPlusOne & p_abs_value[0]) | (bitsNPlusOne & bitsMore)) begin
            round_value = 1'b1;
        end
    end


    // ----------------
    // select output
    // ----------------
    logic [n-2:0] p_value;
    logic [n-1:0] result;
    logic [n-2:0] p_abs_value2;
    assign p_abs_value2 = value_is_special ? p_special_value : (p_abs_value+round_value);

    assign p_value = p_sign ? (~p_abs_value2+1) : p_abs_value2;
    assign result = {p_sign, p_value};
    assign result_o = result_is_special ? special_result : result;
endmodule