from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
from typing import Optional, List
import secrets

from backend.database import get_db, Device, DeviceCredential, Event, AuditLog, IngestionError, Session as DBSession
from backend.auth import get_current_trainer_or_admin, get_current_admin, verify_device_key, get_password_hash
from backend.schemas import (
    DeviceRegisterRequest, DeviceResponse, DeviceStatusResponse,
    LatestTelemetryResponse, DeviceUpdateRequest, DeviceKeyRotateResponse, PaginatedResponse
)
from backend.config import settings
from backend.time_utils import to_utc_datetime, utc_now

router = APIRouter()


@router.post("/api/v1/devices/register", response_model=DeviceResponse)
async def register_device(
    request: DeviceRegisterRequest,
    current_user = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Register or update a device with its authentication key."""
    # Check if device already exists
    device = db.query(Device).filter(Device.device_id == request.device_id).first()
    
    if device:
        # Update existing device
        if request.name:
            device.name = request.name
        if not device.is_active:
            device.is_active = True
        db.commit()
        db.refresh(device)
    else:
        # Create new device
        device = Device(
            device_id=request.device_id,
            name=request.name or request.device_id,
            device_metadata={},
            is_active=True
        )
        db.add(device)
        db.commit()
        db.refresh(device)
    
    # Update or create device credential
    credential = db.query(DeviceCredential).filter(
        DeviceCredential.device_id == request.device_id
    ).first()
    
    key_hash = get_password_hash(request.device_key)
    
    if credential:
        credential.key_hash = key_hash
        credential.is_active = True
    else:
        credential = DeviceCredential(
            device_id=request.device_id,
            key_hash=key_hash,
            is_active=True
        )
        db.add(credential)
    
    # Audit log
    audit = AuditLog(
        user=current_user.username,
        action="device_register",
        resource_type="device",
        resource_id=request.device_id,
        details={"name": request.name}
    )
    db.add(audit)
    
    db.commit()
    db.refresh(device)
    
    # Populate online status
    resp = DeviceResponse.model_validate(device)
    threshold = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(seconds=settings.device_online_threshold_seconds)
    ls = device.last_seen_at.replace(tzinfo=None) if (device.last_seen_at and device.last_seen_at.tzinfo) else device.last_seen_at
    resp.is_online = bool(ls and ls > threshold and device.is_active)
    return resp


@router.get("/api/v1/devices", response_model=PaginatedResponse)
async def list_devices(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    is_active: Optional[bool] = None,
    search: Optional[str] = None,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Paginated device listing and filtering."""
    query = db.query(Device)
    
    if is_active is not None:
        query = query.filter(Device.is_active == is_active)
    
    if search:
        query = query.filter(
            (Device.device_id.ilike(f"%{search}%")) |
            (Device.name.ilike(f"%{search}%"))
        )
    
    total = query.count()
    devices = query.order_by(Device.last_seen_at.desc().nulls_last()).offset((page - 1) * page_size).limit(page_size).all()
    
    now = utc_now()
    threshold = now - timedelta(seconds=settings.device_online_threshold_seconds)
    items = []
    for d in devices:
        resp = DeviceResponse.model_validate(d)
        ls_utc = to_utc_datetime(d.last_seen_at)
        resp.is_online = bool(ls_utc and ls_utc > threshold and d.is_active)
        items.append(resp)
    
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=items
    )


