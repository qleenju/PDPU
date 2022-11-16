//Author: Qiong Li
//Date: 2022-04-07
//功能：桶式移位器，替代原设计中的动态移位（设计需要仅考虑逻辑移位）

module barrel_shifter #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned SHIFT_WIDTH = 3,
    //MODE=0-->shift left; MODE=1-->shift right
    parameter bit MODE = 1'b0
)(
    input logic [WIDTH-1:0] operand_i,
    input logic [SHIFT_WIDTH-1:0] shift_amount,
    output logic [WIDTH-1:0] result_o
);
    logic [SHIFT_WIDTH-1:0][WIDTH-1:0] middle_results;

    assign middle_results[SHIFT_WIDTH-1] = operand_i;

    generate
        genvar i;
        if(MODE==1'b0) begin
            for(i=SHIFT_WIDTH-1;i>0;i--) begin
                assign middle_results[i-1] = shift_amount[i] ? middle_results[i]<<(2**i) : middle_results[i];
            end
            assign result_o = shift_amount[0] ? middle_results[0]<<1 : middle_results;
        end
        else begin
            for(i=SHIFT_WIDTH-1;i>0;i--) begin
                assign middle_results[i-1] = shift_amount[i] ? middle_results[i]>>(2**i) : middle_results[i];
            end
            assign result_o = shift_amount[0] ? middle_results[0]>>1 : middle_results;
        end
    endgenerate
endmodule