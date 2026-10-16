# HazGuard API Contracts

**Version:** 1.0.0
**Backend:** FastAPI
**Authentication:** JWT (Bearer Token) for dashboard users, X-Device-Key for firmware
**Base URL:** Configured per environment (default: http://localhost:8000)

---

## Authentication

### POST /api/v1/auth/login
Authenticate a user and receive a JWT access token.

**Request:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "username": "trainer",
    "role": "trainer",
    "created_at": "2026-10-16T00:00:00Z",
    "is_active": true
  }
}
```

**Error (401):** Invalid credentials

**Usage:** Include `Authorization: Bearer {access_token}` header in subsequent requests.

---

### POST /api/v1/auth/logout
Invalidate the current JWT token.

**Request:** No body
**Headers:** `Authorization: Bearer {token}`

**Response (200):** Success

---

### POST /api/v1/auth/refresh
Refresh authentication token.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
{
  "access_token": "new_token...",
  "token_type": "bearer"
}
```

**Note:** Token refresh is supported. Old tokens remain valid until expiry (no blacklist implemented).

---

### GET /api/v1/auth/me
Get current authenticated user information.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
{
  "id": 1,
  "username": "trainer",
  "role": "trainer",
  "created_at": "2026-10-16T00:00:00Z",
  "is_active": true
}
```

---

## Health & System

### GET /health
Basic liveness check.

**Response (200):**
```json
{
  "status": "healthy",
  "timestamp": "2026-10-16T12:00:00Z"
}
```

---

### GET /ready
Check database and service readiness.

**Response (200):**
```json
{
  "status": "ready",
  "database": "connected",
  "timestamp": "2026-10-16T12:00:00Z"
}
```

---

### GET /api/v1/system/info
Return API version, application version, environment, and server UTC time.

**Response (200):**
```json
{
  "api_version": "1.0.0",
  "application_version": "1.0.0",
  "environment": "production",
  "server_utc": "2026-10-16T12:00:00Z"
}
```

---

## Devices

### GET /api/v1/devices
Paginated device listing with search and filters.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1) - Page number
- `page_size` (int, default: 50, max: 100) - Items per page
- `is_active` (boolean, optional) - Filter by active status
- `search` (string, optional) - Search by device_id or name

**Response (200):**
```json
{
  "total": 10,
  "page": 1,
  "page_size": 50,
  "items": [
    {
      "id": 1,
      "device_id": "SIH-DEV-01",
      "name": "Device 1",
      "firmware_version": "1.1.0",
      "last_seen_at": "2026-10-16T12:00:00Z",
      "device_metadata": {},
      "created_at": "2026-10-16T00:00:00Z",
      "is_active": true
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

### GET /api/v1/devices/{device_id}
Get device metadata and latest known activity.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
{
  "id": 1,
  "device_id": "SIH-DEV-01",
  "name": "Device 1",
  "firmware_version": "1.1.0",
  "last_seen_at": "2026-10-16T12:00:00Z",
  "device_metadata": {},
  "created_at": "2026-10-16T00:00:00Z",
  "is_active": true
}
```

**Error (404):** Device not found

**Authorization:** Trainer or Admin

---

### GET /api/v1/devices/{device_id}/status
Get device status with online/offline calculation, telemetry freshness, and error diagnostics.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
{
  "device_id": "SIH-DEV-01",
  "is_registered": true,
  "is_active": true,
  "is_online": true,
  "last_seen_at": "2026-10-16T12:00:00Z",
  "last_telemetry_at": "2026-10-16T12:00:00Z",
  "has_data": true,
  "is_stale": false,
  "staleness_seconds": 15,
  "firmware_version": "1.1.0",
  "recent_activity_count": 15,
  "last_error": null
}
```

**Online vs Telemetry Freshness:**
- `is_online`: Device has authenticated contact within `DEVICE_ONLINE_THRESHOLD_SECONDS` (default: 300s).
- `has_data`: Device has at least one persisted telemetry record.
- `is_stale`: Telemetry age exceeds threshold (default: 300s or configurable).

**Error (404):** Device not found

**Authorization:** Trainer or Admin

---

### GET /api/v1/devices/{device_id}/telemetry/latest
Get newest ingested event for a device with explicit freshness metadata.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `stale_after_seconds` (int, default: 30, min: 5, max: 300) - Seconds threshold for staleness

**Response (200) - With Data:**
```json
{
  "has_data": true,
  "is_stale": false,
  "staleness_seconds": 15,
  "event": {
    "id": 100,
    "device_id": "SIH-DEV-01",
    "session_id": 1,
    "internal_session_id": 10,
    "trainee_id": "T001",
    "event_kind": "event",
    "device_timestamp": 1729084800000,
    "server_timestamp": "2026-10-16T12:00:00Z",
    "device_uptime_ms": 3600000,
    "event_name": "acoustic_monitoring",
    "alert": "OK",
    "cause": null,
    "model_label": null,
    "leak_probability": null,
    "rms": 45.2,
    "gas_delta": 10,
    "gas_ratio": 1.2,
    "temperature": null,
    "uv_delta": null,
    "wet": false,
    "firmware_version": "1.1.0",
    "raw_payload": {},
    "ingestion_status": "accepted"
  }
}
```

**Response (200) - No Data:**
```json
{
  "has_data": false,
  "is_stale": true,
  "staleness_seconds": -1,
  "event": null
}
```

**Note:** Returns HTTP 200 with `has_data=false` when no events exist - never 404.

**Error (404):** Device not found

**Authorization:** Trainer or Admin

---

### POST /api/v1/devices/register
Register or update a device with its authentication key.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "device_id": "SIH-DEV-01",
  "name": "Device 1",
  "device_key": "secure-random-key"
}
```

**Response (200):**
```json
{
  "id": 1,
  "device_id": "SIH-DEV-01",
  "name": "Device 1",
  "firmware_version": null,
  "last_seen_at": null,
  "device_metadata": {},
  "created_at": "2026-10-16T00:00:00Z",
  "is_active": true
}
```

**Authorization:** Admin only

---

### PATCH /api/v1/devices/{device_id}
Update permitted device metadata.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "name": "Updated Name",
  "is_active": true,
  "device_metadata": {
    "location": "Workshop A"
  }
}
```

**Response (200):** Updated device object

**Authorization:** Admin only

---

### POST /api/v1/devices/{device_id}/rotate-key
Admin-only secure device credential rotation. Immediately revokes old key hash and returns the newly generated secret key in a one-time issuance payload.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
{
  "device_id": "SIH-DEV-01",
  "device_key": "sec_w9Fk2_sample_key_only",
  "message": "Device key rotated successfully. Store this key securely in firmware configuration; it will not be displayed again."
}
```

**Authorization:** Admin only

---

### DELETE /api/v1/devices/{device_id}
Admin-only device revocation. Sets `is_active=false` on the device record and deactivates credentials, preventing further ingestion attempts.

**Headers:** `Authorization: Bearer {token}`

**Response (200):** Updated device object with `is_active=false`

**Authorization:** Admin only

---

## Dashboard

### GET /api/v1/dashboard/overview
Recorded sessions, recent activity, device counts, telemetry freshness breakdown, and event counts.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
{
  "total_sessions": 50,
  "total_devices": 5,
  "total_trainees": 10,
  "total_events": 1000,
  "recent_sessions_count": 3,
  "active_devices_count": 2,
  "online_devices_count": 2,
  "offline_devices_count": 3,
  "stale_devices_count": 1,
  "never_reported_count": 1,
  "alert_events_count": 14,
  "recent_ingestion_failures_count": 0,
  "server_utc": "2026-10-16T12:00:00Z"
}
```

**Notes:**
- `recent_sessions_count`: Sessions started in last 24 hours
- `active_devices_count`: Devices seen in last 5 minutes

**Authorization:** Trainer or Admin

---

### GET /api/v1/dashboard/recent-activity
Recent sessions and events with pagination.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1)
- `page_size` (int, default: 50, max: 100)

**Response (200):**
```json
{
  "total": 100,
  "page": 1,
  "page_size": 50,
  "items": [
    {
      "type": "session",
      "timestamp": "2026-10-16T12:00:00Z",
      "device_id": "SIH-DEV-01",
      "trainee_id": "T001",
      "details": {
        "session_id": 1,
        "status": "active"
      }
    },
    {
      "type": "alert",
      "timestamp": "2026-10-16T11:55:00Z",
      "device_id": "SIH-DEV-01",
      "trainee_id": "T001",
      "details": {
        "event_name": "gas_buildup",
        "alert": "CAUTION",
        "cause": "gas_threshold_exceeded"
      }
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

### GET /api/v1/dashboard/trends
Time-bucketed session/event counts.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `bucket` (string, default: "hour") - "hour", "day", or "week"
- `days` (int, default: 7, min: 1, max: 365) - Number of days to look back

**Response (200):**
```json
[
  {
    "time_bucket": "2026-10-16 12:00:00",
    "session_count": 5,
    "event_count": 100,
    "alert_count": 2
  }
]
```

**Authorization:** Trainer or Admin

---

### GET /api/v1/dashboard/device-health
Device activity and known health indicators.

**Headers:** `Authorization: Bearer {token}`

**Response (200):**
```json
[
  {
    "device_id": "SIH-DEV-01",
    "name": "Device 1",
    "last_seen_at": "2026-10-16T12:00:00Z",
    "is_online": true,
    "total_sessions": 10,
    "total_events": 500,
    "last_error": null
  }
]
```

**Authorization:** Trainer or Admin

---

### GET /api/v1/dashboard/alerts
Recorded device-reported alerts with filters.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1)
- `page_size` (int, default: 100, max: 500)
- `device_id` (string, optional) - Filter by device
- `alert_type` (string, optional) - Filter by alert type (OK, CAUTION, DANGER)

**Response (200):**
```json
{
  "total": 50,
  "page": 1,
  "page_size": 100,
  "items": [
    {
      "id": 100,
      "device_id": "SIH-DEV-01",
      "trainee_id": "T001",
      "timestamp": "2026-10-16T12:00:00Z",
      "alert": "CAUTION",
      "cause": "gas_threshold_exceeded",
      "details": {
        "event_name": "gas_buildup",
        "model_label": null,
        "leak_probability": null,
        "rms": 45.2,
        "gas_delta": 150
      }
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

## Events

### GET /api/v1/events
Paginated event history with filters.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1)
- `page_size` (int, default: 100, max: 500)
- `device_id` (string, optional)
- `session` (int, optional)
- `trainee_id` (string, optional)
- `kind` (string, optional) - "event" or "summary"
- `cause` (string, optional)
- `alert` (string, optional) - "OK", "CAUTION", "DANGER"
- `date_from` (datetime, optional)
- `date_to` (datetime, optional)

**Response (200):**
```json
{
  "total": 1000,
  "page": 1,
  "page_size": 100,
  "items": [
    {
      "id": 100,
      "device_id": "SIH-DEV-01",
      "session_id": 1,
      "internal_session_id": 10,
      "trainee_id": "T001",
      "event_kind": "event",
      "device_timestamp": 1729084800000,
      "server_timestamp": "2026-10-16T12:00:00Z",
      "device_uptime_ms": 3600000,
      "event_name": "acoustic_monitoring",
      "alert": "OK",
      "cause": null,
      "model_label": null,
      "leak_probability": null,
      "rms": 45.2,
      "gas_delta": 10,
      "gas_ratio": 1.2,
      "temperature": null,
      "uv_delta": null,
      "wet": false,
      "firmware_version": "1.1.0",
      "raw_payload": {},
      "ingestion_status": "accepted"
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

### GET /api/v1/events/{event_id}
Get one event's normalized fields and raw payload.

**Headers:** `Authorization: Bearer {token}`

**Response (200):** Event object (same structure as list items)

**Error (404):** Event not found

**Authorization:** Trainer or Admin

---

### GET /api/v1/summaries
Paginated session summary history with filters.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1)
- `page_size` (int, default: 50, max: 100)
- `device_id` (string, optional)
- `trainee_id` (string, optional)
- `date_from` (datetime, optional)
- `date_to` (datetime, optional)

**Response (200):**
```json
{
  "total": 50,
  "page": 1,
  "page_size": 50,
  "items": [
    {
      "id": 10,
      "session_id": 1,
      "device_session_id": 1,
      "device_id": "SIH-DEV-01",
      "trainee_id": "T001",
      "duration_seconds": 3600,
      "windows": 7200,
      "leak_events": 5,
      "gas_events": 2,
      "wet_events": 0,
      "heat_events": 0,
      "uv_events": 0,
      "noise_windows": 7200,
      "max_leak_probability": 0.85,
      "firmware_version": "1.1.0",
      "raw_payload": {},
      "server_timestamp": "2026-10-16T12:00:00Z"
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

## Sessions

### GET /api/v1/sessions
Paginated session listing with filters.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1)
- `page_size` (int, default: 50, max: 100)
- `device_id` (string, optional)
- `trainee_id` (string, optional)

**Response (200):**
```json
{
  "total": 50,
  "page": 1,
  "page_size": 50,
  "items": [
    {
      "id": 10,
      "session_id": 1,
      "device_id": "SIH-DEV-01",
      "trainee_id": "T001",
      "started_at": "2026-10-16T11:00:00Z",
      "ended_at": "2026-10-16T12:00:00Z",
      "trainer_notes": null,
      "session_metadata": {},
      "created_at": "2026-10-16T11:00:00Z"
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

### GET /api/v1/sessions/{session_id}
Get session details.

**Headers:** `Authorization: Bearer {token}`

**Response (200):** Session object (same structure as list items)

**Error (404):** Session not found

**Authorization:** Trainer or Admin

---

### PATCH /api/v1/sessions/{session_id}
Update session notes or metadata.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "trainer_notes": "Session notes",
  "session_metadata": {
    "location": "Workshop A"
  }
}
```

**Response (200):** Updated session object

**Authorization:** Trainer or Admin

---

## Trainees

### GET /api/v1/trainees
Paginated trainee listing with search.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `page` (int, default: 1)
- `page_size` (int, default: 50, max: 100)
- `search` (string, optional) - Search by trainee_id or name

**Response (200):**
```json
{
  "total": 10,
  "page": 1,
  "page_size": 50,
  "items": [
    {
      "id": 1,
      "trainee_id": "T001",
      "name": "Trainee 1",
      "cohort": "Cohort A",
      "trainee_metadata": {},
      "created_at": "2026-10-16T00:00:00Z",
      "is_active": true
    }
  ]
}
```

**Authorization:** Trainer or Admin

---

### POST /api/v1/trainees
Create a new trainee.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "trainee_id": "T002",
  "name": "Trainee 2",
  "cohort": "Cohort A",
  "trainee_metadata": {}
}
```

**Response (201):** Created trainee object

**Authorization:** Trainer or Admin

---

### PATCH /api/v1/trainees/{trainee_id}
Update trainee information.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "name": "Updated Name",
  "cohort": "Cohort B",
  "is_active": true
}
```

**Response (200):** Updated trainee object

**Authorization:** Trainer or Admin

---

## Firmware Ingestion

### POST /api/log
Ingest telemetry from ESP32 firmware.

**Headers:**
- `X-Device-Key: {device_key}` - Device authentication (NOT JWT)
- `Content-Type: application/json`

**Query Parameters:**
- `trainee` (string, required) - Trainee ID
- `session` (int, required) - Session ID
- `kind` (string, required) - "event" or "summary"
- `device` (string, optional) - Device ID (if not provided, backend infers from session)

**Request Body (event):**
```json
{
  "timestamp": 1729084800000,
  "uptime": 3600000,
  "event_name": "acoustic_monitoring",
  "alert": "OK",
  "cause": null,
  "model_label": null,
  "leak_probability": null,
  "rms": 45.2,
  "gas_delta": 10,
  "gas_ratio": 1.2,
  "temperature": null,
  "uv_delta": null,
  "wet": false,
  "firmware_version": "1.1.0"
}
```

**Response (200):** Success

**Error (401):** Invalid device key
**Error (422):** Validation error

**Authentication:** Device key (NOT JWT)

---

## Error Responses

### HTTP 401 Unauthorized
Invalid JWT token or device key.

**Response:**
```json
{
  "detail": "Could not validate credentials"
}
```

---

### HTTP 403 Forbidden
Insufficient permissions (e.g., non-admin accessing admin-only endpoint).

**Response:**
```json
{
  "detail": "Admin access required"
}
```

---

### HTTP 404 Not Found
Resource not found (device, session, event, etc.).

**Response:**
```json
{
  "detail": "Device not found"
}
```

---

### HTTP 422 Unprocessable Entity
Validation error (invalid request body, missing required fields).

**Response:**
```json
{
  "detail": [
    {
      "loc": ["body", "device_id"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

---

### HTTP 500 Internal Server Error
Server error (logged on backend).

**Response:**
```json
{
  "detail": "Internal server error"
}
```

---

## Pagination

All list endpoints support pagination:

**Query Parameters:**
- `page` (int, default: 1) - Page number (1-indexed)
- `page_size` (int, varies by endpoint) - Items per page

**Response Structure:**
```json
{
  "total": 1000,
  "page": 1,
  "page_size": 50,
  "items": [...]
}
```

**Calculations:**
- Total pages = ceil(total / page_size)
- Item range: [(page-1)*page_size + 1, min(page*page_size, total)]

---

## Alert Severity

**Enum Values:**
- `OK` - Normal operation
- `CAUTION` - Warning threshold exceeded
- `DANGER` - Critical threshold exceeded

**Display:**
- OK: Green
- CAUTION: Amber/Orange
- DANGER: Red

---

## Telemetry Freshness

**Latest Telemetry Endpoint:**
- `has_data`: true if events exist, false otherwise
- `is_stale`: true if data older than `stale_after_seconds`
- `staleness_seconds`: seconds since server_timestamp (-1 if no data)

**Device Online Status:**
- `is_online`: true if `last_seen_at` within `DEVICE_ONLINE_THRESHOLD_SECONDS` (default: 300s)
- Calculated by backend, use backend value instead of client-side calculation

---

## Timestamps

**Format:** ISO 8601 (UTC)
- Example: `2026-10-16T12:00:00Z`
- Timezone: Always UTC

**Device Timestamps:**
- `device_timestamp`: Unix epoch milliseconds (from ESP32)
- `server_timestamp`: ISO 8601 UTC (ingestion time)

---

## Firmware Telemetry Fields

**Required Fields:**
- `timestamp` (int) - Unix epoch milliseconds
- `uptime` (int) - Device uptime in milliseconds
- `event_name` (string) - Event name
- `alert` (string) - OK, CAUTION, or DANGER
- `rms` (float) - Acoustic RMS value

**Optional Fields:**
- `cause` (string) - Alert cause
- `model_label` (string) - ML model prediction
- `leak_probability` (float) - Leak confidence (0-1)
- `gas_delta` (int) - Gas sensor delta
- `gas_ratio` (float) - Gas sensor ratio
- `temperature` (float) - Temperature (if MLX90614 enabled)
- `uv_delta` (int) - UV delta (if GUVA-S12SD enabled)
- `wet` (boolean) - Moisture state
- `firmware_version` (string) - Firmware version

**Missing Fields:** Handled as null/None by backend

---

## Roles

**Enum Values:**
- `admin` - Full access including device registration
- `trainer` - Access to monitoring, sessions, trainees (no device registration)

**Authorization Levels:**
- Public: Health endpoints
- Device: Firmware ingestion (X-Device-Key)
- Trainer: Dashboard, devices, events, sessions, trainees
- Admin: All trainer endpoints + device registration

---

## OpenAPI Documentation

**Development:** http://localhost:8000/docs
**Production:** https://your-domain.com/docs

Interactive API documentation (Swagger UI) available at `/docs` endpoint.
