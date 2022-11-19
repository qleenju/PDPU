// Recursive implementation of comparator tree, to obtain the maximum value among inputs with any size
module comp_tree #(
    parameter N = 4,        // size of inputs
    parameter WIDTH = 8     // bit-width of inputs
)(
    input logic signed [N-1:0][WIDTH:0] operands_i,
    output logic signed [WIDTH:0] result_o
);
    localparam int unsigned N_A = N/2;
    localparam int unsigned N_B = N - N_A;

    generate
        if (N==1) begin
            assign result_o = operands_i[0];
        end

        else if (N==2) begin
            comparator #(
                .WIDTH(WIDTH)
            ) u_comparator(
                .operand_a(operands_i[0]),
                .operand_b(operands_i[1]),
                .result_o(result_o)
            );
        end

        else begin
            logic signed [N_A-1:0][WIDTH:0] operands_i_A;
            logic signed [N_B-1:0][WIDTH:0] operands_i_B;
            logic signed [WIDTH:0] result_o_A;
            logic signed [WIDTH:0] result_o_B;

            // Divide the inputs into two chunks
            assign operands_i_A = operands_i[N_A-1:0];
            assign operands_i_B = operands_i[N-1:N_A];

            // Module recursion for operands_i_A
            comp_tree #(
                .N(N_A),
                .WIDTH(WIDTH)
            ) ua_comp_tree(
                .operands_i(operands_i_A),
                .result_o(result_o_A)
            );

            // Module recursion for operands_i_B
            comp_tree #(
                .N(N_B),
                .WIDTH(WIDTH)
            ) ub_comp_tree(
                .operands_i(operands_i_B),
                .result_o(result_o_B)
            );

            // Compare result_o_A and result_o_B
            comparator #(
                .WIDTH(WIDTH)
            ) uc_comparator(
                .operand_a(result_o_A),
                .operand_b(result_o_B),
                .result_o(result_o)
            );
        end
    endgenerate
endmodule