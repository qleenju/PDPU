// 4:2 compressor, compressing 4 inputs into sum and carry
module compressor_4to2 #(
    parameter int unsigned WIDTH_I = 8,                             // bit-width of inputs
    parameter int unsigned WIDTH_O = WIDTH_I + pdpu_pkg::clog2(4)   // bit-width of outputs
)(
    input logic [3:0][WIDTH_I-1:0] operands_i,
    output logic [WIDTH_O-1:0] sum_o,
    output logic [WIDTH_O-1:0] carry_o
);
    logic [WIDTH_I-1:0] sum;
    logic [WIDTH_I:0] cin;
    logic [WIDTH_I-1:0] cout;
    logic [WIDTH_I-1:0] carry;
    
    assign cin[0] = 1'b0;

    // Cascaded 5:3 counters according to input bit-width
    generate
        genvar i;
        for(i=0;i<WIDTH_I;i++) begin
            counter_5to3 u_counter_5to3(
                .x1(operands_i[0][i]),
                .x2(operands_i[1][i]),
                .x3(operands_i[2][i]),
                .x4(operands_i[3][i]),
                .cin(cin[i]),
                .sum(sum[i]),
                .carry(carry[i]),
                .cout(cout[i])
            );
            assign cin[i+1] = cout[i];
        end
    endgenerate

    logic [1:0] carry_temp;
    
    assign sum_o = sum;
    assign carry_temp = carry[WIDTH_I-1]+cin[WIDTH_I];
    assign carry_o = {carry_temp,carry[WIDTH_I-2:0],1'b0};
endmodule