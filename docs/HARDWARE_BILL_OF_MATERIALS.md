# NAADYANTRA — Hardware Bill of Materials (BOM) & Cost Documentation
## Low-Cost Diagnostic Sensing Wearable for Skilled Trades (SIH26244)

> [!NOTE]
> **Pricing Baseline**: October 2026 indicative procurement rates based on standard Indian electronics distributors (Robu.in, ElectronicsComp, Component's Bazaar) and international volume distributors (LCSC, Mouser).  
> **Hardware Status**: Design-verified schematic; physical assembly and bench verification pending component procurement.

---

## 1. Itemized Component Breakdown

| Item # | Subsystem | Component Description | Selected Part / Spec | Qty | Electrical Interface | Operating Voltage | Unit Cost (Est. INR) | Subtotal (INR) | Verification Status |
| :---: | :--- | :--- | :--- | :---: | :--- | :---: | :---: | :---: | :---: |
| **01** | Compute & Radio | ESP32-S3 DevKitC-1 (or ESP32-WROOM-32) | ESP32-S3-WROOM-1-N8R2 (Dual-Core 240MHz, 8MB Flash, 2MB PSRAM, Wi-Fi 4 + BLE 5) | 1 | Native USB-C / UART / GPIO | 3.3V (5V VBUS in) | ₹480 | ₹480 | Design Verified |
| **02** | Acoustic Sensing | Brass Contact Piezoelectric Sensor | 27mm Brass Acoustic Disc Element with acoustic wave coupling cone | 1 | Analog Single-Ended (to Op-Amp) | Passive (piezo-generated) | ₹35 | ₹35 | Design Verified |
| **03** | Analog Front-End | Dual Low-Noise Operational Amplifier | Texas Instruments TL072IP (or LM358P fallback) in inverting AC gain stage ($A_v \approx 33$) | 1 | ADC1 (ESP32-S3 GPIO 4 / ESP32 GPIO 34) | 3.3V Single Supply (1.65V Virtual Ground) | ₹45 | ₹45 | Design Verified |
| **04** | Environmental | Combustible Gas Sensor Module | MQ-2 / MQ-135 Gas Detection Element with 5V to 3.3V resistive divider (10k/20k) | 1 | ADC1 (ESP32-S3 GPIO 5 / ESP32 GPIO 35) | 5.0V Heater, 3.3V Signal | ₹140 | ₹140 | Design Verified |
| **05** | Surface Moisture | Dual-Prong Liquid Conduction Probe | Gated Gold-Plated Interleaved PCB Trace Probe with GPIO excitation switch | 1 | ADC1 (ESP32-S3 GPIO 6 / ESP32 GPIO 32) + Gating GPIO 10 | 3.3V Pulsed (Prevents galvanic oxidation) | ₹60 | ₹60 | Design Verified |
| **06** | Thermal Safety | Contactless Infrared Pyrometer | MLX90614-ESF-BAA (or BCI) Factory Calibrated Non-Contact Pyrometer ($0.5^\circ\text{C}$ accuracy) | 1 | I2C (SDA: GPIO 8, SCL: GPIO 9 @ 100kHz) | 3.3V | ₹420 | ₹420 | Design Verified |
| **07** | Visual Telemetry | 0.96" Monochrome Display | SSD1306 128x64 OLED Display Module | 1 | I2C (Shared bus with Pyrometer, addr `0x3C`) | 3.3V | ₹165 | ₹165 | Design Verified |
| **08** | Actuation / Alarm| Haptic Vibration Motor & Piezo Buzzer | 1027 ERM Coin Vibration Motor + 5V Active Piezo Buzzer driven via 2N2222 NPN Transistors | 1 pair | GPIO 15 (Buzzer), GPIO 16 (Haptic) | 3.3V - 5V | ₹55 | ₹55 | Design Verified |
| **09** | Status Indicators| Tri-Color Diagnostic LEDs | 3mm Industrial LEDs (Green, Amber, Red) with 330Ω ballast resistors | 3 | GPIO 17 (Green), GPIO 18 (Amber), GPIO 21 (Red) | 3.3V | ₹15 | ₹15 | Design Verified |
| **10** | Power System | Li-Ion Battery & Power Management | 3.7V 1200mAh 18650 or LiPo pouch cell + TP4056 Type-C Charger Protection Board + ME6211 3.3V 500mA LDO | 1 set | Battery JST-PH 2.0mm connector | 3.7V nom (4.2V max) | ₹290 | ₹290 | Design Verified |
| **11** | Enclosure | Ergonomic Wearable Forearm / Belt Case | 3D Printed PETG (Impact-resistant, chemical-tolerant) with acoustic isolation gasket | 1 | Mechanical wearable | N/A | ₹180 | ₹180 | CAD Verified |
| **12** | Fasteners & Wiring| Hookup Wire, Connectors & Strap | 26 AWG flexible silicone wire, JST-XH headers, nylon hook-and-loop forearm strap | 1 set | Mechanical / Electrical | N/A | ₹95 | ₹95 | Design Verified |

---

## 2. Cost Summary & Batch Projections

### 2.1 Prototype Bill of Materials (Single Unit)
- **Total Components Subtotal**: **₹1,980 INR (~$23.85 USD)**
- **Prototyping Contingency & Shipping (15%)**: **₹297 INR**
- **Estimated Single Prototype Total**: **₹2,277 INR (~$27.40 USD)**

### 2.2 Volume Production Estimate (100-Unit Batch)
With bulk purchasing of passive components, reel-packaged semiconductors, and custom SMT fabrication:
- SMT PCBA with ESP32-S3 module integrated on board: ₹580 INR
- Sensor bundle (Piezo disc + MQ + MLX90614 + OLED): ₹520 INR
- Injection-molded ABS enclosure & wearable strap: ₹110 INR
- Battery & power management: ₹180 INR
- Assembly, calibration testing & packaging: ₹90 INR
- **Projected Unit Cost @ 100 Units**: **₹1,480 INR (~$17.80 USD)**

---

## 3. Component Sourcing Notes & Alternatives

1. **Acoustic Sensor**: The 27mm brass piezo disc is widely accessible in India for acoustic guitar pickups and buzzer elements. For ultra-low-noise environments, an alternative PZT ceramic disc (Murata 7BB series) is recommended.
2. **Thermal Pyrometer**: The MLX90614 can be substituted with the TI TMP006/TMP007 or Omron D6T-1A-01 if local stock shortages occur.
3. **Microcontroller**: The firmware natively supports both the ESP32-S3 (recommended for native USB-C and expanded vector instructions) and the classic ESP32-WROOM-32 (legacy fallback) via preprocessor conditional pin maps (`#if CONFIG_IDF_TARGET_ESP32S3`).
