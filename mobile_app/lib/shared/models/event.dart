class Event {
  final int id;
  final String deviceId;
  final int sessionId;
  final int internalSessionId;
  final String traineeId;
  final String eventKind;
  final int? deviceTimestamp;
  final DateTime serverTimestamp;
  final int? deviceUptimeMs;
  final String? eventName;
  final String? alert;
  final String? cause;
  final String? modelLabel;
  final double? leakProbability;
  final double? rms;
  final int? gasDelta;
  final double? gasRatio;
  final double? temperature;
  final int? uvDelta;
  final bool? wet;
  final String? firmwareVersion;
  final Map<String, dynamic> rawPayload;
  final String ingestionStatus;
  // Hazard fusion fields (TinyML) — stored in raw_payload, not first-class DB columns.
  // These are uncalibrated model outputs, NOT calibrated probabilities.
  final int?
  hazardState; // 0=normal 1=proximity 2=prox_breach 3=gas_buildup 4=overheat
  final int? hazardConf; // 0–100 model confidence score (not a probability)

  Event({
    required this.id,
    required this.deviceId,
    required this.sessionId,
    required this.internalSessionId,
    required this.traineeId,
    required this.eventKind,
    this.deviceTimestamp,
    required this.serverTimestamp,
    this.deviceUptimeMs,
    this.eventName,
    this.alert,
    this.cause,
    this.modelLabel,
    this.leakProbability,
    this.rms,
    this.gasDelta,
    this.gasRatio,
    this.temperature,
    this.uvDelta,
    this.wet,
    this.firmwareVersion,
    required this.rawPayload,
    required this.ingestionStatus,
    this.hazardState,
    this.hazardConf,
  });

  bool get hasGasData => gasDelta != null || gasRatio != null;
  bool get hasAcousticData => rms != null || leakProbability != null;
  bool get hasMoistureData => wet != null;
  bool get hasTemperatureData => temperature != null;
  bool get hasUvData => uvDelta != null;
  bool get hasHazardData => hazardState != null;

  /// Human-readable label for the hazard fusion state.
  /// Returns null when hazardState is null or 0 (normal).
  String? get hazardStateLabel {
    switch (hazardState) {
      case 1:
        return 'PROXIMITY';
      case 2:
        return 'PROX BREACH';
      case 3:
        return 'GAS BUILDUP';
      case 4:
        return 'OVERHEAT';
      default:
        return null;
    }
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      sessionId: json['session_id'] as int,
      internalSessionId: json['internal_session_id'] as int,
      traineeId: json['trainee_id'] as String,
      eventKind: json['event_kind'] as String,
      deviceTimestamp: json['device_timestamp'] as int?,
      serverTimestamp: DateTime.parse(json['server_timestamp'] as String),
      deviceUptimeMs: json['device_uptime_ms'] as int?,
      eventName: json['event_name'] as String?,
      alert: json['alert'] as String?,
      cause: json['cause'] as String?,
      modelLabel: json['model_label'] as String?,
      leakProbability: (json['leak_probability'] as num?)?.toDouble(),
      rms: (json['rms'] as num?)?.toDouble(),
      gasDelta: json['gas_delta'] as int?,
      gasRatio: (json['gas_ratio'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      uvDelta: json['uv_delta'] as int?,
      wet: json['wet'] == null
          ? null
          : (json['wet'] is bool
                ? json['wet'] as bool
                : (json['wet'] as num) != 0),
      firmwareVersion: json['firmware_version'] as String?,
      rawPayload: json['raw_payload'] as Map<String, dynamic>? ?? {},
      ingestionStatus: json['ingestion_status'] as String? ?? 'accepted',
      // hz / hz_c are stored in raw_payload; extract with null-safety.
      hazardState: _intFromPayload(json['raw_payload'], 'hz'),
      hazardConf: _intFromPayload(json['raw_payload'], 'hz_c'),
    );
  }

  static int? _intFromPayload(dynamic payload, String key) {
    if (payload is Map<String, dynamic>) {
      final v = payload[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'session_id': sessionId,
      'internal_session_id': internalSessionId,
      'trainee_id': traineeId,
      'event_kind': eventKind,
      'device_timestamp': deviceTimestamp,
      'server_timestamp': serverTimestamp.toIso8601String(),
      'device_uptime_ms': deviceUptimeMs,
      'event_name': eventName,
      'alert': alert,
      'cause': cause,
      'model_label': modelLabel,
      'leak_probability': leakProbability,
      'rms': rms,
      'gas_delta': gasDelta,
      'gas_ratio': gasRatio,
      'temperature': temperature,
      'uv_delta': uvDelta,
      'wet': wet,
      'firmware_version': firmwareVersion,
      'raw_payload': rawPayload,
      'ingestion_status': ingestionStatus,
      // hz/hz_c are intentionally not round-tripped through toJson;
      // they are always re-derived from raw_payload on deserialization.
    };
  }
}
