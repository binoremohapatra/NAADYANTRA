from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, text
from datetime import datetime, timezone, timedelta
from typing import Optional

from backend.database import get_db, Session as DBSession, Event, Device, Trainee, IngestionError
from backend.auth import get_current_trainer_or_admin
from backend.schemas import (
    DashboardOverviewResponse, DashboardRecentActivityItem,
    DashboardTrendsResponse, DashboardDeviceHealthResponse,
    DashboardAlertResponse, PaginatedResponse,
)
from backend.config import settings
from backend.time_utils import to_utc_datetime, utc_now

router = APIRouter()


@router.get("/api/v1/dashboard/overview", response_model=DashboardOverviewResponse)
async def dashboard_overview(
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Recorded sessions, recent activity, device counts and event counts."""
    from backend.config import settings
    total_sessions = db.query(DBSession).count()
    total_devices = db.query(Device).count()
    total_trainees = db.query(Trainee).count()
    total_events = db.query(Event).count()
    
    now = utc_now()
    # Recent sessions (last 24 hours)
    recent_threshold = now - timedelta(hours=24)
    recent_sessions_count = db.query(DBSession).filter(
        DBSession.started_at >= recent_threshold
    ).count()
    
    # Device status breakdown
    online_threshold = now - timedelta(
        seconds=settings.device_online_threshold_seconds
    )
    all_devices = db.query(Device).all()
    online_devices_count = 0
    never_reported_count = 0
    stale_devices_count = 0

    for d in all_devices:
        ls_utc = to_utc_datetime(d.last_seen_at)
        if not ls_utc:
            never_reported_count += 1
        elif ls_utc > online_threshold and d.is_active:
            online_devices_count += 1
        else:
            stale_devices_count += 1

    offline_devices_count = total_devices - online_devices_count
    active_devices_count = sum(1 for d in all_devices if d.is_active)

    # Alerts and ingestion error counts
    alert_events_count = db.query(Event).filter(Event.alert.in_(["DANGER", "CAUTION"])).count()
    recent_failures_count = 0
    try:
        recent_failures_count = db.query(IngestionError).filter(
            IngestionError.timestamp >= recent_threshold
        ).count()
    except Exception:
        recent_failures_count = 0
    
    return DashboardOverviewResponse(
        total_sessions=total_sessions,
        total_devices=total_devices,
        total_trainees=total_trainees,
        total_events=total_events,
        recent_sessions_count=recent_sessions_count,
        active_devices_count=active_devices_count,
        online_devices_count=online_devices_count,
        offline_devices_count=offline_devices_count,
        stale_devices_count=stale_devices_count,
        never_reported_count=never_reported_count,
        alert_events_count=alert_events_count,
        recent_ingestion_failures_count=recent_failures_count,
        server_utc=datetime.now(timezone.utc)
    )


@router.get("/api/v1/dashboard/recent-activity", response_model=PaginatedResponse)
async def recent_activity(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Recent sessions and events with pagination."""
    activities = []
    
    # Get recent sessions
    recent_sessions = db.query(DBSession).order_by(
        DBSession.started_at.desc()
    ).limit(page_size).all()
    
    for session in recent_sessions:
        activities.append(DashboardRecentActivityItem(
            type="session",
            timestamp=session.started_at,
            device_id=session.device_id,
            trainee_id=session.trainee_id,
            details={
                "session_id": session.session_id,
                "status": "active" if not session.ended_at else "completed"
            }
        ))
    
    # Get recent events (especially alerts)
    recent_events = db.query(Event).filter(
        Event.alert.in_(["DANGER", "CAUTION"])
    ).order_by(Event.server_timestamp.desc()).limit(page_size).all()
    
    for event in recent_events:
        activities.append(DashboardRecentActivityItem(
            type="alert",
            timestamp=event.server_timestamp,
            device_id=event.device_id,
            trainee_id=event.trainee_id,
            details={
                "event_name": event.event_name,
                "alert": event.alert,
                "cause": event.cause
            }
        ))
    
    # Sort by timestamp
    activities.sort(key=lambda x: x.timestamp, reverse=True)
    
    # Paginate
    total = len(activities)
    start = (page - 1) * page_size
    end = start + page_size
    paginated_activities = activities[start:end]
    
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=paginated_activities
    )


