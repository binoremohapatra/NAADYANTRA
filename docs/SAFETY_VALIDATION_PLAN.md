# NAADYANTRA — Formal Safety & Performance Validation Plan
## Diagnostic Sensing Wearable for Skilled Trades (SIH26244)

> [!WARNING]
> **Regulatory Notice & Operating Boundaries**:  
> **Status**: Bench Protocol Defined / Physical Testing Pending Hardware Assembly  
> **Intrinsic Safety Restriction**: NAADYANTRA is an educational and diagnostic screening prototype for vocational skill training. **IT IS NOT CERTIFIED INTRINSICALLY SAFE (IS)** under ATEX, IECEx, or PESO standards for explosive industrial environments (Zone 0/1/2). It must **NEVER** be brought into live explosive atmospheres or hazardous process plants. All experimental testing must be strictly confined to well-ventilated vocational training workshops and certified laboratory benches equipped with fume extraction and reference safety monitors.

---

## 1. Intended Use & Operating Boundaries

### 1.1 Intended Use
- **Primary Domain**: Educational and diagnostic screening tool for trade apprentices (plumbing, pipefitting, HVAC) learning acoustic joint leak diagnosis and situational hazard awareness.
- **Operating Conditions**:
  - Ambient Temperature: $10^\circ\text{C}$ to $40^\circ\text{C}$
  - Relative Humidity: $10\%$ to $85\%$ non-condensing
  - Pressure Range: Standard atmospheric ($101.3 \pm 5 \text{ kPa}$)

### 1.2 Prohibited Use
- Not for use as primary life-safety gas detection equipment in underground mines, chemical vessels, or confined fuel tanks without an approved industrial multigas monitor.
- Not for subsea or immersed pipe testing.

---

## 2. Sensor Specifications & Calibration Protocols

| Sensor Modality | Target Measurand | Measurement Range | Bandwidth / Sampling | Calibration & Conditioning Protocol |
| :--- | :--- | :--- | :--- | :--- |
| **Contact Piezo** | Structural acoustic vibration & hiss | $0 \text{ to } 4095 \text{ counts}$ (12-bit ADC) | $4000 \text{ Hz}$ ($2000 \text{ Hz}$ Nyquist) | Zero-baseline calibration: 10-second ambient quiet sweep ($< 45\text{ dBA}$ ambient) to establish $R_0$ acoustic floor. Disconnected fault trip at $\text{RMS} < 0.8$. |
| **MQ-2 Gas Sensor** | Combustible hydrocarbons (LPG/CH4) | $200 \text{ to } 10000 \text{ ppm}$ indicative | $10 \text{ Hz}$ moving average | **48-Hour Burn-In**: Initial heater burn-in at $5.0\text{V} \pm 0.1\text{V}$ for 48h. In-session thermal warm-up: 2 to 5 minutes (60s minimum guard). $R_s / R_0$ computed dynamically. |
| **MLX90614 IR** | Non-contact surface temperature | $-70^\circ\text{C} \text{ to } +380^\circ\text{C}$ | $10 \text{ Hz}$ SMBus read | Factory calibrated by Melexis. Spot-verified against calibrated contact K-type thermocouple probe. |
| **Conduction Probe** | Surface liquid / pipe condensation | Binary (Dry / Wet conduction) | $2 \text{ Hz}$ gated pulse | De-ionized water non-trip check vs tap water trip check. Excitation pulse active for $50\text{ ms}$ only to prevent electrolytic corrosion. |

---

## 3. Controlled Laboratory Test Procedures

> [!CAUTION]
> **Strict Laboratory Safety Directives**:  
> Under no circumstances may students or test operators casually release unconfined flammable gas or operate uncertified high-pressure vessels. All testing must follow the controlled bench procedures below:

### Protocol 1: Nominal Baseline & False-Positive Immunity
- **Objective**: Verify that normal technician handling, walking, tool gripping, and ambient speech do not trigger false hazard alarms.
- **Procedure**: Wearable worn for 10 minutes in typical vocational workshop during active instruction.
- **Acceptance Criteria**: Zero false-positive `DANGER` alerts. RMS remains below $1.5\times$ baseline ratio (`CUE_RMS_START_RATIO`).

### Protocol 2: Pressurized Leak Detection on Safe Bench Manifold
- **Objective**: Localize pressurized gas escape from a safe, low-pressure test manifold.
- **Apparatus**: Compressed air manifold operating at regulated low pressure ($\le 1.5\text{ to } 2.0\text{ bar}$) fitted with an ASME-coded pressure relief valve, burst protection shield, and a precision $0.5\text{ mm}$ pinhole orifice.
- **Safety Equipment**: Personal eye protection and hearing protection required.
- **Procedure**: Operator couples piezo probe to pipe surface at distances of $10\text{ cm}$, $30\text{ cm}$, and $100\text{ cm}$ from the orifice.
- **Acceptance Criteria**:
  - RMS differential exceeds $3.0\times$ baseline (`FALLBACK_LEAK_RATIO`) within $1.0\text{ s}$ of acoustic contact.
  - Leak confirmed across at least 2 consecutive analysis windows (`LEAK_CONFIRM_WINDOWS = 2`).
  - Alert transitions to `DANGER`, activating audio cue and tactile vibration.

