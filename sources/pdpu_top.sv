module pdpu_top #(
    // PDPU is configurable from several aspects, i.e., posit formats, dot-product size, and alignment width.
    // dot-product size: N
    parameter int unsigned N = 4,
    // posit format of inputs: posit(n_i,es_i)
    // n_i: word size, es_i: exponent size
    parameter int unsigned n_i = 8,
    parameter int unsigned es_i = 2,
    // posit format of output: posit(n_o,es_o)
    parameter int unsigned n_o = 16,
    parameter int unsigned es_o = 2,
    // alignment width: ALIGN_WIDTH
    parameter int unsigned ALIGN_WIDTH = 14
)(
    // PDPU performs a dot-product of two input vectors "Va" and "Vb" in low-precision format,
    // and then accumulate the dot-product result and previous output "acc" to a high-precision value "out".
    // i.e., out <-- acc + Va*Vb
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

    // extract valid sign, exponent, and mantissa from input vectors
    logic [N-1:0] signs_a, signs_b;
    logic signed [N-1:0][EXP_WIDTH_I:0] rg_exp_a,rg_exp_b;
    logic [N-1:0][MANT_WIDTH_I:0] mants_norm_a, mants_norm_b;

    generate
        genvar i;
        for(i=0;i<N;i++) begin: posit_decoding
            pdpu_posit_decoder #(
                .n(n_i),
                .es(es_i)
            )ua_pdpu_posit_decoder(
                .operand_i(operands_a[i]),
                .sign_o(signs_a[i]),
                .rg_exp_o(rg_exp_a[i]),
                .mant_norm_o(mants_norm_a[i])
            );

            pdpu_posit_decoder #(
                .n(n_i),
                .es(es_i)
            )ub_pdpu_posit_decoder(
                .operand_i(operands_b[i]),
                .sign_o(signs_b[i]),
                .rg_exp_o(rg_exp_b[i]),
                .mant_norm_o(mants_norm_b[i])
            );
        end
    endgenerate


    localparam int unsigned EXP_WIDTH_O = pdpu_pkg::clog2(n_o-1) + es_o;
    localparam int unsigned MANT_WIDTH_O = n_o-es_o-3;

    // extract valid sign, exponent, and mantissa from previous output (acc)
    logic sign_acc;
    logic signed [EXP_WIDTH_O:0] rg_exp_acc;
    logic [MANT_WIDTH_O:0] mant_norm_acc;
    
    pdpu_posit_decoder #(
        .n(n_o),
        .es(es_o)
    )uc_pdpu_posit_decoder(
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
    
    // perform XOR to obtain the signs of the product of Va and Vb
    assign signs_ab = signs_a ^ signs_b;
    assign signs = {sign_acc, signs_ab};


    // ---------------
    // Mantissa Multiplication
    // ---------------
    localparam int unsigned MUL_WIDTH = 2*(MANT_WIDTH_I+1);
    logic [N-1:0][MUL_WIDTH-1:0] mul_sum,mul_carry;

    // Mantissa multiplication is performed by a modified radix-4 booth multiplier
    generate
        genvar j;
        for(j=0;j<N;j++) begin: multiplication
            pdpu_radix4_booth_mult #(
                .WIDTH_A(MANT_WIDTH_I+1),
                .WIDTH_B(MANT_WIDTH_I+1)
            ) u_pdpu_radix4_booth_mult(
                .operand_a(mants_norm_a[j]),
                .operand_b(mants_norm_b[j]),
                .sum(mul_sum[j]),
                .carry(mul_carry[j])
            );
        end
    endgenerate

    // the final addition
    logic [N-1:0][MUL_WIDTH-1:0] mants_norm_c;
    generate
        genvar v;
        for(v=0;v<N;v++) begin
            assign mants_norm_c[v] = mul_sum[v] + mul_carry[v];
        end
    endgenerate


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

    // obtain the maximum exponent by a comparator tree
    logic signed [EXP_WIDTH:0] rg_exp_max;
    pdpu_comp_tree #(
        .N(N+1),
        .WIDTH(EXP_WIDTH)
    ) u_pdpu_comp_tree(
        .exp_i(rg_exp_items),
        .exp_o(rg_exp_max)
    );


    // ---------------
    // Mantissa Alignment
    // ---------------
    logic [N:0][ALIGN_WIDTH-1:0] product;
    logic [N:0][ALIGN_WIDTH-1:0] product_shifted;

    // the mantissa products of Va and Vb are kept in values of bitwidth `ALIGN_WIDTH` before alignment

    // depending on the difference between `ALIGN_WIDTH` and `MUL_WIDTH`,
    // the products will be shifted left or right by a fixed value.
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

    // align the products according to the difference between the respective exponent and the maximum exponent
    localparam int unsigned SHIFT_WIDTH = pdpu_pkg::clog2(ALIGN_WIDTH+1);
    logic [N:0][EXP_WIDTH:0] rg_exp_diff;
    logic [N:0][SHIFT_WIDTH-1:0] shift_amount;
    generate
        genvar z,s;
        // compute the respective exponent difference
        for(z=0;z<N+1;z++) begin
            assign rg_exp_diff[z] = unsigned'(rg_exp_max - rg_exp_items[z]);
        end
        // the maximum shift amount is ALIGN_WIDTH, 
        // since the bits exceeding ALIGN_WIDTH will be discarded directly.
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
    // Sign process and addition of mantissa
    // ---------------
    localparam int unsigned CARRY_WIDTH = posit_pkg::clog2(N+1);
    localparam int unsigned SUM_WIDTH = ALIGN_WIDTH + CARRY_WIDTH;

    logic [N:0][SUM_WIDTH:0] mantissa,mantissa_comp;
    //two's complement
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
        .IN_WIDTH(SUM_WIDTH+1),
        .OUT_WIDTH(SUM_WIDTH+1)
    ) u_csa_tree(
        .operands_i(mantissa_comp),
        .sum_o(csa_sum),
        .carry_o(csa_carry)
    );

    logic [SUM_WIDTH:0] sum_result;
    assign sum_result = csa_sum + csa_carry;

    logic final_sign;
    logic [SUM_WIDTH-1:0] sum_c;
    assign final_sign = sum_result[SUM_WIDTH];
    assign sum_c = final_sign ? (~sum_result+1) : sum_result[SUM_WIDTH-1:0];

    // ---------------
    // Normalization
    // ---------------
    logic signed [EXP_WIDTH:0] rg_exp_norm;
    logic signed [EXP_WIDTH:0] final_rg_exp;
    logic [SUM_WIDTH-1:0] sum_norm;
    // exp_norm的范围：-(ALIGN_WIDTH-2) ~ (carry_bits+1)
    mant_norm #(
        .WIDTH(SUM_WIDTH),
        .EXP_WIDTH(EXP_WIDTH),
        .DOT_BITS(CARRY_WIDTH+2)
    ) u_mant_norm(
        .operand_i(sum_c),
        .exp_norm(rg_exp_norm),
        .operand_o(sum_norm)
    );
    // 备注：此处存在溢出的可能性
    assign final_rg_exp = rg_exp_max + rg_exp_norm;


    // ---------------
    // Posit encoder and Rounding
    // ---------------
    // MANT_WIDTH越大，需要移位的量也越大，所以应尽量减小其位宽
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

    posit_encoder_v2 #(
        .n(n_o),
        .es(es_o),
        .EXP_WIDTH(EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH_O+2)
    ) u_posit_encoder_v2(
        .sign_i(final_sign),
        .rg_exp_i(final_rg_exp),
        .mant_norm_i(final_mant),
        .result_o(result_o)
    );
endmodule