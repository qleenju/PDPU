//Author: Qiong Li
//Date: 2022-03-26
//功能：由5-3计数器构成的4:2压缩器

module CSA4to2 #(
    parameter int unsigned IN_WIDTH = 8,
    parameter int unsigned OUT_WIDTH = IN_WIDTH + 2
)(
    input logic [3:0][IN_WIDTH-1:0] operands_i,
    output logic [OUT_WIDTH-1:0] sum_o,
    output logic [OUT_WIDTH-1:0] carry_o
);
    logic [IN_WIDTH-1:0] sum;
    logic [IN_WIDTH:0] cin;
    logic [IN_WIDTH-1:0] cout;
    logic [IN_WIDTH-1:0] carry;
    assign cin[0] = 1'b0;

    generate
        genvar i;
        for(i=0;i<IN_WIDTH;i++) begin
            counter5to3 u_counter5to3(
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
    assign sum_o = sum; //高两位为0
    assign carry_temp = carry[IN_WIDTH-1]+cin[IN_WIDTH];
    assign carry_o = {carry_temp,carry[IN_WIDTH-2:0],1'b0};
endmodule