@router.get("/api/v1/devices/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: str,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Device metadata and latest known activity."""
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    resp = DeviceResponse.model_validate(device)
    now = utc_now()
    threshold = now - timedelta(seconds=settings.device_online_threshold_seconds)
    ls_utc = to_utc_datetime(device.last_seen_at)
    resp.is_online = bool(ls_utc and ls_utc > threshold and device.is_active)
    return resp


@router.get("/api/v1/devices/{device_id}/status", response_model=DeviceStatusResponse)
async def get_device_status(
    device_id: str,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Canonical device status with connectivity, telemetry freshness, and error diagnostics."""
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    # Determine online status cleanly using normalized timezone-aware UTC
    now = utc_now()
    threshold = now - timedelta(seconds=settings.device_online_threshold_seconds)
    ls_utc = to_utc_datetime(device.last_seen_at)
    is_online = bool(ls_utc and ls_utc > threshold and device.is_active)
    
    # Count recent activity (last 24 hours) with aware UTC comparison
    recent_threshold = now - timedelta(hours=24)
    recent_activity_count = db.query(Event).filter(
        Event.device_id == device_id,
        Event.server_timestamp >= recent_threshold
    ).count()
    
    # Check latest telemetry event for exact freshness
    latest_event = db.query(Event).filter(
        Event.device_id == device_id
    ).order_by(Event.server_timestamp.desc()).first()

    has_data = latest_event is not None
    if latest_event and latest_event.server_timestamp:
        ts_utc = to_utc_datetime(latest_event.server_timestamp)
        staleness_seconds = max(0, int((now - ts_utc).total_seconds()))
        is_stale = staleness_seconds > settings.device_online_threshold_seconds
        last_telemetry_at = ts_utc
    else:
        staleness_seconds = -1
        is_stale = True
        last_telemetry_at = to_utc_datetime(device.last_telemetry_at)

    # Get last error (if any) safely
    last_error = None
    try:
        last_error_record = db.query(IngestionError).filter(
            IngestionError.device_id == device_id
        ).order_by(IngestionError.timestamp.desc()).first()
        if last_error_record:
            last_error = last_error_record.error_message
    except Exception:
        last_error = None
    
    return DeviceStatusResponse(
        device_id=device.device_id,
        is_registered=True,
        is_active=device.is_active,
        is_online=is_online,
        last_seen_at=ls_utc,
        last_telemetry_at=last_telemetry_at,
        has_data=has_data,
        is_stale=is_stale,
        staleness_seconds=staleness_seconds,
        firmware_version=device.firmware_version,
        recent_activity_count=recent_activity_count,
        last_error=last_error
    )


@router.get("/api/v1/devices/{device_id}/telemetry/latest", response_model=LatestTelemetryResponse)
async def get_latest_telemetry(
    device_id: str,
    stale_after_seconds: int = Query(30, ge=5, le=300),
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Newest ingested event for a device with explicit freshness metadata.

    Returns has_data=False (HTTP 200) when no events exist yet — never 404 —
    so clients can render a clean 'awaiting first telemetry' state.
    is_stale=True when server_timestamp is older than stale_after_seconds (default 30).
    """
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    latest_event = db.query(Event).filter(
        Event.device_id == device_id
    ).order_by(Event.server_timestamp.desc()).first()

    if not latest_event:
        return LatestTelemetryResponse(
            has_data=False,
            is_stale=True,
            staleness_seconds=-1,
            event=None
        )

    from backend.schemas import EventResponse
    now = utc_now()
    ts_utc = to_utc_datetime(latest_event.server_timestamp)
    staleness = max(0, int((now - ts_utc).total_seconds())) if ts_utc else 0
    is_stale = staleness > stale_after_seconds

    return LatestTelemetryResponse(
        has_data=True,
        is_stale=is_stale,
        staleness_seconds=staleness,
        event=EventResponse.model_validate(latest_event)
    )


@router.post("/api/v1/devices/{device_id}/rotate-key", response_model=DeviceKeyRotateResponse)
async def rotate_device_key(
    device_id: str,
    current_user = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Admin-only secure device key rotation with one-time raw key issuance."""
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    # Generate a strong, cryptographically secure 32-character key
    new_device_key = secrets.token_urlsafe(24)
    key_hash = get_password_hash(new_device_key)

    credential = db.query(DeviceCredential).filter(
        DeviceCredential.device_id == device_id
    ).first()

    if credential:
        credential.key_hash = key_hash
        credential.is_active = True
    else:
        credential = DeviceCredential(
            device_id=device_id,
            key_hash=key_hash,
            is_active=True
        )
        db.add(credential)

    audit = AuditLog(
        user=current_user.username,
        action="device_key_rotate",
        resource_type="device",
        resource_id=device_id,
        details={"status": "key_rotated"}
    )
    db.add(audit)
    db.commit()

    return DeviceKeyRotateResponse(
        device_id=device_id,
        device_key=new_device_key,
        message="Device key rotated successfully. Store this key securely in firmware configuration; it will not be displayed again."
    )


@router.patch("/api/v1/devices/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: str,
    request: DeviceUpdateRequest,
    current_user = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Update permitted device metadata using administrator authorization."""
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    if request.name is not None:
        device.name = request.name
    if request.is_active is not None:
        device.is_active = request.is_active
    if request.device_metadata is not None:
        device.device_metadata = request.device_metadata
    
    db.commit()
    db.refresh(device)
    
    resp = DeviceResponse.model_validate(device)
    now = utc_now()
    threshold = now - timedelta(seconds=settings.device_online_threshold_seconds)
    ls_utc = to_utc_datetime(device.last_seen_at)
    resp.is_online = bool(ls_utc and ls_utc > threshold and device.is_active)
    return resp


@router.delete("/api/v1/devices/{device_id}", response_model=DeviceResponse)
async def deactivate_device(
    device_id: str,
    current_user = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Deactivate or revoke a device using administrator authorization."""
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    device.is_active = False

    credential = db.query(DeviceCredential).filter(
        DeviceCredential.device_id == device_id
    ).first()
    if credential:
        credential.is_active = False

    audit = AuditLog(
        user=current_user.username,
        action="device_deactivate",
        resource_type="device",
        resource_id=device_id,
        details={"status": "deactivated"}
    )
    db.add(audit)
    db.commit()
    db.refresh(device)

    resp = DeviceResponse.model_validate(device)
    resp.is_online = False
    return resp
