# HazGuard Connectivity Policy

**Date:** 2026-10-16
**Status:** Documented Backend and Flutter Agreement
**Purpose:** Define consistent online/offline/stale behavior across Flutter and web dashboard

---

## Overview

This document defines the connectivity status calculation policy used by the backend and consumed by Flutter and the web dashboard. The policy ensures consistent behavior across all clients.

---

## Policy Definitions

### 1. Device Online/Offline Status

**Purpose:** Determine whether a device is currently considered active based on its last authenticated contact.

**Backend Endpoint:** `GET /api/v1/devices/{device_id}/status`
**Response Field:** `is_online` (boolean)

**Calculation Logic:**
```python
# backend/routers/devices.py (lines 134-137)
threshold = datetime.now(timezone.utc) - timedelta(seconds=settings.device_online_threshold_seconds)
is_online = device.last_seen_at > threshold
```

**Configuration:**
- Environment variable: `DEVICE_ONLINE_THRESHOLD_SECONDS`
- Default value: `300` seconds (5 minutes)
- Configurable in `.env`

**Status Values:**
- **Online:** `last_seen_at` is within the threshold (e.g., less than 5 minutes ago)
- **Offline:** `last_seen_at` is older than the threshold
- **Unknown:** `last_seen_at` is `null` (device has never contacted the backend)

**Flutter Implementation:**
```dart
// mobile_app/lib/shared/models/device.dart (lines 54-66)
String get connectivityStatus {
  if (lastSeenAt == null) return 'unknown';

  final now = DateTime.now().toUtc();
  final difference = now.difference(lastSeenAt!);
  const onlineThreshold = Duration(seconds: 300); // Match backend default

  if (difference < onlineThreshold) {
    return 'online';
  } else {
    return 'offline';
  }
}
```

**Important Notes:**
- `last_seen_at` represents the last time the device successfully ingested telemetry or registered
- This is NOT a heartbeat endpoint - it's derived from event ingestion timestamps
- A device can be "online" even if it hasn't sent telemetry recently (within threshold)
- `last_seen_at` is updated automatically on every successful `/api/log` ingestion

---

### 2. Telemetry Staleness

**Purpose:** Determine whether the latest telemetry data is fresh enough to be considered "live" for display purposes.

**Backend Endpoint:** `GET /api/v1/devices/{device_id}/telemetry/latest`
**Response Fields:**
- `has_data` (boolean): Whether any telemetry exists for this device
- `is_stale` (boolean): Whether the latest telemetry is older than the freshness threshold
- `staleness_seconds` (int): Seconds since server_timestamp (-1 if no data)

**Calculation Logic:**
```python
# backend/routers/devices.py (lines 165-171)
stale_after_seconds: int = Query(30, ge=5, le=300)

now_utc = datetime.now(timezone.utc)
ts = latest_event.server_timestamp
if ts.tzinfo is None:
    ts = ts.replace(tzinfo=timezone.utc)
staleness_seconds = (now_utc - ts).total_seconds()
is_stale = staleness_seconds > stale_after_seconds
```

**Configuration:**
- Query parameter: `stale_after_seconds`
- Default value: `30` seconds
- Valid range: `5` to `300` seconds

**Status Values:**
- **Fresh:** Latest telemetry is within `stale_after_seconds` (e.g., less than 30 seconds old)
- **Stale:** Latest telemetry is older than `stale_after_seconds`
- **No Data:** Device has never sent telemetry (`has_data=False`)

**Flutter Implementation:**
```dart
// mobile_app/lib/shared/services/device_repository.dart (lines 212-251)
Future<LatestTelemetry> getLatestTelemetry(
  String deviceId, {
  int staleAfterSeconds = 30,
  bool useCache = true,
}) async {
  final response = await _apiClient.get(
    ApiConstants.deviceLatestTelemetry(deviceId),
    queryParameters: <String, dynamic>{
      'stale_after_seconds': staleAfterSeconds,
    },
  );
  return LatestTelemetry.fromJson(response.data as Map<String, dynamic>);
}
```

**Important Notes:**
- Telemetry staleness is separate from device online/offline status
- A device can be "online" (recent contact) but have "stale" telemetry (old data)
- This allows the UI to show "Device online, but data is 2 minutes old"
- The 30-second default is stricter than the 5-minute online threshold

---

## Visual States and UI Guidelines

### Flutter UI States

| State | Display Condition | Visual Indicator | Action |
|-------|------------------|------------------|--------|
| **Online + Fresh** | `is_online=true` AND `is_stale=false` | Green beacon, "ONLINE" pill | Show live data |
| **Online + Stale** | `is_online=true` AND `is_stale=true` | Yellow beacon, "ONLINE" pill + "Data stale" banner | Show data with staleness warning |
| **Offline** | `is_online=false` | Gray beacon, "OFFLINE" pill | Show last-known data with "Last seen X ago" |
| **Unknown** | `last_seen_at=null` | Gray beacon, "UNKNOWN" pill | Show "Never connected" empty state |
| **No Telemetry** | `has_data=false` | N/A | Show "Awaiting first telemetry" empty state |

### Empty State Messages

- **No Devices:** "No devices registered. Add a device to begin monitoring."
- **No Telemetry:** "Device has not sent telemetry yet. Waiting for first data packet."
- **Never Connected:** "Device has never connected to the backend. Check device power and WiFi."
- **Backend Unreachable:** "Cannot connect to backend. Check network connection."

---

## Backend API Contract

### Device Status Endpoint

**Request:**
```
GET /api/v1/devices/{device_id}/status
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "device_id": "SIH-DEV-01",
  "last_seen_at": "2026-10-16T10:30:00Z",
  "firmware_version": "1.1.0",
  "is_online": true,
  "recent_activity_count": 42,
  "last_error": null
}
```

