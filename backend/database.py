from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text, JSON, Index, UniqueConstraint
from sqlalchemy.orm import declarative_base, sessionmaker, relationship
from datetime import datetime, timezone
from typing import Optional
import hashlib

from backend.config import settings

# SQLite needs check_same_thread=False; PostgreSQL does not need it
_connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=_connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="trainer")  # admin, trainer
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = Column(Boolean, default=True)


class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(100))
    firmware_version = Column(String(20))
    last_seen_at = Column(DateTime)
    last_telemetry_at = Column(DateTime, nullable=True)
    device_metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = Column(Boolean, default=True)

    credentials = relationship("DeviceCredential", back_populates="device", uselist=False)
    sessions = relationship("Session", back_populates="device")


class DeviceCredential(Base):
    __tablename__ = "device_credentials"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(50), ForeignKey("devices.device_id"), nullable=False, unique=True)
    key_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = Column(Boolean, default=True)

    device = relationship("Device", back_populates="credentials")


class Trainee(Base):
    __tablename__ = "trainees"

    id = Column(Integer, primary_key=True, index=True)
    trainee_id = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(100))
    cohort = Column(String(50))
    trainee_metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = Column(Boolean, default=True)

    sessions = relationship("Session", back_populates="trainee")


class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, nullable=False, index=True)  # Device's session ID (uint32)
    device_id = Column(String(50), ForeignKey("devices.device_id"), nullable=False, index=True)
    trainee_id = Column(String(50), ForeignKey("trainees.trainee_id"), nullable=False, index=True)
    started_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime, nullable=True)
    trainer_notes = Column(Text)
    session_metadata = Column(JSON, default={})
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    device = relationship("Device", back_populates="sessions")
    trainee = relationship("Trainee", back_populates="sessions")
    events = relationship("Event", back_populates="session")
    summary = relationship("SessionSummary", back_populates="session", uselist=False)
    assessments = relationship("Assessment", back_populates="session")

    __table_args__ = (
        Index("ix_sessions_device_session", "device_id", "session_id"),
    )


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(50), ForeignKey("devices.device_id"), nullable=False, index=True)
    session_id = Column(Integer, nullable=False, index=True)  # Device's session ID
    internal_session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False, index=True)
    trainee_id = Column(String(50), nullable=False, index=True)
    event_kind = Column(String(20), nullable=False, index=True)  # event or summary (for events)
    device_timestamp = Column(Integer, nullable=True)  # Unix timestamp from device (0 if unsynced)
    server_timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    device_uptime_ms = Column(Integer, nullable=True)
    event_name = Column(String(50), nullable=True, index=True)
    alert = Column(String(20), nullable=True, index=True)
    cause = Column(String(50), nullable=True, index=True)
    model_label = Column(String(50), nullable=True)
    leak_probability = Column(Float, nullable=True)
    rms = Column(Float, nullable=True)
    gas_delta = Column(Integer, nullable=True)
    gas_ratio = Column(Float, nullable=True)
    temperature = Column(Float, nullable=True)
    uv_delta = Column(Integer, nullable=True)
    wet = Column(Boolean, nullable=True)
    firmware_version = Column(String(20), nullable=True)
    raw_payload = Column(JSON, nullable=False)
    ingestion_status = Column(String(20), default="accepted", index=True)  # accepted, duplicate, error
    idempotency_key = Column(String(64), nullable=True, index=True)  # SHA-256 hash for deduplication

    session = relationship("Session", back_populates="events")

    @property
    def distance_mm(self) -> Optional[int]:
        """Extracted from raw_payload if distance sensor is populated (VL53L0X)."""
        if self.raw_payload and isinstance(self.raw_payload, dict):
            d = self.raw_payload.get("dist") or self.raw_payload.get("dist_mm")
            if d is not None and isinstance(d, (int, float)) and d >= 0:
                return int(d)
        return None

    @property
    def battery_v(self) -> Optional[float]:
        """Extracted from raw_payload if battery voltage is reported (1S LiPo)."""
        if self.raw_payload and isinstance(self.raw_payload, dict):
            vb = self.raw_payload.get("vbat") or self.raw_payload.get("v_bat")
            if vb is not None and isinstance(vb, (int, float)) and vb > 0:
                return round(float(vb), 2)
        return None

    __table_args__ = (
        Index("ix_events_device_session_time", "device_id", "session_id", "server_timestamp"),
        Index("ix_events_idempotency", "idempotency_key"),
    )


