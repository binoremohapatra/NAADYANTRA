from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class AlertEnum(str, Enum):
    OK = "OK"
    CAUTION = "CAUTION"
    DANGER = "DANGER"


class UserRole(str, Enum):
    ADMIN = "admin"
    TRAINER = "trainer"


class HealthResponse(BaseModel):
    status: str
    timestamp: datetime


class ReadyResponse(BaseModel):
    status: str
    database: str
    timestamp: datetime


class SystemInfoResponse(BaseModel):
    api_version: str
    application_version: str
    environment: str
    server_utc: datetime


class DeviceRegisterRequest(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=50)
    name: Optional[str] = Field(None, max_length=100)
    device_key: str = Field(..., min_length=1)


class DeviceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    device_id: str
    name: Optional[str]
    firmware_version: Optional[str]
    last_seen_at: Optional[datetime]
    last_telemetry_at: Optional[datetime] = None
    device_metadata: Dict[str, Any]
    created_at: datetime
    is_active: bool
    is_online: Optional[bool] = None


class DeviceStatusResponse(BaseModel):
    device_id: str
    is_registered: bool = True
    is_active: bool = True
    is_online: bool
    last_seen_at: Optional[datetime] = None
    last_telemetry_at: Optional[datetime] = None
    has_data: bool = False
    is_stale: bool = True
    staleness_seconds: int = -1
    firmware_version: Optional[str] = None
    recent_activity_count: int = 0
    last_error: Optional[str] = None


class DeviceKeyRotateResponse(BaseModel):
    device_id: str
    device_key: str
    message: str = "Device key rotated successfully. Store this key securely; it will not be shown again."


class LatestTelemetryResponse(BaseModel):
    """Latest telemetry event for a device with explicit freshness metadata.

    has_data=False means no events have ever been ingested for this device.
    is_stale=True means the newest event is older than stale_after_seconds.
    staleness_seconds=-1 when has_data=False.
    event=None when has_data=False.
    """
    has_data: bool
    is_stale: bool
    staleness_seconds: int   # seconds since server_timestamp; -1 if no data
    event: Optional["EventResponse"] = None  # forward ref resolved below


class DeviceUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    is_active: Optional[bool] = None
    device_metadata: Optional[Dict[str, Any]] = None


class TraineeCreateRequest(BaseModel):
    trainee_id: str = Field(..., min_length=1, max_length=50)
    name: Optional[str] = Field(None, max_length=100)
    cohort: Optional[str] = Field(None, max_length=50)
    trainee_metadata: Optional[Dict[str, Any]] = None


class TraineeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    trainee_id: str
    name: Optional[str]
    cohort: Optional[str]
    trainee_metadata: Dict[str, Any]
    created_at: datetime
    is_active: bool


class TraineeUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    cohort: Optional[str] = Field(None, max_length=50)
    is_active: Optional[bool] = None
    trainee_metadata: Optional[Dict[str, Any]] = None


class SessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    session_id: int
    device_id: str
    trainee_id: str
    started_at: datetime
    ended_at: Optional[datetime]
    trainer_notes: Optional[str]
    session_metadata: Dict[str, Any]
    created_at: datetime


class SessionUpdateRequest(BaseModel):
    trainer_notes: Optional[str] = None
    session_metadata: Optional[Dict[str, Any]] = None


class EventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    device_id: str
    session_id: int
    internal_session_id: int
    trainee_id: str
    event_kind: str
    device_timestamp: Optional[int]
    server_timestamp: datetime
    device_uptime_ms: Optional[int]
    event_name: Optional[str]
    alert: Optional[str]
    cause: Optional[str]
    model_label: Optional[str]
    leak_probability: Optional[float]
    rms: Optional[float]
    gas_delta: Optional[int]
    gas_ratio: Optional[float]
    temperature: Optional[float]
    uv_delta: Optional[int]
    distance_mm: Optional[int] = None
    battery_v: Optional[float] = None
    wet: Optional[bool]
    firmware_version: Optional[str]
    raw_payload: Dict[str, Any]
    ingestion_status: str


class SessionSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    session_id: int
    device_session_id: int
    device_id: str
    trainee_id: str
    duration_seconds: Optional[int]
    windows: Optional[int]
    leak_events: Optional[int]
    gas_events: Optional[int]
    wet_events: Optional[int]
    heat_events: Optional[int]
    uv_events: Optional[int]
    noise_windows: Optional[int]
    max_leak_probability: Optional[float]
    firmware_version: Optional[str]
    raw_payload: Dict[str, Any]
    server_timestamp: datetime


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=1, max_length=50)
    password: str = Field(..., min_length=1)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8, description="Minimum 8 characters")


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: Dict[str, Any]


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    username: str
    role: str
    created_at: datetime
    is_active: bool


class AssessmentRubricCreateRequest(BaseModel):
    rubric_id: str = Field(..., min_length=1, max_length=50)
    version: str = Field(..., min_length=1, max_length=20)
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    rules: Dict[str, Any]


class AssessmentRubricResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    rubric_id: str
    version: str
    name: str
    description: Optional[str]
    rules: Dict[str, Any]
    created_by: str
    created_at: datetime
    is_active: bool


class AssessmentCreateRequest(BaseModel):
    assessment_id: str = Field(..., min_length=1, max_length=50)
    session_id: int
    rubric_id: str
    rubric_version: str
    evidence_event_ids: List[int]
    scoring_explanation: Optional[str] = None


class AssessmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    assessment_id: str
    session_id: int
    trainee_id: str
    rubric_id: str
    rubric_version: str
    evidence_event_ids: List[int]
    score: Optional[float]
    max_score: Optional[float]
    outcome: str
    scoring_explanation: Optional[str]
    created_by: str
    created_at: datetime


class TrainerReviewRequest(BaseModel):
    comments: Optional[str] = None
    override_score: Optional[float] = None
    override_outcome: Optional[str] = None


class TrainerReviewResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    assessment_id: str
    reviewer: str
    comments: Optional[str]
    override_score: Optional[float]
    override_outcome: Optional[str]
    reviewed_at: datetime


class DashboardOverviewResponse(BaseModel):
    total_sessions: int
    total_devices: int
    total_trainees: int
    total_events: int
    recent_sessions_count: int
    active_devices_count: int
    online_devices_count: int = 0
    offline_devices_count: int = 0
    stale_devices_count: int = 0
    never_reported_count: int = 0
    alert_events_count: int = 0
    recent_ingestion_failures_count: int = 0
    server_utc: Optional[datetime] = None


class DashboardRecentActivityItem(BaseModel):
    type: str  # session, event, alert
    timestamp: datetime
    device_id: str
    trainee_id: Optional[str]
    details: Dict[str, Any]


class DashboardTrendsResponse(BaseModel):
    time_bucket: str
    session_count: int
    event_count: int
    alert_count: int


class DashboardDeviceHealthResponse(BaseModel):
    device_id: str
    name: Optional[str]
    last_seen_at: Optional[datetime]
    is_online: bool
    total_sessions: int
    total_events: int
    last_error: Optional[str]


class DashboardAlertResponse(BaseModel):
    id: int
    device_id: str
    trainee_id: str
    timestamp: datetime
    alert: str
    cause: str
    details: Dict[str, Any]


class AuditLogResponse(BaseModel):
    id: int
    timestamp: datetime
    user: str
    action: str
    resource_type: str
    resource_id: Optional[str]
    details: Dict[str, Any]
    ip_address: Optional[str]

    class Config:
        from_attributes = True


class DiagnosticsIngestionResponse(BaseModel):
    accepted_events: int
    duplicate_events: int
    validation_failures: int
    server_errors: int
    total_processed: int


class DiagnosticsDatabaseResponse(BaseModel):
    database_status: str
    total_tables: int
    total_events: int
    total_sessions: int
    total_devices: int
    total_trainees: int


class PaginatedResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: List[Any]
