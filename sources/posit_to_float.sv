//Author: Qiong Li
//Date: 2022-03-28
//功能: Posit数据格式到64-bit浮点格式的转换，应用于仿真过程中

module posit_to_float#(
    parameter int unsigned n = 16,
    parameter int unsigned es = 1,
    //don't change
    parameter int unsigned FP_WIDTH = 64
)(
    input logic [n-1:0] operand_i,
    output logic [FP_WIDTH-1:0] result_o
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
    fp_t result,special_result;


    // ----------------
    // Special Cases
    // ----------------
    logic result_is_special;
    always_comb begin
        //default assignments
        special_result = '{sign: 1'b0, exponent: '1, mantissa: 1<<(FP_MANT_WIDTH-1)};  //qNaN
        result_is_special = 1'b0;
        if (operand_i == 0) begin
            result_is_special = 1'b1;
            special_result = '0;
        end
        else if (operand_i == 1<<(n-1)) begin
            result_is_special = 1'b1;
        end
    end

    // ----------------
    // two's complement
    // ----------------
    logic operand_sign;
    logic [n-2:0] operand_value;
    assign operand_sign = operand_i[n-1];
    assign operand_value = operand_sign ? (~operand_i[n-2:0]+1) : operand_i[n-2:0];

    // ----------------
    // leading zero count
    // ----------------
    localparam int unsigned LOWER_SUM_WIDTH = n-1;
    logic [LOWER_SUM_WIDTH-1:0]  sum_lower;
    localparam int unsigned LZC_RESULT_WIDTH = posit_pkg::clog2(LOWER_SUM_WIDTH);
    logic [LZC_RESULT_WIDTH-1:0] leading_zero_count;
    logic lzc_zeroes;
    logic regSA;

    assign regSA = operand_value[n-2];
    assign sum_lower = regSA ? ~operand_value : operand_value;
    lzc #(          
        .WIDTH ( LOWER_SUM_WIDTH ),
        .MODE  ( 1               )  //MODE=1 counts leading zeroes
    ) i_lzc (
        .in_i    ( sum_lower          ),
        .cnt_o   ( leading_zero_count ),
        .empty_o ( lzc_zeroes         )
    );


    // ----------------
    // compute runlength and k_sgn
    // ----------------
    localparam int unsigned EXP_WIDTH = LZC_RESULT_WIDTH + es;
    logic [EXP_WIDTH-1:0] run_length;
    logic signed [EXP_WIDTH:0] k_sgn;

    assign run_length = lzc_zeroes ? LOWER_SUM_WIDTH : leading_zero_count;
    assign k_sgn = regSA ? (signed'({1'b0,run_length-1})) : (signed'({1'b1,~run_length+1}));

    // ----------------
    // compute result
    // ----------------
    localparam int unsigned MANT_WIDTH = n-es-3;
    logic [es:0] p_exponent;
    logic [MANT_WIDTH-1:0] p_mantissa;
    logic [FP_MANT_WIDTH-1:0] f_mantissa;
    logic [MANT_WIDTH+es-1:0] exp_mant;

    assign exp_mant = operand_value << (run_length-lzc_zeroes-1);
    assign p_exponent = exp_mant >> MANT_WIDTH;
    assign p_mantissa = exp_mant[MANT_WIDTH-1:0];

    assign result.sign = operand_sign;
    assign result.exponent = signed'(k_sgn<<es) + signed'({1'b0,p_exponent+BIAS});
    assign f_mantissa = p_mantissa;

    if (FP_MANT_WIDTH > MANT_WIDTH) begin
        assign result.mantissa = f_mantissa << (FP_MANT_WIDTH - MANT_WIDTH);
    end
    else begin
        assign result.mantissa = p_mantissa[MANT_WIDTH-1:MANT_WIDTH-FP_MANT_WIDTH];
    end


    // ----------------
    // select output
    // ----------------
    assign result_o = result_is_special ? special_result : result;

endmodule