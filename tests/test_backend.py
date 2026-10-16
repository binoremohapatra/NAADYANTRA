"""
Comprehensive integration tests for HazGuard backend.
Run: pytest tests/test_backend.py -v
"""
import pytest
from backend.config import settings
from backend.auth import get_password_hash
from tests.conftest import TEST_DEVICE_KEY


class TestHealthEndpoints:
    """Test health and readiness endpoints."""

    def test_health_check(self, client):
        """Test basic liveness check."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data

    def test_readiness_check(self, client):
        """Test database and service readiness."""
        response = client.get("/ready")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] in ["ready", "not_ready"]
        assert "database" in data
        assert "timestamp" in data

    def test_system_info(self, client):
        """Test system info endpoint."""
        response = client.get("/api/v1/system/info")
        assert response.status_code == 200
        data = response.json()
        assert "api_version" in data
        assert "application_version" in data
        assert "environment" in data
        assert "server_utc" in data
        # Ensure no secrets are exposed
        assert "secret_key" not in data
        assert "device_key" not in data


class TestDeviceAuthentication:
    """Test device authentication for firmware ingestion."""

    def test_ingestion_with_valid_device_key(self, client, test_device):
        """Test ingestion with valid device key."""
        response = client.post(
            "/api/log?trainee=T001&session=1&kind=event",
            headers={"X-Device-Key": TEST_DEVICE_KEY},
            json={
                "t": 1234567890,
                "up": 1000,
                "ev": "session_start",
                "alert": "OK",
                "cause": "NONE",
                "lbl": "no_leak",
                "pl": 0.1,
                "rms": 50.0,
                "gas": 0,
                "gr": 1.0,
                "tc": 25.0,
                "uv": 0,
                "wet": 0,
                "device": "TEST-DEV-01",
                "fw": "1.1.0"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "accepted"

    def test_ingestion_missing_device_key(self, client):
        """Test ingestion with missing device key."""
        response = client.post(
            "/api/log?trainee=T001&session=1&kind=event",
            json={"ev": "session_start"}
        )
        assert response.status_code == 422  # Unprocessable Entity (missing header)

    def test_ingestion_invalid_device_key(self, client, db):
        """Test ingestion with invalid device key."""
        # Ensure global hash is not matching our test key
        from backend.config import settings
        original_hash = settings.device_key_hash
        settings.device_key_hash = "invalid-hash-that-wont-match"
        
        try:
            response = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": "invalid-key"},
                json={"ev": "session_start", "device": "TEST-DEV-INVALID"}
            )
            assert response.status_code == 401
        finally:
            settings.device_key_hash = original_hash

    def test_ingestion_auto_register_device(self, client, db):
        """Test auto-registration of unknown device."""
        # Set the global device key hash to match our test key
        from backend.config import settings
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            response = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json={
                    "ev": "session_start",
                    "device": "AUTO-DEV-01",
                    "fw": "1.1.0"
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "accepted"
        finally:
            settings.device_key_hash = original_hash


class TestFirmwareIngestion:
    """Test firmware event and summary ingestion."""

    def test_valid_event_ingestion(self, client, db):
        """Test valid event payload."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            response = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json={
                    "t": 1234567890,
                    "up": 1000,
                    "ev": "session_start",
                    "alert": "OK",
                    "cause": "NONE",
                    "lbl": "no_leak",
                    "pl": 0.1,
                    "rms": 50.0,
                    "gas": 0,
                    "gr": 1.0,
                    "tc": 25.0,
                    "uv": 0,
                    "wet": 0,
                    "device": "TEST-DEV-01",
                    "fw": "1.1.0"
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "accepted"
        finally:
            settings.device_key_hash = original_hash

    def test_valid_summary_ingestion(self, client, db):
        """Test valid summary payload."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            response = client.post(
                "/api/log?trainee=T001&session=1&kind=summary",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json={
                    "t": 1234567890,
                    "dur_s": 300,
                    "windows": 600,
                    "leak_events": 5,
                    "gas_events": 0,
                    "wet_events": 0,
                    "heat_events": 0,
                    "uv_events": 0,
                    "noise_windows": 10,
                    "max_leak_p": 0.85,
                    "trainee": "T001",
                    "device": "TEST-DEV-01",
                    "fw": "1.1.0"
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "accepted"
        finally:
            settings.device_key_hash = original_hash

    def test_invalid_json(self, client):
        """Test invalid JSON payload."""
        response = client.post(
            "/api/log?trainee=T001&session=1&kind=event",
            headers={"X-Device-Key": TEST_DEVICE_KEY},
            data="invalid json"
        )
        assert response.status_code == 422

    def test_invalid_kind(self, client):
        """Test invalid kind parameter."""
        response = client.post(
            "/api/log?trainee=T001&session=1&kind=invalid",
            headers={"X-Device-Key": TEST_DEVICE_KEY},
            json={"ev": "session_start"}
        )
        assert response.status_code == 400

    def test_zero_device_timestamp(self, client, db):
        """Test handling of zero/unsynchronized device timestamp."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            response = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json={
                    "t": 0,  # Unsynchronized
                    "up": 1000,
                    "ev": "session_start",
                    "device": "TEST-DEV-01"
                }
            )
            assert response.status_code == 200
        finally:
            settings.device_key_hash = original_hash

    def test_missing_optional_sensor_fields(self, client, db):
        """Test handling of missing optional sensor fields."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            response = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json={
                    "ev": "session_start",
                    "device": "TEST-DEV-01"
                    # Missing many optional fields
                }
            )
            assert response.status_code == 200
        finally:
            settings.device_key_hash = original_hash

    def test_duplicate_event_handling(self, client, db):
        """Test duplicate event retry handling."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            payload = {
                "t": 1234567890,
                "up": 1000,
                "ev": "session_start",
                "device": "TEST-DEV-01"
            }
            
            # First request
            response1 = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json=payload
            )
            assert response1.status_code == 200
            
            # Duplicate request
            response2 = client.post(
                "/api/log?trainee=T001&session=1&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json=payload
            )
            assert response2.status_code == 200
            data = response2.json()
            assert data["status"] == "accepted"
        finally:
            settings.device_key_hash = original_hash

    def test_duplicate_summary_handling(self, client, db):
        """Test duplicate summary retry handling."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            payload = {
                "dur_s": 300,
                "windows": 600,
                "device": "TEST-DEV-01",
                "trainee": "T001"
            }
            
            # First request
            response1 = client.post(
                "/api/log?trainee=T001&session=1&kind=summary",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json=payload
            )
            assert response1.status_code == 200
            
            # Duplicate request
            response2 = client.post(
                "/api/log?trainee=T001&session=1&kind=summary",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json=payload
            )
            assert response2.status_code == 200
        finally:
            settings.device_key_hash = original_hash


class TestAuthentication:
    """Test trainer/admin authentication."""

    def test_login_valid_credentials(self, client, admin_user):
        """Test login with valid credentials."""
        response = client.post("/api/v1/auth/login", json={
            "username": "admin",
            "password": "admin123"
        })
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert "user" in data

    def test_login_invalid_credentials(self, client, admin_user):
        """Test login with invalid credentials."""
        response = client.post("/api/v1/auth/login", json={
            "username": "admin",
            "password": "wrongpassword"
        })
        assert response.status_code == 401

    def test_get_current_user(self, client, auth_headers):
        """Test getting current user info."""
        response = client.get("/api/v1/auth/me", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "admin"
        assert data["role"] == "admin"

    def test_refresh_token(self, client, auth_headers):
        """Test token refresh."""
        response = client.post("/api/v1/auth/refresh", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data

    def test_unauthorized_access(self, client):
        """Test access without authentication."""
        response = client.get("/api/v1/devices")
        # FastAPI HTTPBearer returns 403 when header is missing
        assert response.status_code == 403


class TestDeviceManagement:
    """Test device management APIs."""

    def test_register_device(self, client, auth_headers):
        """Test device registration."""
        response = client.post(
            "/api/v1/devices/register",
            headers=auth_headers,
            json={
                "device_id": "NEW-DEV-01",
                "name": "New Device",
                "device_key": "new-key-456"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["device_id"] == "NEW-DEV-01"
        assert data["name"] == "New Device"

    def test_list_devices(self, client, auth_headers):
        """Test listing devices."""
        response = client.get("/api/v1/devices", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "items" in data
        assert isinstance(data["items"], list)

    def test_get_device(self, client, auth_headers, test_device):
        """Test getting specific device."""
        response = client.get("/api/v1/devices/TEST-DEV-01", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["device_id"] == "TEST-DEV-01"

    def test_get_device_status(self, client, auth_headers, test_device):
        """Test getting device status with canonical freshness fields."""
        response = client.get("/api/v1/devices/TEST-DEV-01/status", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["device_id"] == "TEST-DEV-01"
        assert "is_online" in data
        assert "is_registered" in data
        assert "is_active" in data
        assert "has_data" in data
        assert "is_stale" in data
        assert "staleness_seconds" in data

    def test_rotate_device_key(self, client, auth_headers, test_device):
        """Test admin device key rotation issuing a new one-time key."""
        response = client.post("/api/v1/devices/TEST-DEV-01/rotate-key", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["device_id"] == "TEST-DEV-01"
        assert "device_key" in data
        assert len(data["device_key"]) > 16

    def test_deactivate_device(self, client, auth_headers, test_device):
        """Test admin device deactivation."""
        response = client.delete("/api/v1/devices/TEST-DEV-01", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["is_active"] is False



class TestSessionManagement:
    """Test session management APIs."""

    def test_list_sessions(self, client, auth_headers):
        """Test listing sessions."""
        response = client.get("/api/v1/sessions", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "items" in data

    def test_create_session_via_firmware(self, client, db):
        """Test session creation via firmware session_start event."""
        original_hash = settings.device_key_hash
        settings.device_key_hash = get_password_hash(TEST_DEVICE_KEY)
        
        try:
            response = client.post(
                "/api/log?trainee=T002&session=2&kind=event",
                headers={"X-Device-Key": TEST_DEVICE_KEY},
                json={
                    "ev": "session_start",
                    "device": "TEST-DEV-01"
                }
            )
            assert response.status_code == 200
        finally:
            settings.device_key_hash = original_hash


class TestTraineeManagement:
    """Test trainee management APIs."""

    def test_create_trainee(self, client, auth_headers):
        """Test creating a trainee."""
        response = client.post(
            "/api/v1/trainees",
            headers=auth_headers,
            json={
                "trainee_id": "T002",
                "name": "Test Trainee",
                "cohort": "Cohort A"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["trainee_id"] == "T002"
        assert data["name"] == "Test Trainee"

    def test_list_trainees(self, client, auth_headers):
        """Test listing trainees."""
        response = client.get("/api/v1/trainees", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "items" in data


class TestEventAPIs:
    """Test event APIs."""

    def test_list_events(self, client, auth_headers):
        """Test listing events."""
        response = client.get("/api/v1/events", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "items" in data

    def test_list_events_with_filters(self, client, auth_headers):
        """Test listing events with filters."""
        response = client.get(
            "/api/v1/events?device_id=TEST-DEV-01&alert=DANGER",
            headers=auth_headers
        )
        assert response.status_code == 200


class TestAssessmentAPIs:
    """Test assessment and rubric APIs."""

    def test_create_rubric(self, client, auth_headers):
        """Test creating an assessment rubric."""
        response = client.post(
            "/api/v1/assessment-rubrics",
            headers=auth_headers,
            json={
                "rubric_id": "RUBRIC-001",
                "version": "1.0",
                "name": "Basic Leak Detection Rubric",
                "description": "Basic rubric for leak detection assessment",
                "rules": {
                    "leak_detection": {"weight": 0.5, "max_score": 10},
                    "response_time": {"weight": 0.3, "max_score": 5},
                    "accuracy": {"weight": 0.2, "max_score": 5}
                }
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["rubric_id"] == "RUBRIC-001"

    def test_list_rubrics(self, client, auth_headers):
        """Test listing rubrics."""
        response = client.get("/api/v1/assessment-rubrics", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "items" in data


class TestDashboardAPIs:
    """Test dashboard APIs."""

    def test_dashboard_overview(self, client, auth_headers):
        """Test dashboard overview."""
        response = client.get("/api/v1/dashboard/overview", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total_sessions" in data
        assert "total_devices" in data
        assert "total_trainees" in data
        assert "total_events" in data

    def test_recent_activity(self, client, auth_headers):
        """Test recent activity."""
        response = client.get("/api/v1/dashboard/recent-activity", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "items" in data

    def test_device_health(self, client, auth_headers):
        """Test device health."""
        response = client.get("/api/v1/dashboard/device-health", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)


class TestAuditAndDiagnostics:
    """Test audit and diagnostic APIs."""

    def test_ingestion_diagnostics(self, client, auth_headers):
        """Test ingestion diagnostics."""
        response = client.get("/api/v1/diagnostics/ingestion", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "accepted_events" in data
        assert "duplicate_events" in data
        assert "validation_failures" in data
        assert "server_errors" in data

    def test_database_diagnostics(self, client, auth_headers):
        """Test database diagnostics."""
        response = client.get("/api/v1/diagnostics/database", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "database_status" in data
        assert "total_tables" in data
        # Ensure no credentials are exposed
        assert "password" not in str(data).lower()
        assert "secret" not in str(data).lower()


class TestZeroMockPolicy:
    """Verifies that no fallback/mock objects are returned when querying non-existent records."""

    def test_unknown_device_returns_404_never_mock(self, client, auth_headers):
        """Requesting non-existent device returns 404, never a fabricated device."""
        response = client.get("/api/v1/devices/NON-EXISTENT-DEVICE-999", headers=auth_headers)
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()

    def test_unknown_session_returns_404_never_mock(self, client, auth_headers):
        """Requesting non-existent session returns 404, never a fabricated session."""
        response = client.get("/api/v1/sessions/999999", headers=auth_headers)
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()

    def test_unknown_assessment_returns_404_never_mock(self, client, auth_headers):
        """Requesting non-existent assessment returns 404, never a fabricated assessment."""
        response = client.get("/api/v1/assessments/NON-EXISTENT-EVAL-999", headers=auth_headers)
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()

    def test_empty_event_query_returns_empty_list_never_synthetic(self, client, auth_headers):
        """Querying events for a non-existent device returns empty list, never synthetic records."""
        response = client.get("/api/v1/events?device_id=NON-EXISTENT-DEVICE-999", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 0
        assert data["items"] == []


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
