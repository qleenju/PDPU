//Author: Qiong Li
//Date: 2022-03-27
//功能: 尾数归一化

module mant_norm #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned EXP_WIDTH = 3,
    parameter int unsigned DOT_BITS = 3     //Number of digits before decimal point
)(
    input logic [WIDTH-1:0] operand_i,
    output logic signed [EXP_WIDTH:0] exp_norm,
    output logic [WIDTH-1:0] operand_o
);
    localparam int unsigned LZC_WIDTH = posit_pkg::clog2(WIDTH);
    logic [LZC_WIDTH-1:0] leading_zero_count;
    logic lzc_zeroes;
    
    lzc #(
        .WIDTH(WIDTH),
        .MODE(1)
    ) u_lzc(
        .in_i(operand_i),
        .cnt_o(leading_zero_count),
        .empty_o(lzc_zeroes)
    );

    always_comb begin
        if(lzc_zeroes) begin
            exp_norm = '0;
        end
        else if(leading_zero_count <= DOT_BITS - 1) begin
            exp_norm = DOT_BITS - leading_zero_count - 1;
        end
        else begin
            exp_norm = -signed'(leading_zero_count - DOT_BITS + 1);
        end
    end

    barrel_shifter #(
        .WIDTH(WIDTH),
        .SHIFT_WIDTH(LZC_WIDTH),
        .MODE(1'b0)
    ) u_barrel_shifter(
        .operand_i(operand_i),
        .shift_amount(leading_zero_count),
        .result_o(operand_o)
    );
endmodule