### Protocol 3: Controlled Gas Screening in Specialist Laboratory Fume Hood
- **Objective**: Verify sensor conductivity response without creating atmospheric flammability or explosive hazards.
- **Safety Boundary & Disclaimer**:
  - **Alcohol Swabs Are Qualitative Functional Checks Only**: An isopropyl alcohol or ethanol swab placed near the sensor can only verify that the $\text{SnO}_2$ chemo-resistor changes conductivity. **It does NOT constitute proof of calibrated combustible gas performance, %LEL measurement accuracy, or gas specificity.**
  - **Mandatory Specialist Facility for Hazardous Hydrocarbons**: Any testing involving pressurized combustible gases (methane, propane, butane) is strictly prohibited in general classrooms and must be conducted exclusively in an authorized specialist facility (e.g. certified materials safety or chemical engineering test laboratory).
- **Apparatus**: Certified laboratory chemical fume hood with continuous face-velocity monitoring ($> 100\text{ FPM}$). Calibrated industrial reference gas monitor (Dräger X-am 2500 or Honeywell BW Clip). Certified calibration span-gas canister (e.g. 50% LEL Methane in Air) fitted with a demand-flow regulator and sealed exhaust shroud.
- **Procedure**: The reference monitor and NAADYANTRA sensor intake are co-located in the extraction hood. Controlled span gas is delivered via the shroud for a 5-second pulse.
- **Acceptance Criteria**:
  - Raw ADC delta increases by $\ge 150$ counts (`GAS_WARN_DELTA`) within $3.0\text{ s}$ of exposure.
  - Alert transitions from `NORMAL` to `CAUTION` (or `DANGER` if delta $\ge 400$ counts `GAS_ALARM_DELTA`).
  - Output labeled strictly as indicative relative delta ($\Delta\text{ADC}$), with zero claims of calibrated ppm.

### Protocol 4: Non-Contact Surface Thermal Protection
- **Objective**: Warn technician before placing forearm or hand on high-temperature pipe fitting.
- **Apparatus**: Temperature-controlled hot-plate / oil bath fitting heated to $70^\circ\text{C}$ with contact thermocouple verification.
- **Procedure**: Wearable swept towards fitting from $30\text{ cm}$ distance.
- **Acceptance Criteria**:
  - Audio ticking begins at $40.0^\circ\text{C}$ (`HEAT_CUE_START_C`).
  - Alert transitions to `WARNING` at $60.0^\circ\text{C}$ (`HEAT_WARN_C`) at $\ge 10\text{ cm}$ standoff distance, prior to physical contact.

---

## 4. Latency & System Reliability Benchmarks

| Metric | Firmware Constant / Target | Validation Method |
| :--- | :--- | :--- |
| **Acoustic Confirmation Latency** | $1.0\text{ s}$ (`LEAK_CONFIRM_WINDOWS = 2` @ 500ms hop) | Time from acoustic contact to buzzer pin assertion (logic analyzer). |
| **Telemetry Ingestion Latency** | $< 2.0\text{ s}$ | Wi-Fi payload timestamp vs server ingress `server_timestamp`. |
| **Offline Queue Retention** | $40\text{ entries}$ (`LOG_QUEUE_LEN = 40`) | Disconnect Wi-Fi for 5 minutes during active leak session; verify zero dropped critical events on reconnection. |
| **Battery Autonomy (Provisional)** | $\approx 2.3\text{ hours}$ continuous active telemetry ($\approx 3.5 - 4.0\text{ h}$ intermittent duty-cycle) | 1200mAh LiPo discharge logging continuous Wi-Fi and MQ heater draw. *(Provisional target pending physical battery discharge benchmark).* |

---

## 5. Formal Validation Protocol Review & Sign-Off Record

```markdown
### NAADYANTRA BENCH VALIDATION EXECUTION RECORD
- Date of Test Protocol Audit : 2026-10-17
- Prototype Serial ID          : SIH-DEV-______ (Pending Assembly)
- Firmware Target              : ESP32-S3 (Release 1.1.0)
- Environmental Specification  : 25.0 ± 5 °C / 45 ± 15 % RH
- Facility / Institution        : _________________________________

Validation Protocol Check-List:
[ ] PR-01: False-Positive Immunity (10 min ambient handling)       -> [ PENDING REVIEW ]
[ ] PR-02: Pressurized Leak Detection (Regulated <= 2 bar air line)-> [ PENDING REVIEW ]
[ ] PR-03: Combustible Gas Screening (Specialist Fume Hood Only)    -> [ PENDING REVIEW ]
[ ] PR-04: Non-Contact Thermal Safety (70°C target sweep)          -> [ PENDING REVIEW ]
[ ] PR-05: Offline Queue Replay & Idempotency Verification         -> [ PENDING REVIEW ]

Status Declaration: PROTOCOL SPECIFIED — PENDING INSTITUTIONAL LAB SAFETY REVIEW & QUALIFIED SIGN-OFF BEFORE PHYSICAL TESTING
Lead Test Engineer Signature            : _______________________ Date: ___________
Institutional Safety Officer / Reviewer : _______________________ Date: ___________
```