class SessionSummary(Base):
    __tablename__ = "session_summaries"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False, unique=True)
    device_session_id = Column(Integer, nullable=False)
    device_id = Column(String(50), nullable=False)
    trainee_id = Column(String(50), nullable=False)
    duration_seconds = Column(Integer, nullable=True)
    windows = Column(Integer, nullable=True)
    leak_events = Column(Integer, nullable=True)
    gas_events = Column(Integer, nullable=True)
    wet_events = Column(Integer, nullable=True)
    heat_events = Column(Integer, nullable=True)
    uv_events = Column(Integer, nullable=True)
    noise_windows = Column(Integer, nullable=True)
    max_leak_probability = Column(Float, nullable=True)
    firmware_version = Column(String(20), nullable=True)
    raw_payload = Column(JSON, nullable=False)
    server_timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    idempotency_key = Column(String(64), nullable=True, unique=True, index=True)

    session = relationship("Session", back_populates="summary")


class AssessmentRubric(Base):
    __tablename__ = "assessment_rubrics"

    id = Column(Integer, primary_key=True, index=True)
    rubric_id = Column(String(50), unique=True, nullable=False, index=True)
    version = Column(String(20), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(Text)
    rules = Column(JSON, nullable=False)  # Scoring rules and criteria
    created_by = Column(String(50), nullable=False)  # username
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_active = Column(Boolean, default=True)


class Assessment(Base):
    __tablename__ = "assessments"

    id = Column(Integer, primary_key=True, index=True)
    assessment_id = Column(String(50), unique=True, nullable=False, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    trainee_id = Column(String(50), nullable=False)
    rubric_id = Column(String(50), nullable=False)
    rubric_version = Column(String(20), nullable=False)
    evidence_event_ids = Column(JSON, nullable=False)  # List of event IDs used as evidence
    score = Column(Float, nullable=True)
    max_score = Column(Float, nullable=True)
    outcome = Column(String(50), nullable=False)  # competent, needs_improvement, not_assessable
    scoring_explanation = Column(Text)
    created_by = Column(String(50), nullable=False)  # username
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    session = relationship("Session", back_populates="assessments")
    reviews = relationship("TrainerReview", back_populates="assessment")


class TrainerReview(Base):
    __tablename__ = "trainer_reviews"

    id = Column(Integer, primary_key=True, index=True)
    assessment_id = Column(String(50), ForeignKey("assessments.assessment_id"), nullable=False)
    reviewer = Column(String(50), nullable=False)  # username
    comments = Column(Text)
    override_score = Column(Float, nullable=True)
    override_outcome = Column(String(50), nullable=True)
    reviewed_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    assessment = relationship("Assessment", back_populates="reviews")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    user = Column(String(50), nullable=False, index=True)
    action = Column(String(100), nullable=False)
    resource_type = Column(String(50), nullable=False)
    resource_id = Column(String(50), nullable=True)
    details = Column(JSON, default={})
    ip_address = Column(String(50), nullable=True)


class IngestionError(Base):
    __tablename__ = "ingestion_errors"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    device_id = Column(String(50), nullable=True, index=True)
    error_type = Column(String(50), nullable=False, index=True)  # auth_error, validation_error, database_error
    error_message = Column(Text, nullable=False)
    payload = Column(JSON, nullable=True)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_idempotency_key(device_id: str, session_id: int, kind: str, payload: dict) -> str:
    """Create a fingerprint for idempotency based on available identifiers."""
    # Use device_id, session_id, kind, and a canonicalized payload fingerprint
    fingerprint = f"{device_id}:{session_id}:{kind}:"
    # Include key fields that define uniqueness
    key_fields = ["t", "up", "ev", "alert", "cause"]
    for field in key_fields:
        if field in payload:
            fingerprint += f"{field}={payload[field]};"
    return hashlib.sha256(fingerprint.encode()).hexdigest()
