#!/usr/bin/env python3
"""
train_quantize.py  -  Acoustic TinyML pipeline for the ESP32 trainee wearable.

  16 kHz audio (500 ms) -> RMS-normalise -> 32-band log-Mel x 32 frames -> (32,32,1)
  -> DSCNN (no BatchNorm, L2 + Dropout) -> full-INT8 PTQ -> model_data.h + mel_tables.h

The feature extractor here is the *reference* for firmware/main/main.cpp. Both sides use
the same constants and tables (exported to mel_tables.h):
    window 512 (periodic Hann), hop 240, 32 frames, 32 HTK-mel bands 50 Hz-8 kHz (area-normalised),
    power spectrum |FFT|^2, dB = 10*log10(mel + 1e-10), feature = clip((dB-DB_MIN)/(DB_MAX-DB_MIN), 0, 1)

Usage
    python train_quantize.py --data dataset --out firmware/main
    python train_quantize.py --data dataset --out firmware/main --mel-only   # no TensorFlow needed
Requires: numpy, scipy, tensorflow>=2.15 (tested style: TF 2.15 / Keras 2 and TF 2.16+).
"""
import argparse
import glob
import os
import sys

import numpy as np
from scipy.io import wavfile

# ----------------------------------------------------------------------------- constants
FS = 16000
WIN_SAMPLES = 8000          # 500 ms
N_FFT = 512
HOP = 240
N_FRAMES = 32               # 1 + (8000-512)//240 = 32
N_MELS = 32
FMIN, FMAX = 50.0, 8000.0
NORM_RMS = 0.1
DB_EPS = 1e-10
CLASSES = ["normal", "clatter", "minor_leak", "major_leak"]
MODEL_BUDGET_BYTES = 25 * 1024
ARENA_BUDGET_BYTES = 16 * 1024
ALLOWED_OPS = {"CONV_2D", "DEPTHWISE_CONV_2D", "FULLY_CONNECTED", "MEAN", "SOFTMAX"}
assert 1 + (WIN_SAMPLES - N_FFT) // HOP == N_FRAMES


# ----------------------------------------------------------------------------- DSP reference
def hann_window():
    n = np.arange(N_FFT)
    return (0.5 - 0.5 * np.cos(2.0 * np.pi * n / N_FFT)).astype(np.float32)


def hz_to_mel(f):
    return 2595.0 * np.log10(1.0 + np.asarray(f, dtype=np.float64) / 700.0)


def mel_to_hz(m):
    return 700.0 * (10.0 ** (np.asarray(m, dtype=np.float64) / 2595.0) - 1.0)


def mel_filterbank():
    """(N_MELS, N_FFT//2+1) triangular filters, area-normalised (flat for white noise)."""
    n_bins = N_FFT // 2 + 1
    freqs = np.arange(n_bins) * FS / N_FFT
    edges = mel_to_hz(np.linspace(hz_to_mel(FMIN), hz_to_mel(FMAX), N_MELS + 2))
    fb = np.zeros((N_MELS, n_bins), dtype=np.float64)
    for m in range(N_MELS):
        lo, ce, hi = edges[m], edges[m + 1], edges[m + 2]
        up = (freqs - lo) / (ce - lo)
        dn = (hi - freqs) / (hi - ce)
        fb[m] = np.clip(np.minimum(up, dn), 0.0, None) * (2.0 / (hi - lo))
    return fb.astype(np.float32)


_WIN = hann_window()
_FB = mel_filterbank()
_IDX = (np.arange(N_FRAMES)[:, None] * HOP + np.arange(N_FFT)[None, :])


def rms_normalise(x):
    x = x.astype(np.float64) - np.mean(x)
    g = min(NORM_RMS / (np.sqrt(np.mean(x * x)) + 1e-9), 1000.0)
    return (x * g).astype(np.float32)


def logmel_db(x):
    """x: float array of 8000 samples (raw scale irrelevant) -> (32 frames, 32 mels) in dB."""
    x = rms_normalise(x)
    frames = x[_IDX] * _WIN
    spec = np.fft.rfft(frames, axis=1)
    power = (spec.real ** 2 + spec.imag ** 2).astype(np.float32)
    mel = power @ _FB.T
    return 10.0 * np.log10(mel + DB_EPS)


def normalise_db(db, db_min, db_max):
    return np.clip((db - db_min) / (db_max - db_min), 0.0, 1.0).astype(np.float32)


