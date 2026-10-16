from fastapi import APIRouter, Header, HTTPException, status, Query, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import Optional
import logging

from backend.database import get_db, Device, Session as DBSession, Event, SessionSummary, IngestionError, DeviceCredential, create_idempotency_key
from backend.auth import verify_device_key, verify_password
from backend.config import settings
from backend.schemas import EventResponse, SessionSummaryResponse

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/api/log")
async def firmware_log(
    trainee: str = Query(..., alias="trainee"),
    session: int = Query(..., alias="session"),
    kind: str = Query(..., alias="kind"),
    device: Optional[str] = Query(None, alias="device"),
    x_device_key: str = Header(..., alias="X-Device-Key"),
    payload: dict = None,
    db: Session = Depends(get_db)
):
    """
    Firmware-compatible ingestion endpoint.
    Accepts event and summary payloads from ESP32 devices.
    """
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="JSON payload required"
        )
    
    # Validate kind
    if kind not in ["event", "summary"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid kind: {kind}. Must be 'event' or 'summary'"
        )
    
    # Extract device_id from payload, query param, or lookup from existing session
    device_id = (payload.get("device") if isinstance(payload, dict) else None) or device
    if not device_id:
        existing_sess = db.query(DBSession).filter(DBSession.session_id == session).first()
        if existing_sess and existing_sess.device_id:
            device_id = existing_sess.device_id
        else:
            device_id = "UNKNOWN"
    
    # Authenticate device - first check device-specific credential, then fall back to global
    device_credential = db.query(DeviceCredential).filter(
        DeviceCredential.device_id == device_id,
        DeviceCredential.is_active == True
    ).first()
    
    authenticated = False
    if device_credential:
        # Check against device-specific credential
        if verify_password(x_device_key, device_credential.key_hash):
            authenticated = True
    else:
        # Fall back to global device key hash (for auto-registration or initial setup)
        if verify_device_key(x_device_key):
            authenticated = True
    
    if not authenticated:
        logger.warning(f"Failed device authentication attempt from trainee={trainee}, device={device_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device key"
        )
    
    # Verify device exists in database
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if device is None:
        # Auto-register device if it doesn't exist (for initial setup)
        device = Device(
            device_id=device_id,
            name=device_id,
            firmware_version=payload.get("fw"),
            last_seen_at=datetime.now(timezone.utc),
            last_telemetry_at=datetime.now(timezone.utc),
            device_metadata={},
            is_active=True
        )
        db.add(device)
        db.commit()
        db.refresh(device)
        logger.info(f"Auto-registered new device: {device_id}")
    else:
        # Update last_seen_at, last_telemetry_at, and firmware version
        device.last_seen_at = datetime.now(timezone.utc)
        device.last_telemetry_at = datetime.now(timezone.utc)
        if payload.get("fw"):
            device.firmware_version = payload.get("fw")
        db.commit()
    
    try:
        if kind == "event":
            return await handle_event(device_id, trainee, session, payload, db)
        else:  # summary
            return await handle_summary(device_id, trainee, session, payload, db)
    except Exception as e:
        logger.error(f"Error processing {kind} for device {device_id}: {str(e)}")
        # Log ingestion error
        error = IngestionError(
            device_id=device_id,
            error_type="database_error",
            error_message=str(e),
            payload=payload
        )
        db.add(error)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during ingestion"
        )


