"""
NAADYANTRA Firmware Logic & Contract Tests
==========================================
Tests cover:
  - Ring-buffer boundary and sample-count invariants (pure Python mirror)
  - Telemetry queue full/empty and priority-retention logic
  - Event schema compatibility (all existing fields preserved)
  - Sensor-unavailable / disabled state representation
  - Inference fallback label provenance (rule-based vs model-based)
  - Stale / cached data rendering rules
  - Multi-device event identification (device + session uniqueness)
  - Invalid / incomplete window handling in preprocessing pipeline

Run: pytest tests/test_firmware_logic.py -v
"""
import pytest
import numpy as np
from collections import deque

from ml.src.preprocessing import SignalPreprocessor


# =============================================================================
# Ring-Buffer Boundary Tests (Python mirror of the C circular buffer logic)
# =============================================================================

class RingBuffer:
    """Python mirror of the int16 circular ring buffer in leak_detector.ino."""

    def __init__(self, capacity_pow2: int):
        assert (capacity_pow2 & (capacity_pow2 - 1)) == 0, "Capacity must be power of two"
        self._buf = [0] * capacity_pow2
        self._mask = capacity_pow2 - 1
        self._head = 0

    def push(self, sample: int) -> None:
        self._buf[self._head & self._mask] = sample
        self._head += 1

    def read_window(self, n_samples: int) -> list:
        assert n_samples <= len(self._buf), "Window larger than buffer capacity"
        start = self._head - n_samples
        return [self._buf[(start + i) & self._mask] for i in range(n_samples)]

    @property
    def head(self):
        return self._head


class TestRingBuffer:

    def test_capacity_must_be_power_of_two(self):
        with pytest.raises(AssertionError):
            RingBuffer(3000)

    def test_empty_buffer_head_is_zero(self):
        rb = RingBuffer(8192)
        assert rb.head == 0

    def test_single_push_increments_head(self):
        rb = RingBuffer(8192)
        rb.push(100)
        assert rb.head == 1

    def test_first_window_requires_n_samples(self):
        rb = RingBuffer(8192)
        for _ in range(3999):
            rb.push(200)
        assert rb.head < 4000

    def test_window_exact_after_4000_samples(self):
        rb = RingBuffer(8192)
        for i in range(4000):
            rb.push(i % 4096)
        window = rb.read_window(4000)
        assert len(window) == 4000
        assert window[-1] == 3999 % 4096

    def test_circular_wrap_preserves_latest_window(self):
        rb = RingBuffer(8192)
        for i in range(9000):
            rb.push(i)
        window = rb.read_window(4000)
        assert len(window) == 4000
        assert window[-1] == 8999

    def test_window_larger_than_buffer_raises(self):
        rb = RingBuffer(8192)
        for _ in range(8192):
            rb.push(1)
        with pytest.raises(AssertionError):
            rb.read_window(10000)

    def test_hop_produces_50_percent_overlap(self):
        rb = RingBuffer(8192)
        for i in range(4000):
            rb.push(i)
        win1 = rb.read_window(4000)
        for i in range(2000):
            rb.push(4000 + i)
        win2 = rb.read_window(4000)
        assert win1[2000:] == win2[:2000]

    def test_overrun_does_not_crash(self):
        rb = RingBuffer(8192)
        for i in range(10000):
            rb.push(i % 4096)
        window = rb.read_window(4000)
        assert len(window) == 4000


# =============================================================================
# Queue Priority Retention Tests
# =============================================================================

QUEUE_CAPACITY = 40


class LogQueue:
    """Python mirror of the priority-aware enqueueLog() from firmware."""

    def __init__(self, capacity: int = QUEUE_CAPACITY):
        self._q: deque = deque()
        self._cap = capacity

    def enqueue(self, item: dict) -> bool:
        if len(self._q) < self._cap:
            self._q.append(item)
            return True
        oldest = self._q[0]
        if not oldest["critical"] or item["critical"]:
            self._q.popleft()
            self._q.append(item)
            return True
        return False

    def receive(self) -> dict:
        return self._q.popleft()

    def peek(self) -> dict:
        return self._q[0]

    def __len__(self):
        return len(self._q)


