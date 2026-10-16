class ApiConstants {
  // Base paths
  static const String apiV1 = '/api/v1';

  // Health & Ingestion
  static const String health = '/health';
  static const String ready = '/ready';
  static const String firmwareLog = '/api/log';
  static const String systemInfo = '$apiV1/system/info';

  // Authentication
  static const String login = '$apiV1/auth/login';
  static const String refresh = '$apiV1/auth/refresh';
  static const String logout = '$apiV1/auth/logout';
  static const String me = '$apiV1/auth/me';

  // Devices
  static const String devices = '$apiV1/devices';
  static String device(String deviceId) => '$apiV1/devices/$deviceId';
  static String deviceStatus(String deviceId) =>
      '$apiV1/devices/$deviceId/status';
  static String deviceLatestTelemetry(String deviceId) =>
      '$apiV1/devices/$deviceId/telemetry/latest';


  // Sessions
  static const String sessions = '$apiV1/sessions';
  static String session(String sessionId) => '$apiV1/sessions/$sessionId';
  static String sessionEvents(String sessionId) =>
      '$apiV1/sessions/$sessionId/events';
  static String sessionSummary(String sessionId) =>
      '$apiV1/sessions/$sessionId/summary';
  static String sessionExport(String sessionId) =>
      '$apiV1/sessions/$sessionId/export';

  // Trainees
  static const String trainees = '$apiV1/trainees';
  static String trainee(String traineeId) => '$apiV1/trainees/$traineeId';
  static String traineeSessions(String traineeId) =>
      '$apiV1/trainees/$traineeId/sessions';
  static String traineeAssessments(String traineeId) =>
      '$apiV1/trainees/$traineeId/assessments';

  // Events
  static const String events = '$apiV1/events';
  static const String summaries = '$apiV1/summaries';

  // Assessments
  static const String assessments = '$apiV1/assessments';
  static const String assessmentRubrics = '$apiV1/assessment-rubrics';
  static String assessment(String assessmentId) =>
      '$apiV1/assessments/$assessmentId';

  // Dashboard
  static const String dashboardOverview = '$apiV1/dashboard/overview';
  static const String dashboardRecentActivity =
      '$apiV1/dashboard/recent-activity';
  static const String dashboardTrends = '$apiV1/dashboard/trends';
  static const String dashboardDeviceHealth = '$apiV1/dashboard/device-health';
  static const String dashboardAlerts = '$apiV1/dashboard/alerts';

  // Diagnostics
  static const String diagnosticsIngestion = '$apiV1/diagnostics/ingestion';
  static const String diagnosticsDatabase = '$apiV1/diagnostics/database';

  // Audit
  static const String auditLogs = '$apiV1/audit-logs';
}