# ----------------------------------------------------------------------------- data
def load_dataset(root):
    xs, ys = [], []
    for ci, cls in enumerate(CLASSES):
        files = sorted(glob.glob(os.path.join(root, cls, "*.wav")))
        if not files:
            sys.exit(f"No wav files in {root}/{cls} - run generate_mock_dataset.py first")
        for f in files:
            sr, w = wavfile.read(f)
            assert sr == FS, f"{f}: expected {FS} Hz"
            w = w.astype(np.float32) / 32768.0
            w = np.pad(w, (0, max(0, WIN_SAMPLES - len(w))))[:WIN_SAMPLES]
            xs.append(logmel_db(w))
            ys.append(ci)
    return np.stack(xs), np.array(ys, dtype=np.int64)


def stratified_split(y, rng, fr=(0.70, 0.15, 0.15)):
    tr, va, te = [], [], []
    for c in np.unique(y):
        idx = rng.permutation(np.where(y == c)[0])
        a, b = int(fr[0] * len(idx)), int((fr[0] + fr[1]) * len(idx))
        tr += list(idx[:a]); va += list(idx[a:b]); te += list(idx[b:])
    return np.array(tr), np.array(va), np.array(te)


# ----------------------------------------------------------------------------- model
def build_model(n_classes, l2=1e-4, drop=0.15):
    import tensorflow as tf
    from tensorflow.keras import layers, regularizers
    reg = regularizers.l2(l2)
    inp = layers.Input(shape=(N_FRAMES, N_MELS, 1), name="logmel")
    x = layers.Conv2D(16, 3, strides=2, padding="same", activation="relu",
                      kernel_regularizer=reg, name="conv1")(inp)                     # 16x16x16

    def ds(x, pw, stride, name):
        x = layers.DepthwiseConv2D(3, strides=stride, padding="same", activation="relu",
                                   depthwise_regularizer=reg, name=name + "_dw")(x)
        x = layers.Conv2D(pw, 1, padding="same", activation="relu",
                          kernel_regularizer=reg, name=name + "_pw")(x)
        return layers.Dropout(drop, name=name + "_do")(x)

    x = ds(x, 32, 2, "ds1")                                                          # 8x8x32
    x = ds(x, 48, 1, "ds2")                                                          # 8x8x48
    x = ds(x, 64, 2, "ds3")                                                          # 4x4x64
    x = layers.GlobalAveragePooling2D(name="gap")(x)                                  # MEAN
    x = layers.Dropout(0.3, name="head_do")(x)
    out = layers.Dense(n_classes, activation="softmax", kernel_regularizer=reg, name="fc")(x)
    return tf.keras.Model(inp, out, name="dscnn_leak")


def augment(x, y):
    import tensorflow as tf
    shift = tf.random.uniform([], -4, 5, dtype=tf.int32)          # time shift (frames)
    x = tf.roll(x, shift, axis=0)
    x = x + tf.random.normal([], 0.0, 0.03)                       # loudness-estimate jitter
    x = x + tf.random.normal(tf.shape(x), 0.0, 0.015)             # feature noise
    return tf.clip_by_value(x, 0.0, 1.0), y


# ----------------------------------------------------------------------------- TFLite helpers
def quantise(model, rep_x):
    import tensorflow as tf

    def representative_dataset_gen():
        for i in range(min(300, len(rep_x))):
            yield [rep_x[i:i + 1].astype(np.float32)]

    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.representative_dataset = representative_dataset_gen
    conv.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    conv.inference_input_type = tf.int8
    conv.inference_output_type = tf.int8
    return conv.convert()


def inspect_tflite(tfl):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_content=tfl)
    it.allocate_tensors()
    ops = it._get_ops_details()
    names = [o["op_name"] for o in ops]
    bad = sorted(set(names) - ALLOWED_OPS)
    if bad:
        sys.exit(f"Model uses ops outside the allowed set: {bad} (all ops: {names})")
    # lower-bound arena estimate: peak sum of live activation tensors (16 B aligned) + headroom
    details = {t["index"]: t for t in it.get_tensor_details()}
    graph_in = {d["index"] for d in it.get_input_details()}
    graph_out = {d["index"] for d in it.get_output_details()}
    first, last = {}, {}
    for oi, o in enumerate(ops):
        for t in o["outputs"]:
            first.setdefault(int(t), oi)
            last[int(t)] = max(last.get(int(t), oi), oi)
        for t in o["inputs"]:
            if int(t) in graph_in:
                first.setdefault(int(t), 0)
            if int(t) in first:
                last[int(t)] = max(last.get(int(t), oi), oi)
    for t in graph_out:
        last[int(t)] = len(ops) - 1
    peak = 0
    for oi in range(len(ops)):
        live = 0
        for t, f in first.items():
            if f <= oi <= last.get(t, f):
                d = details[t]
                live += (int(np.prod(d["shape"])) * np.dtype(d["dtype"]).itemsize + 15) // 16 * 16
        peak = max(peak, live)
    return names, peak + 4096          # +4 KiB: TFLM node/eval structs and kernel scratch


