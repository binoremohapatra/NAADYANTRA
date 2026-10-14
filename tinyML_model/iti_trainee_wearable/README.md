# ITI Trainee Diagnostic Wearable (ESP32-WROOM-32E)

## Pipeline
```
pip install -r requirements.txt
python generate_mock_dataset.py                       # dataset/<class>/*.wav + hazard_telemetry.csv
python train_hazard_fusion.py                         # -> firmware/main/hazard_model.h
python train_quantize.py --data dataset --out firmware/main   # -> model_data.h + mel_tables.h (+ leak_model.tflite)
cd firmware && idf.py set-target esp32 && idf.py build flash monitor     # ESP-IDF 5.1 - 5.3
```
`hazard_model.h` and `mel_tables.h` are already generated and included. `model_data.h` needs TensorFlow, so it is NOT included: run `train_quantize.py` before building. `mel_tables.h` must always be regenerated together with `model_data.h` (they share the dB scaling range).

## Wiring
| Function | Pin |
|---|---|
| I2C SDA / SCL (OLED 0x3C, MLX90614 0x5A, VL53L0X 0x29) | GPIO21 / GPIO22 |
| Piezo + OPA344 (centre at ~1.65 V) | GPIO34 (ADC1_CH6) |
| MQ-2 AO via 2:1 divider (5 V -> <3.3 V) | GPIO35 (ADC1_CH7) |
| GUVA-S12SD | GPIO32 (ADC1_CH4) |
| Buzzer (NPN driven) | GPIO25 |
| LEDs green / amber / red | GPIO26 / 27 / 13 |
| Session button (to GND) | GPIO4 |
| Instructor leak-drill button (to GND) | GPIO18 |

## Operation
* Session button: start / end session. Leak-drill button (or BLE command): first press marks leak-simulation onset, second press ends the drill.
* Reaction time = onset mark -> confirmed leak alert (2 consecutive 500 ms windows with p>=0.6).
* False alarm = leak alert rising edge while a session runs and no drill is active.
* Standoff compliance = % of active-arc time (UV index hysteresis, >=2.8 on / <1.5 off) with distance in 200-350 mm.
* Score (0-100) = weighted mean of the components exercised: reaction 40 % (100 at <=2 s, 0 at >=10 s), false alarms 20 % (-25 each), standoff 40 %. >=70 shows COMPETENT. All thresholds are `#define`s at the top of main.cpp.

## BLE GATT (device name `ITI-Trainer`)
Service `06172839-4A5B-6C7D-8E9F-A0B0C0D00001`; characteristics `...0002` alert (read/notify, 12 B), `...0003` assessment (read/notify, 10 B), `...0004` control (write 1 byte: 1 start, 2 leak onset, 3 leak end, 4 end session, 5 reset). Packet layouts: `BleAlertPkt` / `BleAssessPkt` in main.cpp (little-endian, packed).

## Verified here vs. not verified
Verified on a host: dataset generator runs; hazard forest exports with 100 % agreement with scikit-learn, and the generated C header was compiled with gcc and matches 200/200 test vectors; the firmware's FFT/log-Mel/quantisation code (extracted straight from main.cpp) matches the Python reference to within 1 LSB on real generated clips.
NOT verified (no TensorFlow, ESP-IDF or hardware here): TFLite training/PTQ results and the 25 KiB / 16 KiB budgets (the script enforces them and prints sizes; firmware logs real `arena_used_bytes`), compilation of main.cpp against ESP-IDF, and all sensor/BLE behaviour on hardware.

## First things to check on hardware
1. Boot log line `piezo channel rate: ... Hz` must read ~16000. If not, adjust `ADC_CONV_RATE_HZ` (ESP32 ADC DMA rate semantics vary by IDF version).
2. The model is trained on synthetic audio only. Record real piezo clips from real pipes/leaks/workshop noise, drop them into `dataset/<class>/` as 16 kHz mono wavs and retrain before any trainee-facing use.
3. MQ-2 needs a long preheat (24 h for datasheet accuracy); the 30 s warm-up/R0 auto-calibration is a demo convenience. Calibrate in clean air.
4. The MLX90614ESF object range tops out at 380 C; hot-work temperatures above that read as the sensor limit.
