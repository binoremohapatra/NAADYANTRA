# NAADYANTRA — Vocational Training & NSQF Trade Competency Mapping
## AI-Enabled Diagnostic & Sensing Wearables for Skilled Trades (SIH26244)

> [!IMPORTANT]
> **Status**: Proposed Curriculum Integration & Competency Alignment Framework  
> **Regulatory Notice**: This document specifies a software-assisted assessment framework aligned with the National Skills Qualifications Framework (NSQF). It constitutes an engineering proposal for vocational training centers (ITIs, polytechnics, and skill development institutes). Formal certification and awarding of NSQF credits requires adoption and authorization by an accredited awarding body (e.g., NCVET, DGT, or Sector Skill Councils).

---

## 1. Executive Summary & Objective

The **NAADYANTRA** wearable sensor rig and companion software platform provide automated diagnostic session logging, acoustic signal analysis, hazard warning verification, and trainer-in-the-loop evaluation.

To fulfill **SIH26244** requirements, this framework maps automated telemetry and session evidence directly to standardized vocational performance criteria across:
- **Plumbing & Pipefitting** (NSQF Level 4, QP Ref: `PSC/Q0104`)
- **RAC (Refrigeration & Air Conditioning) Mechanic** (NSQF Level 4, QP Ref: `ELE/Q3102`)
- **Industrial Plant Maintenance Fitter** (NSQF Level 4/5, QP Ref: `CSC/Q0901`)

---

## 2. Trade Competency Mapping Matrix

| Domain / Competency Unit | National Occupational Standard (NOS) Element | NAADYANTRA Telemetry Evidence | Rubric Parameter | Passing Threshold |
| :--- | :--- | :--- | :--- | :--- |
| **Pipeline Leak Detection** | Inspect pressurized joint/fitting for fluid/gas micro-fissures | Contact piezo RMS readout (`rms > 1200`), Crest factor (`> 2.5`), Acoustic leak probability (`pl >= 0.70`) | `RUBRIC-LEAK-V1`: Joint Acoustic Verification | Detection of leak within 15 seconds; RMS differential `> 600` above ambient baseline. |
| **Combustible Hazard Check** | Screen confined workspace for flammable vapor accumulation | MQ sensor resistance ratio (`gr < 0.60`), Gas delta (`gas > 250 ppm delta`) | `RUBRIC-HAZARD-V1`: Atmospheric Safety Sweep | 100% pre-entry clearance sweep logged prior to opening pressurized line. |
| **Thermal Surface Audit** | Verify pipe/vessel operating temperature prior to contact | MLX90614 pyrometer temperature (`tc > 50.0°C`) | `RUBRIC-HAZARD-V1`: Surface Burn Hazard Awareness | Thermal sweep executed prior to acoustic contact probe placement. |
| **Moisture / Grounding Safety**| Detect corrosive condensation and surface liquid pooling | Gated conduction probe status (`wet == 1`) | `RUBRIC-HAZARD-V1`: Ingress & Corrosion Audit | Accurate recording of wet pipe exterior; prevention of probe shorting. |
| **Session Discipline & Logging**| Complete systematic inspection checklist and maintain logs | Session start/stop events (`session_start`, `session_stop`), duration, window count | `RUBRIC-LEAK-V1`: Protocol Adherence | Minimum inspection duration >= 60 seconds per test point; complete session metadata. |

---

## 3. Rubric Definitions & Scoring Architecture

The NAADYANTRA backend (`/api/v1/assessment-rubrics`) models standardized scoring rules applied to session events:

### 3.1 Rubric Specification: `RUBRIC-LEAK-V1` (Acoustic Inspection)
```json
{
  "rubric_id": "RUBRIC-LEAK-V1",
  "version": "1.0",
  "name": "Pressurized Piping Acoustic Leak Diagnosis",
  "trade": "Pipefitting / RAC Mechanic (NSQF Level 4)",
  "max_score": 100.0,
  "passing_score": 75.0,
  "criteria": [
    {
      "code": "CRIT-01",
      "title": "Baseline Ambient Calibration",
      "weight": 20.0,
      "rule": "Candidate must record at least 10 clean baseline windows (RMS < 600) before testing active joints."
    },
    {
      "code": "CRIT-02",
      "title": "Probe Coupling & Signal Integrity",
      "weight": 30.0,
      "rule": "Steady acoustic contact probe coupling maintained with zero open-circuit sensor dropouts."
    },
    {
      "code": "CRIT-03",
      "title": "Leak Identification & Triage",
      "weight": 35.0,
      "rule": "Correctly localize micro-fissure; trigger event confirmation with leak probability >= 0.70."
    },
    {
      "code": "CRIT-04",
      "title": "Inspection Hygiene & Session Closure",
      "weight": 15.0,
      "rule": "Proper session closure via BOOT button; session duration >= 60 seconds."
    }
  ]
}
```

### 3.2 Evaluation Outcomes
- **`COMPETENT`**: Total score $\ge 75\%$, with all safety checks cleared and leak successfully detected.
- **`NEEDS_IMPROVEMENT`**: Total score $< 75\%$, or failure to detect simulated leak within allowable inspection time.
- **`NOT_ASSESSABLE`**: Zero evidence events recorded, sensor open-circuit fault detected, or session aborted prematurely ($< 15$ seconds).

---

## 4. Trainer Review & Override Workflow

1. **Automated Evidence Ingestion**: Candidate performs inspection with NAADYANTRA sensor rig. Events stream to PostgreSQL.
2. **Evaluation Generation**: System or trainer initializes evaluation via `POST /api/v1/assessments` linking candidate, session ID, and evidence event IDs.
3. **Trainer Verification**: Trainer logs in to the Web Dashboard (`/assessments`) or Mobile App (`/assessments`):
   - Reviews acoustic RMS graphs and gas delta curves.
   - Validates physical candidate technique (probe angle, contact pressure, sweep speed).
   - Enters qualitative comments and applies authorized score overrides (`POST /api/v1/assessments/{id}/review`).
4. **Permanent Audit Log**: All overrides are stamped with trainer ID, timestamp, and immutable audit log entry.
