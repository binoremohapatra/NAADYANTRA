# NAADYANTRA — Hardware Commissioning & Bench Testing Guide
## Firmware Flashing, Pinout Verification & Sensor Integration (SIH26244)

> [!IMPORTANT]
> **Core Requirement**: Arduino-ESP32 Core **3.x** is required (`ESP_ARDUINO_VERSION_MAJOR >= 3`).  
> Ensure your Arduino IDE or PlatformIO environment is updated to Espressif Core $\ge 3.0.0$.

---

## 1. Board-Specific Pinout Configuration

The firmware [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino) automatically maps pins at compile time based on the active board target:

| Function | Signal Name | ESP32-S3 Pin (Default) | Classic ESP32 Pin | Electrical Notes |
| :--- | :--- | :---: | :---: | :--- |
| **Contact Piezo** | `PIN_PIEZO` | **GPIO 4** (ADC1_CH3) | **GPIO 34** (ADC1_CH6) | AC-coupled via 0.1µF into MCP6002 RRIO op-amp with 1.65V virtual ground bias. |
| **Reference Mic** | `PIN_REFERENCE` | **GPIO 7** (ADC1_CH6) | **GPIO 33** (ADC1_CH5) | Ambient noise cancellation channel (optional). |
| **Combustible Gas** | `PIN_GAS` | **GPIO 5** (ADC1_CH4) | **GPIO 35** (ADC1_CH7) | **CRITICAL**: MQ module powered at 5V. 10kΩ / 20kΩ divider scales signal to $\le 3.3\text{V}$. |
| **Moisture Sense** | `PIN_MOISTURE` | **GPIO 6** (ADC1_CH5) | **GPIO 32** (ADC1_CH4) | Conduction probe sense node with 100kΩ pull-down. |
| **Moisture Power** | `PIN_MOIST_PWR` | **GPIO 10** | **GPIO 23** | Gated excitation pin; driven HIGH for 50ms only during read to prevent galvanic erosion. |
| **I2C SDA** | `PIN_SDA` | **GPIO 8** | **GPIO 21** | Shared I2C bus for SSD1306 OLED (`0x3C`) and MLX90614 pyrometer (`0x5A`). |
| **I2C SCL** | `PIN_SCL` | **GPIO 9** | **GPIO 22** | $100\text{ kHz}$ standard clock. Ensure $4.7\text{k}\Omega$ pull-ups to 3.3V. |
| **Audio Buzzer** | `PIN_BUZZER` | **GPIO 15** | **GPIO 25** | Driven via 2N2222 NPN transistor with flyback protection diode. |
| **Haptic Motor** | `PIN_VIBRATION` | **GPIO 16** | **GPIO 26** | Driven via 2N2222 NPN transistor with 1N4148 flyback diode. |
| **Green LED (OK)** | `PIN_LED_GREEN` | **GPIO 17** | **GPIO 27** | $330\Omega$ series ballast resistor. |
| **Yellow LED (Warn)**| `PIN_LED_YELLOW` | **GPIO 18** | **GPIO 14** | $330\Omega$ series ballast resistor (Avoids strapping pin GPIO 12). |
| **Red LED (Danger)** | `PIN_LED_RED` | **GPIO 21** | **GPIO 13** | $330\Omega$ series ballast resistor. |
| **BOOT / Control** | `PIN_BUTTON` | **GPIO 0** | **GPIO 0** | Active-LOW with internal pull-up. Short press: toggle session; Long press (>2s): calibrate baseline. |

> [!WARNING]
> **ADC Channel Rule**: All analog sensors are strictly routed to **ADC1**. On the ESP32 platform, **ADC2 cannot be used simultaneously with active Wi-Fi transmission**. Violating this will cause silent sample corruption or radio crashes.

---

## 2. Analog Signal Conditioning & Schematics

### 2.1 Contact Piezoelectric Op-Amp Stage (Dual-Stage MCP6002 with Anti-Aliasing LPF)

