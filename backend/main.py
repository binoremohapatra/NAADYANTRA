from fastapi import FastAPI, Request, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from datetime import datetime, timezone
import logging
import os
import uvicorn

from backend.config import settings
from backend.database import engine, Base, get_db
from backend.routers import health, ingestion, devices, sessions, trainees, events, auth, assessments, dashboard, audit

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup
    logger.info("Starting HazGuard backend...")
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created/verified")
    except Exception as e:
        logger.error(f"Failed to create database tables: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Shutting down HazGuard backend...")


# Create FastAPI app
app = FastAPI(
    title="HazGuard Backend",
    description="Backend for ESP32-based diagnostic sensing and vocational training platform",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# CORS middleware
# ⚠️ SECURITY: Restrict to specific origins in production
# Development: Allow all origins for testing
# Production: Must specify allowed origins - will fail if not configured
production_origins = []
if settings.environment == "production":
    # Production origins MUST be configured via environment variable
    # Set CORS_ORIGINS environment variable (comma-separated list)
    # Example: CORS_ORIGINS=https://hazguard.onrender.com,https://your-domain.com
    cors_origins_env = os.environ.get("CORS_ORIGINS", "")
    if cors_origins_env:
        # Split by comma and strip whitespace
        origins = [origin.strip() for origin in cors_origins_env.split(",")]
        # Filter out empty strings
        origins = [origin for origin in origins if origin]
        # Validate that we have at least one valid origin
        if origins:
            # Basic URL validation (must start with http:// or https://)
            valid_origins = []
            for origin in origins:
                if origin.startswith("http://") or origin.startswith("https://"):
                    valid_origins.append(origin)
                else:
                    logger.warning(f"⚠️ CORS: Invalid origin format (must start with http:// or https://): {origin}")
            if valid_origins:
                production_origins = valid_origins
            else:
                logger.error("❌ CORS: No valid origins found in CORS_ORIGINS. Application will NOT start.")
                raise RuntimeError("CORS_ORIGINS must contain valid HTTP/HTTPS URLs")
        else:
            logger.error("❌ CORS: CORS_ORIGINS environment variable is empty or contains only whitespace. Application will NOT start.")
            raise RuntimeError("CORS_ORIGINS environment variable must contain valid URLs")
    else:
        logger.warning("⚠️ CORS: No CORS_ORIGINS set in production; falling back to default trusted origins.")
        production_origins = [
            "https://naadyantra.onrender.com",
            "https://hazguard.onrender.com"
        ]
else:
    production_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=production_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include routers
app.include_router(health.router)
app.include_router(ingestion.router)
app.include_router(devices.router)
app.include_router(sessions.router)
app.include_router(trainees.router)
app.include_router(events.router)
app.include_router(auth.router)
app.include_router(assessments.router)
app.include_router(dashboard.router)
app.include_router(audit.router)


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )


# Root endpoint
@app.get("/")
async def root():
    return {
        "name": "HazGuard Backend",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


if __name__ == "__main__":
    port = int(os.environ.get("PORT", settings.server_port))
    uvicorn.run(
        "backend.main:app",
        host="0.0.0.0",
        port=port,
        reload=settings.environment == "development"
    )