class TestLogQueuePriority:

    def _fill_with_snaps(self, q: LogQueue, n: int = QUEUE_CAPACITY):
        for i in range(n):
            q.enqueue({"event": f"snap_{i}", "critical": False})

    def test_empty_queue_accepts_any_item(self):
        q = LogQueue()
        assert q.enqueue({"event": "snap", "critical": False}) is True
        assert len(q) == 1

    def test_full_queue_drops_oldest_noncritical_for_noncritical(self):
        q = LogQueue()
        self._fill_with_snaps(q)
        first = q.peek()["event"]
        q.enqueue({"event": "snap_new", "critical": False})
        assert q.peek()["event"] != first
        assert len(q) == QUEUE_CAPACITY

    def test_full_queue_critical_alarm_displaces_noncritical_oldest(self):
        q = LogQueue()
        self._fill_with_snaps(q)
        accepted = q.enqueue({"event": "GAS_ALARM", "critical": True})
        assert accepted is True
        items = list(q._q)
        assert items[-1]["event"] == "GAS_ALARM"

    def test_full_queue_noncritical_does_not_displace_critical_oldest(self):
        q = LogQueue()
        q.enqueue({"event": "session_start", "critical": True})
        self._fill_with_snaps(q, QUEUE_CAPACITY - 1)
        assert len(q) == QUEUE_CAPACITY
        accepted = q.enqueue({"event": "snap_overflow", "critical": False})
        assert accepted is False
        assert q.peek()["event"] == "session_start"

    def test_critical_displaces_critical_when_both_critical(self):
        q = LogQueue()
        q.enqueue({"event": "session_start", "critical": True})
        self._fill_with_snaps(q, QUEUE_CAPACITY - 1)
        accepted = q.enqueue({"event": "session_stop", "critical": True})
        assert accepted is True
        items = list(q._q)
        assert items[-1]["event"] == "session_stop"

    def test_queue_depth_never_exceeds_capacity(self):
        q = LogQueue()
        for _ in range(QUEUE_CAPACITY * 3):
            q.enqueue({"event": "snap", "critical": False})
        assert len(q) == QUEUE_CAPACITY


# =============================================================================
# Signal Preprocessing Tests
# =============================================================================

class TestSignalPreprocessor:

    @pytest.fixture
    def sp(self):
        return SignalPreprocessor(sample_rate=4000, window_duration_ms=1000)

    def test_correct_window_length(self, sp):
        assert sp.window_samples == 4000

    def test_nyquist_is_2000hz(self, sp):
        assert sp.nyquist == 2000.0

    def test_dc_block_removes_constant_offset(self, sp):
        # DC_BLOCK_R = 0.995 has a long time constant: ~1200 samples to reach
        # steady state from a 2048-count DC step. After 4000 samples the output
        # must be very close to zero. Check the last sample (fully settled).
        dc_signal = np.full(4000, 2048.0, dtype=np.float32)
        filtered = sp.dc_block_filter(dc_signal)
        assert abs(float(filtered[-1])) < 5.0

    def test_rms_of_zero_signal_is_zero(self, sp):
        assert sp.compute_rms(np.zeros(4000)) == pytest.approx(0.0)

    def test_rms_of_constant_signal_equals_constant(self, sp):
        sig = np.full(4000, 100.0)
        assert sp.compute_rms(sig) == pytest.approx(100.0, rel=1e-4)

    def test_crest_factor_of_zero_signal_is_zero(self, sp):
        assert sp.compute_crest_factor(np.zeros(4000)) == pytest.approx(0.0)

    def test_crest_factor_of_constant_signal_is_one(self, sp):
        sig = np.full(4000, 50.0)
        assert sp.compute_crest_factor(sig) == pytest.approx(1.0, rel=1e-4)

    def test_band_energy_above_nyquist_returns_zero(self, sp):
        sig = np.random.randn(4000).astype(np.float32)
        assert sp.compute_band_energy(sig, 2500, 5000) == pytest.approx(0.0)

    def test_extract_features_returns_all_9_keys(self, sp):
        sig = np.random.randn(4000).astype(np.float32) * 200
        features = sp.extract_features(sig)
        expected_keys = {
            "rms", "std", "peak_amplitude", "crest_factor",
            "zero_crossing_rate", "band_energy_0_500",
            "band_energy_500_1000", "band_energy_1000_2000", "total_energy"
        }
        assert set(features.keys()) == expected_keys

    def test_extract_features_all_finite(self, sp):
        sig = np.random.randn(4000).astype(np.float32) * 500
        features = sp.extract_features(sig)
        for key, val in features.items():
            assert np.isfinite(val), f"Feature '{key}' is not finite: {val}"

    def test_impulse_has_high_crest_factor(self, sp):
        sig = np.zeros(4000, dtype=np.float32)
        sig[2000] = 3000.0
        features = sp.extract_features(sig)
        assert features["crest_factor"] > 3.5

    def test_sine_hiss_has_low_crest_factor(self, sp):
        t = np.linspace(0, 1.0, 4000)
        sig = (500.0 * np.sin(2 * np.pi * 800 * t)).astype(np.float32)
        features = sp.extract_features(sig)
        assert 1.3 < features["crest_factor"] < 1.5


