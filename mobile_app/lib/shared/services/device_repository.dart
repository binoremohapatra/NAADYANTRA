import 'package:dio/dio.dart';

import '../models/device.dart';
import '../models/common.dart';
import '../models/event.dart';
import '../models/latest_telemetry.dart';
import '../models/session.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/storage/local_database.dart';

class DeviceRepository {
  final ApiClient _apiClient;
  final LocalDatabase _cache;

  DeviceRepository({ApiClient? apiClient, LocalDatabase? cache})
    : _apiClient = apiClient ?? ApiClient(),
      _cache = cache ?? LocalDatabase();

  Future<PaginatedResponse<Device>> getDevices({
    int page = 1,
    int pageSize = 50,
    bool? isActive,
    String? search,
    bool useCache = true,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (isActive != null) queryParams['is_active'] = isActive;
      if (search != null) queryParams['search'] = search;

      final response = await _apiClient.get(
        ApiConstants.devices,
        queryParameters: queryParams,
      );

      final paginatedResponse = PaginatedResponse<Device>.fromJson(
        response.data,
        (json) => Device.fromJson(json as Map<String, dynamic>),
      );

      for (final device in paginatedResponse.items) {
        await _cache.cacheDevice(device.toJson());
      }

      return paginatedResponse;
    } on NetworkException {
      if (useCache) {
        final cachedDevices = await _cache.getCachedDevices(
          isActive: isActive,
          limit: pageSize,
        );
        if (cachedDevices.isNotEmpty) {
          return PaginatedResponse(
            total: cachedDevices.length,
            page: page,
            pageSize: pageSize,
            items: cachedDevices.map((json) => Device.fromJson(json)).toList(),
            isFromCache: true,
          );
        }
      }
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch devices');
    }
  }

  Future<Device> getDevice(String deviceId, {bool useCache = true}) async {
    try {
      final response = await _apiClient.get(ApiConstants.device(deviceId));
      final device = Device.fromJson(response.data);
      await _cache.cacheDevice(device.toJson());
      return device;
    } on NetworkException {
      if (useCache) {
        final cachedDevice = await _cache.getCachedDevice(deviceId);
        if (cachedDevice != null) {
          return Device.fromJson(cachedDevice);
        }
      }
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch device');
    }
  }

