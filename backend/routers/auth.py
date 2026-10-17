from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import timedelta

from backend.database import get_db, User, AuditLog
from backend.auth import verify_password, create_access_token, get_password_hash, get_current_user
from backend.schemas import LoginRequest, LoginResponse, UserResponse, ChangePasswordRequest
from backend.config import settings

router = APIRouter()


@router.post("/api/v1/auth/login", response_model=LoginResponse)
async def login(
    request: LoginRequest,
    db: Session = Depends(get_db)
):
    """Authenticate an authorized trainer/admin account and return a session or access token."""
    user = db.query(User).filter(User.username == request.username).first()
    
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role},
        expires_delta=access_token_expires
    )
    
    return LoginResponse(
        access_token=access_token,
        user={
            "id": user.id,
            "username": user.username,
            "role": user.role
        }
    )


@router.post("/api/v1/auth/refresh")
async def refresh_token(current_user: User = Depends(get_current_user)):
    """Refresh authentication token."""
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": current_user.username, "role": current_user.role},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/api/v1/auth/logout")
async def logout(current_user: User = Depends(get_current_user)):
    """Invalidate the relevant session/token."""
    # In a JWT-only implementation without a token blacklist, this is informational
    # The client should discard the token. For production, implement a token blacklist.
    return {"message": "Successfully logged out"}


@router.get("/api/v1/auth/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Return the authenticated user's safe profile and role."""
    return current_user


@router.post("/api/v1/auth/change-password")
async def change_password(
    request: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Securely rotate password for current authenticated user."""
    if not verify_password(request.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    current_user.hashed_password = get_password_hash(request.new_password)
    
    audit = AuditLog(
        user=current_user.username,
        action="USER_PASSWORD_ROTATED",
        resource_type="user",
        resource_id=str(current_user.id),
        details={"status": "success"}
    )
    db.add(audit)
    db.commit()
    
    return {"message": "Password rotated successfully"}
