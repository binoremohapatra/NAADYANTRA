# NAADYANTRA — Vocational Training & NSQF Trade Competency Alignment
## Proposed Assessment Architecture for Skilled Trades (SIH26244)

> [!IMPORTANT]
> **Regulatory Notice & Status Declaration**:  
> **Status**: Proposed Curriculum Alignment & Diagnostic Assessment Framework  
> **Verification Date**: October 17, 2026 (Audited against NSDC / NCVET National Qualifications Register - NQR)  
> **Accreditation Disclaimer**: This document specifies an engineering proposal for vocational skill training centers (ITIs, polytechnics, and skill development institutes). NAADYANTRA is **not** an officially accredited awarding body. Official granting of NSQF credits, certifications, or formal trade diplomas requires adoption and authorization by an accredited awarding body (e.g., NCVET, DGT, or authorized Sector Skill Councils).

---

## 1. Authoritative Occupational Standards Audit

The table below reconciles all National Occupational Standards (NOS) and Qualification Pack (QP) references against current NCVET / NSDC National Qualifications Register (NQR) records:

| Qualification Pack Code | Official Registry Title | Sector Skill Council (SSC) | Official NSQF Level | NQR Status & Version (Oct 2026 Audit) | NAADYANTRA Application Scope |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **`PSC/Q0104`** | **Plumber (General)** | Water Management & Plumbing Skill Council (WMPSC) | **Level 4** | **Active** (Version 4.0 / Version 3.0 PWD; historical V1.0 Level 3 superseded) | Pressurized pipe joint inspection, coupling integrity, acoustic leak screening. |
| **`ELE/Q3102`** | **Field Technician – Air Conditioner** | Electronics Sector Skills Council of India (ESSCI) | **Level 4** | **Active** (Version 3.0; CTS ITI 2-year trade: "Mechanic Refrigeration & Air Conditioning" - DGT Trade Code 0284) | Refrigerant line screening, brazed joint acoustic verification, compressor line check. |
| **`CSC/Q0901`** | **Fitter – Mechanical Assembly** | Capital Goods Skill Council (CGSC) | **Level 3** | **Active** (Version 2.0; DGT CTS Fitter trade alignment) | Assembly inspection of fluid fittings, hydraulic/pneumatic valves, mechanical sealing. |

*Audited Source: National Qualifications Register (nqr.gov.in) & NSDC National Occupational Standards Portal. Verification Date: October 17, 2026.*

## 2. Competency Alignment Matrix

| Trade Skill Unit | Target NOS Element | Diagnostic Sensor Evidence | Software Rubric Parameter | Passing Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **Joint Acoustic Inspection** | Inspect fluid/gas pipeline joints for micro-fissure leakage | Contact Piezo RMS energy (`rms >= 3.0x` baseline or `rms >= 1200`), Crest Factor (`> 2.0`) | `RUBRIC-LEAK-V1`: Joint Acoustic Verification | Localize leak within 30 seconds; sustained acoustic elevation confirmed across $\ge 2$ consecutive windows. |
| **Confined Space Sweep** | Verify absence of hazardous vapor before opening hot-work lines | MQ-2 resistance ratio ($R_s/R_0 < 0.60$) and raw ADC delta (`gas >= 150`) | `RUBRIC-HAZARD-V1`: Pre-Inspection Sweep | 100% pre-entry atmospheric clearance sweep logged prior to coupling piezo probe. |
| **Surface Temperature Check** | Verify pipe/vessel temperature prior to technician contact | MLX90614 contactless pyrometer (`tc >= 40.0°C` cue, `>= 60.0°C` warn) | `RUBRIC-HAZARD-V1`: Burn Prevention Audit | Non-contact thermal sweep completed before physical contact probe placement. |
| **Moisture / Grounding Safety**| Detect corrosive condensation and surface liquid pooling | Gated conduction probe state (`wet == 1`) | `RUBRIC-HAZARD-V1`: Corrosion/Moisture Check | Identification of pipe sweat/liquid; prevention of sensor short-circuits. |
| **Inspection Discipline** | Systematic testing procedure and automated digital logging | Session start/stop events (`session_start`, `session_stop`), duration $\ge 60\text{ s}$ | `RUBRIC-LEAK-V1`: Protocol Adherence | Complete session record with device linkage and valid timestamps. |

