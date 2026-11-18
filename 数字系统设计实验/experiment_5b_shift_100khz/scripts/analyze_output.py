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


INPUTS=[500000.0, 500123.45, 550321.0, 600000.0]
SHIFT=100000
REFERENCE=99999500.0
LIMIT=0.25
ARCHIVE=ROOT/'archive/20261026_before_output_quality_fix/output'

def tone_stats(t,y,f):
    t=t-t[0]
    a=np.column_stack((np.sin(2*np.pi*f*t),np.cos(2*np.pi*f*t),np.ones(len(t))))
    c=np.linalg.lstsq(a,y,rcond=None)[0]
    amplitude=float(np.hypot(c[0],c[1]))
    residual=y-a@c
    ratio=10*np.log10(max(amplitude**2/2,1e-30)/max(float(np.mean(residual**2)),1e-30))
    window=np.hanning(len(t))
    image_amplitudes=[]
    for image_f in [REFERENCE/50-f,REFERENCE/50+f]:
        image_amplitudes.append(2*abs(np.sum(window*residual*np.exp(-2j*np.pi*image_f*t)))/np.sum(window))
    image_db=20*np.log10(max(float(max(image_amplitudes)),1e-30)/max(amplitude,1e-30))
    return {'amplitude_codes':amplitude,'dc_codes':float(c[2]),
            'single_tone_residual_db':float(ratio),'first_image_dbc':float(image_db),
            'fitted_phase':float(np.arctan2(c[1],c[0]))}

def svg_preview(old_y,old_dt,new_t,new_y,f,old_stat,new_stat):
    # Two periods, each aligned to its independently fitted fundamental phase.
    width,height=1000,430
    panels=[]
    for j,(title,y,dt,stat) in enumerate([
        ('Before: 2 MSPS data, repeated five DAC clocks',old_y,old_dt,old_stat),
        ('After: 10 MSPS interpolated DAC data',new_y,float(np.median(np.diff(new_t))),new_stat)]):
        count=min(len(y),int(np.ceil(2/f/dt))+2)
        yy=(y[:count]-stat['dc_codes'])/stat['amplitude_codes']
        xx=np.arange(count)*dt
        x=lambda v:70+float(v)*860/(2/f)
        cy=110+j*200
        py=lambda v:cy-65*float(v)
        points=[]
        for k in range(count-1):
            points.extend([(x(xx[k]),py(yy[k])),(x(xx[k+1]),py(yy[k]))])
        path=' '.join(f'{a:.2f},{b:.2f}' for a,b in points if a<=931)
        ideal_t=np.linspace(0,2/f,500)
        ideal=' '.join(f'{x(t):.2f},{py(np.sin(2*np.pi*f*t+stat["fitted_phase"])):.2f}' for t in ideal_t)
        panels.append(f'<text x="70" y="{cy-82}" font-size="16">{title}</text>'
                      f'<path d="M70 {cy}H930" stroke="#cbd5e1"/>'
                      f'<polyline points="{ideal}" fill="none" stroke="#94a3b8" stroke-width="1.3"/>'
                      f'<polyline points="{path}" fill="none" stroke="{["#dc5b48","#176fc0"][j]}" stroke-width="2"/>'
                      f'<text x="70" y="{cy+90}" font-size="13">0</text>'
                      f'<text x="800" y="{cy+90}" font-size="13">{2/f*1e6:.3f} us (two cycles)</text>')
    text=f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="white"/><g font-family="Segoe UI,Arial" fill="#1e293b">'+''.join(panels)+'<text x="70" y="424" font-size="11">Digital code streams, normalized per panel; new linear scaling = 2x. Analog output is not measured.</text></g></svg>'
    (ROOT/'output/output_quality_comparison.svg').write_text(text,encoding='utf-8')

rows=[]
for i,fin in enumerate(INPUTS,1):
    d=np.loadtxt(ROOT/'output'/f'translated_case_{i}.csv',delimiter=',',skiprows=1)
    full=np.loadtxt(ROOT/'output'/f'dac_case_{i}.csv',delimiter=',',skiprows=1)
    t=d[:,0]*1e-9;td=full[:,0]*1e-9;y=full[:,1]
    assert np.max(np.abs(np.diff(t)-50/REFERENCE))<1e-12
    assert np.max(np.abs(np.diff(td)-10/REFERENCE))<1e-12
    assert len(full)>=5*len(d)-6 and len(full)<=5*len(d)+6
    assert y.min()>0 and y.max()<255,'Unexpected DAC clipping'
    row={'input_hz':fin,'expected_output_hz':fin-SHIFT,'samples':len(d),
         'dac_samples':len(full),'simulated_reference_hz':REFERENCE,
         'verification_limit_hz':LIMIT,'dac_code_min':int(y.min()),'dac_code_max':int(y.max())}
    if fin==SHIFT:
        row['filtered_ac_rms_codes']=float(np.std(d[:,1]/16))
        row['dac_ac_rms_codes']=float(np.std(y))
        assert row['filtered_ac_rms_codes']<2 and row['dac_ac_rms_codes']<2,row
    else:
        for key,tt,yy in [('filtered',t,d[:,1]/16),('dac',td,y)]:
            row[key]=fit_tone(tt,yy)
            row[key]['absolute_error_hz']=abs(row[key]['frequency_hz']-(fin-SHIFT))
            assert row[key]['absolute_error_hz']<=LIMIT,row
            assert row[key]['explained_fraction']>0.95,row
        old=np.loadtxt(ARCHIVE/f'translated_case_{i}.csv',delimiter=',',skiprows=1)
        old_dt=float(np.median(np.diff(old[:,0])))*1e-9/5
        old_y=np.repeat(old[:,2],5)
        old_t=np.arange(len(old_y))*old_dt
        before=tone_stats(old_t,old_y,fin-SHIFT)
        after=tone_stats(td,y,fin-SHIFT)
        quality={'before':before,'after':after,
                 'first_image_improvement_db':before['first_image_dbc']-after['first_image_dbc'],
                 'amplitude_ratio':after['amplitude_codes']/before['amplitude_codes'],
                 'tone_residual_improvement_db':after['single_tone_residual_db']-before['single_tone_residual_db']}
        row['quality']=quality
        if fin-SHIFT>=20000:
            assert quality['first_image_improvement_db']>10,row
            assert quality['tone_residual_improvement_db']>3,row
        if i==len(INPUTS):svg_preview(old_y,old_dt,td,y,fin-SHIFT,before,after)
    rows.append(row)
    summary={k:v for k,v in row.items() if k not in ['filtered','dac','quality']}
    if 'dac' in row:summary['frequency_error_hz']=row['dac']['absolute_error_hz']
    if 'quality' in row:summary['quality']=row['quality']
    print(json.dumps(summary))
(ROOT/'output/translation_verification.json').write_text(json.dumps(rows,indent=2),encoding='ascii')
quality={'project':ROOT.name,'nominal_full_dac_rate_hz':10000000,
         'nominal_dsp_rate_hz':2000000,'interpolation_factor':5,
         'fractional_bits':4,'dac_gain_relative_to_old':2,
         'baseline_reconstruction':'Archived 2 MSPS DAC codes repeated five times, equivalent up to constant sample phase for spectral magnitude',
         'scope':'Simulated digital DAC-code stream, before physical DAC hold and analog P4 filter',
         'cases':rows}
(ROOT/'output/output_quality_verification.json').write_text(json.dumps(quality,indent=2),encoding='ascii')
print('PASS: full-rate DAC cadence, frequency, headroom and anti-image filtering.')
