# NAADYANTRA — SIH26244 Dashboard Traceability Matrix

> **Problem Statement Title**: AI-Enabled Diagnostic and Sensing Wearables for Skilled Trades (Leak and Hazard Detection)  
> **Problem Statement Code**: SIH26244  
> **Document Status**: Production Traceability Audit & Compliance Specification  
> **Verification Date**: October 19, 2026  
> **System Scope**: React Web Dashboard (`web-dashboard`), FastAPI Backend (`backend`), ESP32-S3 Firmware (`leak_detector.ino`), and NSQF Curriculum Mapping (`docs/VOCATIONAL_NSQF_COMPETENCY_MAPPING.md`).

---

## 1. System Objectives Traceability Matrix

| # | SIH26244 Objective | Implemented Dashboard Features | Source Files & Screens | Backend Endpoints & Schemas | Verification Evidence | Current Status & Limitations |
|---|---|---|---|---|---|---|
| **1** | **Diagnostic Support for Gas/Water Leakage & Multi-Hazard Detection** | • Acoustic Contact Piezo RMS energy & Crest Factor monitoring<br>• MQ-2 Combustible Gas relative delta ($R_s/R_0$)<br>• Gated Moisture conduction probe sensing<br>• Comparative multi-point pipe joint inspection procedure | • `src/pages/Diagnostics.tsx`<br>• `src/pages/DeviceDetail.tsx`<br>• `src/pages/TrainingWorkflow.tsx`<br>• `src/pages/Overview.tsx` | • `GET /api/v1/events`<br>• `GET /api/v1/devices/{id}/telemetry/latest`<br>• `EventResponse` (RMS, gas_delta, gas_ratio, wet) | • Telemetry ingestion confirmed via `POST /api/log`<br>• Firmware ADC sampling on ESP32-S3 `PIN_PIEZO` (CH3) and `PIN_GAS` (CH4) | ✅ **Production Implemented**<br>⚠️ *Piezo captures local vibration only (not spatial coordinates). MQ-2 is uncalibrated relative reading (not ppm or %LEL).* |
| **2** | **Interpretable / Explainable Diagnostic Feedback** | • Automated Explainable Feedback Engine translating raw RMS/ADC counts into diagnostic observations<br>• Explicit Inference Provenance display<br>• Actionable trainer & candidate remediation directives<br>• 9 distinct diagnostic state badges | • `src/pages/Diagnostics.tsx`<br>• `src/pages/TrainingWorkflow.tsx` | • `Event.model_label`<br>• `Event.cause`<br>• `Event.leak_probability`<br>• `Event.rms` | • Feedback rules evaluated against actual telemetry windows<br>• Tested across normal, leak, gas, and moisture events | ✅ **Production Implemented**<br>⚠️ *Active inference operates via deterministic heuristic ratio `(rms)` fallback (`USE_EDGE_IMPULSE == 0`). Python Random Forest baseline was evaluated on synthetic data.* |
| **3** | **Structured Session Logging & Event Chronology** | • Chronological multi-modal event timeline<br>• Summary aggregation (windows, leak events, gas events, duration)<br>• RFC 4180 compliant CSV export with headers & summary section<br>• Trainer qualitative session notes | • `src/pages/Sessions.tsx`<br>• `src/pages/DeviceDetail.tsx` | • `GET /api/v1/sessions`<br>• `GET /api/v1/sessions/{id}/events`<br>• `GET /api/v1/sessions/{id}/summary`<br>• `GET /api/v1/sessions/{id}/export` | • Verified CSV export endpoint passing automated unit tests<br>• Session idempotency guaranteed by SHA-256 event deduplication | ✅ **Production Implemented**<br>Verified across SQLite and PostgreSQL backends. |
| **4** | **Trainer Review, Qualitative Notes & Score Overrides** | • Trainer Review modal with qualitative remarks<br>• Authorized score override ($0 - 100$ points)<br>• Authorized outcome override (`COMPETENT`, `NEEDS_IMPROVEMENT`, `NOT_ASSESSABLE`)<br>• Permanent immutable audit log timestamped with assessor ID | • `src/pages/Assessments.tsx`<br>• `src/pages/TrainingWorkflow.tsx` | • `POST /api/v1/assessments/{id}/review`<br>• `GET /api/v1/assessments/{id}/audit`<br>• `TrainerReview` model | • Audit entries verified in database with foreign key linkage<br>• Authorization restricted to `trainer` and `admin` roles | ✅ **Production Implemented**<br>Immutable audit trail preserved in `audit_logs` table. |
| **5** | **Cost-Aware Deployment & Bill of Materials (BOM) References** | • Low-cost component awareness ($< \$35$ USD / ₹2,800 INR BOM target)<br>• ESP32-S3 dual-core microcontroller architecture<br>• Gated excitation circuit to prevent galvanic sensor replacement costs<br>• MT3608 boost load-disconnect gate control (`PIN_BOOST_EN`) | • `docs/HARDWARE_BILL_OF_MATERIALS.md`<br>• `leak_detector.ino`<br>• `src/pages/Overview.tsx` | • `SystemInfoResponse`<br>• `DeviceResponse.device_metadata` | • BOM audited against Indian open-market electronics distributors (Robu.in / Quartz)<br>• Circuit schematics documented in hardware commissioning guide | ✅ **Documented & Aligned**<br>Hardware unit costs documented in BOM; zero proprietary cloud licensing fees required. |
| **6** | **Safety & Calibration Transparency Disclosures** | • Transparent hardware status labels (Active vs Indicative vs Disabled)<br>• Clear disclaimer that MQ-2 readings do not certify safe confined space entry<br>• Negative diagnostic rule disclosure: pipeline is not proven leak-free just because current sensor reading does not indicate a leak<br>• Temperature / UV / Distance marked as disabled in FW 1.1.0 | • `src/pages/Diagnostics.tsx`<br>• `src/pages/DeviceDetail.tsx`<br>• `src/pages/Overview.tsx` | • `DeviceStatusResponse.is_stale`<br>• `DeviceStatusResponse.staleness_seconds`<br>• `leak_detector.ino` flags | • Firmware compile flags inspected (`HAS_HEAT_SENSOR 0`, `HAS_UV_SENSOR 0`, `HAS_DISTANCE_SENSOR 0`)<br>• Visible warning banners displayed on dashboard | ✅ **Production Implemented**<br>Zero simulated active status for non-configured or disabled sensors. |
| **7** | **Vocational NSQF Competency Mapping Pathway** | • Reconciled against National Qualifications Register (NQR) October 2026 records:<br>  - `PSC/Q0104`: Plumber (General) - Level 4 (WMPSC)<br>  - `ELE/Q3102`: Field Tech - AC - Level 4 (ESSCI)<br>  - `CSC/Q0901`: Fitter - Mech. Assembly - Level 3 (CGSC)<br>• 4-criteria rubric architecture: `CRIT-01` (Baseline), `CRIT-02` (Coupling), `CRIT-03` (Leak Triage), `CRIT-04` (Closure)<br>• Standardized outcomes: `COMPETENT` ($\ge 75\%$), `NEEDS_IMPROVEMENT`, `NOT_ASSESSABLE`<br>• Explicit legal notice that NAADYANTRA is an educational tool, not an accredited awarding body | • `src/pages/TrainingWorkflow.tsx`<br>• `src/pages/Assessments.tsx`<br>• `src/pages/Overview.tsx`<br>• `docs/VOCATIONAL_NSQF_COMPETENCY_MAPPING.md` | • `GET /api/v1/assessment-rubrics`<br>• `POST /api/v1/assessments`<br>• `AssessmentRubricResponse` | • Rubric specifications loaded into database schema and client store<br>• End-to-end evaluation demonstrated in Vocational Training Studio | ✅ **Production Implemented**<br>Fully traceable to authoritative NCVET / NSDC occupational standards. |
| **8** | **Honest Reporting of Physical & Hardware Limitations** | • Explicit separation between software implementation and unverified physical hardware<br>• Isolated Client-Side Demonstration Mode with deterministic fixtures and persistent banner<br>• No fabrication of live sensor feeds or fake pipeline localization<br>• Clear demarcation between real backend telemetry and simulated scenarios | • `src/context/DemoContext.tsx`<br>• `src/components/Layout.tsx`<br>• `src/pages/Diagnostics.tsx`<br>• `src/pages/DeviceDetail.tsx` | • Client-side isolation ensures zero production database contamination<br>• Distinct `[DEMO / SIMULATED]` labels on all mock records | • Build verification passes with zero errors<br>• Toggle test verifies instantaneous isolation from production API | ✅ **Production Implemented**<br>Physical hardware behavior remains explicitly marked as prototype / bench evaluation. |