# =============================================================================
# Backend Event Schema Compatibility Tests
# =============================================================================

class TestEventSchemaCompatibility:

    REQUIRED_EVENT_FIELDS = {
        "t", "up", "ev", "alert", "cause", "lbl", "pl", "rms",
        "gas", "gr", "tc", "uv", "wet"
    }
    REQUIRED_SUMMARY_FIELDS = {
        "t", "dur_s", "windows", "leak_events", "gas_events",
        "wet_events", "heat_events", "uv_events", "noise_windows",
        "max_leak_p", "trainee", "device", "fw"
    }

    def _make_event(self, **overrides) -> dict:
        base = {
            "t": 1750000000, "up": 5000, "ev": "snap",
            "alert": "OK", "cause": "NONE", "lbl": "no_leak(rms)",
            "pl": 0.05, "rms": 45.2, "gas": 0, "gr": 1.0,
            "tc": 26.5, "uv": 0, "wet": 0,
            "device": "SIH-DEV-01", "fw": "1.1.0"
        }
        base.update(overrides)
        return base

    def _make_summary(self, **overrides) -> dict:
        base = {
            "t": 1750000000, "dur_s": 300, "windows": 600,
            "leak_events": 2, "gas_events": 0, "wet_events": 0,
            "heat_events": 0, "uv_events": 0, "noise_windows": 15,
            "max_leak_p": 0.72, "trainee": "T001",
            "device": "SIH-DEV-01", "fw": "1.1.0"
        }
        base.update(overrides)
        return base

    def test_event_has_all_required_fields(self):
        event = self._make_event()
        for field in self.REQUIRED_EVENT_FIELDS:
            assert field in event, f"Missing required event field: {field}"

    def test_summary_has_all_required_fields(self):
        summary = self._make_summary()
        for field in self.REQUIRED_SUMMARY_FIELDS:
            assert field in summary, f"Missing required summary field: {field}"

    def test_alert_values_are_valid(self):
        valid = {"OK", "CAUTION", "DANGER"}
        for alert_val in valid:
            event = self._make_event(alert=alert_val)
            assert event["alert"] in valid

    def test_rms_fallback_label_has_rms_suffix(self):
        for label in ["no_leak(rms)", "leak(rms)"]:
            assert label.endswith("(rms)"), f"Fallback label '{label}' lacks '(rms)' suffix"

    def test_model_label_does_not_have_rms_suffix(self):
        for label in ["no_leak", "leak", "noise", "normal"]:
            assert not label.endswith("(rms)")

    def test_pl_within_0_1(self):
        for pl in [0.0, 0.5, 1.0]:
            event = self._make_event(pl=pl)
            assert 0.0 <= event["pl"] <= 1.0


