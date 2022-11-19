// Recursive implementation of carry-save-adder (CSA) tree, to compress inputs with any size into sum and carry
module csa_tree #(
    parameter int unsigned N = 8,           // size of inputs
    parameter int unsigned WIDTH_I = 8,     // bit-width of inputs
    parameter int unsigned WIDTH_O = WIDTH_I + pdpu_pkg::clog2(N)   // bit-width of outputs
)(
    input logic [N-1:0][WIDTH_I-1:0] operands_i,
    output logic [WIDTH_O-1:0] sum_o,
    output logic [WIDTH_O-1:0] carry_o
);
    localparam int unsigned N_A = N/2;
    localparam int unsigned N_B = N - N_A;

    generate
        if (N==1) begin
            assign sum_o = operands_i[0];
            assign carry_o = '0;
        end
        else if(N==2) begin
            assign sum_o = operands_i[0];
            assign carry_o = operands_i[1];
        end
        else if(N==3) begin
            compressor_3to2 #(
                .WIDTH_I(WIDTH_I),
                .WIDTH_O(WIDTH_O)
            ) u_compressor_3to2(
                .operands_i(operands_i),
                .sum_o(sum_o),
                .carry_o(carry_o)
            );
        end
        else if(N==4) begin
            compressor_4to2 #(
                .WIDTH_I(WIDTH_I),
                .WIDTH_O(WIDTH_O)
            ) u_compressor_4to2(
                .operands_i(operands_i),
                .sum_o(sum_o),
                .carry_o(carry_o)
            );
        end
        else begin
            logic [N_A-1:0][WIDTH_I-1:0] operands_i_A;
            logic [N_B-1:0][WIDTH_I-1:0] operands_i_B;
            logic [WIDTH_O-1:0] sum_o_A;
            logic [WIDTH_O-1:0] sum_o_B;
            logic [WIDTH_O-1:0] carry_o_A;
            logic [WIDTH_O-1:0] carry_o_B;

            // Divide the inputs into two chunks
            assign operands_i_A = operands_i[N_A-1:0];
            assign operands_i_B = operands_i[N-1:N_A];

            csa_tree #(
                .N(N_A),
                .WIDTH_I(WIDTH_I),
                .WIDTH_O(WIDTH_O)
            ) ua_csa_tree(
                .operands_i(operands_i_A),
                .sum_o(sum_o_A),
                .carry_o(carry_o_A)
            );

            csa_tree #(
                .N(N_B),
                .WIDTH_I(WIDTH_I),
                .WIDTH_O(WIDTH_O)
            ) ub_csa_tree(
                .operands_i(operands_i_B),
                .sum_o(sum_o_B),
                .carry_o(carry_o_B)
            );

            logic [3:0][WIDTH_O-1:0] operands_i_C;
            assign operands_i_C = '{sum_o_A, carry_o_A, sum_o_B, carry_o_B};
            
            compressor_4to2 #(
                .WIDTH_I(WIDTH_O),
                .WIDTH_O(WIDTH_O)
            ) uc_compressor_4to2(
                .operands_i(operands_i_C),
                .sum_o(sum_o),
                .carry_o(carry_o)
            );
        end
    endgenerate
endmodule