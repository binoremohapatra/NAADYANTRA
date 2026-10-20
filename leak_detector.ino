/*
 * HazGuard: Multi-Modal Acoustic & Hazardous Environment Diagnostic Firmware
 * Platform: ESP32-S3 / ESP32 DevKit (Dual-Core 240MHz Xtensa)
 * SIH 2026 - Problem Statement: PS26244
 * Firmware Version: 1.1.0
 *
 * Architecture:
 *  1. Acoustic Pipeline:
 *     Contact Piezo -> 12-bit ADC1 -> IIR DC-Block Filter -> Ring Buffer -> TinyML / RMS
 *  2. Environmental Hazards:
 *     MQ Combustible Gas (Rs/R0 & %LEL) + Soil/Pipe Moisture Conduction Probe
 *  3. Thermal / Optical Safety:
 *     MLX90614 Non-Contact IR Pyrometer + GUVA-S12SD UV Radiometer
 *  4. Sensor Fusion:
 *     Multi-Tiered Priority Matrix + Temporal Debounce Windows
 *  5. Actuation & Localisation:
 *     SSD1306 OLED, Status LEDs, Tactile Vibration Motor, Variable-Pitch Audio Cue
 *  6. Telemetry & Cloud Synchronization:
 *     Thread-Safe FreeRTOS Queue -> HTTP(S) REST Dispatch to FastAPI Workstation
 *
 * Hardware Notes:
 *  - Contact Piezo: Requires 1.65V virtual ground bias node and op-amp stage (gain 20-50).
 *  - MQ Gas Sensor: 5V divider stepped down to ADC linear range via 15k/10k resistor network (2.5x divider ratio, max 2.125V at ADC).
 *  - Battery Monitor: 100k/100k 1% divider on 1S LiPo rail (2.0x factor). Low battery alert at 3.55V, critical cutoff at 3.45V.
 *  - Load Disconnect: PIN_BOOST_EN controls high-side P-MOSFET to cut MT3608 + MQ-2 heater to 0mA during shutdown/sleep.
 *  - Moisture Probe: Interleaved excitation pulse via PIN_MOIST_PWR to prevent galvanic corrosion.
 *  - MLX90614: Direct SMBus transaction @ 100kHz standard I2C clock.
 *  - Controls: Short press on BOOT toggles active session; long press (>2s) recalibrates baseline.
 */

#include <Arduino.h>
#include <atomic>
#include <math.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <esp_random.h>

// Forward declarations for types referenced in Arduino-generated prototypes
struct SamplerCtx;

// Dual-core compatibility: supports both Arduino-ESP32 Core 2.x and Core 3.x HAL

#define FW_VERSION  "1.1.0"

#define RUN_MODE_DETECT   0
#define RUN_MODE_COLLECT  1
#define RUN_MODE          RUN_MODE_DETECT   // Set to RUN_MODE_COLLECT for dataset acquisition

#define USE_EDGE_IMPULSE      0   // 0 = RMS fallback detector (verified buildable), 1 = Edge Impulse TinyML
#define USE_TINYML_HAZARD_FUSION 1 // 1 = Embedded TinyML multi-sensor hazard fusion (hazard_model.h), 0 = heuristic only
#define USE_REFERENCE_SENSOR  0   // Dual microphone ambient noise subtraction
#define HAS_GAS_SENSOR        1   // MQ-2 combustible gas sensor (analog PIN_GAS 35)
#define HAS_MOISTURE_SENSOR   0   // 0 = Disabled (not present on physical perfboard, avoids floating-pin false alarms)
#define HAS_HEAT_SENSOR       0   // MLX90614 contactless IR pyrometer (not fitted)
#define HAS_UV_SENSOR         0   // GUVA-S12SD analog UV sensor (not fitted)
#define HAS_DISTANCE_SENSOR   1   // VL53L0X Time-of-Flight distance sensor (I2C 0x29)
#define HAS_BH1750_SENSOR     1   // BH1750 ambient light sensor (I2C 0x23)
#define VL53_ADDR             0x29
#define BH1750_ADDR           0x23
#define MOIST_POWER_GATED     0   // Disabled with moisture probe
#define ENABLE_WIFI_LOGGING   1
#define BUZZER_PASSIVE        0   // 0 = Active digital buzzer, 1 = Passive PWM tone
#define DEBUG_SERIAL          1
#define VERIFY_TLS_CERT       0   // 0 = Bench debug (accepts cloud TLS cert), 1 = Strict ECC CA

#if USE_TINYML_HAZARD_FUSION
#include "hazard_model.h"
#endif

// ---- Wi-Fi & Provisioned Device Credentials ----
// Modular credential loading: if credentials.h exists (ignored by git), load private hardware secrets.
// Otherwise, fall back to safe placeholders and instruct the operator.
#if __has_include("credentials.h")
  #include "credentials.h"
#else
  #warning "No credentials.h found. Using default placeholder configuration. Copy credentials.example.h to credentials.h before flashing."
  #define WIFI_SSID        "YOUR_BENCH_WIFI_SSID"
  #define WIFI_PASSWORD    "YOUR_BENCH_WIFI_PASSWORD"
  #define BACKEND_URL      "https://naadyantra.onrender.com"
  #define DEVICE_KEY       "YOUR_PROVISIONED_DEVICE_KEY"
  #define DEVICE_ID        "SIH-DEV-01"
  #define TRAINEE_ID       "T001"
#endif

// ---- Pins ----
#if CONFIG_IDF_TARGET_ESP32S3      // ESP32-S3 default pinout mapping
  #define PIN_PIEZO       4        // ADC1_CH3
  #define PIN_REFERENCE   7        // ADC1_CH6
  #define PIN_GAS         5        // ADC1_CH4
  #define PIN_MOISTURE    6        // ADC1_CH5
  #define PIN_UV          1        // ADC1_CH0
  #define PIN_BATTERY     2        // ADC1_CH1 (100k/100k divider)
  #define PIN_BOOST_EN    11       // MT3608 load-disconnect gate control
  #define PIN_MOIST_PWR   10
  #define PIN_SDA         8
  #define PIN_SCL         9
  #define PIN_BUZZER      15
  #define PIN_VIBRATION   16
  #define PIN_LED_GREEN   17
  #define PIN_LED_YELLOW  18
  #define PIN_LED_RED     21
  #define PIN_BUTTON      0        // BOOT button
#else                              // Classic ESP32 WROOM pinout mapping
  #define PIN_PIEZO       34       // ADC1_CH6 (input-only)
  #define PIN_REFERENCE   33       // ADC1_CH5
  #define PIN_GAS         35       // ADC1_CH7 (input-only)
  #define PIN_MOISTURE    32       // ADC1_CH4
  #define PIN_UV          36       // ADC1_CH0 / SENSOR_VP (input-only)
  #define PIN_BATTERY     39       // ADC1_CH3 / SENSOR_VN (input-only, 100k/100k divider)
  #define PIN_BOOST_EN    19       // MT3608 load-disconnect gate control
  #define PIN_MOIST_PWR   23
  #define PIN_SDA         21
  #define PIN_SCL         22
  #define PIN_BUZZER      25
  #define PIN_VIBRATION   26
  #define PIN_LED_GREEN   27
  #define PIN_LED_YELLOW  14
  #define PIN_LED_RED     13
  #define PIN_BUTTON      0
#endif

// ---- Acoustic (piezo) ----
#define SAMPLE_RATE_HZ        4000   // Acoustic sampling frequency (fallback/collect)
#define WINDOW_MS             1000   // Analysis window length
#define HOP_MS                500    // Window step hop interval (50% overlap)
#define DC_BLOCK_R            0.995f
#define LEAK_PROB_MIN         0.65f  // Minimum confidence threshold for leak detection
#define NOISE_PROB_MIN        0.60f
#define NORMAL_PROB_MIN       0.60f
#define LEAK_CONFIRM_WINDOWS  2      // Consecutive positive windows to assert leak condition
#define LEAK_CLEAR_WINDOWS    4      // Consecutive negative windows to clear leak condition
#define MIN_SIGNAL_RMS        0.8f   // Disconnected sensor fault threshold (ADC counts)
#define ANOMALY_MAX           0.3f   // Out-of-distribution anomaly threshold
#define FALLBACK_LEAK_RATIO   3.0f   // Fallback RMS ratio threshold for leak alarm
#define REF_NOISE_RMS         30.0f
#define REF_MIN_RATIO         1.5f

// ---- Locate (Geiger-style) beep ----
#define CUE_RMS_START_RATIO   1.5f   // Geiger localization start ratio threshold
#define CUE_RMS_FULL_RATIO    6.0f   // Geiger localization maximum pulse frequency ratio
#define CUE_GAP_SLOW_MS       700
#define CUE_GAP_FAST_MS       80
#define CUE_BEEP_MS           25

// ---- Combustible Gas (MQ Sensor Calibration) ---- (ADC raw counts, 0-4095)
#define GAS_WARMUP_S          120    // Pre-heat stabilization period in seconds (2 min minimum for clean air baseline)
#define GAS_WARN_DELTA        150    // Warning delta above ambient baseline
#define GAS_ALARM_DELTA       400    // Critical alarm delta above ambient baseline
// Load resistor and voltage divider parameters for Rs/R0 calculations
#define GAS_RL_KOHM           10.0f  // module load resistor
#define GAS_VCC               5.0f   // sensor heater/divider supply
#define GAS_DIV_FACTOR        2.5f   // 15k top / 10k bottom divider network (2.5x scaling factor, max V_adc <= 2.125V)
// Optional calibrated ppm / %LEL curve parameters
// Set GAS_CAL_VALID to 1 only after calibrating against reference standards
#define GAS_CAL_VALID         0
#define GAS_PPM_A             0.0f
#define GAS_PPM_B             0.0f
#define GAS_LEL_PPM           18000.0f   // 100% LEL equivalent in ppm for combustible gas
#define GAS_WARN_LEL_PCT      10.0f      // LEL warning threshold percentage
#define GAS_ALARM_LEL_PCT     20.0f

// ---- Battery Monitoring & Power Management ----
#define BAT_DIV_FACTOR        2.0f   // 100k/100k 1% divider network (2.0x scaling factor)
#define BAT_WARN_MV           3550   // 3.55V low-battery warning threshold
#define BAT_CLEAR_MV          3650   // 3.65V clear threshold (hysteresis)
#define BAT_SHUTDOWN_MV       3450   // 3.45V critical cutoff threshold
#define BAT_SHUTDOWN_SAMPLES  10     // Consecutive 1s samples required for shutdown assertion

// ---- Moisture probe ----
#define MOIST_WET_DELTA       300

// ---- Welding & Thermal Radiation Safety Module ----
#define MLX_ADDR              0x5A
#define HEAT_CUE_START_C      40.0f  // Thermal proximity audio warning start point (deg C)
#define HEAT_WARN_C           60.0f
#define HEAT_ALARM_C          100.0f
#define UV_WARN_DELTA         150    // UV warning delta above baseline
#define UV_ALARM_DELTA        500

