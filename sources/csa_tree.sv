//Author: Qiong Li
//Date: 2022-03-26
//功能：递归实现4:2 CSA加法树，实现N个输入，2个输出

module csa_tree #(
    parameter int unsigned N = 8,
    parameter int unsigned IN_WIDTH = 8,
    //N=8时最多产生3个进位
    parameter int unsigned OUT_WIDTH = IN_WIDTH + posit_pkg::clog2(N)
)(
    input logic [N-1:0][IN_WIDTH-1:0] operands_i,
    output logic [OUT_WIDTH-1:0] sum_o,
    output logic [OUT_WIDTH-1:0] carry_o
);
    localparam int unsigned N_A = N/2;
    localparam int unsigned N_B = N - N_A;

    generate
        if (N==1) begin
            assign sum_o = operands_i[0];
            assign carry_o = '0;
        end
        else if(N==2) begin
            assign sum_o = operands_i[0];
            assign carry_o = operands_i[1];
        end
        else if(N==3) begin
            CSA3to2 #(
                .IN_WIDTH(IN_WIDTH),
                .OUT_WIDTH(OUT_WIDTH)
            ) u_CSA3to2(
                .operands_i(operands_i),
                .sum_o(sum_o),
                .carry_o(carry_o)
            );
        end
        else if(N==4) begin
            CSA4to2 #(
                .IN_WIDTH(IN_WIDTH),
                .OUT_WIDTH(OUT_WIDTH)
            ) u_CSA4to2(
                .operands_i(operands_i),
                .sum_o(sum_o),
                .carry_o(carry_o)
            );
        end
        else begin
            logic [N_A-1:0][IN_WIDTH-1:0] operands_i_A;
            logic [N_B-1:0][IN_WIDTH-1:0] operands_i_B;
            logic [OUT_WIDTH-1:0] sum_o_A;
            logic [OUT_WIDTH-1:0] sum_o_B;
            logic [OUT_WIDTH-1:0] carry_o_A;
            logic [OUT_WIDTH-1:0] carry_o_B;

            always_comb begin
                for(int i=0;i<N_A;i++) begin
                    operands_i_A[i] = operands_i[i];
                end
                for(int i=0;i<N_B;i++) begin
                    operands_i_B[i] = operands_i[i+N_A];
                end
            end

            csa_tree #(
                .N(N_A),
                .IN_WIDTH(IN_WIDTH),
                .OUT_WIDTH(OUT_WIDTH)
            ) ua_csa_tree(
                .operands_i(operands_i_A),
                .sum_o(sum_o_A),
                .carry_o(carry_o_A)
            );

            csa_tree #(
                .N(N_B),
                .IN_WIDTH(IN_WIDTH),
                .OUT_WIDTH(OUT_WIDTH)
            ) ub_csa_tree(
                .operands_i(operands_i_B),
                .sum_o(sum_o_B),
                .carry_o(carry_o_B)
            );

            logic [3:0][OUT_WIDTH-1:0] operands_i_C;
            assign operands_i_C = '{sum_o_A, carry_o_A, sum_o_B, carry_o_B};
            
            CSA4to2 #(
                .IN_WIDTH(OUT_WIDTH),
                .OUT_WIDTH(OUT_WIDTH)
            ) ul_CSA4to2(
                .operands_i(operands_i_C),
                .sum_o(sum_o),
                .carry_o(carry_o)
            );
        end
    endgenerate
endmodule