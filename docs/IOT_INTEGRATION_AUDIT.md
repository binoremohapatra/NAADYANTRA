# HazGuard IoT Integration Audit Report

**Date:** 2026-10-16
**Status:** Pre-Hardware Integration Audit
**Objective:** Prepare Flutter app and deployed backend for ESP32 telemetry connectivity

---

## Executive Summary

The HazGuard project has a deployed FastAPI backend with Neon PostgreSQL and a Flutter mobile application. However, critical integration issues exist between the firmware (which targets a local IP) and the cloud-deployed backend. Security vulnerabilities must be addressed before production use. A web dashboard does not exist yet and must be built from scratch.

---

## PART 1: Deployment Configuration Audit

### Backend Deployment Status

**Database:** Neon PostgreSQL (Cloud)
- Connection string: `postgresql://neondb_owner:npg_ESR52ckDljAW@ep-empty-union-b42uyzi6-pooler.c-6.us-east-2.aws.neon.tech/neondb`
- Status: **ACTIVE** - Production cloud database
- **VERIFIED:** SQLite configuration overridden by DATABASE_URL environment variable

**API Server:**
- Default: `0.0.0.0:8000`
- Environment: `development`
- **BLOCKER:** No cloud deployment URL explicitly configured in code. Render/deployment method unknown.

**CORS Configuration:**
```python
allow_origins=["*"]  # Line 53 in main.py
```
- **CRITICAL SECURITY ISSUE:** Wildcard CORS allows any origin. Must be restricted to specific domains for production.

---

## PART 2: Firmware vs Backend Contract Mismatch

### Firmware Configuration (leak_detector.ino lines 64-69)

```cpp
#define BACKEND_URL      "http://192.168.1.10:8000"   // ⚠️ LOCAL IP
#define DEVICE_KEY       "dev-key-123"                // ⚠️ HARDCODED
#define DEVICE_ID        "SIH-DEV-01"
```

**CRITICAL ISSUE:** Firmware targets local LAN IP `192.168.1.10:8000`, but backend is deployed to cloud (Neon PostgreSQL). Firmware will NOT be able to reach the backend without configuration change.

### Flutter API Configuration (app_config.dart line 6)

```dart
static const String productionApiBaseUrl = 'https://hazguard.onrender.com';
```

**ISSUE:** Flutter app points to `hazguard.onrender.com`, but this domain is not verified as the actual deployment. The backend has no explicit Render deployment configuration in code.

### Required Firmware Changes

**Before Hardware Connection:**
1. Change `BACKEND_URL` to actual cloud HTTPS endpoint
2. Change `DEVICE_KEY` to a secure production key
3. Change `DEVICE_ID` to unique device identifier
4. Remove hardcoded WiFi credentials
5. Enable TLS: Remove `secure.setInsecure()` call (line 716 in firmware)

---

## PART 3: Security Audit

### Vulnerabilities Found

| Issue | Location | Severity | Action Required |
|-------|----------|----------|----------------|
| Hardcoded device key | leak_detector.ino:67 | **CRITICAL** | Replace with secure config |
| Local IP in firmware | leak_detector.ino:66 | **CRITICAL** | Update to cloud endpoint |
| Wildcard CORS | backend/main.py:53 | **HIGH** | Restrict to specific domains |
| TLS disabled | leak_detector.ino:716 | **HIGH** | Enable TLS verification |
| Secret key in .env | .env:10 | **HIGH** | Rotate, use env vars, don't commit |
| App name mismatch | app_config.dart:38 | **MEDIUM** | Change to "HazGuard" |

### Credentials Found in .env (MUST BE ROTATED)

```
SECRET_KEY=W4njn1Ma-Z7BUdJXwzl724qsrNPl9ITfjBEVPmlnVXAt8nxnXeirzq4u55xEaes6
DATABASE_URL=postgresql://neondb_owner:npg_ESR52ckDljAW@...
DEVICE_KEY_HASH=$2b$12$hD2jIp.suFfrQCKxpIi49egAWgmOaTM11zfIkzA2JptsF5qJYK59m
```

**ALL ABOVE CREDENTIALS ARE COMPROMISED** and must be:
1. Rotated immediately
2. Removed from version control
3. Moved to environment-specific secrets manager (Render Dashboard)

