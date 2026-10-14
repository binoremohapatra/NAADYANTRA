# NAADYANTRA — TinyML Model Integration Contract

**Document Version:** 2.0.0 (Post-Audit Verified Edition)  
**Target Hardware:** ESP32-WROOM-32E (Xtensa Dual-Core LX6 @ 240 MHz, 520 KB SRAM, 4 MB SPI Flash)  
**Intended Audience:** ML / TinyML Engineer preparing the acoustic leak classification model for NAADYANTRA  
**Firmware Reference:** [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino)  

---

## 1. Executive Summary & Architecture Overview

NAADYANTRA utilizes an asynchronous dual-core FreeRTOS architecture on the ESP32-WROOM-32E:
- **Core 1:** Deterministic hardware-timer sampling ISR ($f_s = 4000\text{ Hz}$), circular ring buffering, slow sensor polling, OLED rendering, and actuator driving.
- **Core 0:** Acoustic inference (`inferTask`, priority 3), FreeRTOS task notification dispatch, and telemetry transmission (`uploaderTask`, priority 1).

The firmware enforces a **dual-path design**:
1. **Model Path (`USE_EDGE_IMPULSE == 1`):** Executes the compiled TinyML model via Edge Impulse C++ library or TFLite Micro wrapper.
2. **Deterministic Fallback Path (`USE_EDGE_IMPULSE == 0`, Active by Default):** Executes the physical RMS-to-baseline ratio detector. Automatically active whenever the model is uninitialized, absent, or disabled.

```
                    CORE 1 (Real-Time Acquisition)
[Piezo + OPA344] ---> Timer ISR (4 kHz) ---> gRing (8192 x int16)
                                                   |
                             every 2000 samples    | (500 ms hop)
                                                   v
                                          xTaskNotify(inferTask)
                                                   |
                    CORE 0 (Inference Engine)     v
                        inferenceStep(): snapshot to gFeat (4000 x float)
                                                   |
                     +-----------------------------+-----------------------------+
                     |                                                           |
          [USE_EDGE_IMPULSE == 1]                                     [USE_EDGE_IMPULSE == 0]
                     v                                                           v
       numpy::signal_from_buffer(gFeat)                                ringRms(gRing, start, 4000)
                     v                                                           v
        run_classifier(&sig, &res)                                    r.rms / gRmsBase ratio
                     v                                                           v
          Output: Model Scores                                          Output: "leak(rms)" / "no_leak(rms)"
                     |                                                           |
                     +-----------------------------+-----------------------------+
                                                   v
                                        xQueueOverwrite(gResultQ)
                                                   |
                                                   v
                                     pollAcoustic() on Core 1
                                   Debounce: 2 confirm / 4 clear
                                                   |
                                                   v
                                   Verdict Fuse -> OLED & Buzzer
```

---

## 2. Input Specification & Selected Input Mode

### Selected Input Mode: 4,000 Raw Waveform Samples

The binding input format for the model is **4,000 raw time-domain audio samples** (`float32` array).

