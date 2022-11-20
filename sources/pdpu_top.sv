/*
PDPU performs a dot-product of two input vectors "Va" and "Vb" in low-precision format,
and then accumulate the dot-product result and previous output "out" to a high-precision value "out".
i.e., acc + Va*Vb --> out

PDPU is configurable from several aspects, i.e., posit formats, dot-product size, and alignment width.
*/
module pdpu_top #(
    parameter int unsigned N = 4,                   // dot-product size
    parameter int unsigned n_i = 8,                 // word size
    parameter int unsigned es_i = 2,                // exponent size
    parameter int unsigned n_o = 16,
    parameter int unsigned es_o = 2,
    parameter int unsigned ALIGN_WIDTH = 14         // alignment width
)(
    input logic [N-1:0][n_i-1:0] operands_a,        // input vector (Va)
    input logic [N-1:0][n_i-1:0] operands_b,        // input vector (Vb)
    input logic [n_o-1:0] acc,                      // previous output (acc)
    output logic [n_o-1:0] result_o                 // output result (out)
);
    // ---------------
    // Posit Decoding
    // ---------------
    // the maximum exponent size (not include sign bit)
    localparam int unsigned EXP_WIDTH_I = pdpu_pkg::clog2(n_i-1) + es_i;
    // the maximum mantissa size (not include implicit bit)
    localparam int unsigned MANT_WIDTH_I = n_i-es_i-3;

    // Extract valid sign, exponent, and mantissa from input vectors
    logic [N-1:0] signs_a, signs_b;
    logic signed [N-1:0][EXP_WIDTH_I:0] rg_exp_a,rg_exp_b;
    logic [N-1:0][MANT_WIDTH_I:0] mants_norm_a, mants_norm_b;

    generate
        genvar i;
        for(i=0;i<N;i++) begin: posit_decoding
            posit_decoder #(
                .n(n_i),
                .es(es_i)
            )ua_posit_decoder(
                .operand_i(operands_a[i]),
                .sign_o(signs_a[i]),
                .rg_exp_o(rg_exp_a[i]),
                .mant_norm_o(mants_norm_a[i])
            );

            posit_decoder #(
                .n(n_i),
                .es(es_i)
            )ub_posit_decoder(
                .operand_i(operands_b[i]),
                .sign_o(signs_b[i]),
                .rg_exp_o(rg_exp_b[i]),
                .mant_norm_o(mants_norm_b[i])
            );
        end
    endgenerate


    localparam int unsigned EXP_WIDTH_O = pdpu_pkg::clog2(n_o-1) + es_o;
    localparam int unsigned MANT_WIDTH_O = n_o-es_o-3;

    // Extract valid sign, exponent, and mantissa from previous output (acc)
    logic sign_acc;
    logic signed [EXP_WIDTH_O:0] rg_exp_acc;
    logic [MANT_WIDTH_O:0] mant_norm_acc;
    
    posit_decoder #(
        .n(n_o),
        .es(es_o)
    )uc_posit_decoder(
        .operand_i(acc),
        .sign_o(sign_acc),
        .rg_exp_o(rg_exp_acc),
        .mant_norm_o(mant_norm_acc)
    );

    // ---------------
    // Sign Process
    // ---------------
    logic [N-1:0] signs_ab;
    logic [N:0] signs;
    
    // Perform XOR to obtain the signs of the product of Va and Vb
    assign signs_ab = signs_a ^ signs_b;
    assign signs = {sign_acc, signs_ab};

    // ---------------
    // Exponent Addition
    // ---------------
    localparam int unsigned EXP_WIDTH = pdpu_pkg::maximum(EXP_WIDTH_I+1,EXP_WIDTH_O);
    
    // obtain the exponents of the product of Va and Vb through signed addition
    logic signed [N-1:0][EXP_WIDTH:0] rg_exp_c;
    generate
        genvar m;
        for(m=0;m<N;m++) begin
            assign rg_exp_c[m] = signed'(rg_exp_a[m]) + signed'(rg_exp_b[m]);
        end
    endgenerate

    // ---------------
    // Mantissa Multiplication
    // ---------------
    localparam int unsigned MUL_WIDTH = 2*(MANT_WIDTH_I+1);
    logic [N-1:0][MUL_WIDTH-1:0] mul_sum,mul_carry;

    // Mantissa multiplication is performed by a modified radix-4 booth multiplier
    generate
        genvar j;
        for(j=0;j<N;j++) begin: multiplication
            radix4_booth_multiplier #(
                .WIDTH_A(MANT_WIDTH_I+1),
                .WIDTH_B(MANT_WIDTH_I+1)
            ) u_radix4_booth_multiplier(
                .operand_a(mants_norm_a[j]),
                .operand_b(mants_norm_b[j]),
                .sum_o(mul_sum[j]),
                .carry_o(mul_carry[j])
            );
        end
    endgenerate

    // ---------------
    // Exponent Compare
    // ---------------
    logic signed [N:0][EXP_WIDTH:0] rg_exp_items;
    generate
        genvar u;
        for(u=0;u<N;u++) begin
            assign rg_exp_items[u] = rg_exp_c[u];
        end
    endgenerate
    assign rg_exp_items[N] = signed'(rg_exp_acc);

    // Obtain the maximum exponent by a recursive comparator tree
    logic signed [EXP_WIDTH:0] rg_exp_max;
    comp_tree #(
        .N(N+1),
        .WIDTH(EXP_WIDTH)
    ) u_comp_tree(
        .operands_i(rg_exp_items),
        .result_o(rg_exp_max)
    );

    // ---------------
    // The final addition
    // ---------------
    logic [N-1:0][MUL_WIDTH-1:0] mants_norm_c;
    generate
        genvar v;
        for(v=0;v<N;v++) begin
            assign mants_norm_c[v] = mul_sum[v] + mul_carry[v];
        end
    endgenerate


    // ---------------
    // Mantissa Alignment
    // ---------------
    logic [N:0][ALIGN_WIDTH-1:0] product;
    logic [N:0][ALIGN_WIDTH-1:0] product_shifted;

    // the mantissa products of Va and Vb are kept in values of bitwidth `ALIGN_WIDTH` before alignment
    generate
        genvar k;
        if(ALIGN_WIDTH>MUL_WIDTH) begin: fixed_shift
            for(k=0;k<N;k++) begin
                assign product[k] = mants_norm_c[k] << (ALIGN_WIDTH-MUL_WIDTH);
            end
        end  
        else begin: fixed_shift
            for(k=0;k<N;k++) begin
                assign product[k] = mants_norm_c[k] >> (MUL_WIDTH-ALIGN_WIDTH);
            end
        end
    endgenerate

    if(ALIGN_WIDTH>MANT_WIDTH_O+2) begin
        assign product[N] = mant_norm_acc << (ALIGN_WIDTH-MANT_WIDTH_O-2);
    end
    else begin
        assign product[N] = mant_norm_acc >> (MANT_WIDTH_O+2-ALIGN_WIDTH);
    end

    // Align the products according to the difference between the respective exponent and the maximum exponent
    localparam int unsigned SHIFT_WIDTH = pdpu_pkg::clog2(ALIGN_WIDTH+1);
    logic [N:0][EXP_WIDTH:0] rg_exp_diff;
    logic [N:0][SHIFT_WIDTH-1:0] shift_amount;
    generate
        genvar z,s;
        // compute the respective exponent difference
        for(z=0;z<N+1;z++) begin
            assign rg_exp_diff[z] = unsigned'(rg_exp_max - rg_exp_items[z]);
        end
        // the maximum shift amount is ALIGN_WIDTH, since the bits exceeding ALIGN_WIDTH will be discarded directly.
        if(EXP_WIDTH+1>SHIFT_WIDTH) begin
            for(s=0;s<N+1;s++) begin
                assign shift_amount[s] = (|rg_exp_diff[s][EXP_WIDTH:SHIFT_WIDTH]) ? ALIGN_WIDTH : rg_exp_diff[s][SHIFT_WIDTH-1:0];
                barrel_shifter #(
                    .WIDTH(ALIGN_WIDTH),
                    .SHIFT_WIDTH(SHIFT_WIDTH),
                    .MODE(1'b1)
                ) u_barrel_shifter(
                    .operand_i(product[s]),
                    .shift_amount(shift_amount[s]),
                    .result_o(product_shifted[s])
                );
            end
        end

        else begin
            for(s=0;s<N+1;s++) begin
                barrel_shifter #(
                    .WIDTH(ALIGN_WIDTH),
                    .SHIFT_WIDTH(EXP_WIDTH+1),
                    .MODE(1'b1)
                ) u_barrel_shifter(
                    .operand_i(product[s]),
                    .shift_amount(rg_exp_diff[s]),
                    .result_o(product_shifted[s])
                );
            end
        end
    endgenerate

    // ---------------
    // Mantissa accumulation in two's complement
    // ---------------
    localparam int unsigned CARRY_WIDTH = pdpu_pkg::clog2(N+1);
    localparam int unsigned SUM_WIDTH = ALIGN_WIDTH + CARRY_WIDTH;

    logic [N:0][SUM_WIDTH:0] mantissa,mantissa_comp;
    // Convert to two's complement
    generate
        genvar y;
        for(y=0;y<N+1;y++) begin
            assign mantissa[y] = product_shifted[y];
            assign mantissa_comp[y] = signs[y] ? (~mantissa[y]+1) : mantissa[y];
        end
    endgenerate

    logic [SUM_WIDTH:0] csa_sum,csa_carry;
    csa_tree #(
        .N(N+1),
        .WIDTH_I(SUM_WIDTH+1),
        .WIDTH_O(SUM_WIDTH+1)
    ) u_csa_tree(
        .operands_i(mantissa_comp),
        .sum_o(csa_sum),
        .carry_o(csa_carry)
    );

    logic [SUM_WIDTH:0] sum_result;
    // the final addition
    assign sum_result = csa_sum + csa_carry;

    logic final_sign;
    logic [SUM_WIDTH-1:0] sum_c;
    
    assign final_sign = sum_result[SUM_WIDTH];
    assign sum_c = final_sign ? (~sum_result+1) : sum_result[SUM_WIDTH-1:0];

    // ---------------
    // Mantissa normalization and exponent adjustment
    // ---------------
    logic signed [EXP_WIDTH:0] rg_exp_adjust;
    logic signed [EXP_WIDTH:0] final_rg_exp;
    logic [SUM_WIDTH-1:0] sum_norm;

    mantissa_norm #(
        .WIDTH(SUM_WIDTH),
        .EXP_WIDTH(EXP_WIDTH),
        .DECIMAL_POINT(CARRY_WIDTH+2)
    ) u_mantissa_norm(
        .operand_i(sum_c),
        .exp_adjust(rg_exp_adjust),
        .result_o(sum_norm)
    );
    // Note: is there any possibility of overflow?
    assign final_rg_exp = rg_exp_max + rg_exp_adjust;

    // ---------------
    // Posit encoder and Rounding
    // ---------------
    logic [MANT_WIDTH_O+2:0] final_mant;
    
    if(SUM_WIDTH>MANT_WIDTH_O+3) begin
        logic [SUM_WIDTH-MANT_WIDTH_O-3:0] sticky_bits;
        logic sticky_bit;
        assign sticky_bits = sum_norm[SUM_WIDTH-MANT_WIDTH_O-3:0];
        assign sticky_bit = |sticky_bits;
        assign final_mant = {sum_norm[SUM_WIDTH-1:SUM_WIDTH-MANT_WIDTH_O-2],sticky_bit};
    end
    else begin
        assign final_mant = sum_norm << (MANT_WIDTH_O+3-SUM_WIDTH);
    end

    posit_encoder #(
        .n(n_o),
        .es(es_o),
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH_O+2)
    ) u_posit_encoder(
        .sign_i(final_sign),
        .rg_exp_i(final_rg_exp),
        .mant_norm_i(final_mant),
        .result_o(result_o)
    );
endmodule