@router.get("/api/v1/dashboard/trends", response_model=list[DashboardTrendsResponse])
async def dashboard_trends(
    bucket: str = Query("hour", pattern="^(hour|day|week)$"),
    days: int = Query(7, ge=1, le=365),
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Clearly defined time-bucketed session/event counts compatible with SQLite & PostgreSQL."""
    from_date = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)
    
    is_postgres = False
    try:
        if db.bind and db.bind.dialect.name == "postgresql":
            is_postgres = True
    except Exception:
        pass
    
    if is_postgres:
        if bucket == "hour":
            bucket_expr = func.to_char(func.date_trunc('hour', Event.server_timestamp), 'YYYY-MM-DD HH24:00:00')
        elif bucket == "day":
            bucket_expr = func.to_char(func.date_trunc('day', Event.server_timestamp), 'YYYY-MM-DD')
        else:
            bucket_expr = func.to_char(func.date_trunc('week', Event.server_timestamp), 'YYYY-IW')
    else:
        if bucket == "hour":
            bucket_expr = func.strftime("%Y-%m-%d %H:00:00", Event.server_timestamp)
        elif bucket == "day":
            bucket_expr = func.strftime("%Y-%m-%d", Event.server_timestamp)
        else:
            bucket_expr = func.strftime("%Y-%W", Event.server_timestamp)
    
    alert_sum = func.sum(func.case((Event.alert.in_(["DANGER", "CAUTION"]), 1), else_=0))
    
    time_buckets = db.query(
        bucket_expr.label("bucket"),
        func.count(DBSession.id.distinct()).label("session_count"),
        func.count(Event.id).label("event_count"),
        alert_sum.label("alert_count")
    ).outerjoin(
        DBSession, Event.internal_session_id == DBSession.id
    ).filter(
        Event.server_timestamp >= from_date
    ).group_by(bucket_expr).order_by(bucket_expr).all()
    
    trends = []
    for bucket_str, session_count, event_count, alert_count in time_buckets:
        if bucket_str:
            trends.append(DashboardTrendsResponse(
                time_bucket=str(bucket_str),
                session_count=session_count or 0,
                event_count=event_count or 0,
                alert_count=alert_count or 0
            ))
    
    return trends


@router.get("/api/v1/dashboard/device-health", response_model=list[DashboardDeviceHealthResponse])
async def device_health(
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Device activity and known health indicators."""
    devices = db.query(Device).all()
    
    now = utc_now()
    threshold = now - timedelta(seconds=settings.device_online_threshold_seconds)
    health_data = []
    for device in devices:
        ls_utc = to_utc_datetime(device.last_seen_at)
        is_online = bool(ls_utc and ls_utc > threshold and device.is_active)
        
        # Count sessions and events
        total_sessions = db.query(DBSession).filter(DBSession.device_id == device.device_id).count()
        total_events = db.query(Event).filter(Event.device_id == device.device_id).count()
        
        # Get last error
        last_error = db.query(IngestionError).filter(
            IngestionError.device_id == device.device_id
        ).order_by(IngestionError.timestamp.desc()).first()
        
        health_data.append(DashboardDeviceHealthResponse(
            device_id=device.device_id,
            name=device.name,
            last_seen_at=ls_utc,
            is_online=is_online,
            total_sessions=total_sessions,
            total_events=total_events,
            last_error=last_error.error_message if last_error else None
        ))
    
    return health_data


@router.get("/api/v1/dashboard/alerts", response_model=PaginatedResponse)
async def dashboard_alerts(
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    device_id: Optional[str] = None,
    alert_type: Optional[str] = None,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Recorded device-reported alerts with filters."""
    query = db.query(Event).filter(Event.alert.isnot(None))
    
    if device_id:
        query = query.filter(Event.device_id == device_id)
    
    if alert_type:
        query = query.filter(Event.alert == alert_type)
    
    total = query.count()
    events = query.order_by(Event.server_timestamp.desc()).offset((page - 1) * page_size).limit(page_size).all()
    
    alerts = []
    for event in events:
        alerts.append(DashboardAlertResponse(
            id=event.id,
            device_id=event.device_id,
            trainee_id=event.trainee_id,
            timestamp=event.server_timestamp,
            alert=event.alert,
            cause=event.cause or "",
            details={
                "event_name": event.event_name,
                "model_label": event.model_label,
                "leak_probability": event.leak_probability,
                "rms": event.rms,
                "gas_delta": event.gas_delta
            }
        ))
    
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=alerts
    )
