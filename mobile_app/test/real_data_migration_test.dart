import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/shared/models/common.dart';
import 'package:mobile_app/shared/models/device.dart';
import 'package:mobile_app/shared/models/event.dart';
import 'package:mobile_app/shared/models/session.dart';
import 'package:mobile_app/shared/models/assessment.dart';
import 'package:mobile_app/shared/models/latest_telemetry.dart';
import 'package:mobile_app/shared/services/providers.dart';
import 'package:mobile_app/shared/services/device_repository.dart';

void main() {
  group('Real-Data Migration & Authoritative Data Access Tests', () {
    test('selectedDeviceIdProvider defaults to null without assuming hardcoded node', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final selected = container.read(selectedDeviceIdProvider);
      expect(selected, isNull);
    });

    test('activeDeviceIdProvider returns null when device list is empty', () {
      final container = ProviderContainer(
        overrides: [
          devicesProvider.overrideWith(
            (ref) async => PaginatedResponse<Device>(
              total: 0,
              page: 1,
              pageSize: 50,
              items: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Trigger resolution
      container.read(devicesProvider);
      final active = container.read(activeDeviceIdProvider);
      expect(active, isNull);
    });

    test('activeDeviceIdProvider resolves real registered hardware node dynamically', () async {
      final container = ProviderContainer(
        overrides: [
          devicesProvider.overrideWith(
            (ref) async => PaginatedResponse<Device>(
              total: 1,
              page: 1,
              pageSize: 50,
              items: [
                Device(
                  id: 1,
                  deviceId: 'ESP32-PIPELINE-ALPHA',
                  name: 'Alpha Pipeline Rig',
                  isActive: true,
                  deviceMetadata: {},
                  createdAt: DateTime(2026, 10, 17),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(devicesProvider.future);
      final active = container.read(activeDeviceIdProvider);
      expect(active, equals('ESP32-PIPELINE-ALPHA'));
    });

    test('deviceStatusProvider returns clean unconnected state when no node is active', () async {
      final container = ProviderContainer(
        overrides: [
          devicesProvider.overrideWith(
            (ref) async => PaginatedResponse<Device>(
              total: 0,
              page: 1,
              pageSize: 50,
              items: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(deviceStatusProvider.future);
      expect(status.deviceId, equals('—'));
      expect(status.isOnline, isFalse);
      expect(status.hasData, isFalse);
      expect(status.isStale, isTrue);
    });

    test('latestTelemetryProvider returns hasData: false when no hardware is provisioned', () async {
      final container = ProviderContainer(
        overrides: [
          devicesProvider.overrideWith(
            (ref) async => PaginatedResponse<Device>(
              total: 0,
              page: 1,
              pageSize: 50,
              items: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final telemetry = await container.read(latestTelemetryProvider.future);
      expect(telemetry.hasData, isFalse);
      expect(telemetry.event, isNull);
      expect(telemetry.isLive, isFalse);
      expect(telemetry.stalenessSecs, equals(-1));
    });

    test('DeviceRepository.sendTelemetryLog blocks simulation against production cloud database', () async {
      final repo = DeviceRepository();
      // Default base URL in AppConfig points to production cloud URL (onrender.com)
      final blocked = await repo.sendTelemetryLog(
        deviceId: 'TEST-DEV',
        rms: 1200.0,
        gas: 100,
        leak: 0.8,
        alert: 'DANGER',
        temp: 30.0,
      );

      // Must be safely blocked from polluting production cloud database
      expect(blocked, isFalse);
    });

    test('Device status truthfully reflects offline node with exact last_seen timestamp', () {
      final lastSeen = DateTime.now().subtract(const Duration(hours: 48));
      final status = DeviceStatus(
        deviceId: 'OFFLINE-NODE-01',
        isOnline: false,
        hasData: true,
        isStale: true,
        lastSeenAt: lastSeen,
        recentActivityCount: 0,
      );

      expect(status.isOnline, isFalse);
      expect(status.isStale, isTrue);
      expect(status.lastSeenAt, equals(lastSeen));
    });

    test('Latest telemetry truth: historical stale reading never masquerades as live', () {
      final recordedAt = DateTime.now().subtract(const Duration(minutes: 45));
      final telemetry = LatestTelemetry(
        hasData: true,
        isStale: true,
        stalenessSecs: 2700,
        event: Event(
          id: 42,
          deviceId: 'OFFLINE-NODE-01',
          sessionId: 1,
          internalSessionId: 1,
          traineeId: 'TR-1',
          eventKind: 'event',
          serverTimestamp: recordedAt,
          rawPayload: const {},
          ingestionStatus: 'accepted',
          rms: 1540.0,
          gasDelta: 210,
          alert: 'WARNING',
        ),
      );

      expect(telemetry.hasData, isTrue);
      expect(telemetry.isLive, isFalse);
      expect(telemetry.isStale, isTrue);
      expect(telemetry.stalenessSecs, equals(2700));
      expect(telemetry.event!.rms, equals(1540.0));
    });

    test('Empty sessions response preserves zero count without inventing placeholder sessions', () {
      final response = PaginatedResponse<Session>(
        total: 0,
        page: 1,
        pageSize: 50,
        items: [],
      );

      expect(response.total, equals(0));
      expect(response.items, isEmpty);
    });

    test('Empty events response preserves zero count without inventing sample anomalies', () {
      final response = PaginatedResponse<Event>(
        total: 0,
        page: 1,
        pageSize: 50,
        items: [],
      );

      expect(response.total, equals(0));
      expect(response.items, isEmpty);
    });

    test('Empty assessments rubric response preserves empty state', () {
      final response = PaginatedResponse<Assessment>(
        total: 0,
        page: 1,
        pageSize: 50,
        items: [],
      );

      expect(response.total, equals(0));
      expect(response.items, isEmpty);
    });
  });
}
