# NAADYANTRA — Hardware Bill of Materials (BOM) & Cost Documentation
## Low-Cost Diagnostic Sensing Wearable for Skilled Trades (SIH26244)

> [!NOTE]
> **Pricing Baseline**: October 2026 indicative procurement rates based on standard Indian electronics distributors (Robu.in, ElectronicsComp, Component's Bazaar) and international volume distributors (LCSC, Mouser).  
> **Hardware Status**: Document reviewed & schematic audited; physical assembly and bench verification pending component procurement.

---

## 1. Itemized Component Breakdown

| Item # | Subsystem | Component Description | Selected Part / Spec | Qty | Electrical Interface | Operating Voltage | Unit Cost (Est. INR) | Subtotal (INR) | Engineering Status |
| :---: | :--- | :--- | :--- | :---: | :--- | :---: | :---: | :---: | :---: |
| **01** | Compute & Radio | ESP32-S3 DevKitC-1 (or ESP32-WROOM-32) | ESP32-S3-WROOM-1-N8R2 (Dual-Core 240MHz, 8MB Flash, 2MB PSRAM, Wi-Fi 4 + BLE 5) | 1 | Native USB-C / UART / GPIO | 3.3V (5V VBUS in) | ₹480 | ₹480 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **02** | Acoustic Sensing | Brass Contact Piezoelectric Sensor | 27mm Brass Acoustic Disc Element with acoustic wave coupling cone | 1 | Analog Single-Ended (to Op-Amp) | Passive (piezo-generated) | ₹35 | ₹35 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **03** | Analog Front-End | Dual Rail-to-Rail Operational Amplifier | Microchip MCP6002-E/P (Dual 1.8V-6V RRIO, 1MHz GBWP, 1pA bias; Stage 1: Pre-amp, Stage 2: 2nd-order Sallen-Key LPF fc~1.6kHz; Alt: TI TLV2372) | 1 | ADC1 (ESP32-S3 GPIO 4 / ESP32 GPIO 34) | 3.3V Single Supply (1.65V Virtual Ground) | ₹38 | ₹38 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **04** | Environmental | Combustible Gas Sensor Module | MQ-2 Gas Module with 5.0V heater and 12k/10k 1% divider (signal $\le 2.39\text{V}$ into linear ADC range) + BAT54S clamp | 1 | ADC1 (ESP32-S3 GPIO 5 / ESP32 GPIO 35) | 5.0V Heater, 2.39V Max Signal | ₹140 | ₹140 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **05** | Surface Moisture | Dual-Prong Liquid Conduction Probe | Gated Interleaved PCB Trace Probe with GPIO excitation switch & 100kΩ pull-down | 1 | ADC1 (ESP32-S3 GPIO 6 / ESP32 GPIO 32) + Gating GPIO 10 (S3) / 23 (Classic) | 3.3V Pulsed (50ms excitation) | ₹60 | ₹60 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **06** | Thermal Safety | Contactless Infrared Pyrometer | MLX90614-ESF-BAA (or BCI) Factory Calibrated Pyrometer ($0.5^\circ\text{C}$ accuracy) | 1 | I2C (SDA: GPIO 8, SCL: GPIO 9 @ 100kHz) | 3.3V | ₹420 | ₹420 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **07** | Visual Telemetry | 0.96" Monochrome Display | SSD1306 128x64 OLED Display Module | 1 | I2C (Shared bus with Pyrometer, addr `0x3C`) | 3.3V | ₹165 | ₹165 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **08** | Actuation / Alarm| Haptic Vibration Motor & Piezo Buzzer | 1027 ERM Coin Vibration Motor + 5V Active Buzzer driven via 2N2222 NPN Transistors | 1 pair | GPIO 15 (S3) / 25 (Classic), GPIO 16 (S3) / 26 (Classic) | 3.3V - 5V | ₹55 | ₹55 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **09** | Status Indicators| Tri-Color Diagnostic LEDs | 3mm Industrial LEDs (Green, Amber, Red) with 330Ω ballast resistors | 3 | GPIO 17, 18, 21 (S3) / GPIO 27, 14, 13 (Classic) | 3.3V | ₹15 | ₹15 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **10** | Power System | Li-Ion Battery & Power Management | 3.7V 1200mAh LiPo + DW01A/8205A PCM + TP4056 Type-C Charger + MT3608 Asynchronous Step-Up Boost (heater) + AP2112K 3.3V LDO | 1 set | Battery JST-PH 2.0mm connector | 3.7V nom (4.2V max) | ₹290 | ₹290 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **11** | Enclosure | Ergonomic Wearable Forearm / Belt Case | 3D Printed PETG (Impact-resistant, chemical-tolerant) with acoustic isolation gasket | 1 | Mechanical wearable | N/A | ₹180 | ₹180 | CAD REVIEWED / FABRICATION PENDING |
| **12** | Fasteners & Wiring| Hookup Wire, Connectors, Diodes & Strap | 26 AWG silicone wire, JST headers, BAT54S dual Schottky clamps, 12k/10k resistors, forearm strap | 1 set | Mechanical / Electrical | N/A | ₹95 | ₹95 | DESIGN PROPOSED / PHYSICAL VALIDATION PENDING |
| **13** | Acoustic (Optional)| Ambient Noise Reference Microphone | MAX4466 (or MAX9814) Electret Mic Module with adjustable gain trimmer (differential subtraction) | 1 | ADC1 (ESP32-S3 GPIO 7 / Classic GPIO 39) | 3.3V | ₹120 | *(₹120)* | OPTIONAL HARDWARE ADDITION (FIRMWARE HOOK POPULATED) |
| **14** | Optical (Optional) | Analog UV Radiometer | GUVA-S12SD UV photodiode module with analog output (200nm - 370nm band) | 1 | ADC1 (Classic GPIO 36 / S3 GPIO 1) | 3.3V | ₹145 | *(₹145)* | OPTIONAL HARDWARE ADDITION (DISABLED IN V1.1.0 CONFIG) |
| **15** | Ranging (Unimpl.)  | Time-of-Flight Distance Sensor | VL53L0X Laser Ranging Sensor Module (I2C addr `0x29`) | 1 | I2C (Shared Bus) | 3.3V | ₹210 | *(₹210)* | UNIMPLEMENTED IN ARDUINO V1.1.0 (ESP-IDF EXPERIMENTAL ONLY) |

---

## 2. Cost Summary & Batch Projections

### 2.1 Prototype Bill of Materials (Single Unit)
- **Core Functional Unit Subtotal (Items 01–05, 07–12)**: **₹1,553 INR (~$18.70 USD)**
- **With Fitted MLX90614 Contactless IR Pyrometer (Item 06)**: **₹1,973 INR (~$23.75 USD)**
- **Prototyping Contingency & Shipping (15%)**: **₹296 INR**
- **Estimated Single Prototype Total (with IR Pyrometer)**: **₹2,269 INR (~$27.30 USD)**
- *(Optional Reference Mic + UV sensor bundle adds ₹265 INR when fully populated).*

*(Prices based on October 2026 distributor listings from Robu.in, ElectronicsComp, and Mouser India. Exact procurement invoices will supersede these estimates once purchase orders are issued).*

### 2.2 Volume Production Estimate (100-Unit Batch)
With bulk purchasing of passive components, reel-packaged semiconductors, and custom SMT fabrication:
- SMT PCBA with ESP32-S3 module integrated on board: ₹580 INR
- Sensor bundle (Piezo disc + MQ-2 + MLX90614 + OLED): ₹520 INR
- Injection-molded ABS enclosure & wearable strap: ₹110 INR
- Battery & power management: ₹180 INR
- Assembly, calibration testing & packaging: ₹90 INR
- **Projected Unit Cost @ 100 Units**: **₹1,480 INR (~$17.80 USD)**

---

## 3. Engineering Audit & Component Sourcing Rationale

1. **Rejection of TL072 on 3.3V Single Supply**:
   - The classic TL072 JFET-input operational amplifier specifies an absolute minimum supply voltage of **7.0V (±3.5V)**. On a 3.3V single-supply rail, internal biasing current mirrors cannot turn on.
   - The LM358, while functional at 3.0V, has an output high limit $V_{OH} \le V_{CC} - 1.5\text{V} = 1.8\text{V}$, leaving only $150\text{mV}$ of positive dynamic range above a 1.65V mid-rail bias.
   - **Selection of MCP6002**: The Microchip MCP6002 is specifically engineered for single-supply 1.8V to 6.0V applications with true Rail-to-Rail Input and Output (RRIO), swinging within $25\text{mV}$ of the 3.3V and GND rails. Its $1\text{pA}$ CMOS input bias current avoids loading the high-impedance piezo element.
2. **Anti-Aliasing Filter Reconciliation (4 kHz Sampling vs. 30 kHz Sensor Bandwidth)**:
   - The active 2nd-order Sallen-Key low-pass filter ($R_1 = R_2 = 10\text{k}\Omega$, $C_1 = 15\text{nF}$, $C_2 = 6.8\text{nF}$) yields $f_0 = 1575.9\text{ Hz}$ and $Q = 0.7425$.
   - **Passband**: $0 - 1150\text{ Hz}$ ($\le -0.75\text{ dB}$); down $-2.18\text{ dB}$ at $1500\text{ Hz}$; down $-5.18\text{ dB}$ at $f_N = 2000\text{ Hz}$; down $-16.16\text{ dB}$ at $f_s = 4000\text{ Hz}$.
   - **Trade-Off**: A 2nd-order analog stage provides modest $-5.2\text{ dB}$ rejection at Nyquist. Acoustic noise in the $2 - 3\text{ kHz}$ range experiences partial aliasing. If workshop tests show acoustic noise contamination, firmware sampling will be raised to $8\text{ kHz}$ with digital decimation.
3. **MQ-2 Gas Sensor Power & Precision ADC Divider**:
   - MQ-2 requires a dedicated **5.0V heater supply** ($V_H = 5.0\text{V} \pm 0.1\text{V}$, consuming $\approx 805\text{ mW} / 161\text{ mA}$) drawn from the MT3608 step-up boost converter.
   - The verified precision **$12\text{k}\Omega / 10\text{k}\Omega\ 1\%$** divider scales the $0 - 5.25\text{V}$ maximum sensor module output down to $\le 2.412\text{V}$ under worst-case resistor tolerance. This keeps the signal completely inside the linear calibrated window of the Classic ESP32 ADC ($150\text{ mV} - 2.45\text{V}$) and ESP32-S3 ADC ($150\text{ mV} - 3.10\text{V}$), with $> 1.18\text{V}$ margin under the $3.6\text{V}$ absolute maximum MCU pin rating.
4. **Power System Topology & Reconciled Power Budget**:
   - The MT3608 is an **asynchronous step-up boost converter** (using an external SS34 Schottky diode, $\eta \approx 85\%$), NOT a synchronous boost converter.
   - The TP4056 board separates charging (`IN+`/`IN-`) from battery (`B+`/`B-`) and system load (`OUT+`/`OUT-`). Because TP4056 lacks dynamic power-path management, the unit must be powered **OFF** during charging to ensure proper $C/10$ termination and prevent cell degradation.
   - **Reconciled Power & Autonomy**: Nominal draw at 3.7V is $426.4\text{ mA}$ ($1.58\text{ W}$), with peak-averaged draw of $445\text{ mA}$ ($1.65\text{ W}$, correcting prior $1.48\text{ W}$ notation). Usable capacity on a 1200mAh LiPo cell ($85\% \implies 1020\text{ mAh}$) provides $\approx 2.29\text{ hours}$ continuous runtime (provisional pending physical discharge test).
5. **Sensor Inventory Accounting (Core vs. Optional vs. Unimplemented)**:
   - Core active sensors in V1.1.0: Contact Piezo, MQ-2 Gas, Moisture Conduction.
   - Optional modular sensors with firmware hooks: Reference Mic (`USE_REFERENCE_SENSOR = 0`), MLX90614 IR (`HAS_HEAT_SENSOR = 0`), GUVA-S12SD UV (`HAS_UV_SENSOR = 0`).
   - Unimplemented in V1.1.0 Arduino firmware: VL53L0X distance sensor (retained only in experimental ESP-IDF testbed; proximity breach alarms are not active).
6. **Hardware Validation Status Disclosure**:
   - Physical breadboarding, PCBA fabrication, and sensor calibration remain pending component procurement. All circuit schematics and BOM specifications are currently **DESIGN PROPOSED / DOCUMENT REVIEWED**, requiring physical bench verification before declaring hardware-validated.
