#pragma once

/**
 * NAADYANTRA Hardware Configuration & Device Credentials Template
 * 
 * Instructions:
 * 1. Copy this file to "credentials.h":
 *      cp credentials.example.h credentials.h
 * 2. Configure with your local bench Wi-Fi SSID and Password.
 * 3. Provision a unique device key for your hardware unit:
 *    - Option A: Use the Web Dashboard -> "+ Register Device" modal
 *    - Option B: Use the Web Dashboard -> Device Detail -> "Rotate Credential"
 *    - Option C: CLI / API call:
 *        POST /api/v1/devices/register
 *        Headers: Authorization: Bearer <ADMIN_JWT>
 *        Body: {"device_id": "SIH-DEV-01", "name": "Bench Unit 1", "device_key": "<YOUR_KEY>"}
 * 4. Paste the provisioned DEVICE_ID and DEVICE_KEY below.
 * 5. NEVER commit "credentials.h" to version control (it is ignored by .gitignore).
 */

#define WIFI_SSID        "YOUR_BENCH_WIFI_SSID"
#define WIFI_PASSWORD    "YOUR_BENCH_WIFI_PASSWORD"
#define BACKEND_URL      "https://naadyantra.onrender.com"
#define DEVICE_KEY       "YOUR_PROVISIONED_DEVICE_KEY"
#define DEVICE_ID        "SIH-DEV-01"
#define TRAINEE_ID       "T001"
