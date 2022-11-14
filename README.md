# PDPU
**An Open-Source Posit Dot-Product Unit (PDPU) for Deep Learning Applications**

## Overview
The proposed PDPU performs a dot-product of two input vectors $V_a$ and $V_b$ in low-precision format, and then accumulates the dot-product result and previous output $acc$ to a high-precision value $out$ as shown below:
$$out = acc+V_a\times V_b = acc+a_0\cdot b_0+a_1\cdot b_1+...+a_{N-1}\cdot b_{N-1}$$

**It introduces the following contributions and features:**
- The proposed PDPU implements efficient dot-product operations with fused and mixed-precision properties. Compared with the conventional discrete architectures, PDPU reduce area, latency, and power by up to 43%, 64%, and 70%, respectively.
- The proposed PDPU is equipped with a fine-grained 6-stage pipeline, which minimizes the critical path and improves computational efficiency. The structure of PDPU is detailed by breaking down the latency and resources of each stage.
- A configurable PDPU generator is developed to enable PDPU flexibly supporting various posit data types, dot-product sizes, and alignment widths.

#### Architecture
**The following figure presents the architecture of PDPU equipped with a fine-grained 6-stage pipeline.**

![Architecture of the proposed posit dot-product unit](docs/figs/architecture.png)

**The dataflow at each pipeline stage is as follows:**
- **S1: Decode.** Posit decoders extract the valid components of inputs in parallel, and subsequently $s_{ab}$ and $e_{ab}$ are calculated in the corresponding hardware logic, where $s_{ab}$ and $e_{ab}$ are the sign and exponent of the product of $V_a$ and $V_b$, respectively.
- **S2: Multiply.** Mantissa multiplication is performed by a modified radix-4 booth multiplier, while all exponents including exponent of $acc$ (i.e., $e_c$) are handled in a comparator tree to obtain the maximum exponent $e_{max}$.
- **S3: Align.** The product results from S2 are aligned according to the difference between the respective exponent and $e_{max}$, and then they are converted in two's complement for subsequent accumulation.
- **S4: Accumulate.** The aligned mantissa is compressed into $sum$ and $carry$ in a recursive carry-save-adder tree, which are then added to obtain accumulated result $s_m$ and final sign $f_s$.
- **S5: Normalize.** Mantissa normalization and exponent adjustment is performed based on the leading zero counts to determine the final exponent $f_e$ and mantissa $f_m$.
- **S6: Encode.** The posit encoder performs rounding and packs each components of the final result into the posit output $out$.

## Getting Started
The PDPU is implemented using SystemVerilog, capable of performing efficient posit-based dot-product operations in deep neural networks.

```
posit_dpu_acc_v2.sv                   # 顶层模块，参数化的Posit混合精度点积运算
├── posit_pkg.sv                      # package包，封装常用的函数、变量等
├── posit_decoder_v2.sv               # posit译码模块
│   ├── posit_pkg.sv
│   ├── lzc.sv                        # 前导零计数
│       └── cf_math_pkg.sv            # lzc模块用到的package库
│   └── barrel_shifter.sv             # 桶式移位器
├── mul_booth_wallace.sv              # 尾数相乘模块
│   ├── gen_prods.sv                  # 基于改进的符号扩展方法生成所有部分积
│       └── gen_product.sv            # 基于radix-4 Booth编码相应移位、取反等
│           └── booth_encoder.sv      # Radix-4 Booth编码
│   └── csa_tree.sv                   # 3:2 CSA和4:2 CSA迭代构成的wallace tree
│       ├── CSA3to2.sv                # 3:2 CSA模块
│           └── fulladder.sv          # 全加器单元
│       └── CSA4to2.sv                # 4:2 CSA模块
│           └── counter5to3.sv        # 5-3计数器单元
├── comp_tree.sv                      # 比较器树
│   └── comparator.sv                 # 比较单元
├── barrel_shifter.sv
├── csa_tree.sv             
│   ├── CSA3to2.sv
│       └── fulladder.sv
│   └── CSA4to2.sv
│       └── counter5to3.sv
├── mant_norm.sv                      # 尾数归一化
│   ├── lzc.sv
│       └── cf_math_pkg.sv
│   └── barrel_shifter.sv
├── posit_encoder_v2.sv               # posit编码单元
│   └── posit_pkg.sv
│   └── barrel_shifter.sv
```


## Publication
if you use PDPU in your work, you can cite us:
```

```

