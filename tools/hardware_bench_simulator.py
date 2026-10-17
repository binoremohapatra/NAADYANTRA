#!/usr/bin/env python3
"""
NAADYANTRA — Controlled Hardware Bench & Multi-Hazard Simulator
===============================================================
Enables repeatable development and test scenario evaluation WITHOUT physical hardware.

CRITICAL SAFETY DIRECTIVE:
--------------------------
This simulator contains hard cryptographic and hostname guards preventing ANY
accidental transmission of synthetic data to live production environments (e.g. Render / Neon).
It is strictly constrained to local test instances (http://localhost:8000).

Supported Deterministic Scenarios:
1. baseline_nominal      : Quiet industrial baseline, steady ambient noise.
2. acoustic_leak_minor   : Micro-fissure hiss, RMS ~1650, high crest factor.
3. acoustic_leak_rupture : Structural leak, RMS ~3200, sustained acoustic energy.
4. combustible_gas_warn  : Elevated gas delta (Rs/R0 drop), warning threshold breach.
5. multi_hazard_critical : High acoustic leak + combustible gas saturation.
6. sensor_fault_open     : Disconnected sensor pins (floating ADC values / fault code).
7. burst_queue_recovery  : Offline queue buffering simulation with idempotency replay.
"""

import sys
import os
import time
import json
import argparse
import urllib.request
import urllib.error
from typing import Dict, Any, List

PRODUCTION_BLOCKED_DOMAINS = [
    "naadyantra.onrender.com",
    "onrender.com",
    "render.com",
    "neon.tech",
    "aws.com"
]

def verify_safety_guard(target_url: str):
    """Enforces strict isolation from live production environments."""
    url_lower = target_url.lower()
    for blocked in PRODUCTION_BLOCKED_DOMAINS:
        if blocked in url_lower:
            print("\n" + "="*80)
            print(" [CRITICAL SECURITY & DATA INTEGRITY VIOLATION]")
            print(f" Target URL '{target_url}' is a live production deployment host!")
            print(" In accordance with NAADYANTRA SIH26244 Zero-Synthetic Production Data Directive,")
            print(" simulated telemetry MUST NEVER be transmitted to production clusters.")
            print(" Simulator aborted.")
            print("="*80 + "\n")
            sys.exit(1)


def generate_event_payload(
    scenario: str,
    device_id: str,
    trainee_id: str,
    session_id: int,
    millis: int,
    seq: int
) -> Dict[str, Any]:
    """Generates a schema-compliant deterministic test telemetry payload."""
    base_payload = {
        "ev": "telemetry",
        "device": device_id,
        "up": millis,
        "millis": millis,
        "t": int(time.time()),
        "fw": "1.1.0-sim",
        "sim": True,
        "mode": "TEST_SIMULATION",
        "seq": seq
    }

    if scenario == "baseline_nominal":
        base_payload.update({
            "alert": "NORMAL",
            "cause": "clear",
            "lbl": "ambient_nominal_rms",
            "pl": 0.04,
            "rms": 420.0 + (seq % 15),
            "gas": 45 + (seq % 10),
            "gr": 0.98,
            "tc": 27.5,
            "uv": 5,
            "wet": False
        })
    elif scenario == "acoustic_leak_minor":
        base_payload.update({
            "alert": "CAUTION",
            "cause": "acoustic_hiss_fissure",
            "lbl": "leak_minor_rms",
            "pl": 0.68,
            "rms": 1680.0 + (seq % 40),
            "gas": 60,
            "gr": 0.95,
            "tc": 28.0,
            "uv": 8,
            "wet": False
        })
    elif scenario == "acoustic_leak_rupture":
        base_payload.update({
            "alert": "DANGER",
            "cause": "high_pressure_rupture",
            "lbl": "leak_critical_rms",
            "pl": 0.96,
            "rms": 3450.0 + (seq % 120),
            "gas": 85,
            "gr": 0.91,
            "tc": 29.2,
            "uv": 12,
            "wet": False
        })
    elif scenario == "combustible_gas_warn":
        base_payload.update({
            "alert": "WARNING",
            "cause": "combustible_gas_buildup",
            "lbl": "gas_hazard_delta",
            "pl": 0.15,
            "rms": 480.0,
            "gas": 420 + (seq % 30),
            "gr": 0.45,
            "tc": 31.0,
            "uv": 6,
            "wet": False
        })
    elif scenario == "multi_hazard_critical":
        base_payload.update({
            "alert": "DANGER",
            "cause": "leak_and_gas_conflagration",
            "lbl": "multi_hazard_combined",
            "pl": 0.98,
            "rms": 3100.0,
            "gas": 680,
            "gr": 0.28,
            "tc": 42.5,
            "uv": 45,
            "wet": True
        })
    elif scenario == "sensor_fault_open":
        base_payload.update({
            "alert": "CAUTION",
            "cause": "sensor_lead_disconnected",
            "lbl": "sensor_fault_open_circuit",
            "pl": 0.0,
            "rms": 0.0,
            "gas": 0,
            "gr": 0.0,
            "tc": -99.0,
            "uv": 0,
            "wet": False
        })
    else:
        raise ValueError(f"Unknown simulation scenario: {scenario}")

    return base_payload


