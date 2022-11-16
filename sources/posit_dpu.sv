//Author: Qiong Li
//Date: 2022-03-26
//功能: 参数化的posit的点积运算单元设计

/*Note:
    1. The default rounding mode is RNE
    2. The format of the input posit vector is consistent: posit(n_i, es)
    3. ......
*/

module posit_dpu #(
    parameter int unsigned N = 4,       //Size of Posit Dot Product Unit
    parameter int unsigned n_i = 8,     //Bit Width of input data
    parameter int unsigned es_i = 1,    //es of input posit data
    parameter int unsigned n_o = 16,    //Bit Width of output data
    parameter int unsigned es_o = 1,    //es of output posit data
    parameter int unsigned ALIGN_WIDTH = n_o

)(
    input logic [N-1:0][n_i-1:0] inA,
    input logic [N-1:0][n_i-1:0] inB,
    output logic [n_o-1:0] result_o
);

    //----------
    //local parameters
    //----------
    localparam int unsigned LOWER_SUM_WIDTH = n_i-1;
    localparam int unsigned LZC_RESULT_WIDTH = posit_pkg::clog2(LOWER_SUM_WIDTH);
    localparam int unsigned EXP_WIDTH = LZC_RESULT_WIDTH + 1 + es_i;
    localparam int unsigned MANT_WIDTH = n_i-es_i-3;    //The maximum possible bit width of mantissa (not include hidden bit)
    localparam int unsigned MSB_BITS = posit_pkg::clog2(N);       //The bit width of carry
    //localparam int unsigned LSB_BITS = 1;               //[Note]可以调整LSB_BITS的大小以平衡精度与位宽开销
    localparam int unsigned MUL_WIDTH = 2*(MANT_WIDTH+1);
    //localparam int unsigned ALIGN_WIDTH = posit_pkg::maximum(n_o+1, MUL_WIDTH + LSB_BITS);
    localparam int unsigned SUM_WIDTH = ALIGN_WIDTH + MSB_BITS;

    //----------
    //Decode
    //----------
    logic [N-1:0] signs_a, signs_b;
    logic signed [N-1:0][LZC_RESULT_WIDTH:0] k_sgn_a, k_sgn_b;
    logic [N-1:0][es_i:0] exps_a, exps_b;
    logic [N-1:0][MANT_WIDTH:0] mants_norm_a, mants_norm_b;

    generate
        genvar i;
        for(i=0;i<N;i++) begin: decode
            posit_decoder #(
                .n(n_i),
                .es(es_i)
            )ua_posit_decoder(
                .operand_i(inA[i]),
                .sign_o(signs_a[i]),
                .k_sgn_o(k_sgn_a[i]),
                .exp_o(exps_a[i]),
                .mant_norm_o(mants_norm_a[i])
            );

            posit_decoder #(
                .n(n_i),
                .es(es_i)
            )ub_posit_decoder(
                .operand_i(inB[i]),
                .sign_o(signs_b[i]),
                .k_sgn_o(k_sgn_b[i]),
                .exp_o(exps_b[i]),
                .mant_norm_o(mants_norm_b[i])
            );
        end
    endgenerate


    //----------
    //mantissa multiplication
    //----------
    logic [N-1:0] signs_c;
    logic [N-1:0][MUL_WIDTH-1:0] mul_sum, mul_carry;
    logic [N-1:0][MUL_WIDTH-1:0] mants_norm_c;
    assign signs_c = signs_a ^ signs_b;

    generate
        genvar j;
        for(j=0;j<N;j++) begin: multiplication
            mul_booth_wallace #(
                .WIDTH_A(MANT_WIDTH+1),
                .WIDTH_B(MANT_WIDTH+1)
            ) u_mul_booth_wallace(
                .operand_a(mants_norm_a[j]),
                .operand_b(mants_norm_b[j]),
                .sum(mul_sum[j]),
                .carry(mul_carry[j])
            );
        end
    endgenerate

    generate
        genvar v;
        for(v=0;v<N;v++) begin
            assign mants_norm_c[v] = mul_sum[v] + mul_carry[v];
        end
    endgenerate

    //----------
    //exp addition
    //----------
    logic signed [N-1:0][EXP_WIDTH:0] exps_c;
    generate
        genvar m;
        for(m=0;m<N;m++) begin: exp_add
            exp_add #(
                .n(n_i),
                .es(es_i)
            ) u_exp_add(
                .k_sgn_a(k_sgn_a[m]),
                .exp_a(exps_a[m]),
                .k_sgn_b(k_sgn_b[m]),
                .exp_b(exps_b[m]),
                .exp_o(exps_c[m])
            );
        end
    endgenerate


    //----------
    //Exponent Compare
    //----------
    logic signed [EXP_WIDTH:0] exp_max;

    comp_tree #(
        .N(N),
        .WIDTH(EXP_WIDTH)
    ) u_comp_tree(
        .exp_i(exps_c),
        .exp_o(exp_max)
    );

    
    //----------
    //Alignment
    //----------
    logic [N-1:0][ALIGN_WIDTH-1:0] product;
    logic [N-1:0][ALIGN_WIDTH-1:0] product_shifted;
    generate
        genvar k;
        if(ALIGN_WIDTH>MUL_WIDTH) begin
            for(k=0;k<N;k++) begin: shift
                assign product[k] = mants_norm_c[k] << (ALIGN_WIDTH-MUL_WIDTH);
            end
        end
        else begin
            for(k=0;k<N;k++) begin: shift
                assign product[k] = mants_norm_c[k] >> (MUL_WIDTH-ALIGN_WIDTH);
            end
        end
    endgenerate

    logic [N-1:0][EXP_WIDTH:0] exp_diff;
    generate
        genvar z;
        for(z=0;z<N;z++) begin
            assign exp_diff[z] = exp_max - exps_c[z];
            barrel_shifter #(
                .WIDTH(ALIGN_WIDTH),
                .SHIFT_WIDTH(EXP_WIDTH),
                .MODE(1'b1)
            ) u_barrel_shifter(
                .operand_i(product[z]),
                .shift_amount(exp_diff[z]),
                .result_o(product_shifted[z])
            );
        end
    endgenerate

    /*
    batch_shift #(
        .N(N),
        .MANT_WIDTH(ALIGN_WIDTH),
        .EXP_WIDTH(EXP_WIDTH)
    ) u_batch_shift(
        .exp_i(exps_c),
        .exp_max(exp_max),
        .mant_i(product),
        .mant_o(product_shifted)
    );*/


    //----------
    //Sign process and addition of mantissa
    //----------
    logic final_sign;
    //logic sign_raw = 1'b0;
    logic [SUM_WIDTH-1:0] sum_c;
    //logic sign_raw;
    //assign sign_raw = 1'b0;
    mant_addition #(
        .N(N),
        .IN_WIDTH(ALIGN_WIDTH)
    ) u_mant_addition(
        .operands_i(product_shifted),
        .signs_i(signs_c),
        .result_o(sum_c),
        .final_sign(final_sign)
    );


    //----------
    //Normalization
    //----------
    logic [SUM_WIDTH-1:0] final_mant; //include hidden bit
    logic signed [EXP_WIDTH:0] exp_norm;
    logic signed [EXP_WIDTH:0] final_exp;
    mant_norm #(
        .WIDTH(SUM_WIDTH),
        .EXP_WIDTH(EXP_WIDTH),
        .DOT_BITS(MSB_BITS+2)
    ) u_mant_norm(
        .operand_i(sum_c),
        .exp_norm(exp_norm),
        .operand_o(final_mant)
    );
    assign final_exp = exp_max + exp_norm;


    //----------
    //rounding and encode
    //----------
    localparam int unsigned OUT_K_WIDTH = EXP_WIDTH - es_o;
    logic signed [OUT_K_WIDTH:0] result_k_sgn;
    logic [es_o:0] result_exp;

    assign result_k_sgn = final_exp >>> es_o;
    //assign result_exp = final_exp[es_o:0] & ~(1<<es_o);
    if(es_o==0) begin
        assign result_exp = 0;
    end
    else begin
        assign result_exp = final_exp[es_o-1:0];
    end
    posit_encoder #(
        .n(n_o),
        .es(es_o),
        .MANT_WIDTH(SUM_WIDTH-1),
        .K_WIDTH(OUT_K_WIDTH)
    ) u_posit_encoder(
        .sign_i(final_sign),
        .k_sgn_i(result_k_sgn),
        .exp_i(result_exp),
        .mant_norm_i(final_mant),
        .result_o(result_o)
    );
endmodule