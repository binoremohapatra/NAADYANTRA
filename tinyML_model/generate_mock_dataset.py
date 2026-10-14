#!/usr/bin/env python3
"""
generate_mock_dataset.py
Synthetic data generator for the ITI trainee diagnostic wearable.

Outputs
  dataset/<class>/<class>_#####.wav   16 kHz, mono, 16-bit, 500 ms (8000 samples)
  hazard_telemetry.csv                slow-sensor tabular data (5 hazard states)

Anti-shortcut design
  * Every class is built on top of the SAME randomised ambient bed (random mains-hum
    fundamental 40-130 Hz with a random harmonic subset, pink noise, slow pipe flow),
    so "hum present" / "pink noise present" is not a class cue.
  * Fundamental, harmonic count/weights, band edges, decay times and SNRs are drawn
    per sample -> no fixed harmonic signature that a network could collapse onto.
  * Every waveform is DC-removed, RMS loudness-matched to one target, then soft-limited
    to a common peak ceiling, so amplitude/energy carries no label information.
    The model has to learn spectral/temporal structure.
Mock data only: real deployment needs real recordings (see README).
"""
import argparse
import csv
import os

import numpy as np
from scipy import signal
from scipy.io import wavfile

FS = 16000
N = 8000                      # 500 ms window
PAD = 4000                    # filter warm-up margin
CLASSES = ["normal", "clatter", "minor_leak", "major_leak"]
TARGET_RMS = 0.05             # -26 dBFS, identical for all classes
PEAK_CEIL = 0.90


# ----------------------------------------------------------------------------- DSP helpers
def colored_noise(n, rng, beta):
    """Noise with power ~ 1/f^beta (beta=0 white, 1 pink, 2 brown)."""
    spec = rng.standard_normal(n // 2 + 1) + 1j * rng.standard_normal(n // 2 + 1)
    f = np.arange(n // 2 + 1, dtype=np.float64)
    f[0] = 1.0
    spec = spec / np.power(f, beta / 2.0)
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def _sos(kind, cut, order=4):
    return signal.butter(order, cut, btype=kind, fs=FS, output="sos")


def bandpass(x, lo, hi, order=4):
    return signal.sosfilt(_sos("band", [lo, hi], order), x)


def lowpass(x, fc, order=4):
    return signal.sosfilt(_sos("low", fc, order), x)


def highpass(x, fc, order=4):
    return signal.sosfilt(_sos("high", fc, order), x)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))) + 1e-12)


def scale_to_snr(sig, ref, snr_db):
    """Scale `sig` so rms(sig)/rms(ref) = snr_db."""
    return sig * (rms(ref) * 10.0 ** (snr_db / 20.0) / rms(sig))


def crop(x):
    return x[PAD:PAD + N]


def slow_am(rng, n, depth, f_lo, f_hi):
    t = np.arange(n) / FS
    f = rng.uniform(f_lo, f_hi)
    ph = rng.uniform(0, 2 * np.pi)
    return 1.0 + depth * np.sin(2 * np.pi * f * t + ph)


# ----------------------------------------------------------------------------- ambient bed
def ambient(rng, n=N + 2 * PAD):
    t = np.arange(n) / FS
    # Mains / machinery hum: random fundamental and random harmonic subset.
    f0 = rng.uniform(40.0, 130.0)
    hum = np.zeros(n)
    for h in range(1, rng.integers(2, 8)):
        if rng.random() < 0.7:
            amp = 1.0 / (h ** rng.uniform(0.3, 2.0))
            hum += amp * np.sin(2 * np.pi * f0 * h * t + rng.uniform(0, 2 * np.pi))
    hum /= (rms(hum) if np.any(hum) else 1.0)
    pink = colored_noise(n, rng, rng.uniform(0.7, 1.3))
    flow = lowpass(colored_noise(n, rng, rng.uniform(0.0, 1.0)), rng.uniform(150, 900))
    flow = flow / rms(flow) * slow_am(rng, n, rng.uniform(0.1, 0.5), 0.3, 3.0)
    w_hum, w_pink, w_flow = rng.uniform(0.0, 1.0), rng.uniform(0.2, 1.0), rng.uniform(0.0, 1.0)
    bed = w_hum * hum + w_pink * pink + w_flow * flow
    # HVAC / airflow band that is NOT in the leak band: stops "any HF == leak" shortcut.
    if rng.random() < 0.4:
        lo = rng.uniform(300, 2200)
        air = bandpass(colored_noise(n, rng, 0.0), lo, lo + rng.uniform(400, 1300))
        bed += rng.uniform(0.2, 0.9) * air / rms(air)
    return bed / rms(bed)


