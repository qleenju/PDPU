import numpy as np

def gen_posit_value(Nbits, es, log_range=16, eps=1e-20):
    """Generate real numbers that can be represented with posit(Nbits,es) format"""
    assert es < Nbits

    res = []
    num = 2 ** (Nbits-1)
    for ele in range(num):
        ele_str = bin(ele).split('b')[1].zfill(Nbits - 1).ljust(Nbits - 1 + es + 1, '0')
        regime_msb = ele_str[0]
        idx_first_flipped = ele_str.find('1') if regime_msb == '0' else ele_str.find('0')
        max_k_flag = (idx_first_flipped == -1)
        if max_k_flag is False:
            val_k = -idx_first_flipped if regime_msb == '0' else idx_first_flipped - 1
            # seg_k = ele_str[: idx_first_flipped]
        else:
            val_k = -(Nbits - 1)
            # seg_k = ele_str[: Nbits - 1]
            idx_first_flipped = Nbits - 1
        
        if idx_first_flipped == Nbits - 1:
            idx_es_start = idx_first_flipped
        else:
            idx_es_start = idx_first_flipped + 1
        if es > 0:
            val_e = int(ele_str[idx_es_start: idx_es_start + es], 2)
        else:
            val_e = 0
        # seg_e = ele_str[idx_es_start: idx_es_start + es]

        shift_fbits = len(ele_str[idx_es_start + es: ])
        tmpv_fbits = int(ele_str[idx_es_start + es: ], 2)
        val_f = tmpv_fbits / (2.0 ** shift_fbits)
        # seg_f = ele_str[idx_es_start + es: ]

        val = 2.0 ** (val_k * 2 ** es + val_e) * (1 + val_f)
        
        res.append(val)

    res = np.array(res)
    res = res[res > eps]
    res = res[ np.log10(res) < log_range ]
    res = res[ np.log10(res) > -log_range ]
    
    return res

def gen_fp_value(Nbits, ebits, denorm=True, log_range=16, eps=1e-20):
    """Generate real numbers that can be represented with float(Nbits,ebits) format"""
    assert ebits < Nbits
    bias = 2**(ebits-1)-1
    fbits = Nbits - ebits - 1
 
    res = []
    num = 2 ** (Nbits-1)
    for ele in range(num):
        ele_str = bin(ele).split('b')[1].zfill(Nbits - 1)
        
        seg_ebits = ele_str[: ebits]
        seg_fbits = ele_str[ebits: ]

        tmpv_ebits = int(seg_ebits, 2)
        tmpv_fbits = int(seg_fbits, 2)

        if tmpv_ebits == 2 ** ebits - 1:
            continue
        elif tmpv_ebits == 0 and tmpv_fbits == 0:
            val = 0.0
        elif tmpv_ebits == 0 and denorm is True:
            val_ebits = 1 - bias
            val_fbits = tmpv_fbits / (2.0 ** fbits)
            val = 2.0 ** val_ebits * val_fbits
        else:
            val_ebits = tmpv_ebits - bias
            val_fbits = tmpv_fbits / (2.0 ** fbits)
            val = 2.0 ** val_ebits * (1 + val_fbits)

        # print("[Binary:{} | Value:{}] seg:(e)-(f) ==> ({})-({})".format(ele_str, val, seg_ebits, seg_fbits))
        res.append(val)
    
    res = np.array(res)
    res = res[res > eps]
    res = res[ np.log10(res) < log_range ]
    res = res[ np.log10(res) > -log_range ]
    
    return res