> [!CAUTION]
> **Op-Amp Selection Requirement**:  
> A classic **TL072** has a manufacturer-specified minimum supply voltage of **7.0V (±3.5V)** and will not function on a 3.3V single-supply rail. An **LM358** operates at 3V but is not rail-to-rail output ($V_{OH} \approx V_{CC} - 1.5\text{V} = 1.8\text{V}$), leaving only $150\text{mV}$ of positive swing above a 1.65V bias.  
> **Mandatory Component**: Use a true **3.3V Rail-to-Rail Input/Output (RRIO) Op-Amp** such as the **Microchip MCP6002** (dual op-amp, 1.8V - 6.0V single-supply, 1MHz GBWP, 1pA input bias) or **TI TLV2372 / LMV358A**.

#### Anti-Aliasing Reconciliation (4 kHz ADC Sampling vs. Sensor Bandwidth)
The firmware samples the acoustic channel at **$f_s = 4000\text{ Hz}$** ($4\text{ kHz}$), yielding a **Nyquist frequency of $f_N = 2000\text{ Hz}$**. Because raw piezoceramic elements and high-gain op-amps maintain bandwidth up to $\approx 30\text{ kHz}$, any unattenuated mechanical noise, motor whine, or ultrasonic hiss above $2\text{ kHz}$ will alias directly into the $0 - 2\text{ kHz}$ detection baseband, corrupting FFT energy bins and false-triggering the RMS leak heuristic.

To solve this, both operational amplifiers of the dual **MCP6002** package are utilized in a 2-stage topology:
1. **Stage 1 (U1A)**: AC-coupled non-inverting pre-amplifier ($A_{v1} \approx 23\times$, $27.2\text{ dB}$) biased at $V_\text{BIAS} = 1.65\text{ V}$.
2. **Stage 2 (U1B)**: Active 2nd-order Sallen-Key Low-Pass Butterworth Filter ($f_c \approx 1.6\text{ kHz}$, roll-off $-40\text{ dB/decade}$).

```text
                        +3.3V (Clean Analog Rail)
                          │
                         [10k 1%]
                          ├───────────────── V_BIAS (1.65V Mid-Supply Virtual Ground)
                         [10k 1%]  │
                          │        [10uF Tantalum/Ceramic] to GND
                         GND       │
                                   ▼
[STAGE 1: PRE-AMPLIFIER]
Piezo Disc (+) ──[0.1uF C0G]──┬───────[ + ]
                              │        MCP6002 (U1A) ──────┐
Piezo Disc (-) ── GND        [1M]     [ - ]                │
                              │         │                  │
                           V_BIAS       │                  │
                              └──[22k]──┴──[1k]── V_BIAS   │
                              (Av1 ~ 23x, 27 dB)           │
                                                           │
[STAGE 2: ACTIVE 2ND-ORDER SALLEN-KEY ANTI-ALIASING LPF]   │
                                                           ▼
                             ┌──────────────────[15nF]─────┴───────┐
                             │                                     │
                             │   R1 = 10k 1%     R2 = 10k 1%       │
                             └─────[10k]─────┬─────[10k]─────[ + ] │
                                             │                U1B ─┴─[100R]──┬──► PIN_PIEZO (ADC1)
                                           [6.8nF]           [ - ]           │
                                             │                 │          [BAT54S Clamp]
                                           V_BIAS              │             ├── to +3.3V Rail
                                                               └─────────────┴── to GND Rail
```

- **Filter Cutoff Frequency ($f_c$)**:
  $$f_c = \frac{1}{2\pi \sqrt{R_1 R_2 C_1 C_2}} = \frac{1}{2\pi \times 10^4 \times \sqrt{15\text{nF} \times 6.8\text{nF}}} \approx 1575\text{ Hz} \approx 1.6\text{ kHz}$$
