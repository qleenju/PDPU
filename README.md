# PDPU
**An Open-Source Posit Dot-Product Unit (PDPU) for Deep Learning Applications**

English | [简体中文](https://github.com/qleenju/PDPU/blob/main/docs/README_ZH.md)

## Overview
The proposed PDPU performs a dot-product of two input vectors $V_a$ and $V_b$ in low-precision format, and then accumulates the dot-product result and previous output $acc$ to a high-precision value $out$ as shown below:
$$out = acc+V_a\times V_b = acc+a_0\cdot b_0+a_1\cdot b_1+...+a_{N-1}\cdot b_{N-1}$$

**It introduces the following contributions and features:**
- The proposed PDPU implements efficient dot-product operations with fused and mixed-precision properties. Compared with the conventional discrete architectures, PDPU reduce area, latency, and power by up to 43%, 64%, and 70%, respectively.
- The proposed PDPU is equipped with a fine-grained 6-stage pipeline, which minimizes the critical path and improves computational efficiency. The structure of PDPU is detailed by breaking down the latency and resources of each stage.
- A configurable PDPU generator is developed to enable PDPU flexibly supporting various posit data types, dot-product sizes, and alignment widths.

#### Architecture
**The architeture of PDPU equipped with a fined-grained 6-stage pipeline is depicted as follows:**

![Architecture of the proposed posit dot-product unit](docs/figs/architecture.png)

**The dataflow at each pipeline stage is as follows:**
- **S1: Decode.** Posit decoders extract the valid components of inputs in parallel, and subsequently $s_{ab}$ and $e_{ab}$ are calculated in the corresponding hardware logic, where $s_{ab}$ and $e_{ab}$ are the sign and exponent of the product of $V_a$ and $V_b$, respectively.
- **S2: Multiply.** Mantissa multiplication is performed by a modified radix-4 booth multiplier, while all exponents including exponent of $acc$ (i.e., $e_c$) are handled in a comparator tree to obtain the maximum exponent $e_{max}$.
- **S3: Align.** The product results from S2 are aligned according to the difference between the respective exponent and $e_{max}$, and then they are converted in two's complement for subsequent accumulation.
- **S4: Accumulate.** The aligned mantissa is compressed into $sum$ and $carry$ in a recursive carry-save-adder tree, which are then added to obtain accumulated result $s_m$ and final sign $f_s$.
- **S5: Normalize.** Mantissa normalization and exponent adjustment is performed based on the leading zero counts to determine the final exponent $f_e$ and mantissa $f_m$.
- **S6: Encode.** The posit encoder performs rounding and packs each components of the final result into the posit output $out$.

## Getting Started
**The PDPU is implemented using SystemVerilog, and the module hierarchy is as follows:**

```
pdpu_top.sv                         # top module, combinationally implemented
pdpu_top_pipelined.sv               # PDPU equipped with a fine-grained 6-stage pipeline
├── registers.svh                   # register header file
├── pdpu_pkg.sv                     # package, packaging common functions, etc.
├── posit_decoder.sv                # posit decoder, extracting valid components of posit inputs
│   ├── pdpu_pkg.sv
│   ├── lzc.sv                      # leading zero count
│       └── cf_math_pkg.sv
│   └── barrel_shifter.sv           # barrel shifter
├── radix4_booth_multiplier.sv      # modified radix-4 booth wallace multiplier
│   ├── gen_prods.sv                # generate partial products
│       └── gen_product.sv          # generate a partial product according to booth encoding result
│           └── booth_encoder.sv    # radix-4 booth encoder
│   └── csa_tree.sv                 # recursive carry-save-adder (CSA) tree
│       ├── compressor_3to2.sv      # 3:2 compressor
│           └── fulladder.sv        # full adder
│       └── compressor_4to2.sv      # 4:2 compressor
│           └── counter_5to3.sv     # 5:3 counter
├── comp_tree.sv                    # recursive comparator tree
│   └── comparator.sv               # Comparator between two signed numbers
├── barrel_shifter.sv
├── csa_tree.sv             
│   ├── compressor_3to2.sv
│       └── fulladder.sv
│   └── compressor_4to2.sv
│       └── counter5to3.sv
├── mantissa_norm.sv                # mantissa normalization
│   ├── lzc.sv
│       └── cf_math_pkg.sv
│   └── barrel_shifter.sv
├── posit_encoder.sv                # posit encoder, packing result components into posit output
│   └── pdpu_pkg.sv
└── └── barrel_shifter.sv
```

**Benefiting from the highly parameterized sub-modules, PDPU can be configured from several aspects, i.e., posit formats, dot-product size, and alignment width.**
- **Supporting custom posit formats:** PDPU supports any combination of word size ($n$) and exponent size ($es$) both for inputs and outputs. This also enables mixed-precision stragety, since the proposed decoder and encoder are capable of extracting and packing data of any posit format, respectively.
- **Supporting diverse dot-product size:**  PDPU is capable of supporting diverse dot-product size ($N$) rather than a specific size, which makes it more scalable for various hardware constraints. To accommodate the variable size, several sub-modules of PDPU are instantiated in parallel, while some others are recursively generated in a tree structure, e.g., comparator tree and carry-save-adder (CSA) tree.
- **Supporting suitable alignment width:** PDPU parameterizes the width ($W_m$) of aligned mantissa, which can be determined based on distribution characteristics of inputs and DNN accuracy requirements. Configured with suitable alignment width, PDPU minimizes the hardware cost while meeting precision, since the bits exceeding $W_m$ wil be discarded directly.

## Publication
if you use PDPU in your work, you can cite us:
```

```