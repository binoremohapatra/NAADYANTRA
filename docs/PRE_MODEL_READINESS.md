# NAADYANTRA — Final Pre-Model Readiness & Verification Check

**Document Version:** 1.0.0  
**Date:** 2026-10-14  
**Target Hardware:** ESP32-WROOM-32E (Xtensa Dual-Core LX6 @ 240 MHz, 520 KB SRAM, 4 MB Flash)  
**Status:** Pre-Model Audit Complete — Fallback Active — Awaiting Physical Model Artifact  

---

## 1. Resolution of Firmware Build Status & Claims

To eliminate ambiguity across previous documentation, the build verification status is formally categorized into three distinct levels:

| Verification Level | Scope & Method | Actual Measured Status | Evidence / Notes |
| :--- | :--- | :--- | :--- |
| **1. Source-Level Review & Syntax Check** | C/C++ structural audit of [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino) | **PASSED (Unblocked)** | Setting `#define USE_EDGE_IMPULSE 0` eliminates the `#include <YOUR_PROJECT_inferencing.h>` missing-header blocker. Code uses standard Arduino-ESP32 core APIs, FreeRTOS primitives, and STL atomics. |
| **2. Host Algorithmic & Regression Tests** | `pytest tests/test_firmware_logic.py` (Python 3.11 on host) | **PASSED (48/48 tests)** | Validates 32-bit atomic ring-buffer pointer arithmetic, power-of-two circular wrap, queue eviction priority, backoff clamping, and JSON schemas. |
| **3. Target ESP32 Firmware Compilation** | Invocation of `xtensa-esp32-elf-g++` via `arduino-cli` or ESP-IDF | **DEFERRED (Toolchain Unavailable on Host)** | Neither `arduino-cli` nor `idf.py` is installed in the Windows system PATH. Generating an actual `.bin` image requires testing on a machine with the ESP32 Arduino core installed. |

> [!IMPORTANT]
> **Honest Engineering Grounding:**  
> The term *"verified buildable out-of-the-box"* previously used in sprint notes refers strictly to **Level 1 (source-level unblocking)**: all proprietary and missing external dependencies have been conditionally gated out so the source tree has no missing headers.  
> **Level 3 (real target compilation to machine binary)** has **NOT** been performed on this host environment and remains **DEFERRED TO PHYSICAL BENCH ASSEMBLY**.

---

## 2. Edge Impulse Input Contract & Macro Validation

The intended model input is a **4,000-sample raw time-domain audio waveform at 4,000 Hz**. However, the firmware and model adapter must strictly validate the teammate's exported C++ library macros before allowing compilation or runtime execution.

### Edge Impulse Macro Semantics
In an Edge Impulse C++ library export, metadata macros are generated inside `model-parameters/model_metadata.h`. These macros are **not guaranteed to be identical**:

| Macro Name | Semantic Meaning | Expected Value for NAADYANTRA | Risk if Mismatched |
| :--- | :--- | :--- | :--- |
| `EI_CLASSIFIER_RAW_SAMPLE_COUNT` | Number of time-series samples per channel | **4000** | If $< 4000$ (e.g. 2000 for a 500ms window), frame slicing is required. |
| `EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME` | Number of axes / channels per time-step | **1** | Firmware samples a single-axis contact piezo. If $> 1$ (e.g. 3 for tri-axial accelerometer), model expects interleaved channels that do not exist. |
| `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE` | Total number of floats passed to the DSP block | **4000** | Must equal $\text{RAW\_SAMPLE\_COUNT} \times \text{RAW\_SAMPLES\_PER\_FRAME}$. |
| `EI_CLASSIFIER_FREQUENCY` | Expected sampling rate in Hz | **4000** | If different (e.g. 16000), physical timer sampling at 4000 Hz will cause acoustic spectral compression / frequency shifting. |
| `EI_CLASSIFIER_LABEL_COUNT` | Total number of output classes | **3** | Must match operational roles (`normal`, `leak`, `noise`). |