---

## 3. Rubric Architecture & Heuristic vs. AI Disclosure

> [!WARNING]
> **Heuristic vs. AI Model Provenance**:  
> In the current firmware release (`USE_EDGE_IMPULSE == 0`, `USE_TINYML_HAZARD_FUSION == 0`), active detection operates via **deterministic RMS thresholding and signal heuristics** with model labels suffixed by `(rms)`. The heuristic `pl` (leak probability) field reflects a mathematical ratio ($(\text{RMS} / \text{RMS}_\text{base}) / 4.0$, clamped to $[0.0, 1.0]$) rather than an empirically validated neural network classifier. Assessments must evaluate candidate performance on signal evidence and technique, without falsely claiming validated AI inference.

### 3.1 Rubric Specification: `RUBRIC-LEAK-V1` (Acoustic Inspection)
```json
{
  "rubric_id": "RUBRIC-LEAK-V1",
  "version": "1.0",
  "name": "Pressurized Piping Acoustic Leak Diagnosis",
  "trade_alignment": "Plumber (General - Level 4) / Field Technician - AC (Level 4)",
  "max_score": 100.0,
  "passing_score": 75.0,
  "criteria": [
    {
      "code": "CRIT-01",
      "title": "Baseline Ambient Calibration",
      "weight": 20.0,
      "rule": "Candidate must record at least 10 clean baseline windows (RMS < 600 counts) before testing active joints."
    },
    {
      "code": "CRIT-02",
      "title": "Probe Coupling & Signal Integrity",
      "weight": 30.0,
      "rule": "Steady contact probe coupling maintained without open-circuit dropout (MIN_SIGNAL_RMS > 0.8 counts)."
    },
    {
      "code": "CRIT-03",
      "title": "Leak Identification & Triage",
      "weight": 35.0,
      "rule": "Correctly localize micro-fissure; trigger acoustic elevation confirmed across at least 2 consecutive windows."
    },
    {
      "code": "CRIT-04",
      "title": "Inspection Hygiene & Session Closure",
      "weight": 15.0,
      "rule": "Proper session closure via BOOT button; session duration >= 60 seconds with valid telemetry."
    }
  ]
}
```

### 3.2 Standardized Evaluation Outcomes
- **`COMPETENT`**: Score $\ge 75.0\%$, all baseline calibration steps satisfied, and leak correctly detected.
- **`NEEDS_IMPROVEMENT`**: Score $< 75.0\%$, or failure to localize leak within allowable trial window.
- **`NOT_ASSESSABLE`**: Zero evidence events recorded, sensor open-circuit fault detected (`MIN_SIGNAL_RMS < 0.8`), or trial aborted prematurely ($< 15$ seconds).

---

## 4. Trainer Review & Override Workflow

1. **Automated Evidence Ingestion**: Candidate performs inspection with NAADYANTRA sensor rig. Events stream to PostgreSQL.
2. **Evaluation Generation**: System or trainer initializes evaluation via `POST /api/v1/assessments` linking candidate, session ID, and evidence event IDs.
3. **Trainer Verification**: Trainer logs in to the Web Dashboard (`/assessments`) or Mobile App (`/assessments`):
   - Reviews acoustic RMS graphs, Crest Factor, and gas delta curves.
   - Validates physical candidate technique (probe angle, contact pressure, sweep speed).
   - Enters qualitative comments and applies authorized score overrides (`POST /api/v1/assessments/{id}/review`).
4. **Permanent Audit Log**: All overrides are stamped with trainer ID, timestamp, and immutable audit log entry.
