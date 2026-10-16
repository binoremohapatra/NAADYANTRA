# HazGuard Security Credential Rotation Guide

**Date:** 2026-10-16
**Status:** IMMEDIATE ACTION REQUIRED
**Purpose:** Rotate all exposed credentials before production deployment

---

## CRITICAL: Credentials Exposed in Repository

The following credentials are currently in `.env` and MUST be rotated immediately:

### 1. Neon PostgreSQL Database URL
**Status:** EXPOSED - MUST ROTATE
**Location:** `.env` line 2
**Action:** 
1. Log into Neon dashboard
2. Reset database password or create new database
3. Update `.env` with new connection string
4. Do NOT commit the new `.env` to Git

### 2. JWT SECRET_KEY
**Status:** EXPOSED - MUST ROTATE
**Location:** `.env` line 10
**Action:**
```bash
# Generate new secure secret
python -c "import secrets; print(secrets.token_urlsafe(64))"
```
1. Copy the generated secret
2. Update `SECRET_KEY` in `.env`
3. All existing JWT tokens will become invalid (users will need to re-login)
4. Do NOT commit the new `.env` to Git

### 3. Device Authentication Key
**Status:** EXPOSED - MUST ROTATE
**Location:** 
- `.env` line 15 (hash)
- `leak_detector.ino` line 70 (plaintext)
**Action:**

**Step 1: Generate new device key**
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

**Step 2: Hash the new key**
```bash
python -c "from passlib.context import CryptContext; ctx = CryptContext(schemes=['bcrypt']); print(ctx.hash('YOUR_NEW_KEY'))"
```

**Step 3: Update backend**
1. Update `DEVICE_KEY_HASH` in `.env` with the new hash
2. Do NOT commit the new `.env` to Git

**Step 4: Update firmware**
1. Update `DEVICE_KEY` in `leak_detector.ino` line 70 with the new plaintext key
2. Flash firmware to all ESP32 devices
3. Old devices will stop authenticating until updated

### 4. WiFi Credentials
**Status:** NOT EXPOSED - PLACEHOLDER
**Location:** `leak_detector.ino` lines 64-65
**Action:**
- These are placeholders ("YOUR_WIFI_NAME", "YOUR_WIFI_PASSWORD")
- No rotation needed, but configure per-deployment

---

## Production Deployment Checklist

### Before Production Deployment

- [ ] **Database credentials rotated** (Neon PostgreSQL)
- [ ] **JWT SECRET_KEY rotated** (generate new, update .env)
- [ ] **Device key rotated** (generate new, hash, update firmware and backend)
- [ ] **CORS configured** via `CORS_ORIGINS` environment variable (comma-separated list)
- [ ] **Backend URL verified** in firmware (check actual deployment endpoint)
- [ ] **TLS enabled** in firmware (set `VERIFY_TLS_CERT=1` in leak_detector.ino)
- [ ] **Environment variable** set to `production` in deployment config
- [ ] **.env file NOT committed** to Git (verify in `.gitignore`)

### Render Deployment Specifics

1. **Database:** Use Render's Internal Database URL (do not expose externally)
2. **Environment Variables:** Add all secrets in Render Dashboard > Environment
3. **CORS:** Set `CORS_ORIGINS` environment variable (comma-separated list)
   - Example: `CORS_ORIGINS=https://hazguard.onrender.com,https://your-frontend.com`
   - Application will FAIL to start if CORS_ORIGINS is not set in production
4. **HTTPS:** Render provides HTTPS automatically - firmware must use HTTPS with VERIFY_TLS_CERT=1

---

## Firmware Security Updates

### Required Changes in `leak_detector.ino`

**Before:**
```cpp
#define BACKEND_URL      "http://192.168.1.10:8000"
#define DEVICE_KEY       "dev-key-123"
```

**After:**
```cpp
#define BACKEND_URL      "https://your-verified-backend.com"  // Verified cloud endpoint
#define DEVICE_KEY       "YOUR_SECURE_GENERATED_KEY"      // Rotate per device
#define VERIFY_TLS_CERT   1   // Enable TLS (requires certificate bundle setup)
```

### TLS Verification

**Status:** Flag added but requires certificate bundle (NOT YET PRODUCTION-READY)
**Action:**
1. Choose verification method:
   - Option A: Use Mozilla root CA bundle (requires PlatformIO or embedded bundle file)
   - Option B: Use specific server certificate (simpler, no bundle required)
2. For Option A (Mozilla bundle):
   - Add certificate bundle file to project
   - Embed in firmware (PlatformIO: board_build.embed_files)
   - Update firmware to call `secure.setCACertBundle(rootca_crt_bundle_start);`
3. For Option B (Server-specific):
   - Generate certificate: `openssl s_client -showcerts -connect your-backend.com:443 </dev/null | openssl x509 -outform PEM > cert.pem`
   - Convert to Arduino-compatible format
   - Update firmware to call `secure.setCACert(cert_pem, cert_pem_len);`
4. Set `VERIFY_TLS_CERT=1` in leak_detector.ino
5. Recompile and flash firmware

**Warning:** Current `setCACertBundle()` call without embedded bundle data will fail at runtime.

---

## Post-Rotation Verification

### Backend Verification
```bash
# Start backend with new .env
python -m backend.main

# Test health endpoint
curl https://your-backend-url/health

# Test device authentication
curl -X POST https://your-backend-url/api/log \
  -H "X-Device-Key: YOUR_NEW_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### Firmware Verification
1. Flash updated firmware to ESP32
2. Monitor serial output for successful WiFi connection
3. Verify backend receives telemetry (check database)
4. Confirm device appears online in Flutter app

### Flutter Verification
1. Test login with existing users (will need re-login after SECRET_KEY rotation)
2. Verify device status shows online after firmware update
3. Check telemetry displays correctly

---

## Long-Term Security Practices

### Secrets Management
- Never commit `.env` to Git
- Use environment-specific secrets for dev/staging/production
- Rotate secrets periodically (e.g., every 90 days)
- Use a secrets manager (Render Environment Variables, AWS Secrets Manager, etc.)

### Device Key Management
- Generate unique device keys per ESP32
- Store device key mapping securely (backend DeviceCredential table)
- Revoke compromised device keys immediately
- Implement device key rotation mechanism

### Network Security
- Always use HTTPS in production
- Enable TLS verification in firmware
- Restrict CORS to specific frontend domains
- Implement rate limiting on public endpoints

---

## Emergency Revocation Procedure

If a device key is compromised:

1. **Backend:** Set `is_active=False` in `device_credentials` table
2. **Backend:** Update `DEVICE_KEY_HASH` in environment if using shared key
3. **Firmware:** Flash new device key to affected ESP32
4. **Backend:** Re-enable credential in database

If SECRET_KEY is compromised:

1. **Backend:** Generate new SECRET_KEY
2. **Backend:** Update environment variable
3. **Users:** All JWT tokens invalidated - users must re-login
4. **Apps:** Clear cached tokens in Flutter app

---

## Contact

For security issues, rotate credentials immediately and document the incident.