# ----------------------------------------------------------------------------- class sources
def impact(rng, n):
    """Damped multi-mode strike (hammer tap / dropped wrench)."""
    out = np.zeros(n)
    k = int(rng.integers(1, 6))
    for _ in range(k):
        t0 = int(rng.integers(PAD, PAD + N - 400))          # always inside the cropped window
        length = int(rng.uniform(0.01, 0.12) * FS)
        length = min(length, PAD + N - t0)
        tt = np.arange(length) / FS
        ev = np.zeros(length)
        for _m in range(int(rng.integers(2, 5))):
            fm = rng.uniform(300, 6500)
            tau = rng.uniform(0.002, 0.04)
            ev += rng.uniform(0.3, 1.0) * np.exp(-tt / tau) * np.sin(
                2 * np.pi * fm * tt + rng.uniform(0, 2 * np.pi))
        click = int(rng.uniform(0.0005, 0.003) * FS)
        ev[:click] += rng.standard_normal(click) * rng.uniform(0.5, 2.0)
        out[t0:t0 + length] += ev * rng.uniform(0.4, 1.0)
    return out


def grinder_burst(rng, n):
    """Gated band-limited noise with a buzzing amplitude (angle grinder / drill)."""
    out = np.zeros(n)
    t0 = int(rng.integers(PAD, PAD + N - 1600))
    length = int(rng.uniform(0.08, 0.30) * FS)
    length = min(length, PAD + N - t0)
    lo = rng.uniform(800, 3000)
    body = bandpass(colored_noise(length + 400, rng, rng.uniform(0, 1)), lo, lo + rng.uniform(1000, 3000))[400:]
    tt = np.arange(length) / FS
    buzz = 1.0 + 0.6 * np.sin(2 * np.pi * rng.uniform(100, 400) * tt)
    env = np.hanning(length) ** rng.uniform(0.2, 0.8)
    out[t0:t0 + length] = body * buzz * env
    return out


def make_normal(rng):
    return crop(ambient(rng))


def make_clatter(rng):
    n = N + 2 * PAD
    bed = ambient(rng, n)
    ev = impact(rng, n)
    if rng.random() < 0.35:
        g = grinder_burst(rng, n)
        ev = ev + g * (np.max(np.abs(ev)) / (np.max(np.abs(g)) + 1e-9)) * rng.uniform(0.3, 1.0)
    # peak-of-event to RMS-of-bed ratio drawn per clip (events are short, so use peak)
    ev = ev * (rms(bed) * 10.0 ** (rng.uniform(8, 24) / 20.0)) / (np.max(np.abs(ev)) + 1e-9)
    return crop(bed + ev)


def make_minor_leak(rng):
    n = N + 2 * PAD
    bed = ambient(rng, n)
    lo = rng.uniform(3600, 4600)
    hi = rng.uniform(6400, 7400)
    hiss = bandpass(colored_noise(n, rng, rng.uniform(-0.2, 0.3)), lo, hi, order=int(rng.integers(3, 6)))
    hiss = hiss / rms(hiss) * slow_am(rng, n, rng.uniform(0.0, 0.25), 0.5, 4.0)
    hiss = scale_to_snr(hiss, bed, rng.uniform(3, 20))
    return crop(bed + hiss)


def make_major_leak(rng):
    n = N + 2 * PAD
    bed = ambient(rng, n)
    broad = colored_noise(n, rng, rng.uniform(-0.3, 0.8))
    broad = bandpass(broad, rng.uniform(80, 250), rng.uniform(7000, 7800), order=3)
    rumble = lowpass(colored_noise(n, rng, rng.uniform(1.0, 2.0)), rng.uniform(120, 250), order=3)
    mix = broad / rms(broad) + rng.uniform(0.7, 3.0) * rumble / rms(rumble)
    # pressure fluctuation: periodic swell plus slow random-walk gain
    walk = np.cumsum(rng.standard_normal(n)) / np.sqrt(n)
    walk = lowpass(walk, 8.0, order=2)
    am = slow_am(rng, n, rng.uniform(0.2, 0.6), 0.5, 6.0) * (1.0 + 0.3 * walk / (np.std(walk) + 1e-9))
    mix = mix * np.clip(am, 0.1, None)
    mix = scale_to_snr(mix, bed, rng.uniform(3, 18))
    return crop(bed + mix)


MAKERS = {"normal": make_normal, "clatter": make_clatter,
          "minor_leak": make_minor_leak, "major_leak": make_major_leak}


# ----------------------------------------------------------------------------- loudness matching
def loudness_match(x):
    x = x - np.mean(x)
    x = x * (TARGET_RMS / rms(x))
    pk = np.max(np.abs(x))
    if pk > PEAK_CEIL:                       # soft limiter keeps RMS essentially unchanged
        x = PEAK_CEIL * np.tanh(x / PEAK_CEIL)
        x = x * (TARGET_RMS / rms(x))
        x = np.clip(x, -0.99, 0.99)
    return x


