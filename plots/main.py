# Author: Qiong Li
# Date: 2022-10-03
# Intro: 绘制不同数据格式（Posit格式/FP格式）的小数精度分布及数据分布直方图

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.ticker import (
    MultipleLocator,
    PercentFormatter
)
from gen_exact_values import(
    gen_posit_value,
    gen_fp_value
)
from gen_sample_points import interp

if __name__ == "__main__":
    # 子图1
    # 获取数据真值
    log_range = 10
    fp16_value = gen_fp_value(Nbits=16,ebits=5,log_range=log_range)
    posit16_0_value = gen_posit_value(Nbits=16,es=0,log_range=log_range)
    posit16_1_value = gen_posit_value(Nbits=16,es=1,log_range=log_range)
    posit16_2_value = gen_posit_value(Nbits=16,es=2,log_range=log_range)
    # 采样并计算小数精度
    fp16_pair = interp(fp16_value,interval=1)
    posit16_0_pair = interp(posit16_0_value,interval=1)
    posit16_1_pair = interp(posit16_1_value,interval=1)
    posit16_2_pair = interp(posit16_2_value,interval=1)
    
    coding_result = {
        "FP16":fp16_pair,
        
        "P(16,0)":posit16_0_pair,
        "P(16,1)":posit16_1_pair,
        "P(16,2)":posit16_2_pair
    }
    # 参考:《Python作图颜色汇总》https://blog.csdn.net/gsgbgxp/article/details/119349882
    colors = ['red','lime','deepskyblue','peru']

    # 子图1
    plt.rc('font', family='DejaVu Math TeX Gyre')
    fig, ax1 = plt.subplots(1, 1, figsize=(12, 5))
    for idx, (label,data_pair) in enumerate(coding_result.items()):
        # alpha表示散点透明度，0表示完全透明，1表示完全不透明
        ax1.plot(data_pair[0],data_pair[1],label=label,alpha=0.5,color=colors[idx],linewidth=2.0)
        ax1.plot((data_pair[0][0],data_pair[0][0]),(0,data_pair[1][0]),linestyle='--',alpha=0.5,color=colors[idx],linewidth=2.0)
        ax1.plot((data_pair[0][-1],data_pair[0][-1]),(0,data_pair[1][-1]),linestyle='--',alpha=0.5,color=colors[idx],linewidth=2.0)
    # 设置坐标轴的范围及刻度
    ax1.set_xbound(lower=-log_range,upper=log_range)
    ax1.set_ybound(lower=0)
    # 使用set_major_locator函数指定坐标轴主刻度数值倍数 (MultipleLocator)
    ax1.xaxis.set_major_locator(MultipleLocator(4))
    ax1.xaxis.set_minor_locator(MultipleLocator(1))
    # 设置子图1坐标轴标签
    ax1.set_xlabel("log10(x)",fontsize=20)
    ax1.set_ylabel("Decimal Accuracy",fontsize=20)
    ax1.tick_params(labelsize=18)
    # 设置子图1坐标轴刻度的字体大小（包括x轴和y轴）
    ax1.legend(fontsize=16)

    # 子图2
    ax2 = ax1.twinx()
    # 读取.txt文件中的数据，返回列表类型
    data_file = './dnn_data/resnet18_acts_conv1_1x3x224x224_fp64.bin'
    # data = np.loadtxt("precision_curve/data.txt",dtype=np.float64)
    data = np.fromfile(data_file, dtype=np.float64)
    nonzero_data = np.abs(data[ data != 0 ])
    
    # 将data线性域转换为对数域(log10)
    log_data = np.log10(np.abs(nonzero_data))
    weights = np.ones_like(log_data)/float(len(log_data))
    ax2.set_ylim((0,0.5))
    # ax2.yaxis.set_major_formatter(PercentFormatter(xmax=1, decimals=1))
    ax2.set_ylabel("Percentage",fontsize=20,color='purple')
    ax2.hist(log_data, bins=12, rwidth=0.9, weights=weights, color='#cba0e6') # 紫色
    # ax2.hist(log_data, bins=12, rwidth=0.9, weights=weights, color='purple') # 紫色
    # 调整子图2坐标轴刻度字体大小
    ax2.tick_params(labelsize=18,colors="purple")

    plt.savefig("../docs/figs/precision_distribution.png",bbox_inches='tight')
    plt.show()