- **Quality Factor ($Q$)**: $Q = \frac{\sqrt{C_1 C_2}}{2 C_2} \approx 0.74$ (maximally flat Butterworth passband).
- **Passband**: $0 - 1500\text{ Hz}$ ($\pm 0.8\text{ dB}$ flatness), covering pipe leak acoustic hiss ($300 - 1500\text{ Hz}$).
- **Stopband Attenuation**: $-16.5\text{ dB}$ at $4\text{ kHz}$; $-32\text{ dB}$ at $10\text{ kHz}$ ($-40\text{ dB/decade}$).
- **ADC Protection**: $100\Omega$ series resistor + BAT54S dual Schottky clamp to prevent excursions outside $-0.3\text{V}$ to $+3.6\text{V}$.
- **Validation Status**: `CIRCUIT SCHEMATIC VERIFIED — PHYSICAL ACOUSTIC TRANSDUCER VALIDATION PENDING`.

---

### 2.2 MQ Combustible Gas Sensor Integration & Precision ADC Divider

> [!IMPORTANT]
> **Conditioning & Measurement Honesty**:
> 1. **Initial Heater Conditioning**: Manufacturer documentation (Winsen MQ-2 / MQ-135) specifies a continuous **48-hour burn-in period** at rated heater voltage ($V_H = 5.0\text{V} \pm 0.1\text{V}$) for chemical stabilization of the $\text{SnO}_2$ sensing layer.
> 2. **Session Warm-Up**: During bench deployment, a **2 to 5 minute thermal warm-up** is required after power-on before recording baseline resistance ($R_0$). The firmware enforces a minimum 60-second stabilization guard (`GAS_WARMUP_S = 60`).
> 3. **Measurement Status**: Because certified span-gas chamber calibration has not yet been conducted on the physical rig, gas readings must be treated as **indicative relative sensor delta ($\Delta\text{ADC}$) and resistance ratio ($R_s/R_0$)**, NOT certified absolute ppm or %LEL.

#### Verified ADC Interface Divider Calculation
The MQ-2 sensor breakout module is powered from the regulated $+5.0\text{V}$ rail ($V_{CC} = 5.0\text{V} \pm 5\%$, maximum $V_{in,\max} = 5.25\text{V}$). Under extreme gas saturation, the module analog output $A_0$ approaches $V_{CC}$.
- **ESP32 ADC Linear Range**: With $11\text{ dB}$ attenuation (`ADC_ATTEN_DB_11` on Classic ESP32), the linear measurable range is $\approx 100\text{ mV}$ to $2450\text{ mV}$ ($2.45\text{V}$). On ESP32-S3 with $12\text{ dB}$ attenuation, it is $\approx 100\text{ mV}$ to $3100\text{ mV}$.
- **Absolute Maximum GPIO Rating**: $V_{DD} + 0.3\text{V} = 3.6\text{V}$. Direct exposure to $5.0\text{V} - 5.25\text{V}$ will destroy the MCU input.
- **Divider Selection ($12\text{k}\Omega / 10\text{k}\Omega\ 1\%$)**:
  $$K = \frac{R_2}{R_1 + R_2} = \frac{10\text{k}\Omega}{12\text{k}\Omega + 10\text{k}\Omega} = \frac{10}{22} \approx 0.4545$$
  - At $V_{in} = 5.00\text{V} \implies V_\text{ADC} = 2.273\text{V}$ (inside linear range).
  - At $V_{in} = 5.25\text{V} \implies V_\text{ADC} = 2.386\text{V}$ (below $2.45\text{V}$ saturation threshold).
  - Absolute maximum $3.6\text{V}$ GPIO limit would require $V_{in} > 7.92\text{V}$, providing $> 2.6\text{V}$ overvoltage headroom.
  - Output impedance: $R_{eq} = 12\text{k}\Omega \parallel 10\text{k}\Omega \approx 5.45\text{k}\Omega$ (well below ESP32 ADC source impedance recommendation of $< 10\text{k}\Omega$).

```text
MQ-2 Analog Out (0 - 5.25V) ───[12k 1%]───┬───► PIN_GAS (ADC1, 0 - 2.39V Max)
                                          │
                                        [10k 1%] ──┬── [10nF Ceramic] to GND
                                          │        │
                                         GND    [BAT54S Dual Clamp]
                                                   ├── to +3.3V Rail
                                                   └── to GND Rail
```

