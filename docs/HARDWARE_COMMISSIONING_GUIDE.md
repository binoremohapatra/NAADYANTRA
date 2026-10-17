# NAADYANTRA — Hardware Commissioning & Bench Testing Guide
## Firmware Flashing, Pinout Verification & Sensor Integration (SIH26244)

> [!IMPORTANT]
> **Core Compatibility**: Supports both Arduino-ESP32 Core **2.x** and Core **3.x** (`ESP_ARDUINO_VERSION_MAJOR`).  
> Validated with PlatformIO on both Classic ESP32 (`esp32dev`) and ESP32-S3 (`esp32-s3-devkitc-1`).

---

## 1. Board-Specific Pinout Configuration

The firmware [leak_detector.ino](file:///d:/NAADYANTRA/leak_detector.ino) automatically maps pins at compile time based on the active board target:

| Function | Signal Name | ESP32-S3 Pin (Default) | Classic ESP32 Pin | Electrical Notes |
| :--- | :--- | :---: | :---: | :--- |
| **Contact Piezo** | `PIN_PIEZO` | **GPIO 4** (ADC1_CH3) | **GPIO 34** (ADC1_CH6) | AC-coupled via 0.1µF into MCP6002 RRIO op-amp with 1.65V virtual ground bias. |
| **Reference Mic** | `PIN_REFERENCE` | **GPIO 7** (ADC1_CH6) | **GPIO 33** (ADC1_CH5) | Ambient noise cancellation channel (optional). |
| **Combustible Gas** | `PIN_GAS` | **GPIO 5** (ADC1_CH4) | **GPIO 35** (ADC1_CH7) | **CRITICAL**: MQ module powered at 5V. 15kΩ / 10kΩ 1% divider scales signal to $\le 2.13\text{V}$. |
| **Moisture Sense** | `PIN_MOISTURE` | **GPIO 6** (ADC1_CH5) | **GPIO 32** (ADC1_CH4) | Conduction probe sense node with 100kΩ pull-down. |
| **Moisture Power** | `PIN_MOIST_PWR` | **GPIO 10** | **GPIO 23** | Gated excitation pin; driven HIGH for 50ms only during read to prevent galvanic erosion. |
| **Battery Monitor** | `PIN_BATTERY` | **GPIO 2** (ADC1_CH1) | **GPIO 39** (ADC1_CH3 / SENSOR_VN) | 100kΩ / 100kΩ 1% divider on 1S LiPo rail (2.0x scaling factor, max 2.15V at 4.3V). |
| **Boost / Heater EN**| `PIN_BOOST_EN` | **GPIO 11** | **GPIO 19** | Load disconnect control: asserts HIGH to power MT3608 + MQ-2 heater; deasserts to cut to 0mA in sleep. |
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

#### Anti-Aliasing Sallen-Key Low-Pass Filter Response & Reconciled Trade-Offs
The firmware samples the acoustic channel at **$f_s = 4000\text{ Hz}$** ($4\text{ kHz}$), setting the **Nyquist folding frequency at $f_N = 2000\text{ Hz}$**. Because raw piezoceramic discs and wideband pre-amplifiers maintain acoustic sensitivity up to $\approx 30\text{ kHz}$, an analog anti-aliasing filter is required prior to the ADC.

In the dual **MCP6002** circuit:
- **Stage 1 (U1A)**: AC-coupled non-inverting pre-amplifier ($A_{v1} \approx 23\times$, $27.2\text{ dB}$) biased at $V_\text{BIAS} = 1.65\text{ V}$.
- **Stage 2 (U1B)**: Active 2nd-order Sallen-Key Low-Pass Butterworth Filter ($R_1 = R_2 = 10\text{k}\Omega\ 1\%$, $C_1 = 15\text{nF}$, $C_2 = 6.8\text{nF}$).

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

#### Mathematical Transfer Function & Frequency Response Verification
The 2nd-order Sallen-Key low-pass transfer function is:
$$H(s) = \frac{\omega_0^2}{s^2 + \frac{\omega_0}{Q}s + \omega_0^2}, \quad \omega_0 = \frac{1}{\sqrt{R_1 R_2 C_1 C_2}}, \quad Q = \frac{\sqrt{R_1 R_2 C_1 C_2}}{C_2(R_1 + R_2)} = \frac{\sqrt{C_1/C_2}}{2}$$

With $R_1 = R_2 = 10\text{k}\Omega$, $C_1 = 15\text{nF}$, $C_2 = 6.8\text{nF}$:
- **Corner Frequency ($f_0$)**: $f_0 = \frac{1}{2\pi \times 10^4 \times \sqrt{15\times 10^{-9} \times 6.8\times 10^{-9}}} = 1575.9\text{ Hz} \approx 1.58\text{ kHz}$
- **Damping Factor ($Q$)**: $Q = \frac{\sqrt{15 / 6.8}}{2} = 0.7425$ (near-Butterworth maximally flat passband, $Q_\text{Butterworth} = 0.7071$)
- **Magnitude Equation**:
  $$|H(j f)|_{\text{dB}} = -10 \log_{10} \left[ \left(1 - \left(\frac{f}{f_0}\right)^2\right)^2 + \frac{1}{Q^2}\left(\frac{f}{f_0}\right)^2 \right]$$

#### Calculated Filter Response Spectrum
| Frequency ($f$) | Ratio ($f / f_0$) | Attenuation (dB) | Signal Integrity & Anti-Aliasing Interpretation |
| :---: | :---: | :---: | :--- |
| **$300\text{ Hz}$** | $0.190$ | **$-0.01\text{ dB}$** | Flat passband; lower limit of pipe leak acoustic hiss. |
| **$500\text{ Hz}$** | $0.317$ | **$-0.04\text{ dB}$** | Flat passband; negligible attenuation. |
| **$1000\text{ Hz}$** | $0.635$ | **$-0.36\text{ dB}$** | Flat passband; core fluid turbulence frequency band. |
| **$1150\text{ Hz}$** | $0.730$ | **$-0.75\text{ dB}$** | Upper limit of $\pm 0.8\text{ dB}$ flatness region. |
| **$1500\text{ Hz}$** | $0.952$ | **$-2.18\text{ dB}$** | Transition knee (attenuated by $\approx 2.2\text{ dB}$, NOT flat). |
| **$1576\text{ Hz}$** ($f_0$) | $1.000$ | **$-2.87\text{ dB}$** | Filter cutoff frequency ($-3\text{ dB}$ nominal). |
| **$2000\text{ Hz}$** ($f_N$) | $1.269$ | **$-5.18\text{ dB}$** | **Nyquist folding frequency**: modest attenuation of $-5.2\text{ dB}$. |
| **$3000\text{ Hz}$** | $1.904$ | **$-11.45\text{ dB}$** | Out-of-band noise aliasing into $1000\text{ Hz}$ is suppressed by $\approx 11.5\text{ dB}$. |
| **$4000\text{ Hz}$** ($f_s$) | $2.538$ | **$-16.16\text{ dB}$** | Sampling frequency rejection. |
| **$8000\text{ Hz}$** | $5.077$ | **$-28.21\text{ dB}$** | Ultrasonic suppression. |
| **$16000\text{ Hz}$** | $10.15$ | **$-40.23\text{ dB}$** | High-frequency electromagnetic / switching rejection. |

#### Architectural Filter Trade-Off & Future Roadmap
- **Design Trade-Off**: A 2nd-order single op-amp filter provides $-5.2\text{ dB}$ attenuation at $f_N = 2000\text{ Hz}$. This is sufficient to damp ambient acoustics, but acoustic noise between $2.0\text{ kHz}$ and $3.0\text{ kHz}$ will experience partial aliasing back into $1.0 - 2.0\text{ kHz}$ with $5 - 11\text{ dB}$ attenuation.
- **Physical Verification Requirement**: Acoustic frequency response and alias rejection must be physically measured with an arbitrary waveform generator and swept sine input before finalizing PCBA tape-out.
- **Revision 2.0 Enhancement Path**: If physical bench testing reveals excessive in-band aliasing in high-noise workshops, the firmware sampling rate will be doubled to $f_s = 8000\text{ Hz}$ ($f_N = 4000\text{ Hz}$, where analog rejection is $-16.2\text{ dB}$) with a software 4th-order IIR decimation filter to $4\text{ kHz}$.

---

### 2.2 MQ Combustible Gas Sensor Integration & ADC Calibration

> [!IMPORTANT]
> **Conditioning & Measurement Honesty**:
> 1. **Initial Heater Conditioning**: Manufacturer documentation (Winsen MQ-2 / MQ-135) specifies a continuous **48-hour burn-in period** at rated heater voltage ($V_H = 5.0\text{V} \pm 0.1\text{V}$) for chemical stabilization of the $\text{SnO}_2$ sensing layer.
> 2. **Session Warm-Up**: During bench deployment, a **2 to 5 minute thermal warm-up** is required after power-on before recording baseline resistance ($R_0$). The firmware enforces a minimum 120-second stabilization guard (`GAS_WARMUP_S = 120`).
> 3. **Indicative Status**: Gas readings are treated strictly as **indicative relative sensor delta ($\Delta\text{ADC}$) and resistance ratio ($R_s/R_0$)**, NOT certified absolute ppm or %LEL.

#### ADC Calibration & Interface Verification (ESP32-S3 vs. Classic ESP32)
Per [Espressif's Official ADC Documentation](https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/api-reference/peripherals/adc/index.html) and [ADC Calibration Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/peripherals/adc/adc_calibration.html):
- **Classic ESP32 ADC1**: With $11\text{ dB}$ attenuation (`ADC_ATTEN_DB_11`), the recommended linear range is **$150\text{ mV}$ to $2450\text{ mV}$ ($2.45\text{V}$)**. Above $2.45\text{V}$, saturation non-linearity is severe. Factory calibration is read via `esp_adc_cal_characterize()` using eFuse Two Point or Vref values.
- **ESP32-S3 ADC1**: Redesigned SAR ADC with Curve Fitting calibration (`adc_cali_create_scheme_curve_fitting()`). With $12\text{ dB}$ attenuation (`ADC_ATTEN_DB_12`), the recommended calibrated range is **$150\text{ mV}$ to $3100\text{ mV}$ ($3.10\text{V}$)**.
- **Absolute Maximum GPIO Rating**: $V_{DD} + 0.3\text{V} = 3.6\text{V}$. Direct exposure to $5.0\text{V}$ will permanently damage the silicon.

#### Verified Resistor & Voltage Margin Calculation ($15\text{k}\Omega / 10\text{k}\Omega\ 1\%$)
- MQ-2 Supply Rail ($V_{CC}$): $5.0\text{V} \pm 5\%$ tolerance $\implies V_{in,\max} = 5.25\text{V}$.
- Selected Resistors: $R_1 (\text{top}) = 15\text{k}\Omega\ 1\%$, $R_2 (\text{bottom}) = 10\text{k}\Omega\ 1\%$.
- Nominal Divider Ratio & Scaling Factor:
  $$K_{\text{nom}} = \frac{10\text{k}\Omega}{15\text{k}\Omega + 10\text{k}\Omega} = 0.4000 \implies \text{Multiplier Factor } = \frac{1}{0.4000} = 2.50\times$$
  $$V_{\text{ADC},\text{nom}} = 5.0\text{V} \times 0.4000 = 2.000\text{V}$$
- Worst-Case Resistor Tolerance ($\pm 1\%$):
  - $R_1 (\text{top}) = 15\text{k}\Omega \times 0.99 = 14.85\text{k}\Omega$
  - $R_2 (\text{bottom}) = 10\text{k}\Omega \times 1.01 = 10.10\text{k}\Omega$
  - Worst-Case Ratio:
    $$K_{\max} = \frac{10.10\text{k}\Omega}{14.85\text{k}\Omega + 10.10\text{k}\Omega} = \frac{10.10}{24.95} \approx 0.4048$$
- **Maximum ADC Input Voltage Under Worst-Case Tolerance**:
  $$V_{\text{ADC},\max} = 5.25\text{V} \times 0.4048 = 2.125\text{V} \approx 2.13\text{V}$$
- **Verification of Margins**:
  1. Margin to Classic ESP32 Linear Limit ($2.450\text{V}$): **$+325\text{ mV}$ (13.3% margin under worst-case tolerance)**.
  2. Margin to ESP32-S3 Linear Limit ($3.100\text{V}$): **$+975\text{ mV}$ (31.5% margin)**.
  3. Margin to Absolute Maximum Pin Rating ($3.600\text{V}$): **$+1.475\text{V}$ (41.0% margin)**.
- **Implementation Rule**: Firmware scaling constant is `#define GAS_DIV_FACTOR 2.5f`. Firmware voltage conversion must use ESP-IDF eFuse calibration APIs (`esp_adc_cal_characterize()` on Classic ESP32, `adc_cali_raw_to_voltage()` on ESP32-S3) rather than naive straight-line math (`raw * 3.3 / 4095.0`).
- **Physical Verification Requirement**: Bench verification with a precision DMM must confirm that under clean air and hydrocarbon exposure, the junction voltage never exceeds $2.13\text{V}$.

```text
MQ-2 Analog Out (0 - 5.25V) ───[15k 1%]───┬───► PIN_GAS (ADC1, 0 - 2.13V Max)
                                          │
                                        [10k 1%] ──┬── [10nF Ceramic] to GND
                                          │        │
                                         GND    [BAT54S Dual Clamp]
                                                   ├── to +3.3V Rail
                                                   └── to GND Rail
```

---

### 2.3 Power System Architecture, TP4056 Topology & Reconciled Energy Budget

#### Battery Rail, LDO Dropout & Regulated Supply Architecture
- **LDO Dropout Analysis**:
  - The AP2112K specifies a typical dropout of $V_{\text{drop}} \approx 250\text{ mV}$ at full $600\text{ mA}$ load, and approximately $125 - 150\text{ mV}$ at the system's $150 - 200\text{ mA}$ average operating current.
  - The ME6211 specifies a dropout of $V_{\text{drop}} \approx 100 - 140\text{ mV}$ at $100 - 200\text{ mA}$.
  - When feeding a 3.3V LDO directly from the 1S LiPo rail ($3.0\text{V} - 4.2\text{V}$ nominal $3.7\text{V}$), as the battery discharges below $3.45\text{V}$ ($3.3\text{V} + 0.15\text{V}$ dropout), the LDO exits regulation and the 3.3V rail begins to sag. If the cell reaches $3.0\text{V}$, the 3.3V rail drops to $\approx 2.85 - 2.90\text{V}$, which threatens brownout detector resets during Wi-Fi transmission bursts (peak currents up to $350\text{ mA}$).
- **Recommended Supply Architecture (Boost-Derived MCU Supply)**:
  - To guarantee a rock-solid 3.3V rail across the entire discharge curve, feed the MT3608 5.0V regulated boost output directly into the development board's **5V / VIN pin**.
  - Because the MT3608 boost converter operates down to $2.0\text{V}$ input (well below the battery cutoff), the 5.0V rail remains solidly at 5.0V until the cell is exhausted. The onboard development board LDO receives a constant 5.0V ($1.7\text{V}$ of headroom), completely isolating the 3.3V MCU and analog rail from battery voltage sag.
- **Defensible Low-Battery Cutoff Thresholds**:
  For designs monitoring the battery rail via an ADC voltage divider:
  - **Soft Warning Cutoff ($3.55\text{V}$)**: Triggers an OLED low-battery warning icon and intermittent audio cue (10–15% capacity remaining).
  - **Hard Shutdown Cutoff ($3.45\text{V}$)**: Initiates ESP32 deep sleep ($< 20\mu\text{A}$), safely ceasing telemetry and Wi-Fi before LDO dropout can cause brownout instability, and protecting the LiPo cell well above the DW01A protection IC emergency cutoff ($2.4\text{V}$).
- **USB VBUS vs. External Supply Conflict Mitigation**:
  - Development boards (NodeMCU-32S, ESP32-S3-DevKitC) feature an onboard Schottky diode (e.g., MBR0520) between USB VBUS (5V) and the 5V / VIN pin.
  - If feeding external 5.0V from the MT3608 boost converter into the 5V pin while simultaneously plugging in a PC USB cable for flashing/debugging, the two 5V sources can conflict, resulting in back-feeding into the USB port or circulating ground currents.
  - **Safety Directive**: **Always switch the main battery SPST switch OFF** before plugging in the USB-C cable for firmware flashing or serial debugging. For permanent dual-feed safety, a series Schottky diode (e.g., SS14 or 1N5819) or ideal diode OR-ing circuit must isolate the MT3608 5V output from the MCU VIN pin.

#### Corrected Hardware Power Topology Diagram
The TP4056 board with integrated protection (DW01A + 8205A) separates battery charging from load draw. The MT3608 is an **asynchronous step-up boost converter** with an external Schottky rectifier diode:

```text
[EXTERNAL 5V USB CHARGER]
       │
   (USB-C Port)
       │
     [IN+] ─── TP4056 Li-Ion Charger IC ─── [B+] ──────┐
     [IN-] ─── (1000mA CC/CV Charging)  ─── [B-] ──┐   │
                                                   │   │
                                           [1S Li-Po Cell 3.7V 1200mAh]
                                           (Bare Lithium Polymer Battery)
                                                   │   │
     [OUT+] ◄──────────────────────────────────────┴───┘ (Positive Terminal)
     [OUT-] ◄── [8205A Dual N-MOSFET] ◄── [DW01A Protection IC (Overcharge/Discharge/Overcurrent)]
       │
       ▼
[MAIN SPST POWER SWITCH]
       │
       ├────────────────────────────────────────────────┐
       │ (Battery Rail: 3.45V - 4.2V, 3.7V Nom)         │
       ▼                                                ▼
[MT3608 Asynchronous Step-Up Converter]          [Optional External 3.3V LDO]
(SS34 Schottky, ~85% Eff, 2.0V-24V in)          (AP2112K / ME6211, ~89% Eff)
       │                                                │
       ▼                                                ▼
  +5.0V Regulated Rail                            +3.3V Regulated Rail
  ├── MQ-2 Heater (RH ~31Ω, ~161mA, 805mW)        ├── MCP6002 Op-Amp (0.6mA)
  ├── Piezoceramic Buzzer (~5mA time-avg)         ├── SSD1306 OLED (15mA)
  ├── 100µF Low-ESR Decoupling Capacitor          ├── MLX90614 Pyrometer (1.5mA, if fitted)
  └── [Schottky Isolation SS14]                   ├── Diagnostic LEDs (5mA)
             │                                    └── 47µF Tantalum Decoupling
             ▼
      ESP32 VIN / 5V Pin ──► [Onboard LDO] ──► ESP32 Core & Wi-Fi (3.3V Rail)
```

#### Critical TP4056 Simultaneous Charge-and-Load Limitation
> [!WARNING]
> **No Dynamic Power-Path Management in TP4056**:  
> The basic TP4056 module does not contain an ideal diode OR-ing or power-path circuit. If the device is operated while USB is plugged in, the system load current ($\approx 445\text{ mA}$) is drawn directly from the charger output in parallel with the battery:
> 1. The effective charging current into the cell is reduced ($1000\text{ mA} - 445\text{ mA} \approx 555\text{ mA}$).
> 2. Because the system load continuously draws current, the TP4056 may never detect the $C/10$ charge termination threshold ($100\text{ mA}$), preventing the charge cycle from terminating properly.
> 3. **Operational Directive**: The prototype wearable must be switched **OFF** via the SPST power switch during battery charging. For Revision 2.0, a dedicated power-path IC (e.g., TI BQ24075 or Microchip MCP73871) will be integrated.

#### Reconciled Component Energy Budget, Transients & Autonomy
Recalculated with converter losses, haptic motor inrush transients, and realistic operating duty cycle:

| Subsystem Component | Operating Rail | Operating Current | Electrical Power | Battery Current @ 3.7V Nom | Power from Battery |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **MQ-2 Gas Heater (Continuous)** | $5.0\text{V}$ | $161\text{ mA}$ ($31\Omega$) | $805\text{ mW}$ | $256.0\text{ mA}$ (via boost $\eta=85\%$) | $947.1\text{ mW}$ |
| **Piezoceramic Buzzer (Time-Avg)** | $5.0\text{V}$ | $5\text{ mA}$ | $25\text{ mW}$ | $7.9\text{ mA}$ (via boost $\eta=85\%$) | $29.4\text{ mW}$ |
| **ESP32-S3 Core & Active Wi-Fi** | $3.3\text{V}$ | $140\text{ mA}$ avg (350mA burst) | $462\text{ mW}$ | $140.0\text{ mA}$ (via LDO) | $518.0\text{ mW}$ |
| **SSD1306 OLED Display (40% lit)** | $3.3\text{V}$ | $15\text{ mA}$ | $49.5\text{ mW}$ | $15.0\text{ mA}$ (via LDO) | $55.5\text{ mW}$ |
| **Haptic Motor (1027 ERM, 10% duty)**| $3.3\text{V}$ | $7\text{ mA}$ avg ($70\text{ mA}$ pulse) | $23.1\text{ mW}$ | $7.0\text{ mA}$ (via LDO) | $25.9\text{ mW}$ |
| **Dual MCP6002 Op-Amp** | $3.3\text{V}$ | $0.6\text{ mA}$ | $2.0\text{ mW}$ | $0.6\text{ mA}$ (via LDO) | $2.2\text{ mW}$ |
| **MLX90614 Pyrometer (Optional)** | $3.3\text{V}$ | $1.5\text{ mA}$ | $5.0\text{ mW}$ | $1.5\text{ mA}$ (via LDO) | $5.6\text{ mW}$ |
| **Diagnostic LEDs (1 active)** | $3.3\text{V}$ | $5\text{ mA}$ | $16.5\text{ mW}$ | $5.0\text{ mA}$ (via LDO) | $18.5\text{ mW}$ |
| **LDO Quiescent & Leakage** | $3.3\text{V}$ | $0.4\text{ mA}$ | $1.3\text{ mW}$ | $0.4\text{ mA}$ (via LDO) | $1.5\text{ mW}$ |
| **Total Reconciled System Draw** | — | — | — | **$433.4\text{ mA}$ (Nominal)**<br>**$455.0\text{ mA}$ (Peak-Avg)** | **$1.60\text{ W}$ (Nominal)**<br>**$1.68\text{ W}$ (Peak-Avg)** |

- **Dynamic Startup & Transmission Transients**:
  - Wi-Fi TX burst ($350\text{ mA}$) combined with haptic motor inrush ($70\text{ mA}$), buzzer assertion ($20\text{ mA}$), and MQ-2 heater ($161\text{ mA}$) can produce instantaneous peak battery currents exceeding **$680\text{ mA}$**.
  - A $100\mu\text{F}$ low-ESR decoupling capacitor on the 5.0V rail and $47\mu\text{F}$ on the 3.3V rail are essential to absorb these inductive transients.
- **Provisional Battery Autonomy Calculation**:
  - Cell Capacity: $1200\text{ mAh}$ nominal ($4.44\text{ Wh}$ @ $3.7\text{V}$).
  - Usable Capacity Factor (accounting for $3.45\text{V}$ low-battery cutoff & cell ESR): $85\% \implies 1020\text{ mAh}$ ($3.77\text{ Wh}$).
  - **Provisional Continuous Runtime**:
    $$\text{Runtime} = \frac{1020\text{ mAh}}{455\text{ mA}} \approx 2.24\text{ hours} \approx 2\text{ hours } 14\text{ minutes}$$
  - *(With 5-second periodic telemetry duty-cycling and OLED sleep mode, estimated battery life extends to $\approx 3.5\text{ hours}$. All runtime figures remain strictly **PROVISIONAL PENDING MEASURED BENCHMARK ON ASSEMBLED HARDWARE**).*

---

### 2.4 Sensor Modality Inventory & Firmware Implementation Matrix

To resolve discrepancies across documentation, schematics, and codebases, the status of every sensor modality is explicitly defined below:

| Sensor Modality | Part / Sensor Spec | Hardware Interface | Firmware Flag & Pin (`leak_detector.ino`) | Implementation Status | Telemetry Schema Field | Automated Test Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Contact Piezo** | 27mm Brass Piezo Disc | Analog ADC1 (via MCP6002 AFE + LPF) | Active (Always On)<br>S3: GPIO 4 / Classic: GPIO 34 | **IMPLEMENTED (CORE)** | `rms`, `crest_factor`, `leak_status` | Tested (`test_firmware_logic.py`) |
| **Combustible Gas** | MQ-2 Gas Module | Analog ADC1 (via 15k/10k divider) | `HAS_GAS_SENSOR = 1`<br>S3: GPIO 5 / Classic: GPIO 35 | **IMPLEMENTED (CORE)** | `gas_delta`, `gas_status` | Tested (`test_firmware_logic.py`) |
| **Moisture Probe** | Interleaved PCB Probe | Analog ADC1 + Gated Dig Out | `HAS_MOISTURE_SENSOR = 1`<br>Sense: S3 GPIO 6 / Classic GPIO 32<br>Gate: S3 GPIO 10 / Classic GPIO 23 | **IMPLEMENTED (CORE)** | `moisture_detected` (bool) | Tested (`test_firmware_logic.py`) |
| **Reference Mic** | MAX4466 / MAX9814 | Analog ADC1 (Single-ended) | `USE_REFERENCE_SENSOR = 0`<br>S3: GPIO 7 / Classic: GPIO 39 (VN) | **OPTIONAL (DISABLED)** | Diff RMS (stub) | Tested with flag disabled |
| **IR Pyrometer** | MLX90614-ESF-BAA | I2C Bus (`0x5A` @ 100kHz) | `HAS_HEAT_SENSOR = 0`<br>SDA: S3 GPIO 8 / Classic GPIO 21<br>SCL: S3 GPIO 9 / Classic GPIO 22 | **OPTIONAL (DISABLED)** | `temperature_c` (defaults 0.0) | Tested disabled state |
| **UV Radiometer** | GUVA-S12SD | Analog ADC1 (Single-ended) | `HAS_UV_SENSOR = 0`<br>Classic: GPIO 36 (VP) / S3: GPIO 1 | **OPTIONAL (DISABLED)** | `uv_delta` (defaults 0) | Tested disabled state |
| **Distance / ToF** | VL53L0X | I2C Bus (`0x29` @ 100kHz) | `HAS_DISTANCE_SENSOR = 0`<br>SDA: S3 GPIO 8 / Classic GPIO 21<br>SCL: S3 GPIO 9 / Classic GPIO 22 | **IMPLEMENTED CODE-LEVEL OPTIONAL (CONFIG-FLAGGED / DISABLED)** | `dist` / `distance_mm` (int, defaults -1) | Tested disabled state & UI parsing |

> [!CAUTION]
> **Safety & Capability Declarations**:
> 1. **No Automatic Spatial Localization**: A single contact piezoelectric pickup with an RMS threshold measures local vibration amplitude at the point of physical contact. It **does not prove or perform automatic spatial leak localization or beamforming**. Leak localization is an instructional, **trainee-executed comparative multi-point procedure** (the apprentice tests successive fittings and identifies the maximum sustained acoustic differential).
> 2. **Proximity & UV Alarms Not Active**: Because the VL53L0X and GUVA-S12SD are disabled in config (`HAS_DISTANCE_SENSOR = 0`, `HAS_UV_SENSOR = 0`), the wearable **does not provide active distance breach or UV burn protection** in this default configuration. Proximity and UV alerts remain inactive unless hardware is physically populated and config flags are enabled.
> 3. **Educational Non-Life-Safety Boundary**: The MQ-2 sensor module is uncalibrated against certified gas standards. **It must never be used to authorize confined-space entry or certify atmospheric clearance**. In industrial environments, confined-space permits legally require certified, multi-gas monitors (O2, LEL, CO, H2S) calibrated by qualified safety personnel.

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
