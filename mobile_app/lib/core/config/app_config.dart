import 'package:flutter/foundation.dart';

class AppConfig {
  // ── API Backend URLs ──────────────────────────────────────────────────────
  // Cloud (Render) deployment — production / demo when hardware is on WAN.
  static const String productionApiBaseUrl = 'https://naadyantra.onrender.com';

  // Alias so existing code keeps compiling; defaults to cloud.
  static const String defaultApiBaseUrl = productionApiBaseUrl;

  // Android emulator host bridge → localhost:8000 on the host machine.
  static const String emulatorApiBaseUrl = 'http://10.0.2.2:8000';

  // Physical Android device on the same LAN as the backend.
  // *** Set this to the actual LAN IP of the machine running FastAPI. ***
  // Example: 'http://192.168.1.10:8000'
  // Find it with: ipconfig (Windows) or ip addr (Linux/Mac)
  static const String localApiBaseUrl = 'http://10.0.2.2:8000'; // override for physical device

  // Connection Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Polling Intervals
  static const Duration liveInspectionPollInterval = Duration(seconds: 5);
  static const Duration statusRefreshInterval = Duration(seconds: 30);

  // Cache Settings
  static const Duration cacheExpiration = Duration(hours: 24);
  static const Duration deviceOfflineThreshold = Duration(minutes: 5);

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  // App Info
  static const String appName = 'HazGuard';
  static const String appVersion = '1.0.0';

  // Debug Mode
  static bool get isDebugMode => kDebugMode;

  // Sensor Semantics - These must match firmware documentation
  static const String gasSensorNote =
      'Baseline-relative ADC delta (not ppm or %LEL)';
  static const String leakProbabilityNote =
      'Model score (not calibrated probability)';
  static const String disabledSensorNote = 'Sensor disabled in firmware';

  // Safety Disclaimer
  static const String safetyDisclaimer =
      'This is a training aid only. Not a certified gas detector or safety instrument.';
}