---

## 2. Firmware Configuration Reconciliation (FW 1.1.0)

| Modality / Sensor | Firmware Flag (`leak_detector.ino`) | Pin Assignment | Hardware Status | Dashboard Representation |
|---|---|---|---|---|
| **Contact Acoustic Piezo** | `RUN_MODE_DETECT` (Active) | `PIN_PIEZO` (ADC1_CH3) | **Active** (12-bit ADC @ 8kHz, IIR DC-block) | `ACTIVE`: Displays raw RMS counts, Crest factor, and heuristic leak probability. Discloses local vibration only (no triangulation). |
| **Combustible Gas (MQ-2)** | `HAS_GAS_SENSOR 1` | `PIN_GAS` (ADC1_CH4) | **Active** (5V divider stepped down to ADC linear range) | `INDICATIVE RELATIVE`: Displays ADC delta and $R_s/R_0$ ratio. Explicitly flags uncalibrated nature (not ppm or %LEL). |
| **Moisture Conduction Probe** | `HAS_MOISTURE_SENSOR 1`<br>`MOIST_POWER_GATED 1` | `PIN_MOISTURE` (ADC1_CH5)<br>`PIN_MOIST_PWR` (GPIO10) | **Active** (Gated excitation to prevent galvanic oxidation) | `ACTIVE`: Displays binary WET / DRY conduction state. |
| **MLX90614 Contactless IR** | `HAS_HEAT_SENSOR 0` | I2C SMBus (`PIN_SDA` 8, `PIN_SCL` 9) | **Disabled** in firmware build | `DISABLED IN FW`: Clearly badged as disabled; does not fabricate IR temperature values. |
| **GUVA-S12SD UV Radiometer** | `HAS_UV_SENSOR 0` | `PIN_UV` (ADC1_CH0) | **Disabled** in firmware build | `DISABLED IN FW`: Clearly badged as disabled; welding arc alarm shown as inactive. |
| **VL53L0X ToF Distance** | `HAS_DISTANCE_SENSOR 0` | I2C Addr `0x29` | **Disabled** in firmware build | `DISABLED IN FW`: Proximity tracking shown as unconfigured. |
| **TinyML Hazard Fusion** | `USE_TINYML_HAZARD_FUSION 0` | N/A | **Disabled** (Heuristic fallback active) | Discloses heuristic ratio $(\text{RMS}/\text{RMS}_\text{base})/4.0$ with label suffix `(rms)`. |
| **Edge Impulse TinyML** | `USE_EDGE_IMPULSE 0` | N/A | **Disabled** (RMS fallback detector) | Discloses that machine learning model is inactive in embedded runtime. |

