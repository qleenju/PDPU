//Author: Qiong Li
//Date: 2022-03-13
//功能：递归实现输出N个输入值中的最大值
//相关参考：https://github.com/raiker/tarsier/blob/master/src/AdderTree.sv (递归实现加法树)

module pdpu_comp_tree #(
    parameter N = 4,
    parameter WIDTH = 8
)(
    input logic signed [N-1:0][WIDTH:0] exp_i,   //[Note]在设计过程选择压缩数组/非压缩数组有什么考量呢？
    output logic signed [WIDTH:0] exp_o
);
    localparam N_A = N/2;
    localparam N_B = N - N_A;

    generate
        if (N==1) begin
            assign exp_o = exp_i[0];
        end

        else if (N==2) begin
            comparator #(
                .WIDTH(WIDTH)
            ) ua_comparator(
                .exp_a(exp_i[0]),
                .exp_b(exp_i[1]),
                .exp_o(exp_o)
            );
        end

        else begin
            logic signed [N_A-1:0][WIDTH:0] exp_i_A;
            logic signed [N_B-1:0][WIDTH:0] exp_i_B;
            logic signed [WIDTH:0] exp_o_A;
            logic signed [WIDTH:0] exp_o_B;

            always_comb begin
                for (int i=0; i<N_A; i++) begin
                    exp_i_A[i] = exp_i[i];
                end
                for (int i=0; i<N_B; i++) begin
                    exp_i_B[i] = exp_i[i+N_A];
                end
            end

            //Divide set into two chunks
            comp_tree #(
                .N(N_A),
                .WIDTH(WIDTH)
            ) ua_comp_tree(
                .exp_i(exp_i_A),
                .exp_o(exp_o_A)
            );

            comp_tree #(
                .N(N_B),
                .WIDTH(WIDTH)
            ) ub_comp_tree(
                .exp_i(exp_i_B),
                .exp_o(exp_o_B)
            );

            //Instantiate the comparator module
            comparator #(
                .WIDTH(WIDTH)
            ) ub_comparator(
                .exp_a(exp_o_A),
                .exp_b(exp_o_B),
                .exp_o(exp_o)
            );
        end
    endgenerate
endmodule