// ---- UI / session / logging ----
#define LONG_PRESS_MS         2000
#define SNAPSHOT_EVERY_S      5
#define STALE_MS              4000
#define BUZZER_FREQ_HZ        2700
#define LOG_QUEUE_LEN         40

#if RUN_MODE == RUN_MODE_DETECT
  #if USE_EDGE_IMPULSE
    #include <YOUR_PROJECT_inferencing.h>   // Edge Impulse model header include
    static_assert(EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME == 1, "Impulse model must be configured for single-axis contact piezo");
  #endif
  #include <Wire.h>
  #include <Adafruit_GFX.h>
  #include <Adafruit_SSD1306.h>
  #if ENABLE_WIFI_LOGGING
    #include <WiFi.h>
    #include <WiFiClientSecure.h>
    #include <HTTPClient.h>
  #endif
#endif

enum Role     : uint8_t { ROLE_NORMAL, ROLE_LEAK, ROLE_NOISE, ROLE_UNCERTAIN };
enum GasLevel : uint8_t { GAS_OK, GAS_WARN, GAS_ALARM };    // Shared alert severity levels across auxiliary sensors
enum Alert    : uint8_t { ALERT_OK, ALERT_CAUTION, ALERT_DANGER };
enum Cause    : uint8_t { CAUSE_NONE, CAUSE_STARTUP, CAUSE_UNCERTAIN, CAUSE_NOISE, CAUSE_AMBIENT,
                          CAUSE_FAULT, CAUSE_GAS_WARN, CAUSE_WET, CAUSE_LEAK, CAUSE_GAS_ALARM,
                          CAUSE_HEAT_WARN, CAUSE_UV_WARN, CAUSE_HEAT_ALARM, CAUSE_UV_ALARM,
                          CAUSE_PROX_WARN, CAUSE_ARC_WARN };
enum LogKind  : uint8_t { LOGK_EVENT, LOGK_SUMMARY };

struct AcousticResult {
  float    pNormal, pLeak, pNoise;   // Accumulated class probabilities mapped to operational roles
  float    rms, refRms;              // Window RMS energy (ADC counts)
  uint16_t inferMs;
  bool     anomalous;
  char     topLabel[20];
};

// critical=true means the item survives queue saturation (alarm/session events).
// critical=false items (routine 'snap' telemetry) are discarded first when the queue is full.
struct LogItem { uint32_t session; LogKind kind; bool critical; char trainee[16]; char json[320]; };

// Consecutive window debouncer to prevent rapid signal chatter
struct Debounce {
  uint8_t onN, offN, onCnt, offCnt; bool state;
  Debounce(uint8_t on = 2, uint8_t off = 4) : onN(on), offN(off), onCnt(0), offCnt(0), state(false) {}
  bool update(bool active) {
    if (active) { offCnt = 0; if (onCnt < 255) onCnt++; if (onCnt >= onN) state = true; }
    else        { onCnt = 0; if (offCnt < 255) offCnt++; if (offCnt >= offN) state = false; }
    return state;
  }
};

struct SlowFilter {
  float ema = 0; bool primed = false;
  void feed(float x, float alpha) { if (!primed) { ema = x; primed = true; } else ema += alpha * (x - ema); }
};

struct GasState   { SlowFilter f; float base = 0; bool cal = false; GasLevel level = GAS_OK; bool wasFault = false; Debounce fault{40, 10}; };
struct MoistState { SlowFilter f; float base = 0; bool cal = false; Debounce wet{10, 20}; };
struct UvState    { SlowFilter f; float base = 0; bool cal = false; GasLevel level = GAS_OK; };
struct HeatState  { SlowFilter f; float temp = 0; GasLevel level = GAS_OK; uint32_t lastMs = 0; Debounce fault{8, 3}; };

struct Session {
  bool active = false;
  uint32_t id = 0, startMs = 0, windows = 0, leakEvents = 0, gasEvents = 0, wetEvents = 0,
           heatEvents = 0, uvEvents = 0, noiseWindows = 0;
  float maxLeakP = 0;
};

struct FuseIn {
  bool gasAlarm, gasWarn, gasFault, heatAlarm, heatWarn, heatFault, uvAlarm, uvWarn;
  bool leak, wet, noSignal, stale, ambient, startup;
  Role role;
  int hzState;
  uint8_t hzConf;
};
struct Verdict { Alert alert; Cause cause; };

struct App {
  // acoustic
  bool haveResult = false, stale = false, rmsPrimed = false, rmsCal = false, ambient = false;
  uint32_t lastResultMs = 0, resultCount = 0;
  Role role = ROLE_UNCERTAIN;
  float pLeak = 0, pNoise = 0, pNormal = 0, rms = 0, rmsEma = 0, refRms = 0;
  char label[20] = "-";
  Debounce leak{LEAK_CONFIRM_WINDOWS, LEAK_CLEAR_WINDOWS};
  Debounce noSignal{3, 2};
  // slow sensors
  GasState gas; MoistState moist; UvState uv; HeatState heat; uint32_t lastSlowSeq = 0;
  // calibration
  bool calFastPending = true, calGasPending = (HAS_GAS_SENSOR != 0);
  uint32_t calFastAt = 4000, calGasAt = (uint32_t)GAS_WARMUP_S * 1000UL;
  // verdict + outputs
  Alert alert = ALERT_CAUTION; Cause cause = CAUSE_STARTUP; uint8_t faultMask = 0;
  uint16_t buzzPat = 0, vibPat = 0; bool buzzOn = false; uint32_t beepUntil = 0;
  // ui — _lastOledAlert/Cause used to detect state changes for faster redraw
  uint32_t lastOledMs = 0, msgUntil = 0; char msg[22] = ""; bool oledInv = false;
  Alert _lastOledAlert = ALERT_CAUTION; Cause _lastOledCause = CAUSE_STARTUP;
  // session
  Session sess; uint32_t lastSnapMs = 0, lastDbgMs = 0;
  // instrumentation
  uint32_t minFreeHeap = UINT32_MAX;
  // TinyML multimodal hazard fusion state
  int hzState = 0;
  uint8_t hzConf = 0;
  // power & battery
  uint16_t vBatMv = 0;
  float vBat = 0.0f;
  bool batLowWarn = false;
  uint8_t batShutdownCnt = 0;
  // distance (ToF) & optical light
  int16_t distMm = -1;
  float distVel = 0.0f;
  uint32_t lastDistMs = 0;
  float lux = 0.0f;
};

// First-order IIR DC-blocking filter to remove ~1.65V DC virtual ground offset.
struct DcBlock {
  float x1 = 0, y1 = 0; bool primed = false;
  float step(float x) {
    if (!primed) { x1 = x; y1 = 0; primed = true; }
    float y = x - x1 + DC_BLOCK_R * y1;
    x1 = x; y1 = y;
    return y;
  }
};

struct SamplerCtx {
  DcBlock dcMain, dcRef;
  uint32_t tick = 0, sinceHop = 0, slowDiv = 200;
};

// Explicit function prototypes for Arduino IDE preprocessor
static void samplerInit(SamplerCtx& c);
static void samplerStep(SamplerCtx& c);

static uint32_t gFs = 0, gWin = 0, gHop = 0, gRingMask = 0;
static int16_t *gRing = nullptr, *gRefRing = nullptr;
static float* gFeat = nullptr;
static std::atomic<uint32_t> gHead{0}, gSlowSeq{0}, gOverruns{0};
static std::atomic<uint16_t> gGasRaw{0}, gMoistRaw{0}, gUvRaw{0};
static TaskHandle_t gSamplerTask = nullptr, gConsumerTask = nullptr;
static hw_timer_t* gTimer = nullptr;

static inline int16_t clamp16(float v) {
  if (v >  32767.0f) return  32767;
  if (v < -32768.0f) return -32768;
  return (int16_t)lrintf(v);
}

static void* allocBig(size_t bytes) {
  void* p = psramFound() ? ps_malloc(bytes) : nullptr;
  return p ? p : malloc(bytes);
}

static void computeSamplingParams() {
#if RUN_MODE == RUN_MODE_DETECT && USE_EDGE_IMPULSE
  gFs  = (uint32_t)EI_CLASSIFIER_FREQUENCY;          // Model target sampling frequency
  gWin = (uint32_t)EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE;
#else
  gFs  = SAMPLE_RATE_HZ;
  gWin = (uint32_t)((uint64_t)SAMPLE_RATE_HZ * WINDOW_MS / 1000);
#endif
  gHop = (uint32_t)((uint64_t)gFs * HOP_MS / 1000);
  if (gHop < 1) gHop = 1;
  uint32_t cap = 1;
  while (cap < gWin * 2) cap <<= 1;                  // Round up to power-of-two for bitwise circular buffer wrapping
  gRingMask = cap - 1;
}

static bool allocateRings() {
  const size_t cap = (size_t)gRingMask + 1;
  gRing = (int16_t*)calloc(cap, sizeof(int16_t));
#if USE_REFERENCE_SENSOR
  gRefRing = (int16_t*)calloc(cap, sizeof(int16_t));
  if (!gRefRing) return false;
#endif
  return gRing != nullptr;
}

static void setupAdc() {
  analogReadResolution(12);
  const uint8_t pins[] = {
    PIN_PIEZO,
    PIN_BATTERY,
#if USE_REFERENCE_SENSOR
    PIN_REFERENCE,
#endif
#if HAS_GAS_SENSOR
    PIN_GAS,
#endif
#if HAS_MOISTURE_SENSOR
    PIN_MOISTURE,
#endif
#if HAS_UV_SENSOR
    PIN_UV,
#endif
  };
  for (uint8_t p : pins) { analogSetPinAttenuation(p, ADC_11db); (void)analogRead(p); }  // Pre-initialize ADC channels during setup
#if HAS_MOISTURE_SENSOR && MOIST_POWER_GATED
  pinMode(PIN_MOIST_PWR, OUTPUT);
  digitalWrite(PIN_MOIST_PWR, LOW);
#endif
}

static void samplerInit(SamplerCtx& c) {
  c = SamplerCtx();
  c.slowDiv = (gFs / 20 < 8) ? 8 : gFs / 20;         // Sub-sample auxiliary sensors at ~20 Hz
}