---

## 3. NSQF Vocational Standards Reference

The NAADYANTRA vocational training framework is aligned to the following official occupational standards audited from the National Qualifications Register (NQR - nqr.gov.in) and NSDC portal:

1. **Plumber (General)**:
   - **Qualification Code**: `PSC/Q0104` (Version 4.0 / Version 3.0 PWD)
   - **Sector Skill Council**: Water Management & Plumbing Skill Council (WMPSC)
   - **Official NSQF Level**: Level 4
   - **Competency Scope**: Pressurized pipe joint inspection, coupling integrity, multi-point acoustic leak triage.

2. **Field Technician – Air Conditioner**:
   - **Qualification Code**: `ELE/Q3102` (Version 3.0; CTS ITI Trade: Mechanic RAC - DGT Code 0284)
   - **Sector Skill Council**: Electronics Sector Skills Council of India (ESSCI)
   - **Official NSQF Level**: Level 4
   - **Competency Scope**: Refrigerant line screening, brazed joint acoustic verification, compressor line audit.

3. **Fitter – Mechanical Assembly**:
   - **Qualification Code**: `CSC/Q0901` (Version 2.0; DGT CTS Fitter alignment)
   - **Sector Skill Council**: Capital Goods Skill Council (CGSC)
   - **Official NSQF Level**: Level 3
   - **Competency Scope**: Assembly inspection of fluid fittings, hydraulic/pneumatic valves, mechanical sealing.