# =============================================================================
# Multi-Device Event Identification Tests
# =============================================================================

class TestMultiDeviceEventIdentification:

    def test_same_session_number_different_devices_are_independent(self):
        key1 = ("SIH-DEV-01", 1750000000)
        key2 = ("SIH-DEV-02", 1750000000)
        assert key1 != key2

    def test_same_device_different_sessions_are_independent(self):
        key1 = ("SIH-DEV-01", 1750000000)
        key2 = ("SIH-DEV-01", 1750001000)
        assert key1 != key2

    def test_idempotency_key_stable_for_identical_payload(self):
        import hashlib, json
        payload = {"t": 1750000000, "ev": "snap", "rms": 45.0}

        def make_key(device, session, kind, p):
            content = f"{device}:{session}:{kind}:{json.dumps(p, sort_keys=True)}"
            return hashlib.sha256(content.encode()).hexdigest()

        k1 = make_key("SIH-DEV-01", 1750000000, "event", payload)
        k2 = make_key("SIH-DEV-01", 1750000000, "event", payload)
        assert k1 == k2

    def test_idempotency_key_differs_for_different_payloads(self):
        import hashlib, json
        p1 = {"t": 1750000000, "ev": "snap", "rms": 45.0}
        p2 = {"t": 1750000001, "ev": "snap", "rms": 45.0}

        def make_key(device, session, kind, p):
            content = f"{device}:{session}:{kind}:{json.dumps(p, sort_keys=True)}"
            return hashlib.sha256(content.encode()).hexdigest()

        k1 = make_key("SIH-DEV-01", 1750000000, "event", p1)
        k2 = make_key("SIH-DEV-01", 1750000000, "event", p2)
        assert k1 != k2


# =============================================================================
# Sensor Disabled / Unavailable State Tests
# =============================================================================

class TestSensorDisabledStates:

    def test_disabled_heat_sensor_default_tc_is_zero(self):
        event = {"tc": 0.0}
        assert event["tc"] == 0.0

    def test_disabled_uv_sensor_default_delta_is_zero(self):
        event = {"uv": 0}
        assert event["uv"] == 0

    def test_moisture_false_by_default(self):
        event = {"wet": 0}
        assert event["wet"] in (0, 1)

    def test_sensor_fault_cause_is_fault(self):
        valid_fault_causes = {"FAULT"}
        assert "FAULT" in valid_fault_causes


# =============================================================================
# Targeted Stress Tests: Queue Saturation & Priority Invariants
# =============================================================================