// Single timer tick execution step
static void samplerStep(SamplerCtx& c) {
  const uint32_t h = gHead.load(std::memory_order_relaxed);
  gRing[h & gRingMask] = clamp16(c.dcMain.step((float)analogRead(PIN_PIEZO)));
#if USE_REFERENCE_SENSOR
  gRefRing[h & gRingMask] = clamp16(c.dcRef.step((float)analogRead(PIN_REFERENCE)));
#endif
  gHead.store(h + 1, std::memory_order_release);

  // Interleave slow sensor reads across sample ticks
  const uint32_t phase = (++c.tick) % c.slowDiv;
#if HAS_MOISTURE_SENSOR && MOIST_POWER_GATED
  if (phase == 0) digitalWrite(PIN_MOIST_PWR, HIGH);      // Pulse moisture probe power rail to minimize electrolysis
  if (phase == 4) digitalWrite(PIN_MOIST_PWR, LOW);
#endif
#if HAS_GAS_SENSOR
  if (phase == 1) gGasRaw.store((uint16_t)analogRead(PIN_GAS), std::memory_order_relaxed);
#endif
#if HAS_MOISTURE_SENSOR
  if (phase == 3) gMoistRaw.store((uint16_t)analogRead(PIN_MOISTURE), std::memory_order_relaxed);
#endif
#if HAS_UV_SENSOR
  if (phase == 5) gUvRaw.store((uint16_t)analogRead(PIN_UV), std::memory_order_relaxed);
#endif
  if (phase == 6) gSlowSeq.fetch_add(1, std::memory_order_release);

  if (++c.sinceHop >= gHop) {
    c.sinceHop = 0;
    if (gConsumerTask) xTaskNotifyGive(gConsumerTask);
  }
}

static void IRAM_ATTR onSampleTimer() {
  BaseType_t woken = pdFALSE;
  vTaskNotifyGiveFromISR(gSamplerTask, &woken);
  if (woken) portYIELD_FROM_ISR();
}

static void samplerTask(void*) {
  SamplerCtx c;
  samplerInit(c);
  for (;;) {
    const uint32_t pending = ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    if (pending > 1) gOverruns.fetch_add(pending - 1, std::memory_order_relaxed);   // Track missed timer ticks
    samplerStep(c);
  }
}

static void startSampling() {
  xTaskCreatePinnedToCore(samplerTask, "sampler", 4096, nullptr, 10, &gSamplerTask, 1);
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
  gTimer = timerBegin(1000000);                                  // 1 MHz tick
  timerAttachInterrupt(gTimer, &onSampleTimer);
  timerAlarm(gTimer, 1000000UL / gFs, true, 0);                  // 1/Fs timer period
#else
  gTimer = timerBegin(0, 80, true);                              // Core 2.x: Timer 0, prescaler 80 = 1 MHz
  timerAttachInterrupt(gTimer, &onSampleTimer, true);
  timerAlarmWrite(gTimer, 1000000UL / gFs, true);
  timerAlarmEnable(gTimer);
#endif
}

#if RUN_MODE == RUN_MODE_COLLECT
void setup() {
  Serial.begin(921600);
  setupAdc();
  computeSamplingParams();
  if (!allocateRings()) { for (;;) delay(1000); }
  startSampling();
}

void loop() {
  static uint32_t tail = 0;
  const uint32_t head = gHead.load(std::memory_order_acquire);
  if (head - tail > gRingMask - 64) tail = head - gWin;         // Ring buffer overflow recovery: advance tail pointer
  char buf[512]; size_t len = 0;
  while (tail != head && len + 8 < sizeof(buf)) {
    len += snprintf(buf + len, sizeof(buf) - len, "%d\n", (int)gRing[tail & gRingMask]);
    tail++;
  }
  if (len) Serial.write((const uint8_t*)buf, len); else delay(1);
}

#else
static std::atomic<float> gRmsBase{0.0f};          // Rolling baseline RMS energy reference
static QueueHandle_t gResultQ = nullptr, gLogQ = nullptr;
static volatile bool gWifiUp = false;
static Adafruit_SSD1306 gOled(128, 64, &Wire, -1);
static bool gOledOk = false;
static App app;
static char gTrainee[16] = TRAINEE_ID;             // Active operator trainee identifier
static uint32_t gLastCue = 0;

// ---------- helpers ----------
static inline float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
static inline bool slotOn(uint16_t pattern, uint32_t nowMs) { return (pattern >> ((nowMs / 100) & 15)) & 1; }

static float rmsOf(const float* x, uint32_t n) {
  float s = 0.0f;
  for (uint32_t i = 0; i < n; i++) s += x[i] * x[i];
  return sqrtf(s / (float)n);
}
static float ringRms(const int16_t* ring, uint32_t start, uint32_t n) {
  float s = 0.0f;
  for (uint32_t i = 0; i < n; i++) { const float v = ring[(start + i) & gRingMask]; s += v * v; }
  return sqrtf(s / (float)n);
}

// ---------- pure logic ----------
// Map model output labels into internal operational roles
static Role roleOfLabel(const char* l) {
  if (strstr(l, "no_leak") || strstr(l, "normal") || strstr(l, "idle") || strstr(l, "background")) return ROLE_NORMAL;
  if (strstr(l, "leak"))  return ROLE_LEAK;
  if (strstr(l, "noise")) return ROLE_NOISE;
  return ROLE_UNCERTAIN;
}

// Prioritize leak classification for safety margins
static Role decideRole(float pLeak, float pNoise, float pNormal) {
  if (pLeak   >= LEAK_PROB_MIN)   return ROLE_LEAK;
  if (pNoise  >= NOISE_PROB_MIN)  return ROLE_NOISE;
  if (pNormal >= NORMAL_PROB_MIN) return ROLE_NORMAL;
  return ROLE_UNCERTAIN;
}

// Hysteresis comparator: 100% trip threshold, 80% release threshold
static GasLevel levelFrom(float v, float warn, float alarm, GasLevel prev) {
  const float h = 0.8f;
  if (v >= alarm || (prev == GAS_ALARM && v >= alarm * h)) return GAS_ALARM;
  if (v >= warn  || (prev >= GAS_WARN  && v >= warn  * h)) return GAS_WARN;
  return GAS_OK;
}

// Priority arbitration: Gas > Heat > UV > Acoustic Leak > Moisture > Warnings > System faults
//           > Sensor faults > Initialization > Ambient noise > Uncertain
static Verdict fuse(const FuseIn& in) {
  // High-confidence TinyML multimodal hazard reinforcement (hazard_model.h)
  // Classes: 0: Normal, 1: Safe Arc, 2: Proximity Breach, 3: Gas Buildup, 4: Workpiece Overheat
  if (in.hzConf >= 55) {
    if (in.hzState == 3) return {ALERT_DANGER,  CAUSE_GAS_ALARM};   // Gas Buildup predicted by TinyML
    if (in.hzState == 4) return {ALERT_DANGER,  CAUSE_HEAT_ALARM};  // Workpiece Overheat predicted by TinyML
    if (in.hzState == 2) return {ALERT_CAUTION, CAUSE_PROX_WARN};   // Proximity breach (<150mm)
    if (in.hzState == 1) return {ALERT_CAUTION, CAUSE_ARC_WARN};    // Optical / Arc flash flare detected
  }
  if (in.gasAlarm)  return {ALERT_DANGER,  CAUSE_GAS_ALARM};
  if (in.heatAlarm) return {ALERT_DANGER,  CAUSE_HEAT_ALARM};
  if (in.uvAlarm)   return {ALERT_DANGER,  CAUSE_UV_ALARM};
  if (in.leak)      return {ALERT_DANGER,  CAUSE_LEAK};
  if (in.wet)       return {ALERT_DANGER,  CAUSE_WET};
  if (in.gasWarn)   return {ALERT_CAUTION, CAUSE_GAS_WARN};
  if (in.heatWarn)  return {ALERT_CAUTION, CAUSE_HEAT_WARN};
  if (in.uvWarn)    return {ALERT_CAUTION, CAUSE_UV_WARN};
  if (in.gasFault || in.heatFault || in.noSignal || in.stale) return {ALERT_CAUTION, CAUSE_FAULT};
  if (in.startup)   return {ALERT_CAUTION, CAUSE_STARTUP};
  if (in.ambient)   return {ALERT_CAUTION, CAUSE_AMBIENT};
  if (in.role == ROLE_NOISE)     return {ALERT_CAUTION, CAUSE_NOISE};
  if (in.role == ROLE_UNCERTAIN) return {ALERT_CAUTION, CAUSE_UNCERTAIN};
  return {ALERT_OK, CAUSE_NONE};
}

static const char* causeText(Cause c) {      // OLED banner string (10 characters max at size 2)
  switch (c) {
    case CAUSE_GAS_ALARM:  return "GAS LEAK!";
    case CAUSE_HEAT_ALARM: return "TOO HOT!";
    case CAUSE_UV_ALARM:   return "UV DANGER";
    case CAUSE_LEAK:       return "LEAK!";
    case CAUSE_WET:        return "WATER!";
    case CAUSE_GAS_WARN:   return "GAS RISING";
    case CAUSE_HEAT_WARN:  return "HEAT WARN";
    case CAUSE_UV_WARN:    return "UV WARN";
    case CAUSE_PROX_WARN:  return "TOO CLOSE!";
    case CAUSE_ARC_WARN:   return "ARC FLASH!";
    case CAUSE_FAULT:      return "SENSOR ERR";
    case CAUSE_STARTUP:    return "STARTING";
    case CAUSE_AMBIENT:    return "TOO NOISY";
    case CAUSE_NOISE:      return "NOISE";
    case CAUSE_UNCERTAIN:  return "UNCERTAIN";
    default:               return "NO LEAK";
  }
}
static const char* causeName(Cause c) {
  switch (c) {
    case CAUSE_GAS_ALARM:  return "GAS_ALARM";
    case CAUSE_HEAT_ALARM: return "HEAT_ALARM";
    case CAUSE_UV_ALARM:   return "UV_ALARM";
    case CAUSE_LEAK:       return "LEAK";
    case CAUSE_WET:        return "WET";
    case CAUSE_GAS_WARN:   return "GAS_WARN";
    case CAUSE_HEAT_WARN:  return "HEAT_WARN";
    case CAUSE_UV_WARN:    return "UV_WARN";
    case CAUSE_PROX_WARN:  return "PROX_WARN";
    case CAUSE_ARC_WARN:   return "ARC_WARN";
    case CAUSE_FAULT:      return "FAULT";
    case CAUSE_STARTUP:    return "STARTUP";
    case CAUSE_AMBIENT:    return "AMBIENT";
    case CAUSE_NOISE:      return "NOISE";
    case CAUSE_UNCERTAIN:  return "UNCERTAIN";
    default:               return "NONE";
  }
}
static const char* alertName(Alert a) { return a == ALERT_DANGER ? "DANGER" : (a == ALERT_CAUTION ? "CAUTION" : "OK"); }

