// Generate partial products based on modified sign extension in booth multipliers
module gen_prods #(
    parameter int unsigned WIDTH_A = 16,
    parameter int unsigned WIDTH_B = 16,
    // do not change
    parameter int unsigned COUNT = (WIDTH_B+2)/2,       // count of partial products generated in unsigned multiplication
    parameter int unsigned WIDTH_O = WIDTH_A + WIDTH_B  // bit-width of outputs
)(
    input logic [WIDTH_A-1:0] operand_a,
    input logic [WIDTH_B-1:0] operand_b,
    output [COUNT-1:0][WIDTH_O-1:0] partial_prods
);
    logic [WIDTH_B+2:0] multiplier;
    logic [COUNT-1:0][2:0] codes;
    logic [COUNT-1:0][WIDTH_A:0] temp_prods;
    logic [COUNT-1:0] signs;

    assign multiplier = {2'b00,operand_b,1'b0};
    assign codes[0] = multiplier[2:0];

    // Generate partial products
    gen_product #(
        .WIDTH(WIDTH_A)
    ) ua_gen_product(
        .multiplicand(operand_a),
        .code(codes[0]),
        .partial_prod(temp_prods[0]),
        .sign(signs[0])
    );
    assign partial_prods[0] = {~signs[0], signs[0], signs[0], temp_prods[0]};

    generate
        genvar i;
        for(i=1;i<COUNT-1;i++) begin
            assign codes[i] = multiplier[2*i+2:2*i];
            gen_product #(
                .WIDTH(WIDTH_A)
            ) ub_gen_product(
                .multiplicand(operand_a),
                .code(codes[i]),
                .partial_prod(temp_prods[i]),
                .sign(signs[i])
            );
            // modified sign extension in booth multipliers
            assign partial_prods[i] = {1'b1,~signs[i],temp_prods[i],1'b0,signs[i-1]} << (2*i-2);
        end
    endgenerate

    assign codes[COUNT-1] = multiplier[2*COUNT:2*COUNT-2];
    gen_product #(
        .WIDTH(WIDTH_A)
    ) uc_gen_product(
        .multiplicand(operand_a),
        .code(codes[COUNT-1]),
        .partial_prod(temp_prods[COUNT-1]),
        .sign(signs[COUNT-1])
    );
    assign partial_prods[COUNT-1] = {temp_prods[COUNT-1],1'b0,signs[COUNT-2]} << (2*COUNT-4);

endmodule