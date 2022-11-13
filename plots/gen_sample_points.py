# Author: Qiong Li
# Date: 2022-10-03
# Reference: ../decimal_precision/gen_format_value.py (Chao Fang)

import numpy as np

# Decimal Precision Function
def cal_dec_accuracy(x_pair):
    if np.isinf(x_pair[0]) or x_pair[0] < 1e-20 or x_pair[0] == x_pair[1]:
        return 100
    return -np.log10(np.abs(np.log10(x_pair[0]/x_pair[1])))
    #return -np.log10(abs((x_pair[0]-x_pair[1])/x_pair[0]))

def interp(exact_data, interval):
    """在真值区间内采样interval个点"""
    exp_exact_data = np.log10(exact_data)
    data_num = len(exact_data)
    exp_sample_data_set = []
    sample_pair = []
    for idx in range(data_num - 1):
        # linspace()函数：返回指定区间内均匀间隔的数字，默认包含区间端点(endpoint=True)
        # 在log10区间内均匀采样，此处修改添加"endpoint=False"
        exp_data_sample = np.linspace(exp_exact_data[idx], exp_exact_data[idx + 1], interval + 1, endpoint=False)[1: ]
        data_sample = 10 ** exp_data_sample
        # [0]为data_sample，也即理论值(correct_value)，[1]为真值，也即实际值
        curr_pair = list(zip(data_sample, [exact_data[idx]] * interval))
        exp_sample_data_set += exp_data_sample.tolist()
        sample_pair += curr_pair
        # print("[idx={}, data={}, generated_pair={}]".format(idx, exact_data[idx], curr_pair))
    dec_prec = np.array(list(map(cal_dec_accuracy, sample_pair)))
    exp_sample_data_set = np.array(exp_sample_data_set)

    return exp_sample_data_set, dec_prec