async def handle_event(device_id: str, trainee_id: str, session_id: int, payload: dict, db: Session):
    """Handle event payload from firmware."""
    # Create idempotency key
    idempotency_key = create_idempotency_key(device_id, session_id, "event", payload)
    
    # Check for duplicate
    existing = db.query(Event).filter(Event.idempotency_key == idempotency_key).first()
    if existing:
        logger.info(f"Duplicate event detected, returning 200: {idempotency_key[:16]}...")
        return {"status": "accepted", "note": "duplicate"}
    
    # Find or create internal session
    internal_session = db.query(DBSession).filter(
        DBSession.device_id == device_id,
        DBSession.session_id == session_id
    ).first()
    
    # Ensure trainee exists
    from backend.database import Trainee
    trainee = db.query(Trainee).filter(Trainee.trainee_id == trainee_id).first()
    if not trainee:
        trainee = Trainee(
            trainee_id=trainee_id,
            name=trainee_id,
            is_active=True
        )
        db.add(trainee)
        db.commit()
        db.refresh(trainee)
    
    event_name = payload.get("ev")
    
    # Create session on session_start event if it doesn't exist
    if event_name == "session_start" and not internal_session:
        internal_session = DBSession(
            session_id=session_id,
            device_id=device_id,
            trainee_id=trainee_id,
            started_at=datetime.now(timezone.utc),
            session_metadata={}
        )
        db.add(internal_session)
        db.commit()
        db.refresh(internal_session)
    
    # If session still doesn't exist, create it (for events after session_start)
    if not internal_session:
        internal_session = db.query(DBSession).filter(
            DBSession.device_id == device_id,
            DBSession.session_id == session_id
        ).first()
        if not internal_session:
            # Estimate start time from device uptime
            uptime_ms = payload.get("up", 0)
            estimated_start = datetime.now(timezone.utc)
            if uptime_ms > 0:
                from datetime import timedelta
                estimated_start = estimated_start - timedelta(milliseconds=uptime_ms)
            
            internal_session = DBSession(
                session_id=session_id,
                device_id=device_id,
                trainee_id=trainee_id,
                started_at=estimated_start,
                session_metadata={"auto_created": True}
            )
            db.add(internal_session)
            db.commit()
            db.refresh(internal_session)
    
    # Update session end time on session_stop
    if event_name == "session_stop" and internal_session:
        internal_session.ended_at = datetime.now(timezone.utc)
        db.commit()
    
    # Create event record
    event = Event(
        device_id=device_id,
        session_id=session_id,
        internal_session_id=internal_session.id,
        trainee_id=trainee_id,
        event_kind="event",
        device_timestamp=payload.get("t") if "t" in payload else payload.get("millis"),  # Epoch or millis
        server_timestamp=datetime.now(timezone.utc),
        device_uptime_ms=payload.get("up"),
        event_name=event_name,
        alert=payload.get("alert"),
        cause=payload.get("cause"),
        model_label=payload.get("lbl"),
        leak_probability=payload.get("pl") if "pl" in payload else payload.get("leak"),
        rms=payload.get("rms"),
        gas_delta=payload.get("gas"),
        gas_ratio=payload.get("gr"),
        temperature=payload.get("tc") if "tc" in payload else payload.get("temp"),
        uv_delta=payload.get("uv"),
        wet=bool(payload.get("wet")) if payload.get("wet") is not None else None,
        firmware_version=payload.get("fw"),
        raw_payload=payload,
        ingestion_status="accepted",
        idempotency_key=idempotency_key
    )
    
    db.add(event)
    db.commit()
    
    logger.debug(f"Event accepted: device={device_id}, session={session_id}, event={event_name}")
    return {"status": "accepted"}


async def handle_summary(device_id: str, trainee_id: str, session_id: int, payload: dict, db: Session):
    """Handle summary payload from firmware."""
    # Create idempotency key
    idempotency_key = create_idempotency_key(device_id, session_id, "summary", payload)
    
    # Check for duplicate
    existing = db.query(SessionSummary).filter(SessionSummary.idempotency_key == idempotency_key).first()
    if existing:
        logger.info(f"Duplicate summary detected, returning 200: {idempotency_key[:16]}...")
        return {"status": "accepted", "note": "duplicate"}
    
    # Find internal session
    internal_session = db.query(DBSession).filter(
        DBSession.device_id == device_id,
        DBSession.session_id == session_id
    ).first()
    
    if not internal_session:
        logger.warning(f"Summary received for unknown session: device={device_id}, session={session_id}")
        # Create session if it doesn't exist
        from backend.database import Trainee
        trainee = db.query(Trainee).filter(Trainee.trainee_id == trainee_id).first()
        if not trainee:
            trainee = Trainee(
                trainee_id=trainee_id,
                name=trainee_id,
                is_active=True
            )
            db.add(trainee)
            db.commit()
            db.refresh(trainee)
        
        duration_s = payload.get("dur_s", 0)
        started_at = datetime.now(timezone.utc)
        if duration_s > 0:
            from datetime import timedelta
            started_at = started_at - timedelta(seconds=duration_s)
        
        internal_session = DBSession(
            session_id=session_id,
            device_id=device_id,
            trainee_id=trainee_id,
            started_at=started_at,
            ended_at=datetime.now(timezone.utc),
            session_metadata={"auto_created": True}
        )
        db.add(internal_session)
        db.commit()
        db.refresh(internal_session)
    
    # Create summary record
    summary = SessionSummary(
        session_id=internal_session.id,
        device_session_id=session_id,
        device_id=device_id,
        trainee_id=trainee_id,
        duration_seconds=payload.get("dur_s"),
        windows=payload.get("windows"),
        leak_events=payload.get("leak_events"),
        gas_events=payload.get("gas_events"),
        wet_events=payload.get("wet_events"),
        heat_events=payload.get("heat_events"),
        uv_events=payload.get("uv_events"),
        noise_windows=payload.get("noise_windows"),
        max_leak_probability=payload.get("max_leak_p"),
        firmware_version=payload.get("fw"),
        raw_payload=payload,
        server_timestamp=datetime.now(timezone.utc),
        idempotency_key=idempotency_key
    )
    
    db.add(summary)
    db.commit()
    
    logger.debug(f"Summary accepted: device={device_id}, session={session_id}")
    return {"status": "accepted"}
