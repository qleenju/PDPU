//Author: Qiong Li
//Date: 2022-03-13
//功能：求最大值

module comparator #(
    parameter int unsigned WIDTH = 8
)(
    input logic signed [WIDTH:0] exp_a,
    input logic signed [WIDTH:0] exp_b,
    output logic signed [WIDTH:0] exp_o
);
    logic [1:0] sign_ab;
    logic [WIDTH-1:0] data_a;
    logic [WIDTH-1:0] data_b;

    assign sign_ab = {exp_a[WIDTH],exp_b[WIDTH]};
    assign data_a = exp_a[WIDTH-1:0];
    assign data_b = exp_b[WIDTH-1:0];
    
    always_comb begin
        case(sign_ab)
            2'b10: exp_o = exp_b;
            2'b01: exp_o = exp_a;
            default: exp_o = (data_a>data_b) ? exp_a : exp_b;
        endcase
    end
endmodule