### Latest Telemetry Endpoint

**Request:**
```
GET /api/v1/devices/{device_id}/telemetry/latest?stale_after_seconds=30
Authorization: Bearer <jwt_token>
```

**Response (Fresh Data):**
```json
{
  "has_data": true,
  "is_stale": false,
  "staleness_seconds": 15,
  "event": {
    "id": 1234,
    "device_id": "SIH-DEV-01",
    "rms": 142.5,
    "gas_delta": 15,
    "alert": "OK",
    "server_timestamp": "2026-10-16T10:30:15Z"
  }
}
```

**Response (Stale Data):**
```json
{
  "has_data": true,
  "is_stale": true,
  "staleness_seconds": 90,
  "event": { ... }
}
```

**Response (No Data):**
```json
{
  "has_data": false,
  "is_stale": true,
  "staleness_seconds": -1,
  "event": null
}
```

---

## Web Dashboard Implementation

### Overview Page

**Required Metrics:**
- Total registered devices
- Online devices (using 5-minute threshold)
- Offline devices
- Devices with stale telemetry (using 30-second threshold)
- Total events in last 24 hours

**API:** `GET /api/v1/dashboard/overview`

### Device Inventory

**Required Filters:**
- All devices
- Online only
- Offline only
- Stale telemetry only
- Search by device ID or name

**API:** `GET /api/v1/devices?page=1&page_size=50&is_active=true&search=...`

### Device Detail View

**Required Information:**
- Device ID and name
- Connectivity status (online/offline/unknown)
- Last seen timestamp
- Firmware version
- Latest telemetry (if available)
- Staleness indicator
- Recent activity count
- Last error (if any)

**APIs:**
- `GET /api/v1/devices/{device_id}`
- `GET /api/v1/devices/{device_id}/status`
- `GET /api/v1/devices/{device_id}/telemetry/latest`

### Alerts View

**Required Filters:**
- All alerts
- DANGER alerts only
- CAUTION alerts only
- Filter by device ID
- Filter by time range

**API:** `GET /api/v1/dashboard/alerts?page=1&page_size=100&device_id=...&alert_type=...`

---

## Configuration Recommendations

### Development Environment
```env
DEVICE_ONLINE_THRESHOLD_SECONDS=300  # 5 minutes - allows for testing delays
```

### Production Environment
```env
DEVICE_ONLINE_THRESHOLD_SECONDS=300  # 5 minutes - standard for IoT devices
```

### High-Security Environment
```env
DEVICE_ONLINE_THRESHOLD_SECONDS=60   # 1 minute - stricter monitoring
```

---

## Important Distinctions

### Device Online vs Telemetry Fresh

| Concept | Threshold | Purpose | Use Case |
|---------|-----------|---------|----------|
| **Device Online** | 300s (5 min) | Device has contacted backend recently | "Is the device powered on and connected?" |
| **Telemetry Fresh** | 30s (configurable) | Latest data is recent enough for display | "Is this data live enough to show?" |

### last_seen_at vs server_timestamp

| Field | Meaning | Updated When |
|-------|---------|--------------|
| **last_seen_at** | Last time device contacted backend | Every successful `/api/log` ingestion |
| **server_timestamp** | Timestamp of specific event | Per-event ingestion |

### Backend Unreachable vs Device Offline

| Scenario | User Perception | Backend Status | Device Status |
|----------|----------------|----------------|--------------|
| Backend down | "Cannot load data" | N/A | Unknown (can't query) |
| Network failure | "Cannot load data" | N/A | Unknown (can't query) |
| Device powered off | "Device offline" | Online | Offline |
| Device WiFi down | "Device offline" | Online | Offline |
| Device not flashed | "Never connected" | Online | Unknown |

---

## Testing Checklist

### Backend Tests
- [ ] Device with recent last_seen_at returns `is_online=true`
- [ ] Device with old last_seen_at returns `is_online=false`
- [ ] Device with null last_seen_at returns `is_online=false`
- [ ] Custom DEVICE_ONLINE_THRESHOLD_SECONDS is respected
- [ ] Latest telemetry within stale_after_seconds returns `is_stale=false`
- [ ] Latest telemetry older than stale_after_seconds returns `is_stale=true`
- [ ] Device with no events returns `has_data=false`

### Flutter Tests
- [ ] Device model `connectivityStatus` returns correct values
- [ ] Device model `stalenessText` formats correctly
- [ ] Device model `isStale` matches connectivity status
- [ ] Online device shows green indicator
- [ ] Offline device shows gray indicator
- [ ] Unknown device shows "Never seen" text
- [ ] Stale telemetry shows warning banner

### Web Dashboard Tests
- [ ] Overview page counts online devices correctly
- [ ] Device inventory filters work
- [ ] Device detail shows last_seen_at correctly
- [ ] Staleness indicator matches backend calculation
- [ ] Empty states display for no data scenarios

---

## Migration Notes

If the threshold needs to change in the future:

1. Update `.env` with new `DEVICE_ONLINE_THRESHOLD_SECONDS`
2. Restart backend to load new configuration
3. Flutter uses hardcoded 300s - update if backend default changes
4. Web dashboard should respect backend-computed `is_online` field (do not recalculate client-side)

---

## References

- Backend implementation: `backend/routers/devices.py` (lines 119-159)
- Backend configuration: `backend/config.py` (line 14)
- Flutter Device model: `mobile_app/lib/shared/models/device.dart` (lines 50-87)
- Flutter repository: `mobile_app/lib/shared/services/device_repository.dart` (lines 96-120, 212-251)