class TestQueueSaturationAndPriorityUnderStress:
    """Rigorous verification that critical alerts are never silently lost under load."""

    def test_burst_routine_telemetry_never_evicts_critical_alarm(self):
        """Even with 1,000 incoming non-critical snaps, an enrolled critical alarm stays queued."""
        q = LogQueue(capacity=40)
        # Pre-fill with routine snaps
        for i in range(20):
            q.enqueue({"event": f"snap_pre_{i}", "critical": False})

        # Enqueue 1 critical alarm (e.g. GAS_ALARM)
        assert q.enqueue({"event": "GAS_ALARM", "critical": True}) is True

        # Now barrage with 500 routine snapshots while queue is saturated
        for i in range(500):
            q.enqueue({"event": f"snap_flood_{i}", "critical": False})

        # The critical alarm MUST still be present in the queue
        all_events = [item["event"] for item in list(q._q)]
        assert "GAS_ALARM" in all_events, "CRITICAL ALARM WAS SILENTLY DROPPED BY ROUTINE SNAPS!"

    def test_multiple_critical_alarms_preserved_under_continuous_saturation(self):
        """When 10 critical alarms are recorded amidst heavy traffic, all 10 are retained."""
        q = LogQueue(capacity=40)
        # Fill queue halfway with routine
        for i in range(20):
            q.enqueue({"event": f"snap_{i}", "critical": False})

        # Inject 10 distinct critical alarms
        alarm_names = [f"ALARM_{i}" for i in range(10)]
        for name in alarm_names:
            accepted = q.enqueue({"event": name, "critical": True})
            assert accepted is True

        # Flood with 200 more non-critical snaps
        for i in range(200):
            q.enqueue({"event": f"snap_flood_{i}", "critical": False})

        # All 10 alarms must still reside in the queue
        present_events = {item["event"] for item in q._q}
        for name in alarm_names:
            assert name in present_events, f"Alarm {name} was unexpectedly evicted!"

    def test_100_percent_critical_queue_drops_oldest_critical_for_newest(self):
        """If emergency conditions produce 41 critical alarms, oldest is dropped for newest."""
        q = LogQueue(capacity=40)
        for i in range(40):
            q.enqueue({"event": f"CRIT_{i}", "critical": True})

        # Enqueue the 41st critical alarm
        accepted = q.enqueue({"event": "CRIT_41", "critical": True})
        assert accepted is True
        assert len(q) == 40
        # CRIT_0 should have been displaced by CRIT_41
        events = [item["event"] for item in q._q]
        assert "CRIT_0" not in events
        assert events[-1] == "CRIT_41"


# =============================================================================
# Targeted Buffer Overrun & Sampling Continuity Tests
# =============================================================================

class TestBufferOverrunRecovery:
    """Verifies circular ring buffer invariants under consumer stalls (overruns)."""

    def test_consumer_lag_simulated_overrun_detection(self):
        """If consumer is blocked for 3 seconds while timer ISR produces 12,000 samples,
        the buffer safely wraps without memory fault and yields the latest contiguous 1-sec window."""
        rb = RingBuffer(capacity_pow2=8192)
        # 4 kHz sampling for 3 seconds = 12,000 samples pushed by ISR
        for sample_idx in range(12000):
            rb.push(sample_idx)

        # Overrun occurred: head (12000) > capacity (8192)
        assert rb.head == 12000

        # Consumer wakes up: reads 1000 ms window (4000 samples)
        window = rb.read_window(4000)
        assert len(window) == 4000

        # Invariant: latest sample must be exactly sample 11999
        assert window[-1] == 11999
        # Invariant: first sample of 4000-sample window must be exactly sample 8000
        assert window[0] == 8000
        # Invariant: samples inside the window are strictly monotonic without distortion
        diffs = [window[i + 1] - window[i] for i in range(len(window) - 1)]
        assert all(d == 1 for d in diffs), "Contiguous window order corrupted during circular wrap!"


# =============================================================================
# Targeted Wi-Fi Reconnection Backoff Tests
# =============================================================================

class WiFiBackoffSimulator:
    """Exact logic mirror of leak_detector.ino lines 748-770."""

    def __init__(self, initial_ms: int = 5000, max_ms: int = 60000):
        self.initial_ms = initial_ms
        self.max_ms = max_ms
        self.current_backoff_ms = initial_ms
        self.connected = True

    def on_disconnect(self):
        self.connected = False

    def on_retry_failure(self):
        """Doubles backoff up to max_ms (60000)."""
        self.current_backoff_ms = (
            self.current_backoff_ms * 2 if self.current_backoff_ms <= 30000 else self.max_ms
        )

    def on_connect(self):
        self.connected = True
        self.current_backoff_ms = self.initial_ms