> [!IMPORTANT]
> **Why Raw Samples instead of 9 Handcrafted Features?**  
> In [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino) (lines 563–568), the firmware feeds raw waveform samples into Edge Impulse's `signal_t` via `numpy::signal_from_buffer(x, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, &sig)`.  
> The firmware **does not contain embedded C implementations of FFT, spectral energy bands, or zero-crossing rate**. Those 9 features exist solely in Python ([ml/src/preprocessing.py](file:///d:/NAADYANTRA/ml/src/preprocessing.py)) for offline analysis.  
> Edge Impulse Studio generates its own optimized embedded DSP block (e.g., Spectrogram or MFE) inside the exported C++ library, computing any required spectral features internally on device.

| Parameter | Specification | Firmware Constant | Physical Significance |
| :--- | :--- | :--- | :--- |
| **Physical Sensor** | Piezoelectric Disc 27mm + OPA344 Amp | `PIN_PIEZO = 34` (ADC1_CH6) | Contact acoustic vibration |
| **Sampling Rate ($f_s$)** | **4000 Hz** ($\pm 10\text{ Hz}$) | `SAMPLE_RATE_HZ = 4000` | Hardware timer period: $250\ \mu\text{s}$ |
| **Window Duration** | **1000 ms** (4000 samples) | `WINDOW_MS = 1000` | Full 1-second analysis window |
| **Hop Interval** | **500 ms** (2000 samples) | `HOP_MS = 500` | 50% window overlap |
| **Nyquist Limit** | **2000 Hz** | — | Structural audio band (not ultrasound) |
| **Hardware High-Pass** | First-Order IIR DC-Block Filter | `DC_BLOCK_R = 0.995f` | $y[n] = x[n] - x[n-1] + 0.995 \cdot y[n-1]$ |
| **Data Type in Memory** | `float32` array (`gFeat[4000]`) | `float gFeat[4000]` | Centered ADC counts (virtual ground at ~0) |
| **Input Shape to Model** | `[1, 4000]` (single channel) | `EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME = 1` | 1-axis contact piezo |

> [!WARNING]
> **Train-Serve Audio Scaling Mismatch Hazard:**  
> The firmware delivers unscaled, centered `float32` ADC counts ($\pm 2048$ nominal range) directly to `numpy::signal_from_buffer()`.  
> **Edge Impulse DSP blocks (MFCC, Spectrogram, MFE) must NOT be assumed to correct arbitrary training-versus-inference scaling differences.**  
> If the teammate's model was trained on standard floating-point audio WAV files (normalized to $[-1.0, +1.0]$) or 16-bit PCM ($\pm 32768$) without applying the identical scaling transform in Edge Impulse Studio, the model input magnitudes will be mismatched by orders of magnitude (up to 2000×), causing neural network saturation and inference failure.  
> **Mandatory Teammate Disclosure:** The teammate must explicitly disclose:
> 1. Exact training input representation and numeric range (must verify compatibility with firmware's $\approx \pm 2048$ centered counts).
> 2. Whether DC-block filtering ($R = 0.995$) was applied during training.
> 3. Sample rate ($4000\text{ Hz}$) and window length ($4000\text{ samples}$ / $1000\text{ ms}$).
> 4. Any normalization (min-max, standard scaling, or zero-centering) applied in Edge Impulse Studio.  
> Training data collected via `leak_detector.ino` in `RUN_MODE_COLLECT` (which streams raw DC-blocked integer counts at 921600 baud) is verified compatible.

---

## 3. Edge Impulse Metadata & Header Verification

When exporting the model from Edge Impulse Studio as a **C++ Library**, the teammate must inspect and verify `model-parameters/model_metadata.h` before delivery:

```cpp
// Required metadata declarations in model-parameters/model_metadata.h:
#define EI_CLASSIFIER_RAW_SAMPLE_COUNT        4000
#define EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME   1
#define EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE    4000
#define EI_CLASSIFIER_FREQUENCY               4000
#define EI_CLASSIFIER_LABEL_COUNT             3
```

### Preprocessor & C++ Compile-Time Guardrail Rules
1. **Include Metadata Header First:** `#include "model-parameters/model_metadata.h"` must occur before any macro validation checks.
2. **Integer Macros via `#if`:** Integer constants (`EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME`, `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE`, `EI_CLASSIFIER_LABEL_COUNT`) can be safely checked using preprocessor `#if` directives.
3. **Exact Compile-Time Frequency Check via C++ `static_assert`:** In Edge Impulse, `EI_CLASSIFIER_FREQUENCY` can be defined as a floating-point literal (e.g. `4000.0f` or `4000.0`). The C preprocessor evaluates only integer arithmetic and will throw a syntax error (`error: floating constant in preprocessor expression`) if evaluated in `#if`. Frequency validation must use an exact compile-time comparison against `4000.0f` via C++ `static_assert`, where supported by the actual generated metadata type:
   ```cpp
   static_assert(EI_CLASSIFIER_FREQUENCY == 4000.0f,
                 "Sampling frequency mismatch: EI_CLASSIFIER_FREQUENCY must be exactly 4000.0f");
   ```
   *Rationale:* Direct comparison against `4000.0f` avoids `static_cast<uint32_t>`, which would dangerously truncate fractional mismatches (e.g., `4000.5f` truncates to `4000`, silently bypassing validation).

> [!WARNING]
> **Do not assume `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE == 4000` automatically.**  
> If Edge Impulse Studio downsampled the frequency (e.g., to 2000 Hz) or configured a window shorter than 1000 ms, `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE` will differ.  
> If `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE != 4000`, `numpy::signal_from_buffer(x, ...)` will read out-of-bounds or fail. The teammate must confirm this value matches 4,000.
> **Note:** These compile-time checks have not been tested against the teammate's model because the artifact has not yet been delivered.

---

## 4. Reconciled Memory Budgets & Footprint Limits

The table below reconciles all previous conflicting memory figures and establishes clear targets versus hard limits for the ESP32-WROOM-32E (520 KB SRAM, 4 MB SPI Flash):

| Memory Domain | Measurement Method | Recommended Target | Hard Firmware Limit | Engineering Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Tensor Arena (SRAM)** | `arena_used_bytes` / TFLite interpreter | $\le 32\text{ KB}$ | **$\le 60\text{ KB}$** | Exceeding 60 KB risks allocation failure during Wi-Fi TLS handshake |
| **Model Flash Footprint** | Binary diff of `.bin` size | $\le 350\text{ KB}$ | **$\le 550\text{ KB}$** | Must fit inside default 1.2 MB or 1.9 MB app partition with FreeRTOS & Wi-Fi |
| **Model Weights (RODATA)** | Size of `tflite_learn_*_compiled.cpp` | $\le 250\text{ KB}$ | **$\le 400\text{ KB}$** | Stored in SPI flash, cached in instruction cache |
| **Transient Preprocessing** | Fixed allocation in BSS | Exactly 16.0 KB | Exactly 16.0 KB | `gFeat[4000]` ($4000 \times 4\text{ bytes}$) |
| **Total Free Heap on Boot** | `ESP.getFreeHeap()` | $\ge 180\text{ KB}$ | **$\ge 120\text{ KB}$** | Baseline free heap is ~210 KB; model must not consume >60 KB heap |
| **Minimum Lifetime Heap** | `minFreeHeap` in debug log | $\ge 90\text{ KB}$ | **$\ge 60\text{ KB}$** | Prevents heap fragmentation crash during simultaneous Wi-Fi send |

### Note on TensorFlow Lite Micro vs. Static C Array
A flat C byte array (`const unsigned char model_data[]`) generated by `xxd -i` is **only the model weights**. It does not execute itself. If the teammate delivers a raw `.tflite` array rather than an Edge Impulse C++ library:
1. The firmware must compile the TFLite Micro interpreter runtime (`tensorflow/lite/micro/`).
2. TFLite Micro adds $\sim 100\text{ KB}$ to flash footprint and $\sim 6\text{ KB}$ to static BSS.
3. Edge Impulse C++ Library export is strongly preferred because it bundles the interpreter, kernels, and DSP blocks into a self-contained folder.

---

## 5. Cross-Core Buffer Ownership & Race-Free Strategy

Acquisition and inference run on separate cores with zero mutex blocking in the audio path:

```
Core 1:  Timer ISR pushes samples into gRing (8192 elements)
         Head index advances continuously at 4000 samples/sec
                                 |
Core 0:  inferenceStep() executes:
         1. Reads current head:  head = gHead.load(std::memory_order_acquire)
         2. Copies 4000 samples: gRing -> gFeat (takes ~150 microseconds)
         3. Exclusive ownership: Core 0 owns gFeat exclusively during inference
```

### Safety Margin & Timing Analysis
1. **Ring Buffer Size:** $N = 8192\text{ samples}$.
2. **Window Size:** $W = 4000\text{ samples}$.
3. **Hop Interval:** $H = 2000\text{ samples}$ ($500\text{ ms}$).
4. **Buffer Margin:** $N - W = 4192\text{ samples}$.
5. **Acquisition Immunity:** At 4 kHz, Core 1 requires $\frac{4192}{4000} = \mathbf{1048\text{ ms}}$ before it can lap the start pointer of the current window.
6. **Snapshot Duration:** The loop copying `gRing` to `gFeat` executes in **$\approx 150\ \mu\text{s}$** on Xtensa LX6 @ 240 MHz.
7. **Cross-Core Safety Guarantee:** Because Core 0 takes a private snapshot into `gFeat` within $150\ \mu\text{s}$, and Core 1 is $1048\text{ ms}$ away from overwriting the read head, **no mutex or critical section is required**.
8. **Inference Latency Limit:** Total Core 0 execution (snapshot + preprocessing + inference) must complete in **$\le 450\text{ ms}$** to avoid dropping task notifications before the next 500 ms hop.

---

## 6. Real Fallback Implementation & Label Semantics

The verified fallback implementation in [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino) behaves as follows:

> [!NOTE]
> **No Crest Factor in Firmware:**  
> The physical firmware does **not** evaluate crest factor in its decision logic. Crest factor is computed only in the Python offline dataset tooling. The firmware fallback is strictly RMS ratio-based.

### Fallback Decision Equations
$$\text{RMS}_{\text{window}} = \sqrt{\frac{1}{4000} \sum_{i=0}^{3999} gRing[\text{start} + i]^2}$$

$$R_{\text{RMS}} = \frac{\text{RMS}_{\text{window}}}{\text{RMS}_{\text{baseline}}}$$

$$\text{pLeak} = \text{clamp}\left(\frac{R_{\text{RMS}} - 1.0}{\text{FALLBACK\_LEAK\_RATIO} - 1.0},\ 0.0,\ 1.0\right) = \text{clamp}\left(\frac{R_{\text{RMS}} - 1.0}{2.0},\ 0.0,\ 1.0\right) \quad (\text{where } \text{FALLBACK\_LEAK\_RATIO} = 3.0\text{f})$$

$$\text{pNormal} = 1.0 - \text{pLeak}$$

### Mathematical Derivation of Detector Transitions:
1. **Quiescent / Normal:** When $R_{\text{RMS}} < 1.0$, $\text{pLeak} = 0.0$ and $\text{pNormal} = 1.0$.
2. **Intermediate Warning:** When $R_{\text{RMS}} = 2.0$, $\text{pLeak} = 0.50$. The OLED and telemetry label switch to `"leak(rms)"`, but the operational role remains `ROLE_UNCERTAIN` because $\text{pLeak} < 0.65$.
3. **Leak Trip Threshold:** Setting $\text{pLeak} \ge 0.65$ (`LEAK_PROB_MIN`):
   $$\frac{R_{\text{RMS}} - 1.0}{2.0} \ge 0.65 \implies R_{\text{RMS}} - 1.0 \ge 1.30 \implies \mathbf{R_{\text{RMS}} \ge 2.30}$$
   Therefore, **the leak detector asserts `ROLE_LEAK` at $R_{\text{RMS}} \ge 2.30$**, NOT $3.0$.
4. **Saturation:** A ratio of $R_{\text{RMS}} \ge 3.0$ (`FALLBACK_LEAK_RATIO`) saturates the score at $\mathbf{\text{pLeak} = 1.0}$.
5. **Debounce Confirmation:** `ROLE_LEAK` must be sustained for **2 consecutive windows** ($1.0\text{ s}$) via `app.leak.update()` before triggering `ALERT_DANGER` / `CAUSE_LEAK`.

> [!CAUTION]
> **Heuristic Score vs. Probability Labeling:**  
> The variable name `pLeak` and JSON field `pl` are legacy names. In fallback mode, `pLeak` is strictly a **heuristic normalized energy ratio score**, NOT a statistical probability. It must be communicated as a rule-based score.

### Role Classification & Debounce
- **Classification (`decideRole`):**
  - $\text{pLeak} \ge 0.65\text{f}$ (`LEAK_PROB_MIN`) $\rightarrow$ `ROLE_LEAK`
  - $\text{pNoise} \ge 0.60\text{f}$ (`NOISE_PROB_MIN`) $\rightarrow$ `ROLE_NOISE`
  - $\text{pNormal} \ge 0.60\text{f}$ (`NORMAL_PROB_MIN`) $\rightarrow$ `ROLE_NORMAL`
  - Otherwise $\rightarrow$ `ROLE_UNCERTAIN`
- **Debounce Filter:**
  - `LEAK_CONFIRM_WINDOWS = 2`: Leak alert asserted only after **2 consecutive positive windows** ($1.0\text{ s}$ sustained leak).
  - `LEAK_CLEAR_WINDOWS = 4`: Leak alert cleared only after **4 consecutive negative windows** ($2.0\text{ s}$ quiet).
- **Display & Telemetry Labels:**
  - Fallback label string: `"leak(rms)"` (if $\text{pLeak} \ge 0.5$) or `"no_leak(rms)"`.
  - Model label string: raw winning label from model (e.g. `"leak"`, `"normal"`, `"noise"`).
  - OLED Display: Banner shows `"LEAK!"` or `"NO LEAK"` via `causeText()`. Bottom line displays `app.label`.
  - Backend Telemetry (`POST /api/log`): Field `lbl` transmits `app.label`, maintaining complete provenance between rule-based and model-based verdicts.

---

## 7. Model Confidence Scores vs. Calibrated Probabilities

> [!CAUTION]
> **Softmax Outputs Are NOT Calibrated Probabilities.**  
> Standard neural network Softmax outputs represent uncalibrated confidence scores. They are notoriously overconfident on out-of-distribution workshop noise (e.g., metal clatter, compressed air exhaust, tool drops).

1. **Terminology:** The raw outputs of the model must be documented and treated as **Model Confidence Scores (0.0 to 1.0)**, not true posterior probabilities.
2. **Calibration Requirement:** If the teammate claims the scores represent true probabilities, they must supply:
   - Calibration method used (e.g., Temperature Scaling with parameter $T$, or Platt Scaling).
   - Expected Calibration Error (ECE) and Brier Score on a held-out test split.
   - Temperature parameter $T$ for firmware deployment:
     $$p_i = \frac{e^{z_i / T}}{\sum_j e^{z_j / T}}$$
3. **Firmware Default:** If no temperature parameter is provided, the firmware treats raw Softmax outputs directly as heuristic scores against the `LEAK_PROB_MIN = 0.65` threshold.

---

## 8. Latency Budget & Realistic System Contention

The $300\text{ ms}$ inference limit is an **empirical target**, not a mathematical guarantee of queue stability:

1. **Core 0 Contention:** Core 0 executes:
   - `inferTask` (Priority 3)
   - `uploaderTask` (Priority 1)
   - ESP-IDF lwIP TCP/IP stack (`tiT` task)
   - Wi-Fi driver interrupt handlers
2. **Worst-Case Latency Measurement:** The teammate must measure inference latency on the actual hardware while:
   - Wi-Fi is actively transmitting telemetry payloads over HTTP POST (`sendItem`).
   - The SSD1306 OLED display is being updated on I2C.
3. **Acceptance Criterion:** Under active Wi-Fi logging:
   - Total Core 0 execution: $\text{latency}_{\text{dsp}} + \text{latency}_{\text{infer}} \le \mathbf{300\text{ ms}}$ (nominal) and $\le \mathbf{420\text{ ms}}$ (worst-case peak).
   - Sampling overruns: `gOverruns` must remain **0** across a 10-minute continuous run.
   - Log queue: `qd` must not monotonically increase.

---

## 9. Output Classes & Provenance Integrity

### Output Label Ordering
The model classification array must map to these three operational roles:

```cpp
Index 0: "normal"     // Laminar pipe flow, nominal quiet workshop state
Index 1: "leak"       // Turbulent pressurized gas/air orifice leak
Index 2: "noise"      // Ambient workshop noise (machinery, impact, voices)
```

The firmware's `roleOfLabel()` function maps these string labels to internal FreeRTOS enums:
```cpp
static Role roleOfLabel(const char* s) {
  if (strstr(s, "leak")   != nullptr) return ROLE_LEAK;
  if (strstr(s, "noise")  != nullptr) return ROLE_NOISE;
  if (strstr(s, "normal") != nullptr) return ROLE_NORMAL;
  return ROLE_UNCERTAIN;
}
```

### Dataset Provenance Disclosure Requirement
Any model delivered by the teammate must include a **Data Provenance Disclosure**:
1. **Synthetic Data Warning:** The models currently in `ml/models/` were trained on synthetic signals from [ml/src/generate_synthetic.py](file:///d:/NAADYANTRA/ml/src/generate_synthetic.py). If the new model is also trained on synthetic data, it must be explicitly labeled:
   > **"PROTOTYPE SYNTHETIC MODEL — Unvalidated on Physical Pipe Physics."**
2. **Physical Data Requirements:** For the model to be certified as validated physical leak detection, the training set must document:
   - Pipe material and diameter (e.g., 1/2" Schedule 40 PVC, copper, steel).
   - Operating pressure (e.g., 2 bar to 6 bar compressed air).
   - Orifice size (e.g., 0.5 mm pinhole, crack, threaded fitting).
   - Acoustic transducer coupling (direct contact piezo with OPA344 pre-amp).
   - Ambient workshop noise recorded in situ.

---

## 10. Teammate Handoff Deliverables Checklist

When delivering the model, the teammate must provide:

- [ ] **1. Artifact Archive:** Edge Impulse C++ library export ZIP OR quantized TFLite flat byte array.
- [ ] **2. Header Verification:** Copy of `model_metadata.h` confirming:
  - `EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME == 1`
  - `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE == 4000`
  - `EI_CLASSIFIER_FREQUENCY == 4000.0f` (exact compile-time check against `4000.0f`)
  - `EI_CLASSIFIER_LABEL_COUNT == 3` (labels: `normal`, `leak`, `noise`)
- [ ] **3. Mandatory Training Input & Preprocessing Disclosure:**
  - Exact training input representation and numeric range (must verify compatibility with firmware's $\approx \pm 2048$ centered ADC counts).
  - Confirmation of DC-block filtering ($R = 0.995$) in training data.
  - Confirmation of sample rate ($4000\text{ Hz}$) and window length ($4000\text{ samples}$ / $1000\text{ ms}$).
  - Full disclosure of any normalization applied in Edge Impulse Studio (Edge Impulse DSP must not be assumed to auto-scale arbitrary training-vs-inference differences).
- [ ] **4. Memory Footprint:**
  - Measured Tensor Arena size (must be $\le 60\text{ KB}$, target $\le 32\text{ KB}$).
  - Compiled Flash size contribution (must be $\le 550\text{ KB}$, target $\le 350\text{ KB}$).
- [ ] **5. Execution Latency:** Measured inference time on ESP32 @ 240 MHz (must be $\le 300\text{ ms}$).
- [ ] **6. Score Calibration:** Statement of whether scores are uncalibrated Softmax or temperature-scaled ($T$).
- [ ] **7. Dataset Provenance Disclosure:** Statement of training data origin (Synthetic vs. Physical Bench).
- [ ] **8. Model Adapter Implementation:** Working C++ implementation of `tinyml_init()` and `tinyml_infer()` conforming to [Section 11](#11-adapter-header-specification-model_adapterh).
- [ ] **9. Firmware File Placement:** Confirm files are extracted into the Arduino `libraries/` directory (e.g., `Arduino/libraries/<project_name>_inferencing/`) or PlatformIO `lib/` directory. *(Do NOT place model files in `mobile_app/`, which is the Flutter mobile client).*

---

## 11. Adapter Header Specification (`model_adapter.h`)

```cpp
#pragma once
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float prob_normal;      // Confidence score [0.0 - 1.0] for nominal normal state
    float prob_leak;        // Confidence score [0.0 - 1.0] for turbulent leak
    float prob_noise;       // Confidence score [0.0 - 1.0] for background noise
    float anomaly_score;    // Out-of-distribution anomaly score (0.0 if disabled)
    uint16_t latency_ms;    // Measured inference execution time in milliseconds
    bool is_valid;          // True if inference executed successfully
    char top_label[16];     // String of the highest-scoring class
} TinyMLResult;

// Lifecycle & Execution
bool tinyml_is_available(void);
bool tinyml_init(void);
bool tinyml_infer(const float* sample_window, uint32_t num_samples, TinyMLResult* result);

#ifdef __cplusplus
}
#endif
```