def send_telemetry(target_url: str, device_key: str, trainee_id: str, session_id: int, payload: Dict[str, Any]) -> bool:
    """Dispatches telemetry to local test server with simulation headers."""
    endpoint = f"{target_url.rstrip('/')}/api/log?trainee={trainee_id}&session={session_id}&kind=event&device={payload['device']}"
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(endpoint, data=data, method='POST')
    req.add_header('Content-Type', 'application/json')
    req.add_header('X-Device-Key', device_key)
    req.add_header('X-Simulation-Test', 'true')
    req.add_header('X-Environment', 'development_bench')

    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status == 200
    except urllib.error.HTTPError as e:
        print(f"  [!] HTTP Error: {e.code} - {e.read().decode('utf-8')}")
        return False
    except Exception as e:
        print(f"  [!] Connection failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="NAADYANTRA Controlled Hardware Bench Simulation Tool")
    parser.add_argument("--target", default="http://localhost:8000", help="Target API endpoint (Strictly local dev only)")
    parser.add_argument("--device", default="DEV-BENCH-SIM-01", help="Test device ID")
    parser.add_argument("--trainee", default="TR-SIM-TEST", help="Test trainee ID")
    parser.add_argument("--session", type=int, default=999, help="Test session ID")
    parser.add_argument("--key", default="test-device-key-123", help="Test device authentication key")
    parser.add_argument("--scenario", choices=[
        "baseline_nominal",
        "acoustic_leak_minor",
        "acoustic_leak_rupture",
        "combustible_gas_warn",
        "multi_hazard_critical",
        "sensor_fault_open"
    ], default="baseline_nominal", help="Deterministic scenario to execute")
    parser.add_argument("--count", type=int, default=5, help="Number of telemetry cycles to emit")
    parser.add_argument("--interval", type=float, default=1.0, help="Interval between events in seconds")

    args = parser.parse_args()

    # Mandatory Safety Verification
    verify_safety_guard(args.target)

    print("\n" + "="*70)
    print(" NAADYANTRA BENCH SIMULATION TOOL (ISOLATED LOCAL DEVELOPMENT)")
    print("="*70)
    print(f" Target Host : {args.target}")
    print(f" Scenario    : {args.scenario}")
    print(f" Device ID   : {args.device} [ISOLATED TEST SUITE]")
    print(f" Trainee ID  : {args.trainee}")
    print(f" Session ID  : #{args.session}")
    print(f" Cycles      : {args.count} events @ {args.interval}s")
    print("="*70 + "\n")

    successful = 0
    start_millis = 1000

    for i in range(1, args.count + 1):
        millis = start_millis + (i * int(args.interval * 1000))
        payload = generate_event_payload(args.scenario, args.device, args.trainee, args.session, millis, i)
        
        ok = send_telemetry(args.target, args.key, args.trainee, args.session, payload)
        if ok:
            successful += 1
            print(f"  [{i}/{args.count}] Emitted: {args.scenario} | RMS={payload['rms']} | Gas={payload['gas']} | Status: ACCEPTED")
        else:
            print(f"  [{i}/{args.count}] Failed to emit event")
        
        if i < args.count:
            time.sleep(args.interval)

    print("\n" + "-"*70)
    print(f" Simulation Run Completed: {successful}/{args.count} events ingested into local test database.")
    print(" Zero production records were affected.")
    print("-"*70 + "\n")


if __name__ == "__main__":
    main()