// 1600ms cyclic cadence bitmask (100ms per slot)
static uint16_t buzzPattern(Cause c) {
  switch (c) {
    case CAUSE_GAS_ALARM:  return 0x5555;   // Continuous rapid pulsing tone
    case CAUSE_HEAT_ALARM: return 0x0F0F;   // 400ms on / 400ms off tone
    case CAUSE_UV_ALARM:   return 0x1111;   // 100ms pulse every 400ms
    case CAUSE_LEAK:       return 0x0055;   // Quad-pulse burst with cadence pause
    case CAUSE_WET:        return 0x0015;   // Triple-pulse burst
    case CAUSE_GAS_WARN:   return 0x0005;   // Double-pulse warning tone
    case CAUSE_HEAT_WARN:  return 0x0003;   // Single elongated warning tone
    case CAUSE_UV_WARN:    return 0x0001;   // Short periodic warning pulse
    case CAUSE_PROX_WARN:  return 0x0303;   // Rapid double-pip proximity warning
    case CAUSE_ARC_WARN:   return 0x1111;   // Rapid optical flare warning
    default:               return 0x0000;   // Silent mode: visual feedback only
  }
}

// ---------- model ----------
static void runModel(float* x, AcousticResult& r) {
#if USE_EDGE_IMPULSE
  signal_t sig;
  if (numpy::signal_from_buffer(x, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, &sig) != 0) return;
  ei_impulse_result_t res = { 0 };
  const uint32_t t0 = millis();
  if (run_classifier(&sig, &res, false) != EI_IMPULSE_OK) return;
  r.inferMs = (uint16_t)(millis() - t0);
  float best = -1.0f;
  for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
    const char* lbl = res.classification[i].label;
    const float v = res.classification[i].value;
    switch (roleOfLabel(lbl)) {                    // Accumulate compound class probabilities (e.g. small/large leak)
      case ROLE_LEAK:   r.pLeak   += v; break;
      case ROLE_NOISE:  r.pNoise  += v; break;
      case ROLE_NORMAL: r.pNormal += v; break;
      default: break;
    }
    if (v > best) { best = v; snprintf(r.topLabel, sizeof(r.topLabel), "%s", lbl); }
  }
#if EI_CLASSIFIER_HAS_ANOMALY
  r.anomalous = res.anomaly > ANOMALY_MAX;
#endif
#else
  (void)x;
  const float base = gRmsBase.load();
  if (base > 0.0f) {
    r.pLeak   = clampf((r.rms / base - 1.0f) / (FALLBACK_LEAK_RATIO - 1.0f), 0.0f, 1.0f);
    r.pNormal = 1.0f - r.pLeak;
    snprintf(r.topLabel, sizeof(r.topLabel), "%s", r.pLeak >= 0.5f ? "leak(rms)" : "no_leak(rms)");
  } else {
    snprintf(r.topLabel, sizeof(r.topLabel), "calibrating");
  }
#endif
}

// Process incoming audio window and run detection.
// When USE_EDGE_IMPULSE==0 (RMS fallback), the int16->float copy into gFeat is
// skipped entirely; RMS is computed directly from the ring buffer to avoid a
// 16 KB unnecessary memory write every 500 ms on Core 0.
static void inferenceStep() {
  const uint32_t head = gHead.load(std::memory_order_acquire);
  if (head < gWin) return;                         // Wait until circular buffer accumulates a full window
  const uint32_t start = head - gWin;

  AcousticResult r;
  memset(&r, 0, sizeof(r));

#if USE_EDGE_IMPULSE
  // TinyML path: copy ring buffer to float feature array for model input.
  for (uint32_t i = 0; i < gWin; i++) gFeat[i] = (float)gRing[(start + i) & gRingMask];
  r.rms = rmsOf(gFeat, gWin);
#else
  // RMS fallback path: compute energy directly from the int16 ring buffer.
  // No float copy needed — avoids 16 KB write every hop interval.
  r.rms = ringRms(gRing, start, gWin);
  (void)gFeat;  // gFeat allocated but unused in fallback mode
#endif

#if USE_REFERENCE_SENSOR
  r.refRms = ringRms(gRefRing, start, gWin);
#endif
  runModel(gFeat, r);
  xQueueOverwrite(gResultQ, &r);
}

static void inferenceTask(void*) {
  for (;;) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);       // Triggered by sampler upon hop completion
    inferenceStep();
  }
}

// ---------- gas helpers (Rs/R0, optional ppm) ----------
static float mqRs(float counts) {                  // Approximate sensor resistance from ADC counts (kOhm)
  const float v = counts / 4095.0f * 3.3f * GAS_DIV_FACTOR;
  if (v < 0.05f || v >= GAS_VCC) return 0.0f;
  return GAS_RL_KOHM * (GAS_VCC - v) / v;
}
static float gasRatio() {                          // Normalized sensor resistance ratio Rs/R0
  const float r0 = mqRs(app.gas.base), rs = mqRs(app.gas.f.ema);
  return (r0 > 0.0f && rs > 0.0f) ? rs / r0 : 0.0f;
}
static float gasPpm() {                            // Uncalibrated fallback code
#if GAS_CAL_VALID
  const float r = gasRatio();
  return r > 0.0f ? GAS_PPM_A * powf(r, GAS_PPM_B) : 0.0f;
#else
  return -1.0f;
#endif
}
static int gasDelta() { return (int)(app.gas.f.ema - app.gas.base); }
static int uvDelta()  { return (int)(app.uv.f.ema - app.uv.base); }

// ---------- logging (HTTP(S) POST to backend, background task) ----------
static uint32_t nowEpoch() {
  const time_t t = time(nullptr);
  return t > 1700000000 ? (uint32_t)t : 0;         // Epoch timestamp (0 indicates pending NTP synchronization)
}
static uint32_t newSessionId() { const uint32_t e = nowEpoch(); return e ? e : esp_random(); }

static void enqueueLog(const LogItem& it) {
#if DEBUG_SERIAL
  Serial.printf("[log] %s %s\n", it.trainee, it.json);
#endif
  if (!gLogQ) return;
  if (xQueueSend(gLogQ, &it, 0) != pdTRUE) {
    // Queue full: only drop the oldest item if it is non-critical (routine snap).
    // If the oldest item is critical (alarm/session boundary), discard the incoming
    // item instead — unless the incoming item is itself critical, in which case
    // we still drop the oldest to preserve the most recent alarm.
    LogItem peeked;
    if (xQueuePeek(gLogQ, &peeked, 0) == pdTRUE) {
      if (!peeked.critical || it.critical) {
        // Drop the oldest: either it is non-critical, or both are critical (keep newest).
        LogItem dropped;
        xQueueReceive(gLogQ, &dropped, 0);
        xQueueSend(gLogQ, &it, 0);
      }
      // else: oldest is critical, incoming is non-critical — silently drop incoming.
    }
  }
}

static void logEvent(const char* ev, uint32_t now) {
  if (!app.sess.active) return;
  LogItem it;
  it.session = app.sess.id; it.kind = LOGK_EVENT;
  // Critical events: session boundaries and active danger alarms must survive queue saturation.
  it.critical = (app.alert == ALERT_DANGER ||
                 strncmp(ev, "session_start", 13) == 0 ||
                 strncmp(ev, "session_stop",  12) == 0);
  snprintf(it.trainee, sizeof(it.trainee), "%s", gTrainee);
  const int n = snprintf(it.json, sizeof(it.json),
    "{\"t\":%lu,\"up\":%lu,\"ev\":\"%s\",\"device\":\"%s\",\"alert\":\"%s\",\"cause\":\"%s\",\"lbl\":\"%s\","
    "\"pl\":%.2f,\"rms\":%.1f,\"gas\":%d,\"gr\":%.2f,\"tc\":%.1f,\"uv\":%d,\"wet\":%d,\"dist\":%d,\"vbat\":%.2f,\"hz\":%d,\"hz_c\":%u}",
    (unsigned long)nowEpoch(), (unsigned long)(now - app.sess.startMs), ev, DEVICE_ID, alertName(app.alert),
    causeName(app.cause), app.label, app.pLeak, app.rmsEma, gasDelta(), gasRatio(),
    app.heat.temp, uvDelta(), app.moist.wet.state ? 1 : 0, (int)app.distMm, app.vBat, app.hzState, (unsigned)app.hzConf);
  if (n <= 0 || n >= (int)sizeof(it.json)) return;
  enqueueLog(it);
}

static void logSummary(uint32_t now) {
  LogItem it;
  it.session = app.sess.id; it.kind = LOGK_SUMMARY;
  it.critical = true;  // Session summaries are always critical — preserve over routine snaps.
  snprintf(it.trainee, sizeof(it.trainee), "%s", gTrainee);
  const int n = snprintf(it.json, sizeof(it.json),
    "{\"t\":%lu,\"dur_s\":%lu,\"windows\":%lu,\"leak_events\":%lu,\"gas_events\":%lu,\"wet_events\":%lu,"
    "\"heat_events\":%lu,\"uv_events\":%lu,\"noise_windows\":%lu,\"max_leak_p\":%.2f,"
    "\"trainee\":\"%s\",\"device\":\"%s\",\"fw\":\"%s\"}",
    (unsigned long)nowEpoch(), (unsigned long)((now - app.sess.startMs) / 1000UL),
    (unsigned long)app.sess.windows, (unsigned long)app.sess.leakEvents, (unsigned long)app.sess.gasEvents,
    (unsigned long)app.sess.wetEvents, (unsigned long)app.sess.heatEvents, (unsigned long)app.sess.uvEvents,
    (unsigned long)app.sess.noiseWindows, app.sess.maxLeakP, it.trainee, DEVICE_ID, FW_VERSION);
  if (n <= 0 || n >= (int)sizeof(it.json)) return;
  enqueueLog(it);
}

#if ENABLE_WIFI_LOGGING
static WiFiClient gPlain;                          // Non-TLS HTTP client transport