### Documented `signal_t` Usage in Firmware
In [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino#L563-L568):
```cpp
#if USE_EDGE_IMPULSE
  signal_t sig;
  if (numpy::signal_from_buffer(x, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, &sig) != 0) return;
  ei_impulse_result_t res = { 0 };
  const uint32_t t0 = millis();
  if (run_classifier(&sig, &res, false) != EI_IMPULSE_OK) return;
```
`numpy::signal_from_buffer` constructs an Edge Impulse `signal_t` wrapper referencing a contiguous `float*` buffer of length `EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE`.

### Safe Adapter Rejection Guardrails
When `#define USE_EDGE_IMPULSE 1` is enabled in firmware, the model header must be included before checking constants. Because `EI_CLASSIFIER_FREQUENCY` can be generated as a floating-point literal (e.g. `4000.0f` or `4000.0`), using it in a C preprocessor `#if` expression causes a compiler syntax error. Preprocessor `#if` must be used strictly for integer macros, while frequency is validated via C++ `static_assert`:

```cpp
#if USE_EDGE_IMPULSE
  // 1. Include generated metadata before checking constants
  #include "model-parameters/model_metadata.h"

  // 2. Preprocessor integer macro assertions
  #if (EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME != 1)
    #error "Model rejection: NAADYANTRA firmware only samples 1 piezo channel (EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME must be 1)."
  #endif

  #if (EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE != 4000)
    #error "Model rejection: Buffer size mismatch with gFeat[4000] (EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE must be 4000)."
  #endif

  #if (EI_CLASSIFIER_LABEL_COUNT != 3)
    #error "Model rejection: Output class count mismatch. Firmware requires exactly 3 classes: normal, leak, noise."
  #endif

  // 3. Exact compile-time frequency comparison against 4000.0f (prevents fractional mismatches from passing integer truncation)
  static_assert(EI_CLASSIFIER_FREQUENCY == 4000.0f,
                "Model rejection: Sampling frequency mismatch. EI_CLASSIFIER_FREQUENCY must be exactly 4000.0f.");
#endif
```

> [!NOTE]
> These validation checks represent the required adapter guardrails. They have **not yet been executed against the teammate's library** because the artifact has not been delivered. Do not assume all Edge Impulse projects generate identical macros or frame sizes without inspecting the delivered `model_metadata.h`.

---

## 3. Firmware ADC Representation & Model Preprocessing Alignment

To prevent catastrophic train-serve skew between offline Python/Edge Impulse training and embedded ESP32 execution, the exact sample representation is confirmed below:

```
[Piezo Contact Sensor + OPA344 Pre-Amp]
                  |
                  v
       Analog In: PIN_PIEZO (GPIO 34, ADC1_CH6)
                  |
                  v
       analogRead(PIN_PIEZO) -> 12-bit unsigned ADC counts (0 to 4095)
       Hardware attenuation: ADC_11db (Full-scale ~3.3V)
       Virtual ground center: ~1.65V (~2048 counts)
                  |
                  v
       DcBlock::step(): y[n] = x[n] - x[n-1] + 0.995 * y[n-1]
                  |
                  v
       clamp16(y): Stored in circular gRing as signed int16_t (-2048 to +2047 nominal)
                  |
                  v
       gFeat[i] = (float)gRing[i]: Snapshot of 4000 float32 samples
                  |
                  v
       numpy::signal_from_buffer(gFeat, 4000, &sig) -> Passed to Edge Impulse DSP Block
```

### Preprocessing Specifications Matrix
| Parameter | Value in Firmware | Value Expected by Model |
| :--- | :--- | :--- |
| **Input Signal Representation** | Centered ADC counts (signed, zero-mean) | Centered ADC counts (signed, zero-mean) |
| **Numeric Data Type** | `float32` (IEEE 754 single-precision) | `float32` array |
| **Nominal Signal Range** | Approximately $-2048.0$ to $+2047.0$ counts | Approximately $-2048.0$ to $+2047.0$ counts |
| **High-Pass Filter** | First-order IIR DC-block filter ($R = 0.995$) | Must match $R = 0.995$ filter |
| **Firmware Normalization** | **None** (unscaled centered counts in C, $\approx \pm 2048$) | Must match training representation (Do NOT assume DSP auto-scales) |
| **Input Frame Length** | Exactly 4,000 samples ($1000\text{ ms}$ @ $4\text{ kHz}$) | Exactly 4,000 samples |
| **Output Label Order** | `[0: "normal", 1: "leak", 2: "noise"]` | `[0: "normal", 1: "leak", 2: "noise"]` |

> [!WARNING]
> **Train-Serve Audio Scaling Mismatch Hazard:**  
> The firmware delivers unscaled, centered `float32` ADC counts ($\pm 2048$ nominal range) directly to `numpy::signal_from_buffer()`.  
> **Edge Impulse DSP blocks (MFCC, Spectrogram, MFE) must NOT be assumed to correct arbitrary training-versus-inference scaling differences.**  
> If the teammate's model was trained on floating-point audio WAV files (normalized to $[-1.0, +1.0]$) or 16-bit PCM ($\pm 32768$) without applying the identical scaling transform in Edge Impulse Studio, the model input magnitudes will be mismatched by up to 2,000×, causing neural network saturation and total inference failure.  
> **Mandatory Teammate Disclosure:** The teammate must explicitly disclose:
> 1. Exact training input signal units and numeric range.
> 2. Whether DC-block filtering ($R = 0.995$) was applied during training.
> 3. Effective sample rate ($4000\text{ Hz}$) and window duration ($1000\text{ ms}$).
> 4. Any normalization (min-max, standard scaling, or zero-centering) applied in Edge Impulse Studio.  
> Training data collected directly via `leak_detector.ino` in `RUN_MODE_COLLECT` (which streams raw DC-blocked integer counts at 921600 baud) is verified compatible.

---

## 4. Preservation of Fallback Mechanism & Threshold Mathematical Relationship

The deterministic fallback detector is **preserved as the active implementation**:
- `leak_detector.ino` maintains `#define USE_EDGE_IMPULSE 0`.
- The fallback algorithm computes the energy ratio between the current window RMS and the calibrated baseline RMS:
  $$R_{\text{RMS}} = \frac{\text{RMS}_{\text{window}}}{\text{RMS}_{\text{baseline}}}$$
  $$\text{pLeak} = \text{clamp}\left(\frac{R_{\text{RMS}} - 1.0}{\text{FALLBACK\_LEAK\_RATIO} - 1.0},\ 0.0,\ 1.0\right) = \text{clamp}\left(\frac{R_{\text{RMS}} - 1.0}{2.0},\ 0.0,\ 1.0\right)$$

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

- The telemetry label emitted is `"leak(rms)"` or `"no_leak(rms)"`, preventing any operator confusion with machine learning inference.
- **Rule:** Under no circumstance will synthetic or fabricated predictions be hardcoded to simulate model execution. The fallback remains active until real model headers and binaries are provided.

---

## 5. Web Dashboard Verification Record

- **Audit Finding:** A comprehensive filesystem scan of `d:\NAADYANTRA` confirms that **no web dashboard application exists** in the repository.
- **Active Codebases:**
  - `backend/`: FastAPI REST API server with OpenAPI docs at `/docs`.
  - `mobile_app/`: Flutter mobile application (Android / iOS / Desktop).
  - `ml/`: Offline Python data collection, preprocessing, and training prototypes.
  - `tests/`: Pytest integration and logic test suites.
- **Truthfulness Standard:** No claims of web dashboard testing, rendering, or integration will be made unless a web frontend codebase is introduced and verified.

---

## 6. Teammate Handoff Checklist & Required Deliverables

When the teammate delivers the acoustic TinyML model, they must supply the following exact artifacts and verified metadata:

```
[ ] 1. MODEL ARTIFACT ARCHIVE
       - Edge Impulse C++ library export (.zip archive containing edge-impulse-sdk/,
         model-parameters/, and tflite-model/)
       - OR flat C byte array (model_data.h) with confirmed TFLite Micro runtime.

[ ] 2. HEADER METADATA PROOF (from model-parameters/model_metadata.h)
       - EI_CLASSIFIER_RAW_SAMPLE_COUNT == 4000
       - EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME == 1
       - EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE == 4000
       - EI_CLASSIFIER_FREQUENCY == 4000.0f (exact compile-time check against 4000.0f)
       - EI_CLASSIFIER_LABEL_COUNT == 3

[ ] 3. MANDATORY TRAINING INPUT & PREPROCESSING DISCLOSURE
       - Exact training input representation (e.g. raw ADC counts vs float audio)
       - Numeric range (must verify compatibility with firmware's ~ +/-2048 counts)
       - DC-block filtering: Was R = 0.995 high-pass IIR applied to training data?
       - Effective sample rate (4000 Hz) and window length (4000 samples / 1000 ms)
       - Normalization applied in Edge Impulse Studio (Edge Impulse DSP must NOT be assumed to auto-scale training-vs-inference differences)

[ ] 4. OUTPUT CLASS MAPPING CONFIRMATION
       - Index 0: "normal"
       - Index 1: "leak"
       - Index 2: "noise"

[ ] 5. BENCH RESOURCE MEASUREMENTS (Measured on ESP32-WROOM-32E @ 240 MHz)
       - Tensor Arena RAM: ______ KB (Target <= 32 KB, Hard Limit <= 60 KB)
       - Flash Binary Contribution: ______ KB (Target <= 350 KB, Hard Limit <= 550 KB)
       - Inference Latency: ______ ms (Target <= 300 ms, Peak <= 420 ms under Wi-Fi load)

[ ] 6. SCORE CALIBRATION DISCLOSURE
       - Are scores uncalibrated Softmax or temperature-scaled?
       - If calibrated, provide temperature scaling parameter T: ______

[ ] 7. TRAINING DATASET PROVENANCE DISCLOSURE
       - Was training performed on synthetic signals (generate_synthetic.py)
         or physical acoustic pipe recordings?
       - If physical: Pipe material, diameter, pressure range, and noise conditions.
```

---

## 7. Next Steps

1. Teammate completes and returns the Handoff Checklist above along with the C++ model archive.
2. Verify headers against preprocessor and C++ compile-time safety guards.
3. Extract model library files into the Arduino `libraries/` directory (e.g. `Arduino/libraries/<project_name>_inferencing/`) or PlatformIO `lib/` directory. *(Note: Do NOT place firmware C++ library files in `mobile_app/`, which is the Flutter client).*
4. Set `#define USE_EDGE_IMPULSE 1` in `leak_detector.ino`.
5. Execute target build using `arduino-cli compile` on the bench workstation.