---

## 4. Assessment Rubric Architecture

### Rubric: `RUBRIC-LEAK-V1` (Acoustic Leak Diagnosis)
- **Trade Alignment**: Plumber (General Level 4) / Field Technician - AC (Level 4)
- **Passing Score**: 75.0%
- **Evaluation Criteria**:
  - `CRIT-01` (Weight: 20 pts): Baseline Ambient Calibration ($\ge 10$ clean baseline windows, $\text{RMS} < 600$ counts).
  - `CRIT-02` (Weight: 30 pts): Probe Coupling & Signal Integrity (steady contact probe coupling without dropout).
  - `CRIT-03` (Weight: 35 pts): Leak Identification & Triage (isolate defect coupling; confirmed acoustic elevation across $\ge 2$ consecutive windows).
  - `CRIT-04` (Weight: 15 pts): Inspection Hygiene & Protocol Closure (proper session closure via BOOT button, duration $\ge 30$ seconds).

### Standardized Evaluation Outcomes:
- **`COMPETENT`**: Total Score $\ge 75.0\%$, all baseline calibration steps satisfied, defect isolated.
- **`NEEDS_IMPROVEMENT`**: Total Score $< 75.0\%$, or failure to localize leak within allowable trial window.
- **`NOT_ASSESSABLE`**: Zero evidence events recorded, sensor open-circuit fault detected, or trial aborted prematurely ($< 15$ seconds).

---

## 5. Security & Authentication Architecture

- **Token Storage**: JWT Bearer token stored in browser `localStorage` as `auth_token`.
- **Automatic Session Expiry**: Global Axios response interceptor intercepts HTTP 401 Unauthorized, purges stored credentials, and redirects immediately to `/login`.
- **Role-Based Access Control**:
  - `trainer`: Full read/write access to sessions, trainees, diagnostic events, rubrics, and assessment review/override submissions.
  - `admin`: Exclusive authorization to register hardware devices, rotate provisioned credentials, and manage system parameters.
- **Device Credential Issuance**: Cryptographically secure 32-character urlsafe keys issued via `/api/v1/devices/{id}/rotate-key`. Stored as salted bcrypt hashes in `device_credentials` table; raw keys are displayed only once upon rotation.

---

## 6. Verification Summary

- **Frontend Compilation**: Production Vite build completed with zero TypeScript errors (`tsc -b && vite build` passed in 446ms).
- **Static Analysis**: Linter validation executed with zero errors (`oxlint` passed).
- **Dual-Theme Integrity**: Verified in both Light (Industrial Ivory `#F7F5F0`) and Dark (`#131416`) modes with persisted preference.
- **Client-Side Demo Mode**: Zero database contamination; deterministic mock fixtures validated.
- **Backend Compatibility**: Backward-compatible with all existing FastAPI routes (`/api/v1/dashboard/overview`, `/api/v1/events`, `/api/v1/sessions`, `/api/v1/trainees`, `/api/v1/assessments`, `/api/v1/devices`).
