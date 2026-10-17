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
| **Contact Piezo** | `PIN_PIEZO` | **GPIO 4** (ADC1_CH3) | **GPIO 34** (ADC1_CH6) | Requires 1.65V virtual ground bias and AC coupling cap ($0.1\mu\text{F}$). Input to op-amp. |
| **Reference Mic** | `PIN_REFERENCE` | **GPIO 7** (ADC1_CH6) | **GPIO 33** (ADC1_CH5) | Ambient noise cancellation channel (optional). |
| **Combustible Gas** | `PIN_GAS` | **GPIO 5** (ADC1_CH4) | **GPIO 35** (ADC1_CH7) | **CRITICAL**: MQ module outputs 5V. Must use 10kΩ / 20kΩ voltage divider to limit signal to $\le 3.3\text{V}$. |
| **Moisture Sense** | `PIN_MOISTURE` | **GPIO 6** (ADC1_CH5) | **GPIO 32** (ADC1_CH4) | Conduction probe sense node with 100kΩ pull-down. |
| **Moisture Power** | `PIN_MOIST_PWR` | **GPIO 10** | **GPIO 25** | Gated excitation pin; driven HIGH for 50ms only during read to eliminate galvanic erosion. |
| **I2C SDA** | `PIN_SDA` | **GPIO 8** | **GPIO 21** | Shared I2C bus for SSD1306 OLED (`0x3C`) and MLX90614 pyrometer (`0x5A`). |
| **I2C SCL** | `PIN_SCL` | **GPIO 9** | **GPIO 22** | $100\text{ kHz}$ standard clock. Ensure $4.7\text{k}\Omega$ pull-ups to 3.3V. |
| **Audio Buzzer** | `PIN_BUZZER` | **GPIO 15** | **GPIO 27** | Driven via 2N2222 NPN transistor with flyback protection diode. |
| **Haptic Motor** | `PIN_VIBRATION` | **GPIO 16** | **GPIO 26** | Driven via 2N2222 NPN transistor with 1N4148 flyback diode. |
| **Green LED (OK)** | `PIN_LED_GREEN` | **GPIO 17** | **GPIO 14** | $330\Omega$ series ballast resistor. |
| **Yellow LED (Warn)**| `PIN_LED_YELLOW` | **GPIO 18** | **GPIO 12** | $330\Omega$ series ballast resistor. |
| **Red LED (Danger)** | `PIN_LED_RED` | **GPIO 21** | **GPIO 13** | $330\Omega$ series ballast resistor. |
| **BOOT / Control** | `PIN_BUTTON` | **GPIO 0** | **GPIO 0** | Active-LOW with internal pull-up. Short press: toggle session; Long press (>2s): calibrate baseline. |

> [!WARNING]
> **ADC Channel Rule**: All analog sensors are strictly routed to **ADC1**. On the ESP32 platform, **ADC2 cannot be used simultaneously with active Wi-Fi transmission**. Violating this will cause silent sample corruption or radio crashes.

---

## 2. Analog Signal Conditioning & Schematics

### 2.1 Contact Piezoelectric Op-Amp Stage
```text
                  +3.3V
                    │
                   [10k]
                    ├─────────── V_BIAS (1.65V Virtual Ground)
                   [10k]          │
                    │           [10uF] to GND
                   GND            │
                                  ▼
Piezo Disc (+) ───[0.1uF]───┬──[ + ]
                            │   TL072 ─── Output ───► PIN_PIEZO (ADC1)
Piezo Disc (-) ─── GND     [1M]  [ - ]
                            │      │
                         V_BIAS    └───[33k]─── Output (Gain ~33x)
```

### 2.2 MQ Gas Sensor 5V to 3.3V Level Divider
```text
MQ Sensor Analog Out (0 - 5V) ───[10k]───┬───► PIN_GAS (ADC1, 0 - 3.3V Max)
                                         │
                                       [20k]
                                         │
                                        GND
```

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