static bool sendItem(WiFiClientSecure& secure, LogItem& it) {
  char url[240];
  const int n = snprintf(url, sizeof(url), "%s/api/log?trainee=%s&session=%lu&kind=%s&device=%s", BACKEND_URL,
                         it.trainee, (unsigned long)it.session, it.kind == LOGK_SUMMARY ? "summary" : "event", DEVICE_ID);
  if (n <= 0 || n >= (int)sizeof(url)) return true;            // Invalid request target URL: discard frame
  const bool https = strncmp(url, "https", 5) == 0;
  WiFiClient& cl = https ? static_cast<WiFiClient&>(secure) : gPlain;
  HTTPClient http;
  if (!http.begin(cl, url)) {
#if DEBUG_SERIAL
    Serial.printf("[http] begin failed for %s\n", url);
#endif
    return false;
  }
  http.setConnectTimeout(5000);
  http.setTimeout(8000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Key", DEVICE_KEY);
  const int code = http.POST((uint8_t*)it.json, strlen(it.json));
#if DEBUG_SERIAL
  if (code != 200) {
    Serial.printf("[http] POST error: code=%d (%s)\n", code, http.errorToString(code).c_str());
  } else {
    Serial.printf("[http] POST success (200 OK): %s\n", it.kind == LOGK_SUMMARY ? "summary" : "event");
  }
#endif
  http.end();
  return code == 200;                                          // Server deduplicates idempotently: safe to retry
}

static void uploaderTask(void*) {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  WiFiClientSecure secure;
#if VERIFY_TLS_CERT
  // Verified Root CA for https://naadyantra.onrender.com (GlobalSign ECC Root CA - R4 / GTS WE1 chain)
  static const char RENDER_ROOT_CA[] PROGMEM =
    "-----BEGIN CERTIFICATE-----\n"
    "MIIB3DCCAYOgAwIBAgINAgPlfvU/k/2lCSGypjAKBggqhkjOPQQDAjBQMSQwIgYD\n"
    "VQQLExtHbG9iYWxTaWduIEVDQyBSb290IENBIC0gUjQxEzARBgNVBAoTCkdsb2Jh\n"
    "bFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTIxMTEzMDAwMDAwWhcNMzgw\n"
    "MTE5MDMxNDA3WjBQMSQwIgYDVQQLExtHbG9iYWxTaWduIEVDQyBSb290IENBIC0g\n"
    "UjQxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wWTAT\n"
    "BgcqhkjOPQIBBggqhkjOPQMBBwNCAAS4xnnTj2wlDp8uORkcA6SumuU5BwkWymOx\n"
    "uYb4ilfBV85C+nOh92VC/x7BALJucw7/xyHlGKSq2XE/qNS5zowdo0IwQDAOBgNV\n"
    "HQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUVLB7rUW44kB/\n"
    "+wpu+74zyTyjhNUwCgYIKoZIzj0EAwIDRwAwRAIgIk90crlgr/HmnKAWBVBfw147\n"
    "bmF0774BxL4YSFlhgjICICadVGNA3jdgUM/I2O2dgq43mLyjj0xMqTQrbO/7lZsm\n"
    "-----END CERTIFICATE-----\n";
  secure.setCACert(RENDER_ROOT_CA);
#else
  // Development/Testing bench mode
  secure.setInsecure();
#endif
  bool ntpStarted = false;
  uint32_t lastKick = millis();
  // Progressive backoff: start at 5s, double on each miss, cap at 60s.
  // This prevents the 500 ms Wi-Fi retry storm from flooding the radio stack.
  uint32_t reconnectBackoffMs = 5000;
  for (;;) {
    if (WiFi.status() != WL_CONNECTED) {
      gWifiUp = false;
      if (millis() - lastKick > reconnectBackoffMs) {
        lastKick = millis();
        WiFi.disconnect();
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
        reconnectBackoffMs = (reconnectBackoffMs <= 30000) ? reconnectBackoffMs * 2 : 60000;
      }
      vTaskDelay(pdMS_TO_TICKS(500));
      continue;
    }
    // Connected: reset backoff.
    reconnectBackoffMs = 5000;
    gWifiUp = true;
    if (!ntpStarted) { configTime(0, 0, "pool.ntp.org", "time.google.com"); ntpStarted = true; }
    LogItem it;
    if (xQueueReceive(gLogQ, &it, pdMS_TO_TICKS(500)) != pdTRUE) continue;
    if (!sendItem(secure, it)) {
      secure.stop(); gPlain.stop();
      xQueueSendToFront(gLogQ, &it, 0);            // Push back to queue head for subsequent retry
      vTaskDelay(pdMS_TO_TICKS(3000));
    }
  }
}
#endif  // ENABLE_WIFI_LOGGING

// ---------- outputs: LED / buzzer / vibration / OLED ----------
static void flashMessage(const char* m, uint32_t now) {
  snprintf(app.msg, sizeof(app.msg), "%s", m);
  app.msgUntil = now + 2000;
}

static void setBuzzer(bool on) {
  if (on == app.buzzOn) return;
  app.buzzOn = on;
#if BUZZER_PASSIVE
  #if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
    ledcWriteTone(PIN_BUZZER, on ? BUZZER_FREQ_HZ : 0);
  #else
    ledcWriteTone(0, on ? BUZZER_FREQ_HZ : 0);
  #endif
#else
  digitalWrite(PIN_BUZZER, on ? HIGH : LOW);
#endif
}

// Proximity audio localization feedback (pulse frequency increases with proximity)
// Acoustic signal strength ratio relative to calibrated baseline
// Thermal and optical exposure level tracking
static void cueBeep(uint32_t now) {
  if (app.alert == ALERT_DANGER || app.cause == CAUSE_AMBIENT) return;   // Active danger alarms override localization audio
  float k = 0.0f;
  const float base = gRmsBase.load();
  if (base > 0.0f && app.rmsCal && app.role != ROLE_NOISE) {
    const float ratio = app.rmsEma / base;
    k = clampf((ratio - CUE_RMS_START_RATIO) / (CUE_RMS_FULL_RATIO - CUE_RMS_START_RATIO), 0.0f, 1.0f);
  }
#if HAS_HEAT_SENSOR
  if (app.heat.f.primed && !app.heat.fault.state)
    k = fmaxf(k, clampf((app.heat.temp - HEAT_CUE_START_C) / (HEAT_ALARM_C - HEAT_CUE_START_C), 0.0f, 1.0f));
#endif
#if HAS_UV_SENSOR
  if (app.uv.cal)
    k = fmaxf(k, clampf(((float)uvDelta() - UV_WARN_DELTA * 0.5f) / (UV_ALARM_DELTA - UV_WARN_DELTA * 0.5f), 0.0f, 1.0f));
#endif
  if (k < 0.02f) return;
  const uint32_t gap = (uint32_t)((float)CUE_GAP_SLOW_MS - k * (float)(CUE_GAP_SLOW_MS - CUE_GAP_FAST_MS));
  if (now - gLastCue >= gap) {
    gLastCue = now;
    if (app.beepUntil < now + CUE_BEEP_MS) app.beepUntil = now + CUE_BEEP_MS;
  }
}

static void driveOutputs(uint32_t now) {
  digitalWrite(PIN_LED_GREEN,  app.alert == ALERT_OK ? HIGH : LOW);
  digitalWrite(PIN_LED_YELLOW, app.alert == ALERT_CAUTION ? HIGH : LOW);
  digitalWrite(PIN_LED_RED,    (app.alert == ALERT_DANGER && ((now / 250) & 1)) ? HIGH : LOW);
  digitalWrite(PIN_VIBRATION,  slotOn(app.vibPat, now) ? HIGH : LOW);
  setBuzzer(slotOn(app.buzzPat, now) || now < app.beepUntil);
}

static void refreshDisplay(uint32_t now) {
  // Throttled to 500 ms (was 250 ms). The SSD1306 framebuffer transfer at 100 kHz
  // I2C consumes ~100 ms per frame. Halving the rate frees ~5% of I2C bus time
  // and reduces Core 1 loop overhead. Alert-state changes still appear within 500 ms.
  const bool alertChanged = (app.alert != app._lastOledAlert || app.cause != app._lastOledCause);
  if (!gOledOk || (now - app.lastOledMs < (alertChanged ? 100u : 500u))) return;
  app.lastOledMs = now;
  char b[32];
  gOled.clearDisplay();
  gOled.setTextColor(SSD1306_WHITE);

  // Header: Trainee ID, elapsed session time, battery and network status
  gOled.setTextSize(1);
  gOled.setCursor(0, 0);
  if (app.sess.active) {
    const unsigned long s = (now - app.sess.startMs) / 1000UL;
    snprintf(b, sizeof(b), "%s %02lu:%02lu", gTrainee, s / 60, s % 60);
  } else {
    snprintf(b, sizeof(b), "%s IDLE", gTrainee);
  }
  gOled.print(b);
  gOled.setCursor(76, 0);
  if (app.batLowWarn && ((now / 500) & 1)) {
    gOled.print("!BAT ");
  } else if (app.vBat > 0.1f) {
    snprintf(b, sizeof(b), "%.1fV ", app.vBat);
    gOled.print(b);
  }
  gOled.print(gWifiUp ? "WiFi" : "----");

  // Primary status readouts
  gOled.setTextSize(2);
  const char* t = causeText(app.cause);
  int16_t x1, y1; uint16_t w, h;
  gOled.getTextBounds(t, 0, 0, &x1, &y1, &w, &h);
  gOled.setCursor((128 - (int)w) / 2, 13);
  gOled.print(t);

  // Normalized confidence progress indicator
  float conf = app.pNormal;
  if (app.cause == CAUSE_LEAK) conf = app.pLeak;
  else if (app.cause == CAUSE_NOISE) conf = app.pNoise;
  else if (app.cause != CAUSE_NONE) conf = fmaxf(app.pLeak, fmaxf(app.pNoise, app.pNormal));
  gOled.drawRect(0, 34, 128, 8, SSD1306_WHITE);
  gOled.fillRect(2, 36, (int)(clampf(conf, 0, 1) * 124), 4, SSD1306_WHITE);

  // Secondary telemetry readouts: Distance, Gas, Lux, and TinyML State
  gOled.setTextSize(1);
  gOled.setCursor(0, 46);
  if (now < app.msgUntil) {
    snprintf(b, sizeof(b), "%s", app.msg);
  } else {
    char distBuf[12];
    if (app.distMm > 0 && app.distMm < 2500) snprintf(distBuf, sizeof(distBuf), "D:%dmm", app.distMm);
    else snprintf(distBuf, sizeof(distBuf), "D:---");
    snprintf(b, sizeof(b), "%s G:%+d L:%.0f", distBuf, gasDelta(), app.lux);
  }
  gOled.print(b);

  gOled.setCursor(0, 56);
  if (app.faultMask) {
    snprintf(b, sizeof(b), "CHK:%s%s%s%s", (app.faultMask & 1) ? " piezo" : "", (app.faultMask & 2) ? " gas" : "",
                                           (app.faultMask & 4) ? " data" : "", (app.faultMask & 8) ? " heat" : "");
  } else {
#if USE_TINYML_HAZARD_FUSION
    static const char* const HZ_NAMES[5] = {"NORM", "ARC", "PROX", "GAS", "HEAT"};
    const char* hzLbl = (app.hzState >= 0 && app.hzState < 5) ? HZ_NAMES[app.hzState] : "?";
    snprintf(b, sizeof(b), "ML:%s %u%% RMS:%.0f", hzLbl, (unsigned)app.hzConf, app.rmsEma);
#else
    snprintf(b, sizeof(b), "RMS %.0f L%.0f%% N%.0f%%", app.rms, app.pLeak * 100, app.pNoise * 100);
#endif
  }
  gOled.print(b);

  const bool inv = (app.alert == ALERT_DANGER) && ((now / 500) & 1);   // Invert display during critical danger alerts
  if (inv != app.oledInv) { gOled.invertDisplay(inv); app.oledInv = inv; }
  gOled.display();
  // Track last-rendered state so next call can skip unchanged frames.
  app._lastOledAlert = app.alert;
  app._lastOledCause = app.cause;
}

// ---------- MLX90614 Direct I2C SMBus Driver ----------
#if HAS_HEAT_SENSOR
static bool mlxReadObjectC(float& c) {
  Wire.beginTransmission(MLX_ADDR);
  Wire.write(0x07);                                  // Target object temperature register
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((uint8_t)MLX_ADDR, (uint8_t)3) != 3) return false;
  const uint8_t lo = Wire.read(), hi = Wire.read();
  (void)Wire.read();                                 // Discard packet error code
  const uint16_t raw = (uint16_t)lo | ((uint16_t)hi << 8);
  if (raw & 0x8000) return false;                    // Sensor internal error flag bit
  c = raw * 0.02f - 273.15f;
  return true;
}
#endif