---

## PART 4: API Contract Verification

### Firmware Telemetry Endpoint

**Route:** `POST /api/log?trainee=<id>&session=<id>&kind=event|summary`
**Headers:** `X-Device-Key: <key>`

**Verified in:** `backend/routers/ingestion.py` (lines 16-111)
- Endpoint exists and is functional
- Device authentication via `X-Device-Key` header
- Auto-registration of devices
- Idempotency via SHA-256 hashing
- **STATUS:** ✅ WORKING

### Flutter API Constants

**Verified in:** `mobile_app/lib/core/constants/api_constants.dart`
- All API endpoints defined
- Matches backend routes
- **STATUS:** ✅ ALIGNED

### Alert Severity Compatibility

**Firmware (leak_detector.ino):**
- `ALERT_OK` (enum value 0)
- `ALERT_CAUTION` (enum value 1)
- `ALERT_DANGER` (enum value 2)

**Backend (schemas.py lines 7-10):**
```python
class AlertEnum(str, Enum):
    OK = "OK"
    CAUTION = "CAUTION"
    DANGER = "DANGER"
```

**STATUS:** ✅ COMPATIBLE

---

## PART 5: Database Schema Audit

### Models Verified (backend/database.py)

| Model | Purpose | Status |
|-------|---------|--------|
| User | Admin/Trainer accounts | ✅ Defined |
| Device | ESP32 device registry | ✅ Defined |
| DeviceCredential | Device auth keys | ✅ Defined |
| Trainee | Trainee profiles | ✅ Defined |
| Session | Inspection sessions | ✅ Defined |
| Event | Telemetry events | ✅ Defined |
| SessionSummary | Session summaries | ✅ Defined |
| Assessment | Rubric assessments | ✅ Defined |
| IngestionError | Ingestion failures | ✅ Defined |

**Indexes:** Present on foreign keys and ID fields
**Migrations:** Alembic configured (alembic.ini present)
**STATUS:** ✅ SCHEMA COMPLETE

---

## PART 6: Flutter Application Audit

### App Configuration Issues

**Issue 1: App Name Mismatch**
```dart
// app_config.dart line 38
static const String appName = 'NAADYANTRA';  // Should be 'HazGuard'
```

**Issue 2: No Device Connectivity Status**
Current Flutter app does not explicitly show:
- Device online/offline status
- Stale data indicators
- Last sync time
- API connection health

**Issue 3: Telemetry Display Gaps**
Backend stores these fields (backend/schemas.py lines 128-138):
- `model_label`, `leak_probability`, `rms`, `gas_delta`, `gas_ratio`, `temperature`, `uv_delta`, `wet`

Flutter models (mobile_app/lib/shared/models/) define:
- Latest telemetry, events, devices
- **UNCLEAR:** Whether all backend fields are displayed in UI

### Flutter Screens Status

| Screen | Status | Notes |
|-------|--------|-------|
| Login | ✅ Exists | Authentication via JWT |
| Home Dashboard | ✅ Exists | Needs connectivity status |
| Device Details | ✅ Exists | Needs online/offline indicators |
| Session/Inspection | ✅ Exists | Workflow complete |
| Settings | ✅ Exists | Basic settings present |
| Help | ✅ Exists | Documentation present |

---

## PART 7: Web Dashboard Status

**Current State:** NO WEB DASHBOARD EXISTS

**Existing:**
- `mobile_app/web/index.html` - Flutter web placeholder only
- No React/Vue/Next.js dashboard
- No standalone web application

**Required:** Build React + TypeScript + Vite dashboard from scratch

---

## PART 8: Firmware ML Model Status

**Verified in leak_detector.ino (lines 47-61):**

```cpp
#define USE_EDGE_IMPULSE      0   // Disabled (was 1)
#define USE_TINYML_HAZARD_FUSION 1   // Enabled
#if USE_TINYML_HAZARD_FUSION
#include "hazard_model.h"
#endif
```

**ISSUE:** `hazard_model.h` file is MISSING. Firmware will not compile with current configuration.

**TinyML Status:**
- ✅ Model placeholder present
- ❌ No actual model file
- ❌ Firmware build will fail

