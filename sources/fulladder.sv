//Author: Qiong Li
//Date: 2022-03-26
//功能：全加器，作为3:2 CSA的基本单元

module fulladder(
    input logic x,y,z,
    output logic s,c
);
    assign s = (x ^ y ) ^ z;
    assign c = ((x ^ y) & z) | (x & y);
endmodule