static void pollHeat(uint32_t now) {
#if HAS_HEAT_SENSOR
  if (now - app.heat.lastMs < 250) return;           // 4 Hz
  app.heat.lastMs = now;
  float c = 0;
  const bool ok = mlxReadObjectC(c);
  app.heat.fault.update(!ok);
  if (!ok) return;
  app.heat.f.feed(c, 0.5f);
  app.heat.temp = app.heat.f.ema;
  app.heat.level = levelFrom(app.heat.temp, HEAT_WARN_C, HEAT_ALARM_C, app.heat.level);
#else
  (void)now;
#endif
}

// ---------- application logic ----------
static void gasFeed(GasState& g, uint16_t raw, uint32_t now) {
  g.f.feed(raw, 0.2f);
  const bool railed = raw < 20;                    // Detect sensor ground rail or open circuit condition
  g.fault.update(railed);
  if (g.wasFault && !g.fault.state) {              // Recovered from fault; schedule baseline recalibration
    app.calGasPending = true; app.calGasAt = now + 3000; g.cal = false; g.level = GAS_OK;
  }
  g.wasFault = g.fault.state;
  if (!g.cal || g.fault.state || railed) return;
  const float delta = g.f.ema - g.base;
  if (g.f.ema < g.base) g.base = g.f.ema;                              // Follow baseline downward drift (clean air settling)
  else if (delta < GAS_WARN_DELTA * 0.5f) g.base += 0.0005f * delta;   // Slow upward baseline compensation filter
#if GAS_CAL_VALID
  g.level = levelFrom(gasPpm() / GAS_LEL_PPM * 100.0f, GAS_WARN_LEL_PCT, GAS_ALARM_LEL_PCT, g.level);
#else
  g.level = levelFrom(g.f.ema - g.base, GAS_WARN_DELTA, GAS_ALARM_DELTA, g.level);
#endif
}

static void moistFeed(MoistState& m, uint16_t raw) {
  m.f.feed(raw, 0.2f);
  if (!m.cal) return;
  m.wet.update(fabsf(m.f.ema - m.base) >= MOIST_WET_DELTA);
}

static void uvFeed(UvState& u, uint16_t raw) {
  u.f.feed(raw, 0.3f);
  if (!u.cal) return;
  const float delta = u.f.ema - u.base;
  if (u.f.ema < u.base) u.base = u.f.ema;
  else if (delta < UV_WARN_DELTA * 0.5f) u.base += 0.0005f * delta;    // Ambient optical baseline drift compensation
  u.level = levelFrom(u.f.ema - u.base, UV_WARN_DELTA, UV_ALARM_DELTA, u.level);
}

static void pollSlowSensors(uint32_t now) {
  const uint32_t seq = gSlowSeq.load(std::memory_order_acquire);
  if (seq == app.lastSlowSeq) return;
  app.lastSlowSeq = seq;
#if HAS_GAS_SENSOR
  gasFeed(app.gas, gGasRaw.load(std::memory_order_relaxed), now);
#endif
#if HAS_MOISTURE_SENSOR
  moistFeed(app.moist, gMoistRaw.load(std::memory_order_relaxed));
#endif
#if HAS_UV_SENSOR
  uvFeed(app.uv, gUvRaw.load(std::memory_order_relaxed));
#endif
  (void)now;
}

// ---------- Battery & Power Management ----------
static uint16_t readBatteryMv() {
  const uint32_t raw = analogRead(PIN_BATTERY);
  // 12-bit ADC -> 0..4095 over ~3.3V (with 11dB attenuation)
  // Multiplied by divider factor (BAT_DIV_FACTOR = 2.0 for 100k/100k)
  const float vPin = (float)raw / 4095.0f * 3.3f;
  const float vBat = vPin * BAT_DIV_FACTOR;
  return (uint16_t)(vBat * 1000.0f);
}

static void shutdownDevice() {
#if DEBUG_SERIAL
  Serial.println("[pwr] CRITICAL LOW BATTERY! Disconnecting load and sleeping...");
  Serial.flush();
#endif
  // 1. OLED shutdown notification
  if (gOledOk) {
    gOled.clearDisplay();
    gOled.setTextColor(SSD1306_WHITE);
    gOled.setTextSize(2);
    gOled.setCursor(4, 16);
    gOled.print("BATTERY LOW");
    gOled.setTextSize(1);
    gOled.setCursor(16, 42);
    gOled.print("SHUTTING DOWN");
    gOled.display();
    delay(1500);
    gOled.ssd1306_command(SSD1306_DISPLAYOFF);
  }
  // 2. Extinguish all indicators and outputs
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_YELLOW, LOW);
  digitalWrite(PIN_LED_RED, LOW);
  digitalWrite(PIN_VIBRATION, LOW);
  setBuzzer(false);
  // 3. Cut off MT3608 boost rail (MQ-2 heater 0 mA)
  digitalWrite(PIN_BOOST_EN, LOW);
#if HAS_MOISTURE_SENSOR && MOIST_POWER_GATED
  digitalWrite(PIN_MOIST_PWR, LOW);
#endif
  // 4. Disable Wi-Fi radio to conserve remaining capacity
#if ENABLE_WIFI_LOGGING
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
#endif
  // 5. Deep sleep indefinitely until external recharge or hard power reset
  esp_deep_sleep_start();
}

static void pollBattery(uint32_t now) {
  static uint32_t lastBatMs = 0;
  if (now - lastBatMs < 1000) return;  // 1 Hz battery check
  lastBatMs = now;
  const uint16_t mv = readBatteryMv();
  if (app.vBatMv == 0) app.vBatMv = mv;
  else app.vBatMv = (uint16_t)(0.8f * (float)app.vBatMv + 0.2f * (float)mv);
  app.vBat = (float)app.vBatMv / 1000.0f;

  // Low battery warning with hysteresis
  if (!app.batLowWarn && app.vBatMv <= BAT_WARN_MV) {
    app.batLowWarn = true;
  } else if (app.batLowWarn && app.vBatMv >= BAT_CLEAR_MV) {
    app.batLowWarn = false;
  }

  // Critical cutoff with 10-sample debouncer
  if (app.vBatMv <= BAT_SHUTDOWN_MV) {
    if (++app.batShutdownCnt >= BAT_SHUTDOWN_SAMPLES) {
      shutdownDevice();
    }
  } else {
    app.batShutdownCnt = 0;
  }
}

// ---------- Zero-Dependency VL53L0X Time-of-Flight Driver ----------
#if HAS_DISTANCE_SENSOR
static bool gVlOk = false;
static uint8_t gVlStopVar = 0;

static bool vl_w(uint8_t reg, uint8_t v) {
  Wire.beginTransmission(VL53_ADDR);
  Wire.write(reg); Wire.write(v);
  return (Wire.endTransmission() == 0);
}

