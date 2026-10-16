import 'event.dart';

/// Response from GET /api/v1/devices/{id}/telemetry/latest.
///
/// [hasData] is false when no events have ever been ingested for this device.
/// [isStale] is true when the newest event is older than the server''s
///   stale_after_seconds threshold (default 30 s).
/// [stalenessSecs] is -1 when [hasData] is false.
/// [event] is null when [hasData] is false.
class LatestTelemetry {
  final bool hasData;
  final bool isStale;
  final int stalenessSecs;
  final Event? event;

  const LatestTelemetry({
    required this.hasData,
    required this.isStale,
    required this.stalenessSecs,
    this.event,
  });

  factory LatestTelemetry.fromJson(Map<String, dynamic> json) {
    return LatestTelemetry(
      hasData: json['has_data'] as bool? ?? false,
      isStale: json['is_stale'] as bool? ?? true,
      stalenessSecs: json['staleness_seconds'] as int? ?? -1,
      event: json['event'] != null
          ? Event.fromJson(json['event'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Returns a human-readable staleness label, e.g. "42 s ago" or "3 min ago".
  String get stalenessLabel {
    if (stalenessSecs < 0) return 'no data';
    if (stalenessSecs < 60) return '${stalenessSecs}s ago';
    final mins = stalenessSecs ~/ 60;
    return '$mins min ago';
  }

  /// True when data exists and is fresh (not stale).
  bool get isLive => hasData && !isStale;
}
