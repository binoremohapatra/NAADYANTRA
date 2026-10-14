# NAADYANTRA — Pre-Model Contract Corrections & Grounding Audit

**Audit Date:** 2026-10-14  
**Target Architecture:** ESP32-WROOM-32E (Xtensa Dual-Core LX6 @ 240 MHz, 520 KB SRAM, 4 MB Flash)  
**Status:** Contract Corrected — Fallback Active (`USE_EDGE_IMPULSE = 0`) — Awaiting Physical Model Delivery  

---

## 1. Executive Summary & Audit Scope

Prior to receiving the TinyML model artifact from the teammate, a targeted audit was conducted on [docs/TINYML_INTEGRATION_CONTRACT.md](file:///d:/NAADYANTRA/docs/TINYML_INTEGRATION_CONTRACT.md) and [docs/PRE_MODEL_READINESS.md](file:///d:/NAADYANTRA/docs/PRE_MODEL_READINESS.md).

Five specific technical corrections were implemented:
1. **Fallback Threshold Math:** Reconciled the exact mathematical relationship between the baseline RMS ratio ($R_{\text{RMS}}$) and the trip threshold ($\text{pLeak} \ge 0.65$), proving the detector trips at $R_{\text{RMS}} \ge 2.30$ and saturates at $3.0$.
2. **Edge Impulse Macro Validation:** Fixed preprocessor guardrails to prevent compiler syntax errors on floating-point frequency macros by mandating C++ `static_assert` and explicit metadata header inclusion.
3. **Train-Serve Audio Scaling Hazard:** Formally documented that the firmware passes unscaled, centered `float32` ADC counts ($\pm 2048$ nominal range) to Edge Impulse, establishing that models trained on normalized audio ($[-1.0, +1.0]$) will fail without identical scaling in Edge Impulse Studio.
4. **Model Placement Correction:** Retracted the incorrect recommendation to place C++ model files in `mobile_app/`; designated the Arduino `libraries/` directory as the sole firmware target.
5. **Preserved Boundaries:** Maintained target ESP32 firmware compilation as DEFERRED and physical battery/sensor performance as UNVERIFIED.

---

## 2. Item A: Fallback Threshold Derivation & Heuristic Score Labeling

### Exact Firmware Implementation
In [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino#L587-L594):
```cpp
const float base = gRmsBase.load();
if (base > 0.0f) {
  r.pLeak   = clampf((r.rms / base - 1.0f) / (FALLBACK_LEAK_RATIO - 1.0f), 0.0f, 1.0f);
  r.pNormal = 1.0f - r.pLeak;
  snprintf(r.topLabel, sizeof(r.topLabel), "%s", r.pLeak >= 0.5f ? "leak(rms)" : "no_leak(rms)");
}
```
And role arbitration in lines 474–479:
```cpp
static Role decideRole(float pLeak, float pNoise, float pNormal) {
  if (pLeak   >= LEAK_PROB_MIN)   return ROLE_LEAK;    // 0.65f
  if (pNoise  >= NOISE_PROB_MIN)  return ROLE_NOISE;   // 0.60f
  if (pNormal >= NORMAL_PROB_MIN) return ROLE_NORMAL;  // 0.60f
  return ROLE_UNCERTAIN;
}
```
Where `FALLBACK_LEAK_RATIO = 3.0f` and `LEAK_PROB_MIN = 0.65f`.

### Mathematical Proof of Detector Transitions
Let $R_{\text{RMS}} = \frac{\text{RMS}_{\text{window}}}{\text{RMS}_{\text{baseline}}}$. The normalized score is:
$$\text{pLeak} = \text{clamp}\left(\frac{R_{\text{RMS}} - 1.0}{3.0 - 1.0},\ 0.0,\ 1.0\right) = \text{clamp}\left(\frac{R_{\text{RMS}} - 1.0}{2.0},\ 0.0,\ 1.0\right)$$

1. **Quiescent Region ($R_{\text{RMS}} < 1.0$):**
   $\text{pLeak} = 0.0$, $\text{pNormal} = 1.0$. Role is `ROLE_NORMAL`.
2. **Intermediate Warning ($R_{\text{RMS}} = 2.0$):**
   $$\text{pLeak} = \frac{2.0 - 1.0}{2.0} = 0.50$$
   The OLED display and telemetry label switch to `"leak(rms)"` (via `r.pLeak >= 0.5f`). However, because $0.50 < 0.65$, `decideRole()` categorizes this window as `ROLE_UNCERTAIN`. **No buzzer or danger alert is triggered.**
3. **Leak Trip Point ($\text{pLeak} \ge 0.65$):**
   $$\frac{R_{\text{RMS}} - 1.0}{2.0} \ge 0.65 \iff R_{\text{RMS}} - 1.0 \ge 1.30 \iff \mathbf{R_{\text{RMS}} \ge 2.30}$$
   **The leak detector asserts `ROLE_LEAK` as soon as the acoustic energy reaches 2.30× baseline.** It does **not** wait for $3.0\times$.
4. **Saturation ($R_{\text{RMS}} \ge 3.0$):**
   $$\text{pLeak} = \frac{3.0 - 1.0}{2.0} = 1.00$$
   Any energy ratio at or above $3.0\times$ baseline saturates the score at $\text{pLeak} = 1.0$.
5. **Debounce Confirmation:**
   `app.leak.update(role == ROLE_LEAK)` requires **2 consecutive windows** ($1.0\text{ s}$ total) with $R_{\text{RMS}} \ge 2.30$ to transition the state to `ALERT_DANGER` / `CAUSE_LEAK`.

### Heuristic Score vs. Probability Labeling
- Variable names like `pLeak`, `pNormal`, and JSON field `pl` are legacy software names.
- In fallback mode, `pLeak` is strictly a **heuristic normalized energy score**, NOT a calibrated statistical probability.
- It must be communicated to trainees and operators as a rule-based indicator, not a statistical confidence value.

---

## 3. Item B: Edge Impulse Metadata & Compile-Time Guardrails

### Problem with Preprocessor `#if` on Floating-Point Macros
In C/C++, preprocessor directives (`#if`, `#elif`) evaluate **only integer constant expressions**. In Edge Impulse Studio exports:
- `EI_CLASSIFIER_FREQUENCY` is frequently generated as a floating-point literal (e.g. `4000.0f` or `4000.0`).
- Evaluating `#if (EI_CLASSIFIER_FREQUENCY != 4000)` causes a compiler syntax error:
  `error: floating constant in preprocessor expression`.

### Corrected Compile-Time & Runtime Validation Strategy
1. **Header Inclusion Order:** The model metadata header must be explicitly included before evaluating constants:
   ```cpp
   #if USE_EDGE_IMPULSE
     #include "model-parameters/model_metadata.h"
   ```
2. **Integer Checks via Preprocessor `#if`:**
   Integer macros can be evaluated with `#if`:
   ```cpp
     #if (EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME != 1)
       #error "Model rejection: Firmware samples only 1 piezo channel (EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME must be 1)."
     #endif

     #if (EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE != 4000)
       #error "Model rejection: Buffer size mismatch with gFeat[4000] (EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE must be 4000)."
     #endif

     #if (EI_CLASSIFIER_LABEL_COUNT != 3)
       #error "Model rejection: Output class count mismatch. Requires exactly 3 classes: normal, leak, noise."
     #endif
   ```
3. **Frequency Check via C++ `static_assert`:**
   Because `EI_CLASSIFIER_FREQUENCY` can be a float, it must be validated using C++ `static_assert` or runtime startup assertion:
   ```cpp
     static_assert(EI_CLASSIFIER_FREQUENCY == 4000.0f,
                   "Model rejection: Sampling frequency mismatch. Firmware timer runs at 4000.0f Hz.");
   #endif
   ```
   *Note: Using exact compile-time comparison against `4000.0f` prevents fractional mismatches from passing integer truncation.*
4. **Honest Readiness Status:** These guardrails are designed and documented, but **have not yet been tested against the teammate's model** because the archive has not been provided.

---

## 4. Item C: Preprocessing Train-Serve Compatibility & Amplitude Scaling

A critical potential failure mode is amplitude scaling mismatch between offline model training and embedded firmware execution:

```
[Physical Sensor + OPA344] -> 12-bit ADC (0 to 4095)
                                    |
                                    v
                           DC-Block Filter (R = 0.995)
                                    |
                                    v
                           clamp16() -> int16_t (-2048 to +2047 nominal)
                                    |
                                    v
                           gFeat[i] = (float)gRing[...]
                                    |
                                    v
                           numpy::signal_from_buffer(gFeat, 4000, &sig)
```

### Potential Scaling Pitfall
- In [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino#L611-L614), `gFeat` contains unscaled, centered `float32` ADC counts with peak values reaching $\pm 1000$ to $\pm 2000$.
- Standard audio machine learning models are typically trained on audio WAV files normalized to $[-1.0, +1.0]$ or 16-bit PCM ($\pm 32768$).
- **If the teammate trained their model on normalized audio without identical scaling inside Edge Impulse Studio, the model input values on device will be 2,000× larger than expected, causing saturation in neural network activations.**
- **Safe Pipeline:** If data was acquired using `RUN_MODE_COLLECT` (where the ESP32 streams raw DC-blocked integer counts at 921600 baud), then the training scale and device inference scale match 100%.

---

## 5. Item D: Firmware Build System Model Placement

### Retraction of `mobile_app/` Recommendation
- An earlier sprint note erroneously suggested placing the Edge Impulse C++ library into `mobile_app/`.
- `mobile_app/` contains the Flutter/Dart mobile application codebase. Placing C++ embedded headers there has zero effect on the ESP32 firmware build.

### Correct Placement Target
When the teammate delivers `<project_name>_inferencing.zip`:
1. Extract the folder into the Arduino user libraries directory:
   - Windows: `C:\Users\<user>\Documents\Arduino\libraries\<project_name>_inferencing/`
   - Linux/Mac: `~/Arduino/libraries/<project_name>_inferencing/`
2. If compiling via PlatformIO, extract into `lib/<project_name>_inferencing/`.
3. In [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino), update line 563 to `#define USE_EDGE_IMPULSE 1` and replace `<YOUR_PROJECT_inferencing.h>` with the exact header name.

---

## 6. Item E: Verification Boundaries & Test Evidence

### Unchanged Architecture & Hardware Safeguards
- **GPIO Pin Allocations:** Preserved 100% unchanged (`PIN_PIEZO = 34`, `PIN_REFERENCE = 33`, `PIN_GAS = 35`, `PIN_MOISTURE = 32`, `PIN_UV = 36`).
- **Acoustic Sampling Pipeline:** Preserved 100% unchanged ($f_s = 4000\text{ Hz}$, window = 4000 samples, hop = 2000 samples).
- **Active Detector:** `#define USE_EDGE_IMPULSE 0` remains active.
- **API Contracts:** FastAPI schemas and SQLite cache remain 100% backward-compatible.

### Test Execution Verification
Both existing test suites were executed to verify zero regression across firmware logic and backend endpoints:

```powershell
pytest tests/test_firmware_logic.py -q
```
- **Output:** `48 passed, 2 warnings in 0.91s` (Exit code: `0`).

```powershell
pytest tests/test_backend.py -q
```
- **Output:** `41 passed, 3 warnings in 172.84s` (Exit code: `0`).

### Deferred Verification Checklist (Hardware & Target Build)
- [ ] **Target ESP32 Firmware Compilation:** Marked **DEFERRED** until tested on physical bench with installed `arduino-cli`.
- [ ] **Physical Leak Detection Sensitivity:** Marked **UNVERIFIED** until tested against pressurized pipe orifices.
- [ ] **Battery Runtime Profiling:** Marked **UNVERIFIED** until measured with multimeter under physical Li-ion discharge.
- [ ] **Teammate Model Integration:** Marked **PENDING** until the teammate returns the Handoff Checklist and validated C++ archive.
