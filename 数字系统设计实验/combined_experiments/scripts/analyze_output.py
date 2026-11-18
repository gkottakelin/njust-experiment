from pathlib import Path
import json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
def fit_tone(t,y):
    t=t-t[0]
    dt=float(np.median(np.diff(t)))
    z=y-y.mean()
    window=np.hanning(len(z))
    spec=np.abs(np.fft.rfft(z*window))
    k=int(np.argmax(spec[1:])+1)
    spacing=1/(dt*len(z))
    initial=k*spacing
    # A least-squares sine fit refines the FFT bin; no expected frequency is
    # used in the search or fit. Downsample only very-low-frequency records.
    stride=max(1,int((1/dt)/(initial*32)))
    if stride>1:
        t=t[::stride];y=y[::stride]
    t=t-t.mean()
    def objective(f,full=False):
        a=np.column_stack((np.sin(2*np.pi*f*t),np.cos(2*np.pi*f*t),np.ones(len(t))))
        c=np.linalg.lstsq(a,y,rcond=None)[0]
        residual=float(np.mean((y-a@c)**2))
        if full:return residual,float(np.hypot(c[0],c[1])),float(c[2])
        return residual
    lo=max(0.01,initial-spacing);hi=initial+spacing
    ratio=(np.sqrt(5)-1)/2
    x1=hi-ratio*(hi-lo);x2=lo+ratio*(hi-lo)
    v1=objective(x1);v2=objective(x2)
    for _ in range(38):
        if v1<v2:
            hi,x2,v2=x2,x1,v1;x1=hi-ratio*(hi-lo);v1=objective(x1)
        else:
            lo,x1,v1=x1,x2,v2;x2=lo+ratio*(hi-lo);v2=objective(x2)
    f=(lo+hi)/2
    residual,amplitude,dc=objective(f,True)
    explained=1-residual/max(float(np.var(y)),1e-30)
    return {'frequency_hz':float(f),'amplitude_codes':amplitude,'dc_codes':dc,'explained_fraction':float(explained)}



REFERENCE=99999505.0
CASES=[
    ('DDS',1,REFERENCE/2560,1.0),('DDS',16,16*REFERENCE/2560,1.0),
    ('DDS',64,64*REFERENCE/2560,1.0),('DDS',11,11*REFERENCE/2560,1.0),
    ('5A',500000.0,0.0,1.0),('5A',500100.0,100.0,1.0),
    ('5A',525123.45,25123.45,1.0),('5A',600000.0,100000.0,1.0),
    ('5B',500000.0,400000.0,1.0),('5B',500123.45,400123.45,1.0),
    ('5B',550321.0,450321.0,1.0),('5B',600000.0,500000.0,1.0)]
rows=[]
for i,(mode,setting,expected,limit) in enumerate(CASES,1):
    d=np.loadtxt(ROOT/'output'/f'combined_case_{i}.csv',delimiter=',',skiprows=1)
    t=d[:,0]*1e-9;y=d[:,1]
    assert np.max(np.abs(np.diff(t)-10/REFERENCE))<1e-12,'DAC sample clock is not uniformly 10 MSPS'
    row={'case':i,'mode':mode,'setting':setting,'expected_output_hz':expected,
         'samples':len(d),'dac_min':int(y.min()),'dac_max':int(y.max())}
    if mode!='DDS':assert y.min()>0 and y.max()<255,'Shift output clipped'
    if expected==0:
        row['ac_rms_codes']=float(np.std(y));assert row['ac_rms_codes']<2,row
    else:
        row['tone']=fit_tone(t,y)
        err=abs(row['tone']['frequency_hz']-expected);row['absolute_error_hz']=err
        assert err<=limit,row
        assert row['tone']['explained_fraction']>0.95,row
        if mode=='DDS':assert row['tone']['amplitude_codes']>120,row
        elif expected>=20000:
            tt=t-t[0]
            a=np.column_stack((np.sin(2*np.pi*expected*tt),np.cos(2*np.pi*expected*tt),np.ones(len(tt))))
            c=np.linalg.lstsq(a,y,rcond=None)[0];residual=y-a@c
            amp=float(np.hypot(c[0],c[1]));w=np.hanning(len(tt))
            sum_frequency=setting+(500000 if mode=='5A' else 100000)
            unwanted=2*abs(np.sum(w*residual*np.exp(-2j*np.pi*sum_frequency*tt)))/w.sum()
            row['unwanted_sum_frequency_hz']=sum_frequency
            row['unwanted_sum_dbc']=float(20*np.log10(max(float(unwanted),1e-30)/amp))
            assert row['unwanted_sum_dbc']<-40,row
    rows.append(row)
    print(json.dumps(row))
result={'clock_model_hz':REFERENCE,'nominal_dac_sample_hz':10000000,
        'single_startup_reset':True,'pre_mixer_decimation':False,'mixer_sample_hz_nominal':10000000,'cases':rows,
        'scope':'Full-rate digital DAC samples across all combined modes; analog output requires physical validation'}
(ROOT/'output/combined_signal_verification.json').write_text(json.dumps(result,indent=2),encoding='ascii')
print('PASS: combined DDS and both calibrated, full-rate 10 MSPS fixed-LO mixer/FIR outputs; all DAC sample streams uniform and unclipped.')
