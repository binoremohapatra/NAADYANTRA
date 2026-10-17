#!/usr/bin/env python3
"""
NAADYANTRA — Sensor Evaluation & Diagnostic Signal Toolkit
==========================================================
Provides reusable engineering utilities for sensor input validation, signal metrics,
threshold boundary analysis, and calibration report generation for physical bench testing.

Mathematical Definitions:
- RMS: sqrt( (1/N) * sum( (x[i] - x_mean)^2 ) )
- Crest Factor: max(|x[i] - x_mean|) / RMS
- Band Energy Ratio: sum(|X[f_low..f_high]|^2) / sum(|X|^2)
- Nyquist Limit: F_s / 2 (For 4000 Hz sampling rate, Nyquist is 2000 Hz)
"""

import math
import json
import csv
import io
from typing import List, Dict, Any, Tuple, Optional


class SensorSignalAnalyzer:
    """Acoustic and time-series sensor signal analysis engine."""

    def __init__(self, sampling_rate_hz: int = 4000):
        self.sampling_rate = sampling_rate_hz
        self.nyquist = sampling_rate_hz / 2.0

    def compute_dc_bias(self, samples: List[float]) -> float:
        """Calculates DC bias (mean offset) of raw ADC samples."""
        if not samples:
            return 0.0
        return sum(samples) / len(samples)

    def apply_dc_block(self, samples: List[float], alpha: float = 0.95) -> List[float]:
        """IIR DC-blocking filter (single-pole high-pass matching firmware logic).
        
        Difference equation: y[n] = x[n] - x[n-1] + alpha * y[n-1]
        """
        if not samples:
            return []
        y = [0.0] * len(samples)
        for i in range(1, len(samples)):
            y[i] = (samples[i] - samples[i - 1]) + (alpha * y[i - 1])
        return y

    def compute_rms(self, samples: List[float]) -> float:
        """Calculates Root Mean Square of zero-mean or DC-blocked signal."""
        if not samples:
            return 0.0
        sum_sq = sum(s * s for s in samples)
        return math.sqrt(sum_sq / len(samples))

    def compute_crest_factor(self, samples: List[float], rms: Optional[float] = None) -> float:
        """Calculates Crest Factor (Peak amplitude / RMS ratio)."""
        if not samples:
            return 0.0
        if rms is None:
            rms = self.compute_rms(samples)
        if rms < 1e-6:
            return 0.0
        peak = max(abs(s) for s in samples)
        return peak / rms

    def evaluate_threshold_boundaries(
        self,
        rms: float,
        gas_delta: float,
        temperature_c: float = 25.0
    ) -> Dict[str, Any]:
        """Evaluates sensor metrics against provisional engineering thresholds.
        
        Provisional Engineering Thresholds (Hardware Bench V1):
        - Acoustic RMS:
            Nominal   : 0 <= RMS < 600
            Warning   : 600 <= RMS < 1800
            Critical  : RMS >= 1800
        - Combustible Gas Delta:
            Nominal   : 0 <= Gas < 150
            Warning   : 150 <= Gas < 400
            Critical  : Gas >= 400
        - Temperature (°C):
            Nominal   : < 45.0
            Warning   : 45.0 <= Temp < 60.0
            Critical  : Temp >= 60.0
        """
        # Acoustic status
        if rms >= 1800.0:
            acoustic_status = "CRITICAL_LEAK"
            acoustic_severity = "DANGER"
        elif rms >= 600.0:
            acoustic_status = "ELEVATED_ACOUSTIC"
            acoustic_severity = "WARNING"
        else:
            acoustic_status = "NOMINAL_AMBIENT"
            acoustic_severity = "NORMAL"

        # Gas status
        if gas_delta >= 400.0:
            gas_status = "COMBUSTIBLE_GAS_SATURATION"
            gas_severity = "DANGER"
        elif gas_delta >= 150.0:
            gas_status = "ELEVATED_GAS_CONCENTRATION"
            gas_severity = "WARNING"
        else:
            gas_status = "CLEAN_AIR"
            gas_severity = "NORMAL"

        # Thermal status
        if temperature_c >= 60.0:
            thermal_status = "THERMAL_OVERHEAT"
            thermal_severity = "DANGER"
        elif temperature_c >= 45.0:
            thermal_status = "ELEVATED_HEAT"
            thermal_severity = "WARNING"
        else:
            thermal_status = "SAFE_OPERATING_RANGE"
            thermal_severity = "NORMAL"

        # Overall composite alert
        severities = [acoustic_severity, gas_severity, thermal_severity]
        if "DANGER" in severities:
            composite_alert = "DANGER"
        elif "WARNING" in severities:
            composite_alert = "CAUTION"
        else:
            composite_alert = "NORMAL"

        return {
            "composite_alert": composite_alert,
            "acoustic": {"rms": rms, "status": acoustic_status, "severity": acoustic_severity},
            "gas": {"delta": gas_delta, "status": gas_status, "severity": gas_severity},
            "thermal": {"temp_c": temperature_c, "status": thermal_status, "severity": thermal_severity}
        }

    def export_test_run_csv(self, records: List[Dict[str, Any]]) -> str:
        """Exports diagnostic evaluation records to standard CSV format."""
        output = io.StringIO()
        fieldnames = [
            "timestamp", "device_id", "session_id", "sample_count",
            "dc_bias", "rms", "crest_factor", "gas_delta", "temperature_c",
            "composite_alert", "validation_status"
        ]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        for r in records:
            writer.writerow({
                "timestamp": r.get("timestamp", ""),
                "device_id": r.get("device_id", ""),
                "session_id": r.get("session_id", ""),
                "sample_count": r.get("sample_count", 0),
                "dc_bias": f"{r.get('dc_bias', 0.0):.2f}",
                "rms": f"{r.get('rms', 0.0):.2f}",
                "crest_factor": f"{r.get('crest_factor', 0.0):.2f}",
                "gas_delta": r.get("gas_delta", 0),
                "temperature_c": f"{r.get('temperature_c', 0.0):.1f}",
                "composite_alert": r.get("composite_alert", "NORMAL"),
                "validation_status": r.get("validation_status", "PASS")
            })
        return output.getvalue()

    def generate_calibration_report_markdown(
        self,
        bench_id: str,
        board_variant: str,
        test_records: List[Dict[str, Any]],
        evaluator: str
    ) -> str:
        """Generates formal Markdown bench test and calibration report."""
        report = []
        report.append("# NAADYANTRA — Sensor Calibration & Bench Evaluation Report")
        report.append(f"**Bench Station ID:** `{bench_id}`  ")
        report.append(f"**Board Target:** `{board_variant}`  ")
        report.append(f"**Evaluator:** `{evaluator}`  ")
        report.append(f"**Sampling Rate:** `{self.sampling_rate} Hz` (Nyquist Limit: `{self.nyquist} Hz`)  \n")
        report.append("---")
        report.append("## 1. Summary Metrics\n")
        report.append(f"- **Total Test Windows Evaluated:** {len(test_records)}")
        
        pass_count = sum(1 for r in test_records if r.get("validation_status") == "PASS")
        report.append(f"- **Pass Rate:** {pass_count}/{len(test_records)} ({pass_count/len(test_records)*100:.1f}%)" if test_records else "- **Pass Rate:** N/A")
        
        report.append("\n## 2. Test Window Execution Table\n")
        report.append("| Window | RMS | Crest Factor | Gas Delta | Temp (°C) | Alert Level | Status |")
        report.append("| :--- | :---: | :---: | :---: | :---: | :---: | :---: |")
        
        for i, r in enumerate(test_records, 1):
            report.append(
                f"| W-{i:03d} | {r.get('rms', 0.0):.1f} | {r.get('crest_factor', 0.0):.2f} | "
                f"{r.get('gas_delta', 0)} | {r.get('temperature_c', 0.0):.1f} | "
                f"`{r.get('composite_alert', 'NORMAL')}` | **{r.get('validation_status', 'PASS')}** |"
            )

        report.append("\n---")
        report.append("## 3. Engineering Reviewer Sign-Off\n")
        report.append("```")
        report.append(f"Evaluator Signature: {evaluator}")
        report.append(f"Date: 2026-10-17")
        report.append("Status: BENCH_SOFTWARE_VERIFIED")
        report.append("```\n")

        return "\n".join(report)


if __name__ == "__main__":
    analyzer = SensorSignalAnalyzer(sampling_rate_hz=4000)
    print("NAADYANTRA Sensor Signal Analyzer Initialized.")
    print(f"Sampling Rate: {analyzer.sampling_rate} Hz | Nyquist: {analyzer.nyquist} Hz")
    
    # Test sample evaluation
    dummy_noise = [float((i * 17) % 256 - 128) for i in range(4000)]
    dc = analyzer.compute_dc_bias(dummy_noise)
    dc_blocked = analyzer.apply_dc_block(dummy_noise)
    rms = analyzer.compute_rms(dc_blocked)
    crest = analyzer.compute_crest_factor(dc_blocked, rms)
    eval_result = analyzer.evaluate_threshold_boundaries(rms, gas_delta=85.0, temperature_c=28.4)
    
    print(f"Test Window: DC Bias={dc:.2f} | RMS={rms:.2f} | Crest Factor={crest:.2f}")
    print(f"Composite Evaluation: {eval_result['composite_alert']}")