def run_tflite(tfl, x):
    import tensorflow as tf
    it = tf.lite.Interpreter(model_content=tfl)
    it.allocate_tensors()
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    s_i, z_i = i["quantization"]
    preds = []
    for k in range(len(x)):
        q = np.clip(np.round(x[k:k + 1] / s_i + z_i), -128, 127).astype(np.int8)
        it.set_tensor(i["index"], q)
        it.invoke()
        preds.append(int(np.argmax(it.get_tensor(o["index"])[0])))
    return np.array(preds), (s_i, z_i), o["quantization"]


# ----------------------------------------------------------------------------- C export
def c_array(name, data: bytes, qualifier="alignas(16) static const unsigned char"):
    lines = [f"{qualifier} {name}[] = {{"]
    for i in range(0, len(data), 12):
        lines.append("  " + ", ".join(f"0x{b:02x}" for b in data[i:i + 12]) + ",")
    lines.append("};")
    return "\n".join(lines)


def f_list(name, arr, per=8, ctype="static const float"):
    arr = np.asarray(arr).ravel()
    out = [f"{ctype} {name}[{len(arr)}] = {{"]
    for i in range(0, len(arr), per):
        out.append("  " + ", ".join(f"{float(v):.9e}f" for v in arr[i:i + per]) + ",")
    out.append("};")
    return "\n".join(out)