---

### 2.3 Power System Architecture & Energy Budget

To ensure physical electrical integrity and avoid ambiguity between portable wearable usage and stationary lab benches, the complete dual power topology is established:

```text
[CONFIGURATION A: WEARABLE / FIELD OPERATION]
1S Li-Po Battery (3.7V Nom, 1200mAh)
    │
  [PCM Protection Circuit: DW01A + 8205A (Over-charge, Over-discharge, Over-current)]
    ├──► TP4056 USB-C Charger (5V USB in, 4.2V CC/CV 1A charge rate)
    │
    ├──► [MT3608 Synchronous Boost Converter (85% eff)] ──► +5.0V Regulated Rail
    │                                                        ├── MQ-2 Heater (RH ~31R, ~160-180mA, 900mW)
    │                                                        └── Piezoceramic Audio Buzzer (~20mA peak)
    │
    └──► [AP2112K / ME6211 3.3V LDO Regulator] ────────────► +3.3V Regulated Rail
                                                             ├── ESP32 / ESP32-S3 MCU (~120-160mA avg, 350mA Wi-Fi burst)
                                                             ├── Dual MCP6002 Op-Amp (< 1mA)
                                                             ├── MLX90614 Pyrometer (1.5mA)
                                                             └── SSD1306 OLED (15mA)

[CONFIGURATION B: BENCH / TRAINING LAB BENCHTOP]
External DC Power Supply (9V - 12V DC, 2A Wall Adapter)
    │
  [MP1584 / LM2596 Step-Down Buck Converter (90% eff)] ──► +5.0V Regulated Rail
                                                            ├── Supplies MQ-2 Heater Directly
                                                            └── Feeds ESP32 Onboard 3.3V LDO for Logic Rail
*(Note: A 12V-to-5V buck converter is for stationary benchtop testing only; it must never be connected directly to a Li-ion cell).*
```

#### Power Demand & Provisional Autonomy Calculation
| Subsystem Rail | Voltage | Average Current | Power Demand | Battery Draw @ 3.7V Nom |
| :--- | :---: | :---: | :---: | :---: |
| **MQ-2 Heater (Continuous)** | $5.0\text{V}$ | $170\text{ mA}$ | $850\text{ mW}$ | $270\text{ mA}$ (via boost $\eta=85\%$) |
| **ESP32 Core & Wi-Fi Active** | $3.3\text{V}$ | $140\text{ mA}$ | $462\text{ mW}$ | $140\text{ mA}$ (via LDO $\eta=89\%$) |
| **Sensors, AFE & OLED Display** | $3.3\text{V}$ | $20\text{ mA}$ | $66\text{ mW}$ | $20\text{ mA}$ (via LDO) |
| **Alert Transducers (Intermittent)** | $5.0\text{V}$ / $3.3\text{V}$ | $\approx 25\text{ mA}$ | $\approx 100\text{ mW}$ | $\approx 15\text{ mA}$ (time-averaged) |
| **Total System Draw** | — | — | **$\approx 1.48\text{ W}$** | **$\approx 445\text{ mA}$** |

- **Provisional Battery Autonomy**:
  $$\text{Run Time} = \frac{1200\text{ mAh}}{445\text{ mA}} \times 0.85\ (\text{usable discharge factor}) \approx 2.3\text{ hours continuous operation}$$
  *(With 5-second telemetry reporting intervals and display timeout, estimated autonomy extends to $\approx 3.5 - 4.0\text{ hours}$. Autonomy remains **provisional pending physical discharge logging on assembled prototype**).*

---

## 3. Firmware Flashing & Provisioning

