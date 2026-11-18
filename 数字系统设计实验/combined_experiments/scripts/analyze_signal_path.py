"""Check measured-frequency isolation and actual received-signal content at the DAC."""
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output"
REFERENCE = 99999505


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fit_components(t, y, frequencies):
    columns = []
    for f in frequencies:
        columns.extend([np.sin(2*np.pi*f*t), np.cos(2*np.pi*f*t)])
    columns.append(np.ones(len(t)))
    design = np.column_stack(columns)
    coeff = np.linalg.lstsq(design, y, rcond=None)[0]
    components = [{"frequency_hz": float(f),
                   "amplitude_codes": float(np.hypot(coeff[2*i], coeff[2*i+1])),
                   "phase_rad": float(np.arctan2(coeff[2*i+1], coeff[2*i]))}
                  for i, f in enumerate(frequencies)]
    residual = y - design @ coeff
    explained = 1-float(np.var(residual))/max(float(np.var(y)), 1e-30)
    return components, explained


def fft_peaks(t, y, count):
    # Find distinct spectral peaks without supplying expected output frequencies.
    spec = abs(np.fft.rfft((y-y.mean())*np.hanning(len(y))))
    spec[:3] = 0
    spacing = 1/(len(y)*np.median(np.diff(t)))
    result = []
    for _ in range(count):
        index = int(np.argmax(spec))
        result.append(float(index*spacing))
        spec[max(0,index-3):index+4] = 0
    return sorted(result), float(spacing)


def main():
    build = json.loads((OUT/"build_verification.json").read_text(encoding="utf-8"))
    for path, digest in build["source_sha256"].items():
        assert sha(ROOT/path) == digest, f"Built RTL/XDC changed: {path}"
    bit = OUT/"combined_experiments_top.bit"
    assert sha(bit) == build["bitstream_sha256"]
    simlog = OUT/"tb_signal_path.log"
    logtext = simlog.read_text(encoding="utf-8")
    assert "PASS:" in logtext and "Fatal:" not in logtext
    results = []
    compared_capture_samples = 0
    for offset, mode, shift in [(0, "5A", 500000), (6, "5B", 100000)]:
        step = (42949672960*shift+REFERENCE//2)//REFERENCE
        lo = step*(REFERENCE/10)/(2**32)
        single = 550000-lo
        two = [530000-lo, 570000-lo]
        cases = []
        for n, kind in enumerate(["zero_before", "single_96", "single_48", "phase_reversed", "two_tones", "zero_after"], 1):
            path = OUT/f"signal_path_case_{offset+n}.csv"
            data = np.loadtxt(path, delimiter=",", skiprows=1)
            t = data[:,0]*1e-9
            y = data[:,1]
            assert np.array_equal(y, data[:,2]), "Poisoned meter or unrelated DDS affected output"
            assert np.max(np.abs(np.diff(t)-10/REFERENCE)) < 1e-12
            assert 0 < y.min() <= y.max() < 255, "DAC clipping"
            compared_capture_samples += len(y)
            row = {"kind": kind, "file": path.relative_to(ROOT).as_posix(), "samples": len(y),
                   "dac_min": int(y.min()), "dac_max": int(y.max()),
                   "meter_poisoned_dac_identical": True, "sha256": sha(path)}
            if kind.startswith("zero"):
                row["maximum_midpoint_deviation_codes"] = float(np.max(np.abs(y-128)))
                assert row["maximum_midpoint_deviation_codes"] <= 1, row
            else:
                frequencies = two if kind == "two_tones" else [single]
                peaks, spacing = fft_peaks(t, y, len(frequencies))
                assert all(abs(a-b) <= spacing for a,b in zip(peaks, frequencies)), (peaks, frequencies)
                components, explained = fit_components(t, y, frequencies)
                assert all(c["amplitude_codes"]>5 for c in components), components
                assert explained>0.99, (kind, explained)
                row.update({"independently_detected_fft_peaks_hz": peaks,
                            "fit_components": components, "explained_variance": explained})
            cases.append(row)
        high = cases[1]["fit_components"][0]
        low = cases[2]["fit_components"][0]
        reversed_phase = cases[3]["fit_components"][0]
        amplitude_ratio = low["amplitude_codes"]/high["amplitude_codes"]
        assert 0.47<amplitude_ratio<0.53, amplitude_ratio
        phase_change = np.angle(np.exp(1j*(reversed_phase["phase_rad"]-high["phase_rad"])))
        phase_error = abs(abs(phase_change)-np.pi)
        assert phase_error<0.03, float(phase_error)
        assert abs(reversed_phase["amplitude_codes"]/high["amplitude_codes"]-1)<0.03
        results.append({"mode": mode, "lo_hz": lo, "input_amplitude_halved_output_ratio": float(amplitude_ratio),
                        "input_180_degree_change_output_degrees": float(np.degrees(phase_change)),
                        "phase_change_error_degrees": float(np.degrees(phase_error)), "cases": cases})
        print(f"PASS {mode}: meter/DDS isolation, zero input, amplitude ratio={amplitude_ratio:.6f}, "
              f"phase change={np.degrees(phase_change):.6f} degrees, two shifted spectral components")
    report = {"verified_at": datetime.now(timezone(timedelta(hours=8))).isoformat(),
              "conclusion": "5A and 5B translate actual received ADC samples; measured frequency is display-only",
              "bitstream_sha256": sha(bit), "rtl_and_constraints_match_built_bitstream": True,
              "rtl_changed_during_audit": False, "hardware_programmed_by_audit": False,
              "simulation": {"log": "output/tb_signal_path.log", "sha256": sha(simlog),
                             "testbench": "sim/tb_signal_path.sv", "testbench_sha256": sha(ROOT/"sim/tb_signal_path.sv"),
                             "production_parameters_used": True,
                             "corrupt_measurements_hz": [1234567, 0, 9876543],
                             "measurement_valid_forced_both_states": True,
                             "independent_dds_settings": [1, 255],
                             "exactly_matching_captured_dac_samples": compared_capture_samples},
              "results": results,
              "scope": "Full combined RTL path, simulated ADC and physical DAC bus; analog hardware not measured"}
    (OUT/"signal_path_verification.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(f"PASS: {compared_capture_samples} captured DAC samples match exactly with poisoned measurement and a different DDS setting; audited RTL/XDC match the current built bitstream")


if __name__ == "__main__":
    main()
