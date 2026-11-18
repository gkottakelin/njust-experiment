"""Plot recorded digital samples; no analog reconstruction or invented data."""
from pathlib import Path
import sys
import json

P=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(P.parent/'tmp/guide_pydeps'))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties

OUT=P/'output'
verification=json.loads((OUT/'waveform_translation_verification.json').read_text())
assert len(verification['cases'])==18
assert all(c['maximum_integer_model_error_codes']==0 for c in verification['cases'])
font_path=Path('C:/Windows/Fonts/msyh.ttc')
if font_path.exists():
    font=FontProperties(fname=str(font_path))
    plt.rcParams['font.family']=font.get_name()
plt.rcParams.update({'font.size':10,'axes.unicode_minus':False,'axes.spines.top':False,
                     'axes.spines.right':False,'savefig.facecolor':'white'})
fig,axes=plt.subplots(3,3,figsize=(12,8),layout='constrained')
labels=['正弦输入','方波输入','三角波输入']
for column,(case_a,case_b) in enumerate([(1,10),(3,12),(4,13)]):
    for row,case in enumerate([case_a,case_a,case_b]):
        prefix='waveform_input' if row==0 else 'waveform_output'
        data=np.loadtxt(OUT/f'{prefix}_{case}.csv',delimiter=',',skiprows=1)
        start=1000
        time=(data[start:,0]-data[start,0])*1e-3
        values=data[start:,1]
        limit=60 if row==1 else 8
        keep=time<=limit
        ax=axes[row,column]
        ax.step(time[keep],values[keep],where='post',linewidth=1.4,
                color=['#6c7280','#1565c0','#00866a'][row])
        ax.set_xlim(0,limit);ax.set_xlabel('相对时间（μs）');ax.grid(alpha=0.2)
        if row==0:ax.set_title(labels[column]);ax.set_ylim(-115,115)
        else:ax.set_ylim(90,166)
        if column==0:
            ax.set_ylabel(['去直流ADC码\n550 kHz输入','5A DAC码\n差频50 kHz','5B DAC码\n差频450 kHz'][row])
fig.suptitle('全程10 MSPS：实际接收样本 → 固定本振混频 → FIR → DAC',fontsize=15)
fig.supxlabel('数字仿真；每行采用自己的时间尺度，各采集段独立计时；不包含P4模拟滤波响应。',fontsize=10)
fig.savefig(OUT/'waveform_translation_comparison.png',dpi=180)
fig.savefig(OUT/'waveform_translation_comparison.svg')
plt.close(fig)
print(OUT/'waveform_translation_comparison.png')