static uint8_t vl_r(uint8_t reg) {
  Wire.beginTransmission(VL53_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return 0;
  if (Wire.requestFrom((uint8_t)VL53_ADDR, (uint8_t)1) != 1) return 0;
  return Wire.read();
}

static uint16_t vl_r16(uint8_t reg) {
  Wire.beginTransmission(VL53_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return 0;
  if (Wire.requestFrom((uint8_t)VL53_ADDR, (uint8_t)2) != 2) return 0;
  uint8_t hi = Wire.read(), lo = Wire.read();
  return (uint16_t)((hi << 8) | lo);
}

static bool vl_wmulti(uint8_t reg, const uint8_t *d, uint8_t n) {
  Wire.beginTransmission(VL53_ADDR);
  Wire.write(reg); Wire.write(d, n);
  return (Wire.endTransmission() == 0);
}

static bool vl_rmulti(uint8_t reg, uint8_t *d, uint8_t n) {
  Wire.beginTransmission(VL53_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((uint8_t)VL53_ADDR, n) != n) return false;
  for (uint8_t i = 0; i < n; ++i) d[i] = Wire.read();
  return true;
}

static bool vl_wait_for(uint8_t reg, uint8_t mask, bool want_set, uint32_t timeout_ms) {
  const uint32_t t0 = millis();
  for (;;) {
    const bool set = (vl_r(reg) & mask) != 0;
    if (set == want_set) return true;
    if (millis() - t0 > timeout_ms) return false;
    delay(1);
  }
}

static bool vl_single_ref_cal(uint8_t vhv_init) {
  vl_w(0x00, (uint8_t)(0x01 | vhv_init));
  if (!vl_wait_for(0x13, 0x07, true, 500)) return false;
  vl_w(0x0B, 0x01);
  vl_w(0x00, 0x00);
  return true;
}

static bool vl_get_spad_info(uint8_t *count, bool *aperture) {
  vl_w(0x80, 0x01); vl_w(0xFF, 0x01); vl_w(0x00, 0x00);
  vl_w(0xFF, 0x06); vl_w(0x83, vl_r(0x83) | 0x04);
  vl_w(0xFF, 0x07); vl_w(0x81, 0x01);
  vl_w(0x80, 0x01);
  vl_w(0x94, 0x6B); vl_w(0x83, 0x00);
  const uint32_t t0 = millis();
  while (vl_r(0x83) == 0x00) { if (millis() - t0 > 500) return false; delay(1); }
  vl_w(0x83, 0x01);
  const uint8_t tmp = vl_r(0x92);
  *count = tmp & 0x7F;
  *aperture = (tmp >> 7) & 1;
  vl_w(0x81, 0x00); vl_w(0xFF, 0x06); vl_w(0x83, vl_r(0x83) & ~0x04);
  vl_w(0xFF, 0x01); vl_w(0x00, 0x01);
  vl_w(0xFF, 0x00); vl_w(0x80, 0x00);
  return true;
}

static bool vl_init() {
  if (vl_r(0xC0) != 0xEE) return false;
  vl_w(0x89, vl_r(0x89) | 0x01);
  vl_w(0x88, 0x00);
  vl_w(0x80, 0x01); vl_w(0xFF, 0x01); vl_w(0x00, 0x00);
  gVlStopVar = vl_r(0x91);
  vl_w(0x00, 0x01); vl_w(0xFF, 0x00); vl_w(0x80, 0x00);
  vl_w(0x60, vl_r(0x60) | 0x12);
  const uint8_t lim[2] = { 0x00, 0x20 };
  vl_wmulti(0x44, lim, 2);
  vl_w(0x01, 0xFF);

  uint8_t spad_count; bool aperture;
  if (!vl_get_spad_info(&spad_count, &aperture)) return false;
  uint8_t map[6];
  if (!vl_rmulti(0xB0, map, 6)) return false;
  vl_w(0xFF, 0x01); vl_w(0x4F, 0x00); vl_w(0x4E, 0x2C);
  vl_w(0xFF, 0x00); vl_w(0xB6, 0xB4);
  const uint8_t first = aperture ? 12 : 0;
  uint8_t enabled = 0;
  for (uint8_t i = 0; i < 48; ++i) {
    if (i < first || enabled == spad_count) map[i / 8] &= (uint8_t)~(1u << (i % 8));
    else if ((map[i / 8] >> (i % 8)) & 1) ++enabled;
  }
  vl_wmulti(0xB0, map, 6);

  static const uint8_t tune[][2] = {
    {0xFF,0x01},{0x00,0x00},{0xFF,0x00},{0x09,0x00},{0x10,0x00},{0x11,0x00},{0x24,0x01},{0x25,0xFF},
    {0x75,0x00},{0xFF,0x01},{0x4E,0x2C},{0x48,0x00},{0x30,0x20},{0xFF,0x00},{0x30,0x09},{0x54,0x00},
    {0x31,0x04},{0x32,0x03},{0x40,0x83},{0x46,0x25},{0x60,0x00},{0x27,0x00},{0x50,0x06},{0x51,0x00},
    {0x52,0x96},{0x56,0x08},{0x57,0x30},{0x61,0x00},{0x62,0x00},{0x64,0x00},{0x65,0x00},{0x66,0xA0},
    {0xFF,0x01},{0x22,0x32},{0x47,0x14},{0x49,0xFF},{0x4A,0x00},{0xFF,0x00},{0x7A,0x0A},{0x7B,0x00},
    {0x78,0x21},{0xFF,0x01},{0x23,0x34},{0x42,0x00},{0x44,0xFF},{0x45,0x26},{0x46,0x05},{0x40,0x40},
    {0x0E,0x06},{0x20,0x1A},{0x43,0x40},{0xFF,0x00},{0x34,0x03},{0x35,0x44},{0xFF,0x01},{0x31,0x04},
    {0x4B,0x09},{0x4C,0x05},{0x4D,0x04},{0xFF,0x00},{0x44,0x00},{0x45,0x20},{0x47,0x08},{0x48,0x28},
    {0x67,0x00},{0x70,0x04},{0x71,0x01},{0x72,0xFE},{0x76,0x00},{0x77,0x00},{0xFF,0x01},{0x0D,0x01},
    {0xFF,0x00},{0x80,0x01},{0x01,0xF8},{0xFF,0x01},{0x8E,0x01},{0x00,0x01},{0xFF,0x00},{0x80,0x00},
  };
  for (size_t i = 0; i < sizeof(tune) / sizeof(tune[0]); ++i) vl_w(tune[i][0], tune[i][1]);

  vl_w(0x0A, 0x04);
  vl_w(0x84, vl_r(0x84) & ~0x10);
  vl_w(0x0B, 0x01);
  vl_w(0x01, 0xE8);
  vl_w(0x01, 0x01); if (!vl_single_ref_cal(0x40)) return false;
  vl_w(0x01, 0x02); if (!vl_single_ref_cal(0x00)) return false;
  vl_w(0x01, 0xE8);

  vl_w(0x80, 0x01); vl_w(0xFF, 0x01); vl_w(0x00, 0x00);
  vl_w(0x91, gVlStopVar);
  vl_w(0x00, 0x01); vl_w(0xFF, 0x00); vl_w(0x80, 0x00);
  vl_w(0x00, 0x02);
  return true;
}

static bool vl_try_read(uint16_t *mm) {
  if ((vl_r(0x13) & 0x07) == 0) return false;
  *mm = vl_r16(0x14 + 10);
  vl_w(0x0B, 0x01);
  return true;
}
#endif

// ---------- Zero-Dependency BH1750 Ambient Light Driver ----------
#if HAS_BH1750_SENSOR
static bool gBh1750Ok = false;

static bool bh1750Init() {
  Wire.beginTransmission(BH1750_ADDR);
  Wire.write(0x10); // Continuous H-Resolution mode
  gBh1750Ok = (Wire.endTransmission() == 0);
  return gBh1750Ok;
}

static bool bh1750ReadLux(float &lux) {
  if (Wire.requestFrom((uint8_t)BH1750_ADDR, (uint8_t)2) != 2) return false;
  uint16_t raw = ((uint16_t)Wire.read() << 8) | Wire.read();
  lux = (float)raw / 1.2f;
  return true;
}
#endif

static void pollDistance(uint32_t now) {
#if HAS_DISTANCE_SENSOR
  static uint32_t lastDistPollMs = 0;
  if (!gVlOk || (now - lastDistPollMs < 50)) return;
  lastDistPollMs = now;
  uint16_t mm = 0;
  if (vl_try_read(&mm)) {
    if (mm > 20 && mm < 2000) {
      if (app.distMm > 0 && app.lastDistMs > 0 && now > app.lastDistMs) {
        float dt = (float)(now - app.lastDistMs) / 1000.0f;
        if (dt > 0.01f) app.distVel = ((float)mm - (float)app.distMm) / dt;
      }
      app.distMm = (int16_t)mm;
      app.lastDistMs = now;
    }
  }
#else
  (void)now;
  app.distMm = -1;  // -1 indicates distance sensor disabled or not fitted
#endif
}

static void pollLight(uint32_t now) {
#if HAS_BH1750_SENSOR
  static uint32_t lastLuxMs = 0;
  if (!gBh1750Ok || (now - lastLuxMs < 100)) return;
  lastLuxMs = now;
  float lx = 0.0f;
  if (bh1750ReadLux(lx)) app.lux = lx;
#else
  (void)now;
#endif
}

static void runCalibration(uint32_t now) {
  if (app.calFastPending && now >= app.calFastAt && app.rmsPrimed &&
      (!HAS_MOISTURE_SENSOR || app.moist.f.primed) && (!HAS_UV_SENSOR || app.uv.f.primed)) {
    app.moist.base = app.moist.f.ema; app.moist.cal = (HAS_MOISTURE_SENSOR != 0); app.moist.wet = Debounce(10, 20);
    app.uv.base = app.uv.f.ema; app.uv.cal = (HAS_UV_SENSOR != 0); app.uv.level = GAS_OK;
    const float b = app.rmsEma;
    gRmsBase.store(b < MIN_SIGNAL_RMS ? MIN_SIGNAL_RMS : b);
    app.rmsCal = true;
    app.calFastPending = false;
  }
  if (app.calGasPending && now >= app.calGasAt && app.gas.f.primed && !app.gas.fault.state) {
    app.gas.base = app.gas.f.ema; app.gas.cal = true; app.gas.level = GAS_OK;
    app.calGasPending = false;
  }
}

static void requestCalibration(uint32_t now) {
  app.calFastPending = true; app.calFastAt = now + 3000;
  app.moist.cal = false; app.uv.cal = false; app.rmsCal = false;
  if (HAS_GAS_SENSOR) {
    const uint32_t warm = (uint32_t)GAS_WARMUP_S * 1000UL;
    app.calGasPending = true; app.calGasAt = (now + 3000 > warm) ? now + 3000 : warm;
    app.gas.cal = false; app.gas.level = GAS_OK;
  }
  flashMessage("RECALIBRATING...", now);
  app.beepUntil = now + 150;
}

static void pollAcoustic(uint32_t now) {
  AcousticResult r;
  if (xQueueReceive(gResultQ, &r, 0) != pdTRUE) {
    app.stale = app.haveResult && (now - app.lastResultMs > STALE_MS);   // Watchdog timeout for inference pipeline staleness
    return;
  }
  app.haveResult = true; app.stale = false; app.lastResultMs = now; app.resultCount++;
  app.rms = r.rms; app.refRms = r.refRms;
  app.pLeak = r.pLeak; app.pNoise = r.pNoise; app.pNormal = r.pNormal;
  if (!app.rmsPrimed) { app.rmsEma = r.rms; app.rmsPrimed = true; } else app.rmsEma += 0.3f * (r.rms - app.rmsEma);

  Role role = decideRole(r.pLeak, r.pNoise, r.pNormal);
  if (r.anomalous && role == ROLE_NORMAL) role = ROLE_UNCERTAIN;      // Anomaly score downgrades normal classification to uncertain

  const bool noSig = r.rms < MIN_SIGNAL_RMS;
  app.noSignal.update(noSig);
  if (noSig) role = ROLE_UNCERTAIN;

  app.ambient = false;
#if USE_REFERENCE_SENSOR
  if (role == ROLE_LEAK && r.refRms > REF_NOISE_RMS && (r.rms / r.refRms) < REF_MIN_RATIO) {
    app.ambient = true; role = ROLE_UNCERTAIN;                         // Reference microphone ambient noise cancellation
  }
#endif
  app.role = role;
  app.leak.update(role == ROLE_LEAK);
  snprintf(app.label, sizeof(app.label), "%s", r.topLabel);

  if (app.sess.active) {
    app.sess.windows++;
    if (role == ROLE_NOISE) app.sess.noiseWindows++;
    if (r.pLeak > app.sess.maxLeakP) app.sess.maxLeakP = r.pLeak;
  }
}

static void onCauseChange(Cause to, uint32_t now) {
  if (!app.sess.active) return;
  if (to == CAUSE_LEAK)       app.sess.leakEvents++;
  if (to == CAUSE_GAS_ALARM)  app.sess.gasEvents++;
  if (to == CAUSE_WET)        app.sess.wetEvents++;
  if (to == CAUSE_HEAT_ALARM) app.sess.heatEvents++;
  if (to == CAUSE_UV_ALARM)   app.sess.uvEvents++;
  logEvent("state", now);
}

static void updateVerdict(uint32_t now) {
  const bool gasFault  = (HAS_GAS_SENSOR != 0) && app.gas.fault.state;
  const bool gasLive   = (HAS_GAS_SENSOR != 0) && app.gas.cal && !gasFault;
  const bool heatFault = (HAS_HEAT_SENSOR != 0) && app.heat.fault.state;
  const bool heatLive  = (HAS_HEAT_SENSOR != 0) && app.heat.f.primed && !heatFault;
  const bool uvLive    = (HAS_UV_SENSOR != 0) && app.uv.cal;
  FuseIn in;
  in.gasAlarm  = gasLive && app.gas.level == GAS_ALARM;
  in.gasWarn   = gasLive && app.gas.level == GAS_WARN;
  in.gasFault  = gasFault;
  in.heatAlarm = heatLive && app.heat.level == GAS_ALARM;
  in.heatWarn  = heatLive && app.heat.level == GAS_WARN;
  in.heatFault = heatFault;
  in.uvAlarm   = uvLive && app.uv.level == GAS_ALARM;
  in.uvWarn    = uvLive && app.uv.level == GAS_WARN;
  in.leak      = app.leak.state;
  in.wet       = (HAS_MOISTURE_SENSOR != 0) && app.moist.cal && app.moist.wet.state;
  in.noSignal  = app.noSignal.state;
  in.stale     = app.stale;
  in.ambient   = app.ambient;
  in.startup   = !app.haveResult || (!USE_EDGE_IMPULSE && !app.rmsCal);
  in.role      = app.role;
#if USE_TINYML_HAZARD_FUSION
  // Feature index map: 0=distance_mm, 1=distance_velocity, 2=temp_object, 3=temp_ambient, 4=delta_temp, 5=uv_index, 6=gas_ppm_slope
  const float curDist = (app.distMm > 0) ? (float)app.distMm : 300.0f;
  // Map BH1750 ambient lux (0..12,000+ lux) to 0..12 optical flare scale (normal room ~200-500 lux -> 0.2-0.5; torch/arc flash >2000 lux -> >2.0)
  float opticalUv = clampf(app.lux / 1000.0f, 0.0f, 12.0f);
  #if HAS_UV_SENSOR
    opticalUv = (float)uvDelta();
  #endif

  float hzX[HZ_FEATURE_COUNT] = {
    curDist,                                             // 0: distance_mm (from VL53L0X)
    app.distVel,                                         // 1: distance_velocity
    (HAS_HEAT_SENSOR ? app.heat.temp : 25.0f),           // 2: temp_object
    25.0f,                                               // 3: temp_ambient
    (HAS_HEAT_SENSOR ? (app.heat.temp - 25.0f) : 0.0f),   // 4: delta_temp
    opticalUv,                                           // 5: uv_index / optical intensity (from BH1750)
    (HAS_GAS_SENSOR ? (float)gasDelta() : 0.0f)          // 6: gas_ppm_slope (from MQ-2)
  };
  uint8_t hzConf = 0;
  app.hzState = hazard_predict(hzX, &hzConf);
  app.hzConf = hzConf;
  in.hzState = app.hzState;
  in.hzConf = app.hzConf;
#else
  in.hzState = 0;
  in.hzConf = 0;
#endif

  app.faultMask = (in.noSignal ? 1 : 0) | (in.gasFault ? 2 : 0) | (in.stale ? 4 : 0) | (in.heatFault ? 8 : 0);

  const Verdict v = fuse(in);
  const Cause prev = app.cause;
  app.alert = v.alert; app.cause = v.cause;
  app.buzzPat = buzzPattern(v.cause);
  app.vibPat  = (v.alert == ALERT_DANGER) ? app.buzzPat : 0;
  if (v.cause != prev) onCauseChange(v.cause, now);
}

static void startSession(uint32_t now) {
  app.sess = Session();
  app.sess.active = true; app.sess.startMs = now; app.sess.id = newSessionId();
  app.lastSnapMs = now;
  logEvent("session_start", now);
  flashMessage("SESSION START", now);
  app.beepUntil = now + 150;
}

static void stopSession(uint32_t now) {
  logEvent("session_stop", now);
  logSummary(now);
  app.sess.active = false;
  flashMessage("SESSION END", now);
  app.beepUntil = now + 150;
}

static void handleButton(uint32_t now) {
  static bool down = false, longDone = false;
  static uint32_t t0 = 0;
  const bool pressed = digitalRead(PIN_BUTTON) == LOW;
  if (pressed && !down) { down = true; longDone = false; t0 = now; }
  else if (pressed && down && !longDone && now - t0 >= LONG_PRESS_MS) { longDone = true; requestCalibration(now); }
  else if (!pressed && down) {
    down = false;
    if (!longDone && now - t0 >= 40) { if (app.sess.active) stopSession(now); else startSession(now); }   // 40ms mechanical contact debounce filter
  }
}

// Serial Monitor (115200, newline): "id T005"
static void handleSerial(uint32_t now) {
  static char buf[32];
  static uint8_t n = 0;
  while (Serial.available()) {
    const char ch = (char)Serial.read();
    if (ch == '\n' || ch == '\r') {
      buf[n] = 0;
      if (n > 3 && strncmp(buf, "id ", 3) == 0) {
        if (app.sess.active) {
          flashMessage("STOP SESSION 1ST", now);
        } else {
          size_t k = 0;
          char tmp[sizeof(gTrainee)];
          for (const char* p = buf + 3; *p && k < sizeof(tmp) - 1; p++)
            if (isalnum((unsigned char)*p) || *p == '_' || *p == '-') tmp[k++] = *p;   // Sanitize identifier to URL-safe character set
          tmp[k] = 0;
          if (k > 0) { memcpy(gTrainee, tmp, k + 1); flashMessage("ID SET", now); }
        }
      }
      n = 0;
    } else if (n < sizeof(buf) - 1) {
      buf[n++] = ch;
    }
  }
}

static void periodicTasks(uint32_t now) {
  if (app.sess.active && now - app.lastSnapMs >= (uint32_t)SNAPSHOT_EVERY_S * 1000UL) {
    app.lastSnapMs = now;
    logEvent("snap", now);
  }
#if DEBUG_SERIAL
  if (now - app.lastDbgMs >= 5000) {
    app.lastDbgMs = now;
    // Track minimum free heap across lifetime for memory regression detection.
    const uint32_t curHeap = (uint32_t)ESP.getFreeHeap();
    if (curHeap < app.minFreeHeap) app.minFreeHeap = curHeap;
    Serial.printf("[%lus] %s/%s lbl=%s pL=%.2f pN=%.2f rms=%.1f base=%.1f gas=%+d gr=%.2f heat=%.1fC uv=%+d wet=%d dist=%d vbat=%.2f wifi=%d ovr=%lu heap=%lu minHeap=%lu qd=%lu\n",
                  (unsigned long)(now / 1000), alertName(app.alert), causeName(app.cause), app.label,
                  app.pLeak, app.pNoise, app.rms, gRmsBase.load(), gasDelta(), gasRatio(), app.heat.temp, uvDelta(),
                  app.moist.wet.state ? 1 : 0, (int)app.distMm, app.vBat, gWifiUp ? 1 : 0,
                  (unsigned long)gOverruns.load(), (unsigned long)curHeap,
                  (unsigned long)app.minFreeHeap,
                  (unsigned long)uxQueueMessagesWaiting(gLogQ));
  }
#endif
}

static void fatal(const char* msg) {
  Serial.println(msg);
  for (;;) { digitalWrite(PIN_LED_RED, !digitalRead(PIN_LED_RED)); delay(200); }
}

void setup() {
  Serial.begin(115200);
  delay(200);

  pinMode(PIN_LED_GREEN, OUTPUT); pinMode(PIN_LED_YELLOW, OUTPUT); pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_VIBRATION, OUTPUT); pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_BOOST_EN, OUTPUT);
  digitalWrite(PIN_BOOST_EN, HIGH); // Assert gate to power MT3608 boost converter for MQ-2 heater
#if BUZZER_PASSIVE
  #if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 3)
    ledcAttach(PIN_BUZZER, BUZZER_FREQ_HZ, 10);
  #else
    ledcSetup(0, BUZZER_FREQ_HZ, 10);
    ledcAttachPin(PIN_BUZZER, 0);
  #endif
#else
  pinMode(PIN_BUZZER, OUTPUT);
#endif

  app = App();                                     // Initialize runtime state machine
  gHead.store(0); gSlowSeq.store(0); gOverruns.store(0); gRmsBase.store(0.0f);

  setupAdc();
  computeSamplingParams();
  if (!allocateRings()) fatal("[fatal] Ring buffer allocation failed (insufficient SRAM)");
  gFeat = (float*)allocBig(sizeof(float) * gWin);
  if (!gFeat) fatal("[fatal] Feature buffer allocation failed (enable PSRAM or reduce window size)");

  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(100000);                          
  gOledOk = gOled.begin(SSD1306_SWITCHCAPVCC, 0x3C, true, false);   
  if (gOledOk) {
    gOled.clearDisplay(); gOled.setTextColor(SSD1306_WHITE);
    gOled.setTextSize(2); gOled.setCursor(8, 8);  gOled.print("LEAK SENSE");
    gOled.setTextSize(1); gOled.setCursor(8, 32); gOled.print("SIH 2026  v" FW_VERSION);
#if USE_TINYML_HAZARD_FUSION
    gOled.setCursor(8, 48); gOled.print("TinyML RF Fusion ON");
#endif
    gOled.display();
  }

#if HAS_DISTANCE_SENSOR
  gVlOk = vl_init();
#if DEBUG_SERIAL
  Serial.printf("[i2c] VL53L0X distance sensor: %s\n", gVlOk ? "OK" : "NOT FOUND (check 0x29)");
#endif
#endif

#if HAS_BH1750_SENSOR
  gBh1750Ok = bh1750Init();
#if DEBUG_SERIAL
  Serial.printf("[i2c] BH1750 light sensor: %s\n", gBh1750Ok ? "OK" : "NOT FOUND (check 0x23)");
#endif
#endif

  gResultQ = xQueueCreate(1, sizeof(AcousticResult));
  xTaskCreatePinnedToCore(inferenceTask, "infer", 16384, nullptr, 2, &gConsumerTask, 0);
#if ENABLE_WIFI_LOGGING
  gLogQ = xQueueCreate(LOG_QUEUE_LEN, sizeof(LogItem));
  xTaskCreatePinnedToCore(uploaderTask, "upload", 16384, nullptr, 1, nullptr, 0);
#endif

#if DEBUG_SERIAL
  Serial.printf("[boot] v%s fs=%lu win=%lu hop=%lu model=%s ref=%d heat=%d uv=%d\n", FW_VERSION, (unsigned long)gFs,
                (unsigned long)gWin, (unsigned long)gHop, USE_EDGE_IMPULSE ? "EdgeImpulse" : "RMS-fallback",
                USE_REFERENCE_SENSOR, HAS_HEAT_SENSOR, HAS_UV_SENSOR);
#endif
  delay(1200);                                     // Boot splash delay
  startSampling();                                 // Initialize hardware timer and sampling engine
}

void loop() {
  const uint32_t now = millis();
  handleButton(now);
  handleSerial(now);
  pollSlowSensors(now);
  pollBattery(now);
  pollDistance(now);
  pollLight(now);
  pollHeat(now);
  runCalibration(now);
  pollAcoustic(now);
  updateVerdict(now);
  cueBeep(now);
  driveOutputs(now);
  refreshDisplay(now);
  periodicTasks(now);
  delay(5);
}

#endif  // RUN_MODE
