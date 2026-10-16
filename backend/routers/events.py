from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from backend.database import get_db, Event, SessionSummary
from backend.auth import get_current_trainer_or_admin
from backend.schemas import EventResponse, SessionSummaryResponse, PaginatedResponse
from backend.time_utils import to_utc_datetime

router = APIRouter()


@router.get("/api/v1/events", response_model=PaginatedResponse)
async def list_events(
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    device_id: Optional[str] = None,
    session: Optional[int] = None,
    trainee_id: Optional[str] = None,
    kind: Optional[str] = None,
    cause: Optional[str] = None,
    alert: Optional[str] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Paginated event history with filters."""
    query = db.query(Event)
    
    if device_id:
        query = query.filter(Event.device_id == device_id)
    
    if session:
        query = query.filter(Event.session_id == session)
    
    if trainee_id:
        query = query.filter(Event.trainee_id == trainee_id)
    
    if kind:
        query = query.filter(Event.event_kind == kind)
    
    if cause:
        query = query.filter(Event.cause == cause)
    
    if alert:
        query = query.filter(Event.alert == alert)
    
    if date_from:
        df_utc = to_utc_datetime(date_from)
        query = query.filter(Event.server_timestamp >= df_utc)
    
    if date_to:
        dt_utc = to_utc_datetime(date_to)
        query = query.filter(Event.server_timestamp <= dt_utc)
    
    total = query.count()
    events = query.order_by(Event.server_timestamp.desc()).offset((page - 1) * page_size).limit(page_size).all()
    
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=[EventResponse.model_validate(e) for e in events]
    )


@router.get("/api/v1/events/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: int,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """One event's normalized fields and raw payload."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found"
        )
    return event


@router.get("/api/v1/summaries", response_model=PaginatedResponse)
async def list_summaries(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    device_id: Optional[str] = None,
    trainee_id: Optional[str] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    current_user = Depends(get_current_trainer_or_admin),
    db: Session = Depends(get_db)
):
    """Paginated session summary history with filters."""
    query = db.query(SessionSummary)
    
    if device_id:
        query = query.filter(SessionSummary.device_id == device_id)
    
    if trainee_id:
        query = query.filter(SessionSummary.trainee_id == trainee_id)
    
    if date_from:
        df_utc = to_utc_datetime(date_from)
        query = query.filter(SessionSummary.server_timestamp >= df_utc)
    
    if date_to:
        dt_utc = to_utc_datetime(date_to)
        query = query.filter(SessionSummary.server_timestamp <= dt_utc)
    
    total = query.count()
    summaries = query.order_by(SessionSummary.server_timestamp.desc()).offset((page - 1) * page_size).limit(page_size).all()
    
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=[SessionSummaryResponse.model_validate(s) for s in summaries]
    )