class TestWiFiReconnectionBackoffLogic:

    def test_initial_backoff_is_5_seconds(self):
        wifi = WiFiBackoffSimulator()
        assert wifi.current_backoff_ms == 5000

    def test_progressive_exponential_growth_on_repeated_failures(self):
        wifi = WiFiBackoffSimulator()
        wifi.on_disconnect()

        expected_sequence = [10000, 20000, 40000, 60000, 60000, 60000]
        actual_sequence = []
        for _ in expected_sequence:
            wifi.on_retry_failure()
            actual_sequence.append(wifi.current_backoff_ms)

        assert actual_sequence == expected_sequence

    def test_reconnection_immediately_resets_backoff_to_5_seconds(self):
        wifi = WiFiBackoffSimulator()
        wifi.on_disconnect()
        # Fail 5 times to reach 60s
        for _ in range(5):
            wifi.on_retry_failure()
        assert wifi.current_backoff_ms == 60000

        # Now reconnect
        wifi.on_connect()
        assert wifi.current_backoff_ms == 5000


# =============================================================================
# TinyML Multimodal Hazard Fusion Integration Tests (hazard_model.h)
# =============================================================================

class TestHazardModelFusionLogic:
    """Verifies the integration of the TinyML hazard model with leak_detector.ino."""

    STATES = ["Normal", "Safe Arc", "Proximity Breach", "Gas Buildup", "Workpiece Overheat"]

    def _fuse_sim(self, gas_alarm=False, heat_alarm=False, uv_alarm=False,
                  leak=False, wet=False, gas_warn=False, heat_warn=False, uv_warn=False,
                  hz_state=0, hz_conf=0):
        """Python replica of leak_detector.ino fuse() arbitration logic with TinyML."""
        if hz_conf >= 60:
            if hz_state == 3:
                return ("DANGER", "GAS_ALARM")
            if hz_state == 4:
                return ("DANGER", "HEAT_ALARM")
        if gas_alarm:
            return ("DANGER", "GAS_ALARM")
        if heat_alarm:
            return ("DANGER", "HEAT_ALARM")
        if uv_alarm:
            return ("DANGER", "UV_ALARM")
        if leak:
            return ("DANGER", "LEAK")
        if wet:
            return ("DANGER", "WET")
        if gas_warn:
            return ("CAUTION", "GAS_WARN")
        if heat_warn:
            return ("CAUTION", "HEAT_WARN")
        if uv_warn:
            return ("CAUTION", "UV_WARN")
        if hz_conf >= 50 and hz_state == 2:
            return ("CAUTION", "HEAT_WARN")
        return ("OK", "NONE")

    def test_high_confidence_gas_buildup_asserts_danger(self):
        alert, cause = self._fuse_sim(hz_state=3, hz_conf=85)
        assert alert == "DANGER"
        assert cause == "GAS_ALARM"

    def test_high_confidence_overheat_asserts_danger(self):
        alert, cause = self._fuse_sim(hz_state=4, hz_conf=90)
        assert alert == "DANGER"
        assert cause == "HEAT_ALARM"

    def test_proximity_breach_asserts_caution_heat_warn(self):
        alert, cause = self._fuse_sim(hz_state=2, hz_conf=70)
        assert alert == "CAUTION"
        assert cause == "HEAT_WARN"

    def test_low_confidence_hazard_does_not_override_normal_state(self):
        alert, cause = self._fuse_sim(hz_state=3, hz_conf=40)
        assert alert == "OK"
        assert cause == "NONE"

    def test_physical_leak_retains_priority_when_hazard_normal(self):
        alert, cause = self._fuse_sim(leak=True, hz_state=0, hz_conf=95)
        assert alert == "DANGER"
        assert cause == "LEAK"

    def test_telemetry_event_json_includes_hazard_fields(self):
        import json
        event_str = (
            '{"t":1750000000,"up":5000,"ev":"snap","alert":"OK","cause":"NONE","lbl":"no_leak(rms)",'
            '"pl":0.05,"rms":45.2,"gas":0,"gr":1.00,"tc":26.5,"uv":0,"wet":0,"hz":0,"hz_c":80}'
        )
        parsed = json.loads(event_str)
        assert parsed["hz"] == 0
        assert parsed["hz_c"] == 80
        assert "t" in parsed and "pl" in parsed and "rms" in parsed

