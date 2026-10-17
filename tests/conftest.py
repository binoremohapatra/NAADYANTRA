"""
Test configuration and fixtures for NAADYANTRA backend tests.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.main import app
from backend.database import Base, get_db, Device, DeviceCredential, User
from backend.auth import get_password_hash

# Test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_hazguard.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

# Test device key
TEST_DEVICE_KEY = "test-device-key-123"


@pytest.fixture(scope="function")
def db():
    """Create a clean, isolated database for each test function."""
    # Drop everything first so no state leaks from previous tests,
    # then recreate the full schema.
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def admin_user(db):
    """Create admin user for testing."""
    user = User(
        username="admin",
        hashed_password=get_password_hash("admin123"),
        role="admin",
        is_active=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture(scope="function")
def auth_token(admin_user):
    """Get authentication token."""
    client = TestClient(app)
    response = client.post("/api/v1/auth/login", json={
        "username": "admin",
        "password": "admin123"
    })
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture(scope="function")
def auth_headers(auth_token):
    """Get authentication headers."""
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture(scope="function")
def test_device(db):
    """Create a test device with credential."""
    device = Device(
        device_id="TEST-DEV-01",
        name="Test Device",
        is_active=True
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    
    # Add device credential
    credential = DeviceCredential(
        device_id="TEST-DEV-01",
        key_hash=get_password_hash(TEST_DEVICE_KEY),
        is_active=True
    )
    db.add(credential)
    db.commit()
    
    return device


@pytest.fixture(scope="function")
def client(db):
    """Get test client backed by a fresh per-test SQLite database."""
    return TestClient(app)
