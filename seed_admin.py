"""
Seed script to create initial admin user.
Run: python seed_admin.py
"""
import os, sys, secrets
from backend.database import SessionLocal, User
from backend.auth import get_password_hash
from backend.config import settings

def create_admin_user():
    db = SessionLocal()
    try:
        # Check if admin already exists
        existing = db.query(User).filter(User.username == "admin").first()
        if existing:
            print("Admin user already exists")
            return
        
        password = os.environ.get("ADMIN_INITIAL_PASSWORD")
        if not password:
            if settings.environment == "production":
                print("ERROR: In production, ADMIN_INITIAL_PASSWORD environment variable MUST be set!")
                sys.exit(1)
            password = secrets.token_urlsafe(16)
            print(f"Generated secure initial admin password (dev): {password}")
            print("Please store and rotate this password immediately.")
        
        # Create admin user
        admin = User(
            username="admin",
            hashed_password=get_password_hash(password),
            role="admin",
            is_active=True
        )
        db.add(admin)
        db.commit()
        print("Admin user created successfully")
    finally:
        db.close()

if __name__ == "__main__":
    create_admin_user()
