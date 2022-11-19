// Generate partial product according to radix-4 booth encoding result
module gen_product #(
    parameter int unsigned WIDTH = 16
)(
    input logic [WIDTH-1:0] multiplicand,
    input logic [2:0] code,
    output logic [WIDTH:0] partial_prod,
    output sign
);
    logic neg,zero,one,two;
    booth_encoder u_booth_encoder(
        .code(code),
        .neg(neg),
        .zero(zero),
        .one(one),
        .two(two)
    );

    logic [WIDTH:0] temp_prod;
    always_comb begin
        if(one) begin
            temp_prod = multiplicand;
        end
        else if(two) begin
            temp_prod = multiplicand << 1;
        end
        else begin
            temp_prod = '0;
        end
    end
    assign partial_prod = neg ? (~temp_prod) : temp_prod;
    assign sign = neg;
endmodule