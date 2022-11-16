//Author: Qiong Li
//Date: 2022-03-23
//功能：完成两个Posit数据指数的相加操作

module exp_add #(
    parameter int unsigned n = 16,
    parameter int unsigned es = 1,

    //don't change
    parameter int unsigned LZC_WIDTH = posit_pkg::clog2(n-1),
    parameter int unsigned EXP_WIDTH = LZC_WIDTH + 1 + es
)(
    input logic signed [LZC_WIDTH:0] k_sgn_a,
    input logic [es:0] exp_a,
    input logic signed [LZC_WIDTH:0] k_sgn_b,
    input logic [es:0] exp_b,
    output logic signed [EXP_WIDTH:0] exp_o
);

    logic [es:0] exp_raw, exp_c;
    logic signed [LZC_WIDTH+1:0] k_sgn_c;
    
    assign exp_raw = exp_a + exp_b;
    assign k_sgn_c = k_sgn_a + k_sgn_b + signed'({1'b0,exp_raw[es]});
    if(es==0) begin
        assign exp_c = '0;
    end
    else begin
        assign exp_c = exp_raw[es-1:0];
    end
    
    assign exp_o = (k_sgn_c<<es) | exp_c;
endmodule