def export_mel_tables(path, db_min, db_max):
    fb = _FB
    starts, lens, offs, weights = [], [], [], []
    for m in range(N_MELS):
        nz = np.nonzero(fb[m] > 0)[0]
        s, e = int(nz[0]), int(nz[-1]) + 1
        starts.append(s); lens.append(e - s); offs.append(len(weights))
        weights += list(fb[m, s:e])
    k = np.arange(N_FFT // 2)
    cos_t = np.cos(2 * np.pi * k / N_FFT)
    sin_t = -np.sin(2 * np.pi * k / N_FFT)
    txt = f"""// AUTO-GENERATED by train_quantize.py - do not edit.
#pragma once
#include <stdint.h>

#define MEL_SAMPLE_RATE   {FS}
#define MEL_WIN_SAMPLES   {WIN_SAMPLES}
#define MEL_N_FFT         {N_FFT}
#define MEL_HOP           {HOP}
#define MEL_N_FRAMES      {N_FRAMES}
#define MEL_N_MELS        {N_MELS}
#define MEL_NORM_RMS      {NORM_RMS}f
#define MEL_DB_EPS        {DB_EPS}f
#define MEL_DB_MIN        {float(db_min)}f
#define MEL_DB_MAX        {float(db_max)}f
#define MEL_FB_TOTAL      {len(weights)}

{f_list("MEL_HANN", _WIN)}

// FFT twiddles: exp(-j*2*pi*k/N), k = 0..N/2-1
{f_list("MEL_TW_COS", cos_t)}
{f_list("MEL_TW_SIN", sin_t)}

// Sparse triangular mel filterbank: filter m uses bins [START[m], START[m]+LEN[m]) with
// weights MEL_FB_W[OFFSET[m] ...]
static const uint16_t MEL_FB_START[{N_MELS}] = {{{", ".join(map(str, starts))}}};
static const uint16_t MEL_FB_LEN[{N_MELS}]   = {{{", ".join(map(str, lens))}}};
static const uint16_t MEL_FB_OFFSET[{N_MELS}] = {{{", ".join(map(str, offs))}}};
{f_list("MEL_FB_W", weights)}
"""
    with open(path, "w") as f:
        f.write(txt)
    print(f"[export] {path}: {len(weights)} sparse filter weights, dB range [{db_min}, {db_max}]")


def export_model_header(path, tfl, in_q, out_q, arena_est, acc):
    txt = f"""// AUTO-GENERATED by train_quantize.py - do not edit.
// INT8 DSCNN leak classifier. Classes: 0 normal, 1 clatter, 2 minor_leak, 3 major_leak
#pragma once
#include <stdint.h>

#define MODEL_NUM_CLASSES      {len(CLASSES)}
#define MODEL_ARENA_ESTIMATE   {arena_est}   // host-side lower-bound estimate (bytes); firmware budget is 16384
#define MODEL_INPUT_SCALE      {in_q[0]:.9e}f
#define MODEL_INPUT_ZEROPOINT  {int(in_q[1])}
#define MODEL_OUTPUT_SCALE     {out_q[0]:.9e}f
#define MODEL_OUTPUT_ZEROPOINT {int(out_q[1])}
// test accuracy of this exact INT8 model on the synthetic hold-out set: {acc*100:.2f}%

{c_array("g_model_data", tfl)}
static const unsigned int g_model_data_len = {len(tfl)};
"""
    with open(path, "w") as f:
        f.write(txt)
    print(f"[export] {path}: {len(tfl)} bytes")


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="dataset")
    ap.add_argument("--out", default="firmware/main")
    ap.add_argument("--epochs", type=int, default=80)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--mel-only", action="store_true", help="export mel_tables.h only (no TensorFlow)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    print("[data] extracting log-Mel features ...")
    X_db, y = load_dataset(args.data)
    db_min = float(np.floor(np.percentile(X_db, 0.5)))
    db_max = float(np.ceil(np.percentile(X_db, 99.5)))
    print(f"[data] {len(y)} clips, dB range for scaling: [{db_min}, {db_max}]")
    export_mel_tables(os.path.join(args.out, "mel_tables.h"), db_min, db_max)
    if args.mel_only:
        return

    import tensorflow as tf
    tf.keras.utils.set_random_seed(args.seed)
    X = normalise_db(X_db, db_min, db_max)[..., None]
    tr, va, te = stratified_split(y, rng)
    print(f"[data] train/val/test = {len(tr)}/{len(va)}/{len(te)}")

    model = build_model(len(CLASSES))
    model.summary()
    model.compile(optimizer=tf.keras.optimizers.Adam(2e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    ds_tr = (tf.data.Dataset.from_tensor_slices((X[tr], y[tr])).shuffle(len(tr), seed=args.seed)
             .map(augment, num_parallel_calls=tf.data.AUTOTUNE).batch(args.batch).prefetch(2))
    cb = [tf.keras.callbacks.ReduceLROnPlateau(patience=5, factor=0.5, min_lr=1e-5),
          tf.keras.callbacks.EarlyStopping(patience=14, restore_best_weights=True)]
    model.fit(ds_tr, validation_data=(X[va], y[va]), epochs=args.epochs, callbacks=cb, verbose=2)
    f_acc = float(np.mean(np.argmax(model.predict(X[te], verbose=0), 1) == y[te]))
    print(f"[float] test accuracy: {f_acc*100:.2f}%")

    print("[ptq] full-INT8 post-training quantisation ...")
    tfl = quantise(model, X[tr])
    ops, arena_est = inspect_tflite(tfl)
    print(f"[ptq] ops: {sorted(set(ops))}")
    print(f"[ptq] model size {len(tfl)} B (budget {MODEL_BUDGET_BYTES}), "
          f"arena estimate {arena_est} B (budget {ARENA_BUDGET_BYTES})")
    if len(tfl) > MODEL_BUDGET_BYTES:
        sys.exit("Model exceeds 25 KiB budget")
    if arena_est > ARENA_BUDGET_BYTES:
        sys.exit("Estimated tensor arena exceeds 16 KiB budget")

    pred, in_q, out_q = run_tflite(tfl, X[te])
    q_acc = float(np.mean(pred == y[te]))
    print(f"[int8] test accuracy: {q_acc*100:.2f}%  (float {f_acc*100:.2f}%)")
    cm = np.zeros((len(CLASSES), len(CLASSES)), dtype=int)
    for t, p in zip(y[te], pred):
        cm[t, p] += 1
    print("confusion (rows=true, cols=pred):", CLASSES)
    print(cm)

    with open(os.path.join(args.out, "leak_model.tflite"), "wb") as f:
        f.write(tfl)
    export_model_header(os.path.join(args.out, "model_data.h"), tfl, in_q, out_q, arena_est, q_acc)


if __name__ == "__main__":
    main()
