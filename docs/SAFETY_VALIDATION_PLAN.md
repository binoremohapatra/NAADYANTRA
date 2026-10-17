# NAADYANTRA — Formal Safety & Performance Validation Plan
## Diagnostic Sensing Wearable for Skilled Trades (SIH26244)

> [!WARNING]
> **Regulatory & Operating Boundaries**:  
> NAADYANTRA is an engineering prototype and vocational skill training tool.  
> **IT IS NOT INTRINSICALLY SAFE (IS) CERTIFIED** under ATEX, IECEx, or PESO standards for hazardous explosive atmospheres (Zone 0/1/2). It must NOT be introduced into active refinery explosive vapour zones until formal intrinsic safety barrier encapsulation and certification are achieved. All physical testing must be conducted in controlled vocational workshops and well-ventilated laboratory benches.

---

## 1. Intended Use & Operating Boundaries

### 1.1 Intended Use
- **Primary Domain**: Educational and diagnostic screening tool for trade apprentices (plumbers, HVAC technicians, fitters) learning acoustic pipe leak diagnosis and ambient hazard awareness.
- **Operating Conditions**:
  - Ambient Temperature: $10^\circ\text{C}$ to $45^\circ\text{C}$
  - Relative Humidity: $10\%$ to $85\%$ non-condensing
  - Pressure Range: Standard atmospheric ($101.3 \pm 5 \text{ kPa}$)

### 1.2 Prohibited Use
- Not for use as primary life-safety gas detection equipment in underground mines or enclosed chemical storage vessels without a certified industrial gas monitor backup.
- Not for subsea or immersed pipe testing.

---

## 2. Sensor Specifications & Calibration Protocols

| Sensor Modality | Target Measurand | Measurement Range | Bandwidth / Sampling | Calibration Protocol |
| :--- | :--- | :--- | :--- | :--- |
| **Contact Piezo** | Structural acoustic vibration & hiss | $0 \text{ to } 4095 \text{ counts}$ (12-bit ADC) | $4000 \text{ Hz}$ ($2000 \text{ Hz}$ Nyquist) | Zero-baseline calibration: 10-second ambient quiet sweep ($< 45\text{ dBA}$ ambient) to establish $R_0$ acoustic floor. |
| **MQ Gas Sensor** | Combustible hydrocarbons (LPG/CH4) | $200 \text{ to } 10000 \text{ ppm}$ indicative | $10 \text{ Hz}$ moving average | 24-hour preheat burn-in. $R_0$ baseline established in fresh outdoor air. $R_s / R_0$ computed dynamically. |
| **MLX90614 IR** | Non-contact surface temperature | $-70^\circ\text{C} \text{ to } +380^\circ\text{C}$ | $10 \text{ Hz}$ SMBus read | Factory calibrated by Melexis. Spot-verified against calibrated contact K-type thermocouple probe. |
| **Conduction Probe** | Surface liquid / pipe condensation | Binary (Dry / Wet conduction) | $2 \text{ Hz}$ gated pulse | De-ionized water non-trip check vs tap water trip check. Excitation pulse active for $50\text{ ms}$ only. |

---

## 3. Test Cases & Validation Matrix

### Scenario 1: Nominal Baseline & False-Positive Immunity
- **Objective**: Verify that normal handling, typing, forearm motion, and ambient speech do not trigger false hazard alarms.
- **Procedure**: Wearable worn for 10 minutes in typical classroom/workshop.
- **Acceptance Criteria**: Zero false-positive `DANGER` alerts. RMS remains below $600$ counts.

### Scenario 2: Acoustic Compressed Air Leak Detection
- **Objective**: Localize pressurized gas escape from an engineered test fixture (2 bar compressed air line, $0.5\text{ mm}$ orifice).
- **Procedure**: Operator couples piezo probe to pipe surface at distances of $10\text{ cm}$, $30\text{ cm}$, and $100\text{ cm}$ from the orifice.
- **Acceptance Criteria**:
  - RMS differential $> 800$ counts above baseline within $1.0\text{ s}$ of acoustic contact.
  - Event alert transitions from `NORMAL` to `CAUTION` or `DANGER`.
  - Telemetry logs `pl >= 0.70` (leak probability) and triggers tactile/buzzer cue.

### Scenario 3: Transient Combustible Gas Spike
- **Objective**: Detect rapid hydrocarbon accumulation.
- **Procedure**: Controlled release of butane vapor at $30\text{ cm}$ distance in fume-hood environment.
- **Acceptance Criteria**:
  - Gas resistance ratio drops ($gr < 0.60$) within $3.0\text{ s}$.
  - System latches `WARNING` or `DANGER` alert; logs event to backend.

### Scenario 4: Surface Burn Prevention
- **Objective**: Warn technician before placing forearm or hand on high-temperature pipe fitting.
- **Procedure**: Sensor swept towards steam-pipe mock-up heated to $70^\circ\text{C}$.
- **Acceptance Criteria**: IR reading exceeds $60^\circ\text{C}$ threshold at $10\text{ cm}$ distance; triggers audio/visual warning before physical contact.

---

## 4. Latency & Reliability Metrics

| Metric | Target Specification | Validation Method |
| :--- | :--- | :--- |
| **Acoustic Detection Latency** | $< 500\text{ ms}$ | Time from valve crack to buzzer activation (measured via oscilloscope / logic analyzer). |
| **Telemetry Dispatch Latency** | $< 2.0\text{ s}$ | Wi-Fi payload timestamp vs server ingress `server_timestamp`. |
| **Offline Buffering Endurance** | $\ge 50\text{ events}$ without memory leak | Disconnect Wi-Fi for 5 minutes during active leak session; verify zero dropped critical events on reconnection. |
| **Power Autonomy** | $\ge 4\text{ hours}$ continuous operation | 1200mAh battery discharge curve logging active Wi-Fi transmit cycles. |

---

## 5. Validation Execution Sign-Off Template

```markdown
### NAADYANTRA BENCH VALIDATION PROTOCOL EXECUTION RECORD
- Date of Test Execution : [ YYYY-MM-DD ]
- Prototype Serial ID   : SIH-DEV-______
- Firmware Version       : 1.1.0-release
- Environmental Temp/RH  : _____ °C / _____ % RH
- Facility / Institution : _________________________________

Test Case Results:
[ ] TC-01: False-Positive Immunity (10 min quiet handling) -> [ PASS / FAIL ]
[ ] TC-02: Pressurized Leak Detection (2 bar air line)     -> [ PASS / FAIL ]
[ ] TC-03: Combustible Gas Screening (Fume hood butane)     -> [ PASS / FAIL ]
[ ] TC-04: Surface Burn Warning (70°C target)              -> [ PASS / FAIL ]
[ ] TC-05: Offline Queue Replay & Idempotency Check        -> [ PASS / FAIL ]

Lead Test Engineer Signature: _______________________
Vocational Instructor Review : _______________________
```
