//Author: Qiong Li
//Date: 2022-03-26
//功能：由全加器构成的3:2压缩器，3个输入，2个输出

module CSA3to2 #(
    parameter int unsigned IN_WIDTH = 8,
    parameter int unsigned OUT_WIDTH = IN_WIDTH + posit_pkg::clog2(3)
)(
    input logic [2:0][IN_WIDTH-1:0] operands_i,
    output logic [OUT_WIDTH-1:0] sum_o,
    output logic [OUT_WIDTH-1:0] carry_o
);
    logic [IN_WIDTH-1:0] sum;
    logic [IN_WIDTH-1:0] carry;
    generate
        genvar i;
        for(i=0;i<IN_WIDTH;i++) begin
            fulladder u_fulladder(
                .x(operands_i[0][i]),
                .y(operands_i[1][i]),
                .z(operands_i[2][i]),
                .s(sum[i]),
                .c(carry[i])
            );
        end
    endgenerate

    assign sum_o = sum; //高2位为0
    assign carry_o = {1'b0,carry,1'b0}; //之所以前面再补0主要是为了适配4:2压缩器
endmodule