//Author: Qiong Li
//Date: 2022-04-08
//功能：Radix-4 Booth乘法器编码器，根据输入生成0/+1/+2/-1/-2
// Coef = -2code[2]+code[1]+code[0]
/*
code | value | operation
000  |  +0   |     0
001  |  +1   |    1*A
010  |  +1   |    1*A
011  |  +2   |    2*A
100  |  -2   |   -2*A
101  |  -1   |   -1*A
110  |  -1   |   -1*A
111  |   0   |     0

*/
module booth_encoder(
    input [2:0] code,
    output neg,
    output zero,
    output one,
    output two
);
    //Only when code = 100/101/110, neg = 1
    assign neg = code[2]&(~code[0]) | code[2]&(~code[1]);
    assign zero = ~(|code) | &code;
    assign two = ~code[2]&code[1]&code[0] | code[2]&(~code[1])&(~code[0]);
    assign one = code[1]&(~code[0]) | (~code[1])&code[0];
endmodule