"""Independent integer convolution check of actual ADC-to-DAC waveform captures."""
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output'
REFERENCE=99999505

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def analyze():
    log=OUT/'tb_waveform_translation.log'
    assert 'PASS:' in log.read_text() and 'Fatal:' not in log.read_text()
    configs=json.loads((OUT/'fullrate_fir_design.json').read_text())
    cases=np.loadtxt(OUT/'waveform_cases.csv',delimiter=',',skiprows=1)
    assert len(cases)==18
    rows=[]
    cosine=np.rint(16384*np.cos(2*np.pi*np.arange(1024)/1024)).astype(np.int64)
    for case,mode,kind,freq,duty,input_amplitude in cases:
        case=int(case); mode='5A' if mode==16 else '5B'
        source=OUT/f'waveform_input_{case}.csv';dest=OUT/f'waveform_output_{case}.csv'
        x=np.loadtxt(source,delimiter=',',skiprows=1)
        y=np.loadtxt(dest,delimiter=',',skiprows=1)
        assert np.max(abs(np.diff(x[:,0])-1e10/REFERENCE))<2e-6
        assert np.max(abs(np.diff(y[:,0])-1e10/REFERENCE))<2e-6
        shift=500000 if mode=='5A' else 100000
        step=(42949672960*shift+REFERENCE//2)//REFERENCE
        # The bench releases external reset at 40 ns. Synchronous release and
        # ADC/conditioner registers make the first mixer sample system edge 12.5.
        # Compute NCO phase directly from time and its fixed increment; do not
        # read internal mixed or FIR data from the simulated design.
        sample_index=(x[:,0]*REFERENCE/1e9-12.5)/10
        index=np.rint(sample_index).astype(np.int64)
        assert max(abs(sample_index-index))<2e-7
        phase=(index*step)&0xffffffff
        mixed=((x[:,1].astype(np.int64)<<4)*cosine[phase>>22]+8192)>>14
        coefficients=np.array(configs[mode]['coefficients'],dtype=np.int64)
        filtered=(np.convolve(mixed,coefficients)[:len(mixed)]+32768)>>16
        expected=np.clip(((filtered+32)>>6)+128,0,255)
        start=len(coefficients)+10
        # FIR pipeline plus DAC falling-edge register and rising-edge latch is
        # exactly three sample slots for both branches (not their group delay).
        # Capture starts can fall between ADC and DAC edges; align by recorded
        # timestamps. The fixed ADC-mixer-input to DAC rising-edge delay is 29 ticks.
        lag=int(round((29e9/REFERENCE-(y[0,0]-x[0,0]))/(1e10/REFERENCE)))
        actual=y[start:,1].astype(np.int64)
        predicted=expected[start-lag:len(y)-lag]
        error=actual-predicted
        assert len(actual)==len(predicted)
        assert max(abs(error))==0, (case,mode,dict(zip(*np.unique(error,return_counts=True))))
        assert 0<actual.min()<=actual.max()<255
        row={'case':case,'mode':mode,'input_kind':['sine','square','triangle','fundamental_plus_third'][int(kind)],
             'input_frequency_hz':freq,'input_adc_amplitude_codes':input_amplitude,'duty_or_ramp_fraction':duty,
             'compared_samples':len(actual),'maximum_integer_model_error_codes':int(max(abs(error))),
             'rms_integer_model_error_codes':float(np.sqrt(np.mean(error.astype(float)**2))),
             'dac_min':int(actual.min()),'dac_max':int(actual.max()),
             'input_sha256':sha(source),'output_sha256':sha(dest)}
        rows.append(row)
        print(f"PASS waveform {case} {mode}: {row['input_kind']} {freq:g} Hz, {len(actual)} samples exactly equal to independent fixed-LO mixer / FIR model")
    report={'scope':'Digital ADC captures through actual 10 MSPS fixed-LO mixer, FIR and physical DAC bus; waveform identity is not required',
            'sample_hz_nominal':10000000,'pre_mixer_decimation':False,
            'measurement_controls_output':False,'cases':rows,
            'testbench_sha256':sha(ROOT/'sim/tb_waveform_translation.sv'),
            'log_sha256':sha(log),'total_exactly_matching_samples':sum(r['compared_samples'] for r in rows)}
    (OUT/'waveform_translation_verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f"PASS: {len(rows)} cases, {report['total_exactly_matching_samples']} exact integer ADC/mixer/FIR/DAC comparisons")

if __name__=='__main__':
    analyze()