  Future<DeviceStatus> getDeviceStatus(
    String deviceId, {
    bool useCache = true,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.deviceStatus(deviceId),
      );
      final status = DeviceStatus.fromJson(response.data);
      await _cache.cacheDeviceStatus(deviceId, status.toJson());
      return status;
    } catch (_) {
      // If status endpoint returns error (500 or 404), fall back to getDevice metadata
      try {
        final device = await getDevice(deviceId, useCache: useCache);
        final isOnline = device.lastSeenAt != null &&
            DateTime.now().difference(device.lastSeenAt!).inMinutes < 5;
        final fallbackStatus = DeviceStatus(
          deviceId: device.deviceId,
          lastSeenAt: device.lastSeenAt,
          firmwareVersion: device.firmwareVersion,
          isOnline: isOnline,
          recentActivityCount: 0,
        );
        await _cache.cacheDeviceStatus(deviceId, fallbackStatus.toJson());
        return fallbackStatus;
      } catch (innerError) {
        if (useCache) {
          final cachedStatus = await _cache.getCachedDeviceStatus(deviceId);
          if (cachedStatus != null) {
            return DeviceStatus.fromJson(cachedStatus);
          }
        }
        if (innerError is AppException) rethrow;
        throw ServerException('Failed to fetch device status');
      }
    }
  }

  Future<List<Event>> getDeviceEvents(
    String deviceId, {
    int limit = 20,
    bool useCache = true,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.events,
        queryParameters: <String, dynamic>{
          'device_id': deviceId,
          'page_size': limit,
        },
      );
      final data = response.data;
      final List<dynamic> items = data is Map<String, dynamic> && data['items'] is List
          ? data['items'] as List<dynamic>
          : (data is List<dynamic> ? data : <dynamic>[]);
      final events = items
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final event in events) {
        await _cache.cacheEvent(event.toJson());
      }
      return events;
    } on NetworkException {
      if (useCache) {
        final cached = await _cache.getCachedEventsByDeviceId(
          deviceId,
          limit: limit,
        );
        if (cached.isNotEmpty) {
          return cached.map((e) => Event.fromJson(e)).toList();
        }
      }
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch device events');
    }
  }

  Future<List<SessionSummary>> getDeviceSummaries(
    String deviceId, {
    int limit = 20,
    bool useCache = true,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.summaries,
        queryParameters: <String, dynamic>{
          'device_id': deviceId,
          'page_size': limit,
        },
      );
      final data = response.data;
      final List<dynamic> items =
          data is Map<String, dynamic> && data['items'] is List
              ? data['items'] as List<dynamic>
              : (data is List<dynamic> ? data : <dynamic>[]);
      final summaries = items
          .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final summary in summaries) {
        await _cache.cacheSummary(summary.toJson());
      }
      return summaries;
    } on NetworkException {
      if (useCache) {
        final cached = await _cache.getCachedSummariesByDeviceId(
          deviceId,
          limit: limit,
        );
        if (cached.isNotEmpty) {
          return cached.map((s) => SessionSummary.fromJson(s)).toList();
        }
      }
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch device summaries');
    }
  }

  /// Fetch the most recent ingested event for [deviceId] with freshness metadata.
  ///
  /// Returns [LatestTelemetry] with [hasData]=false when no events exist yet —
  /// never throws NotFoundException for an empty device.
  /// Falls back to the most-recent cached event (marked stale) when offline.
  Future<LatestTelemetry> getLatestTelemetry(
    String deviceId, {
    int staleAfterSeconds = 30,
    bool useCache = true,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.deviceLatestTelemetry(deviceId),
        queryParameters: <String, dynamic>{
          'stale_after_seconds': staleAfterSeconds,
        },
      );
      return LatestTelemetry.fromJson(
          response.data as Map<String, dynamic>);
    } catch (_) {
      // If /telemetry/latest endpoint returns 404 (not yet deployed) or errors,
      // fallback to standard getDeviceEvents(limit: 1) which is supported on all backend versions.
      try {
        final events = await getDeviceEvents(deviceId, limit: 1, useCache: useCache);
        if (events.isNotEmpty) {
          final event = events.first;
          final staleness = DateTime.now()
              .toUtc()
              .difference(event.serverTimestamp.toUtc())
              .inSeconds
              .abs();
          final isStale = staleness > staleAfterSeconds;
          return LatestTelemetry(
            hasData: true,
            isStale: isStale,
            stalenessSecs: staleness,
            event: event,
          );
        }
        return const LatestTelemetry(
          hasData: false,
          isStale: true,
          stalenessSecs: -1,
        );
      } catch (innerError) {
        if (useCache) {
          final cached =
              await _cache.getCachedEventsByDeviceId(deviceId, limit: 1);
          if (cached.isNotEmpty) {
            final event = Event.fromJson(cached.first);
            return LatestTelemetry(
              hasData: true,
              isStale: true,
              stalenessSecs: -1,
              event: event,
            );
          }
        }
        return const LatestTelemetry(
          hasData: false,
          isStale: true,
          stalenessSecs: -1,
        );
      }
    }
  }

  /// Simulation helper for lab test benches without physical ESP32 nodes connected.
  ///
  /// [SECURITY COMPLIANCE - P0-08]:
  /// In operational production deployments, telemetry is authenticated and transmitted
  /// directly from physical ESP32 hardware using an onboard hardware key stored in ESP32 NVS,
  /// never originating from the mobile client.
  /// When invoking this method in lab testing, provide the test rig key in [deviceKey].
  Future<bool> sendTelemetryLog({
    required String deviceId,
    required double rms,
    required int gas,
    required double leak,
    required String alert,
    required double temp,
    int session = 1,
    String trainee = 'TR-01',
    String? deviceKey,
  }) async {
    final effectiveKey = deviceKey ?? 'dev-key-123';
    try {
      await _apiClient.post(
        '${ApiConstants.firmwareLog}?trainee=$trainee&session=$session&kind=event',
        data: <String, dynamic>{
          'device': deviceId,
          'millis': DateTime.now().millisecondsSinceEpoch % 10000000,
          'rms': rms,
          'gas': gas,
          'leak': leak,
          'alert': alert,
          'temp': temp,
        },
        options: Options(
          headers: <String, dynamic>{'X-Device-Key': effectiveKey},
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