---

## PART 9: Hardware Verification Status

**Hardware:** NOT ASSEMBLED YET
- ESP32-S3 device: **NOT AVAILABLE**
- Sensors: **NOT ARRIVED**
- Physical connectivity: **UNVERIFIED**

**Test Constraints:**
- Cannot verify ESP32 telemetry flow
- Cannot test serial communication
- Cannot validate sensor readings
- Cannot test WiFi connectivity to cloud

---

## PART 10: Existing Features Working

### ✅ What Works
1. Backend API with Neon PostgreSQL
2. Device authentication and registration
3. Event/summary ingestion from firmware
4. Session and trainee management
5. Dashboard overview API endpoints
6. Flutter authentication and routing
7. Flutter device/session/assessment workflows
8. SQLite offline caching in Flutter
9. Dio-based API client with interceptors

### ❌ What Does NOT Work
1. Firmware cloud connectivity (wrong URL)
2. Firmware TLS verification (disabled)
3. Firmware TinyML integration (missing model file)
4. Device online/offline status in Flutter
5. Stale data indicators in Flutter
6. Web dashboard (doesn't exist)
7. Production CORS configuration
8. App name display (still shows NAADYANTRA)

### ⚠️ UNVERIFIED (Hardware Dependent)
1. ESP32 telemetry ingestion to cloud
2. Sensor calibration and readings
3. WiFi connectivity from physical device
4. ML model inference on ESP32
5. Serial data collection workflow

---

## PART 11: Immediate Blockers

### Critical Blockers (Must Fix Before Hardware)

1. **Firmware Cloud URL:** Must change from `192.168.1.10:8000` to actual cloud endpoint
2. **Firmware Device Key:** Must replace hardcoded `"dev-key-123"`
3. **Firmware Model File:** Must provide `hazard_model.h` or disable `USE_TINYML_HAZARD_FUSION`
4. **Secret Rotation:** All credentials in `.env` must be rotated
5. **CORS Configuration:** Must restrict `allow_origins` from `*` to specific domains

### Secondary Blockers (Can Proceed With)

1. **Web Dashboard:** Must be built from scratch
2. **Flutter Connectivity UI:** Must add online/offline/stale indicators
3. **App Name Change:** Must update Flutter app name to "HazGuard"

---

## PART 12: 5-Day Execution Plan

### Day 1: Critical Fixes & Cloud Verification
**Priority:** CRITICAL

**Tasks:**
1. ✅ Document cloud deployment URL (investigate Render/dashboard)
2. Update firmware `BACKEND_URL` to cloud HTTPS endpoint
3. Rotate SECRET_KEY and DEVICE_KEY_HASH
4. Update .env with new credentials (don't commit)
5. Restrict CORS to specific domains
6. Disable or fix firmware TinyML integration (remove `hazard_model.h` include or provide file)
7. Change Flutter app name to "HazGuard"
8. Test backend health endpoint connectivity from Flutter

**Deliverable:** Firmware configured for cloud, backend secure, Flutter app renamed

### Day 2: Flutter Connectivity & Telemetry UI
**Priority:** HIGH

**Tasks:**
1. Add device online/offline status to Flutter device model
2. Add stale data indicators (last sync time, staleness threshold)
3. Add API connection health check in Flutter
4. Display connectivity status in home screen
5. Ensure all backend telemetry fields surface in UI
6. Add manual refresh capability
7. Handle offline/ unreachable states gracefully
8. Add empty states for no device data

**Deliverable:** Flutter app with live/stale/offline indicators

### Day 3: Web Dashboard Build
**Priority:** HIGH

**Tasks:**
1. Initialize React + TypeScript + Vite project
2. Configure Tailwind CSS with HazGuard color palette
3. Build dashboard overview page (device counts, status)
4. Build device inventory page (search, filter, pagination)
5. Build device details page (connectivity, telemetry, events)
6. Build alerts page (filtered event history)
7. Integrate with FastAPI backend
8. Test all dashboard APIs

**Deliverable:** Functional web dashboard connected to cloud backend

### Day 4: Hardware Integration Preparation
**Priority:** MEDIUM (Hardware Dependent)

**Tasks:**
1. Verify firmware compiles successfully
2. Create serial data collection tool (already exists in ml/src/serial_collect.py)
3. Test serial collection tool if hardware arrives
4. Verify ESP32 WiFi connects to configured network
5. Test firmware telemetry to cloud backend
6. Validate sensor readings are ingested correctly
7. Test Flutter app receives real telemetry
8. Verify web dashboard displays real data

**Deliverable:** Hardware ready for full integration, serial tool tested

### Day 5: End-to-End Validation & Polish
**Priority:** MEDIUM

**Tasks:**
1. Complete end-to-end test: ESP32 → Cloud → Database → Flutter → Web
2. Run Flutter tests and fix failures
3. Run backend tests and fix failures
4. Verify production build (Flutter APK/IPA, web dashboard)
5. Document deployment steps
6. Create hardware connection checklist
7. Create user guide for operators
8. Security review final check

**Deliverable:** Production-ready integrated system

---

## PART 13: Files Changed in Audit Phase

**No code changes yet** - This is audit-only phase.

**Files Inspected:**
- backend/main.py
- backend/config.py
- backend/database.py
- backend/routers/dashboard.py
- backend/routers/ingestion.py
- backend/schemas.py
- backend/auth.py
- .env.example
- .env (credentials exposed - must rotate)
- leak_detector.ino
- mobile_app/lib/core/config/app_config.dart
- mobile_app/lib/core/constants/api_constants.dart
- mobile_app/lib/core/network/api_client.dart
- mobile_app/web/index.html
- Flutter models and repositories (directory scan)

---

## PART 14: Sensor Reading Verification

### Firmware Sensors (Verified from leak_detector.ino)

| Sensor | Firmware Status | Backend Support | Flutter Display |
|--------|----------------|-----------------|-----------------|
| Piezo/Acoustic | ✅ | `rms`, `leak_probability` | ⚠️ Partial |
| Gas (MQ) | ✅ | `gas_delta`, `gas_ratio` | ⚠️ Partial |
| Moisture | ✅ | `wet` (boolean) | ⚠️ Partial |
| Temperature (MLX90614) | ❌ Disabled | `temperature` | ❌ |
| UV (GUVA-S12SD) | ❌ Disabled | `uv_delta` | ❌ |

**Notes:**
- MLX90614 and UV sensors are disabled in firmware (lines 52-53)
- Temperature/UV data will not be available until firmware is updated
- Gas readings are ADC delta, NOT calibrated ppm or %LEL (documented in app_config.dart)

---

## PART 15: Hardware Day Checklist

### Pre-Connection Checklist
- [ ] Firmware cloud URL updated to actual HTTPS endpoint
- [ ] Firmware device key changed from "dev-key-123"
- [ ] Firmware DEVICE_ID changed to unique identifier
- [ ] WiFi credentials configured for target network
- [ ] TLS verification enabled (remove `secure.setInsecure()`)
- [ ] Backend CORS configured for production domains
- [ ] All credentials rotated and .env updated
- [ ] TinyML model file provided or disabled in firmware
- [ ] Firmware compiles successfully

### Connection Day Checklist
- [ ] ESP32-S3 hardware assembled
- [ ] Piezo sensor connected to GPIO 4
- [ ] Gas sensor connected to GPIO 5
- [ ] Moisture probe connected to GPIO 6
- [ ] ESP32 powered on
- [ ] ESP32 connects to configured WiFi
- [ ] Device successfully registers with backend (check backend DB)
- [ ] Device key authentication succeeds
- [ ] Telemetry events appear in backend database
- [ ] Flutter app shows device as online
- [ ] Web dashboard shows device as online
- [ ] Sensor readings appear in both Flutter and web dashboard
- [ ] Alert triggers propagate correctly
- [ ] Stale status appears when device disconnects

---

## CONCLUSION

**Status:** Ready for implementation with critical security and configuration fixes required.

**Hardware Integration:** NOT POSSIBLE YET - ESP32 hardware not assembled.

**Next Step:** Begin Day 1 tasks - investigate actual cloud deployment URL and fix critical security issues.

**Important:** Do not attempt physical ESP32 testing until hardware arrives and firmware is configured for cloud connectivity.