### 3.1 Step 1: Provision Private Credentials
1. Copy [credentials.example.h](file:///d:/NAADYANTRA/credentials.example.h) to `credentials.h` in the repository root:
   ```bash
   cp credentials.example.h credentials.h
   ```
2. Open `credentials.h` and configure:
   ```cpp
   #define WIFI_SSID        "Your_Workshop_SSID"
   #define WIFI_PASSWORD    "Your_Workshop_Password"
   #define BACKEND_URL      "https://naadyantra.onrender.com"
   #define DEVICE_KEY       "prov_sec_xxxxxxxxxxxx" // From Web Dashboard device registration
   #define DEVICE_ID        "SIH-DEV-01"
   #define TRAINEE_ID       "TR-001"
   ```
   *(Note: `credentials.h` is excluded in `.gitignore` to prevent credential exposure).*

### 3.2 Step 2: Install Arduino IDE Libraries
- **ArduinoJson** (v6.21.x or v7.x) by Benoit Blanchon
- **Adafruit SSD1306** & **Adafruit GFX**
- **Adafruit MLX90614** (if thermal pyrometer is populated)

### 3.3 Step 3: Flash to Target Microcontroller
1. Connect ESP32 board via USB-C.
2. Select Board: `Tools` $\to$ `Board` $\to$ `esp32` $\to$ `ESP32S3 Dev Module` (or `ESP32 Dev Module`).
3. Set CPU Frequency: `240MHz (WiFi)`.
4. Set Flash Size: `8MB` (or `4MB` for classic).
5. Set PSRAM: `OPI PSRAM` (for ESP32-S3) or `Disabled`.
6. Click **Upload**.

---

## 4. Bench Verification & Serial Monitor Flow

Open the Serial Monitor at **115200 baud**. Expected operational boot sequence:

```text
========================================
 NAADYANTRA Acoustic Diagnostic Rig
 Firmware Version : 1.1.0
 Board Target     : ESP32-S3 (Xtensa Dual-Core 240MHz)
========================================
[init] I2C bus initialized @ 100kHz
[init] SSD1306 OLED display detected at 0x3C
[init] FreeRTOS ring-buffer allocated: 8192 int16 samples
[init] Telemetry log queue allocated: 64 entries
[wifi] Connecting to SSID: Workshop_WiFi_5G ...
[wifi] Connected! IP: 192.168.1.142, RSSI: -54 dBm
[tls] GlobalSign Root CA loaded. TLS verification ACTIVE.
[sntp] Synchronizing epoch time via pool.ntp.org ...
[sntp] System time synchronized: 2026-10-17 12:30:15 UTC
[cal] Calibrating 10-second acoustic baseline...
[cal] Baseline established: RMS_floor = 384.2 counts
[main] Standby. Press BOOT button to begin diagnostic session.
```

---

## 5. Common Bench Failure Modes & Troubleshooting

| Symptom | Root Cause | Verification & Remediation |
| :--- | :--- | :--- |
| **Continuous Brownout Reset Loop** | ESP32 Wi-Fi peak current draws ($> 350\text{ mA}$) sagging low-quality USB power. | Power board from dedicated 5V 2A wall adapter or add $100\mu\text{F}$ low-ESR electrolytic capacitor across 3.3V and GND rails. |
| **Acoustic RMS Clamped at 0 or 4095** | Broken piezo lead or missing 1.65V DC virtual ground bias. | Measure voltage at op-amp non-inverting input with DMM. Must read $1.65 \pm 0.1\text{V}$. Verify coupling capacitor. |
| **I2C Bus Hangs on Boot** | SSD1306 display or MLX90614 missing pull-up resistors or faulty address. | Run an I2C scanner sketch to confirm devices respond at `0x3C` (OLED) and `0x5A` (Pyrometer). Check SDA/SCL pull-ups. |
| **HTTP Ingestion Returns 401 Unauthorized** | Device key mismatch between `credentials.h` and database `device_credentials`. | Log into Web Dashboard (`/devices`), select the device, click **Rotate Device Key**, copy the new key into `credentials.h`, and reflash. |
| **Server Rejects SSL Handshake** | Expired or incorrect CA certificate in firmware progmem. | Ensure `RENDER_ROOT_CA` in `leak_detector.ino` contains the active GlobalSign ECC Root CA - R4 / GTS Root R1 certificate chain. |
