module radix4_booth_multiplier #(
    parameter int unsigned WIDTH_A = 16,                // bit-width of operand A
    parameter int unsigned WIDTH_B = 16,                // bit-width of operand B
    parameter int unsigned WIDTH_O = WIDTH_A + WIDTH_B  // bit-width of the multiplication result
)(
    input logic [WIDTH_A-1:0] operand_a,
    input logic [WIDTH_B-1:0] operand_b,
    // the partial products are compressed into sum_o and carry_o
    output logic [WIDTH_O-1:0] sum_o,
    output logic [WIDTH_O-1:0] carry_o
);
    // number of partial products generated in unsigned multiplication
    localparam int unsigned COUNT = (WIDTH_B+2)/2;
    
    // ---------------
    // Generate partial products
    // ---------------
    logic [COUNT-1:0][WIDTH_O-1:0] partial_prods;
    gen_prods #(
        .WIDTH_A(WIDTH_A),
        .WIDTH_B(WIDTH_B)
    ) u_gen_prods(
        .operand_a(operand_a),
        .operand_b(operand_b),
        .partial_prods(partial_prods)
    );

    // ---------------
    // Compress the partial products into sum and carry
    // ---------------
    csa_tree #(
        .N(COUNT),
        .IN_WIDTH(WIDTH_O),
        .OUT_WIDTH(WIDTH_O)
    ) u_csa_tree(
        .operands_i(partial_prods),
        .sum_o(sum_o),
        .carry_o(carry_o)
    );
endmodule