# ----------------------------------------------------------------------------- telemetry
def gen_telemetry(rng, per_state):
    rows = []
    for state in range(5):
        for _ in range(per_state):
            amb = float(np.clip(rng.normal(31, 5), 15, 48))
            vel = float(rng.normal(0, 18))
            gas = float(rng.normal(0, 0.9))
            uv = float(abs(rng.normal(0.15, 0.2)))
            dist = float(rng.uniform(150, 1200))
            tobj = amb + abs(float(rng.normal(3, 6)))
            if state == 0:
                dist = float(rng.uniform(150, 1000)) if rng.random() < 0.8 else float(rng.uniform(1000, 2000))
            elif state == 1:     # Safe arc: 200-350 mm, high UV, workpiece warm but < 210C
                dist = float(rng.uniform(195, 355))
                uv = float(rng.uniform(2.8, 11.5))
                tobj = min(amb + float(rng.uniform(20, 150)), 205.0)
                if rng.random() < 0.05:
                    gas = float(rng.normal(0, 1.4))
            elif state == 2:     # Proximity breach (priority hazard): anything else can co-occur
                dist = float(rng.uniform(25, 149))
                vel = float(rng.normal(-30, 60))
                if rng.random() < 0.5:
                    uv = float(rng.uniform(2.8, 11.5))
                    tobj = min(amb + float(rng.uniform(20, 150)), 380.0)
                if rng.random() < 0.2:
                    gas = float(10 ** rng.uniform(0.4, 1.6))
                if rng.random() < 0.1:
                    tobj = float(rng.uniform(210, 380))
            elif state == 3:     # Gas build-up, no proximity breach
                dist = float(rng.uniform(150, 1000))
                gas = float(10 ** rng.uniform(np.log10(2.6), np.log10(50)))
                if rng.random() < 0.3:
                    uv = float(rng.uniform(2.8, 11.5))
                    tobj = min(amb + float(rng.uniform(20, 150)), 205.0)
            elif state == 4:     # Overheat, not proximity, not gas
                dist = float(rng.uniform(150, 1000))
                tobj = float(rng.uniform(212, 380))
                if rng.random() < 0.4:
                    uv = float(rng.uniform(2.8, 11.5))
                gas = float(rng.normal(0, 1.0))
            # sensor noise / clipping to physical ranges
            dist = float(np.clip(dist + rng.normal(0, 3), 20, 2000))
            tobj = float(np.clip(tobj + rng.normal(0, 0.8), -40, 380))
            uv = float(np.clip(uv, 0, 12))
            gas = float(np.clip(gas, -20, 80))
            rows.append([round(dist, 1), round(vel, 1), round(tobj, 2), round(amb, 2),
                         round(tobj - amb, 2), round(uv, 2), round(gas, 2), state])
    rng.shuffle(rows)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out_dir", default="dataset")
    ap.add_argument("--per_class", type=int, default=600, help="500 ms clips per acoustic class")
    ap.add_argument("--per_state", type=int, default=1500, help="telemetry rows per hazard state")
    ap.add_argument("--csv", default="hazard_telemetry.csv")
    ap.add_argument("--seed", type=int, default=1234)
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)
    print(f"[audio] {args.per_class} clips x {len(CLASSES)} classes -> {args.out_dir}/")
    stats = {}
    for cls in CLASSES:
        os.makedirs(os.path.join(args.out_dir, cls), exist_ok=True)
        rms_l, pk_l, cen_l = [], [], []
        for i in range(args.per_class):
            x = loudness_match(MAKERS[cls](rng))
            assert len(x) == N
            wavfile.write(os.path.join(args.out_dir, cls, f"{cls}_{i:05d}.wav"), FS,
                          np.round(x * 32767).astype(np.int16))
            rms_l.append(rms(x))
            pk_l.append(np.max(np.abs(x)))
            sp = np.abs(np.fft.rfft(x)) ** 2
            fr = np.fft.rfftfreq(N, 1 / FS)
            cen_l.append(float(np.sum(fr * sp) / np.sum(sp)))
        stats[cls] = (np.mean(rms_l), np.std(rms_l), np.mean(pk_l), np.mean(cen_l))
    print(f"{'class':<11}{'rms(mean)':>10}{'rms(std)':>10}{'peak(mean)':>12}{'centroid Hz':>13}")
    for cls, (m, s, p, c) in stats.items():
        print(f"{cls:<11}{m:10.4f}{s:10.5f}{p:12.3f}{c:13.0f}")

    rows = gen_telemetry(rng, args.per_state)
    with open(args.csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["distance_mm", "distance_velocity", "temp_object", "temp_ambient",
                    "delta_temp", "uv_index", "gas_ppm_slope", "hazard_state"])
        w.writerows(rows)
    print(f"[telemetry] {len(rows)} rows -> {args.csv}")


if __name__ == "__main__":
    main()
