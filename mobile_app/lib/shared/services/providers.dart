import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth_repository.dart';
import 'device_repository.dart';
import 'session_repository.dart';
import 'assessment_repository.dart';
import 'dashboard_repository.dart';
import '../models/event.dart';
import '../models/device.dart';
import '../models/latest_telemetry.dart';
import '../models/session.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/storage/local_database.dart';
import '../../core/config/app_config.dart';

// API Client
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Secure Storage
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// Local Database
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(
    apiClient: ref.watch(apiClientProvider),
    cache: ref.watch(localDatabaseProvider),
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(
    apiClient: ref.watch(apiClientProvider),
    cache: ref.watch(localDatabaseProvider),
  );
});

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return AssessmentRepository(apiClient: ref.watch(apiClientProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    apiClient: ref.watch(apiClientProvider),
    cache: ref.watch(localDatabaseProvider),
  );
});

// Connectivity Providers
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  try {
    return ref.watch(connectivityProvider).onConnectivityChanged;
  } catch (_) {
    return const Stream.empty();
  }
});

final isOfflineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityStreamProvider);
  return connectivityAsync.when(
    data: (results) =>
        results.isEmpty || results.contains(ConnectivityResult.none),
    loading: () => false,
    error: (_, _) => false,
  );
});

// Selected Device ID (nullable: null by default, user-selected override)
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// Device List Provider
final devicesProvider = FutureProvider.autoDispose((ref) async {
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  return await deviceRepo.getDevices();
});

/// Active Device ID Resolver:
/// 1. Prioritizes explicit user selection via [selectedDeviceIdProvider].
/// 2. Otherwise dynamically selects the first registered hardware node from [devicesProvider].
/// 3. Returns null if no hardware nodes are registered in the cloud database.
final activeDeviceIdProvider = Provider<String?>((ref) {
  final explicit = ref.watch(selectedDeviceIdProvider);
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  final devicesAsync = ref.watch(devicesProvider);
  return devicesAsync.valueOrNull?.items.firstOrNull?.deviceId;
});

// Device Status Provider
// Resolves status for currently active hardware node from the backend.
// Returns an authentic unconnected status if no node is provisioned.
final deviceStatusProvider = FutureProvider.autoDispose<DeviceStatus>((
  ref,
) async {
  final activeDeviceId = ref.watch(activeDeviceIdProvider);
  if (activeDeviceId == null || activeDeviceId.isEmpty) {
    return DeviceStatus(
      deviceId: '—',
      isOnline: false,
      hasData: false,
      isStale: true,
      recentActivityCount: 0,
    );
  }
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  return await deviceRepo.getDeviceStatus(activeDeviceId);
});

// Latest Telemetry Provider
// Fetches /telemetry/latest for the currently active hardware node.
// Returns an authentic empty model if no hardware node is active or provisioned.
final latestTelemetryProvider = FutureProvider.autoDispose<LatestTelemetry>((
  ref,
) async {
  final activeDeviceId = ref.watch(activeDeviceIdProvider);
  if (activeDeviceId == null || activeDeviceId.isEmpty) {
    return const LatestTelemetry(
      hasData: false,
      isStale: true,
      stalenessSecs: -1,
      event: null,
    );
  }
  final repo = ref.watch(deviceRepositoryProvider);
  return await repo.getLatestTelemetry(activeDeviceId);
});

// Backend URL Provider
// Reads the persisted URL from SecureStorage; falls back to AppConfig default.
// Use backendUrlProvider.notifier to persist a new URL:
//   ref.read(backendUrlProvider.notifier).setUrl(newUrl)
final backendUrlProvider = AsyncNotifierProvider<BackendUrlNotifier, String>(
  BackendUrlNotifier.new,
);

class BackendUrlNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final storage = ref.watch(secureStorageProvider);
    final saved = await storage.getApiBaseUrl();
    final url = saved ?? AppConfig.defaultApiBaseUrl;
    // Apply to the Dio client immediately on startup.
    ref.read(apiClientProvider).updateBaseUrl(url);
    return url;
  }

  Future<void> setUrl(String newUrl) async {
    final storage = ref.read(secureStorageProvider);
    await storage.saveApiBaseUrl(newUrl);
    ref.read(apiClientProvider).updateBaseUrl(newUrl);
    state = AsyncData(newUrl);
  }

  Future<void> resetToDefault() async {
    final storage = ref.read(secureStorageProvider);
    await storage.saveApiBaseUrl(AppConfig.defaultApiBaseUrl);
    ref.read(apiClientProvider).updateBaseUrl(AppConfig.defaultApiBaseUrl);
    state = AsyncData(AppConfig.defaultApiBaseUrl);
  }
}

// Device Events Provider
final deviceEventsProvider = FutureProvider.autoDispose
    .family<List<Event>, String>((ref, deviceId) async {
      final repo = ref.watch(deviceRepositoryProvider);
      return await repo.getDeviceEvents(deviceId, limit: 50);
    });

// Device Summaries Provider
final deviceSummariesProvider = FutureProvider.autoDispose
    .family<List<SessionSummary>, String>((ref, deviceId) async {
      final repo = ref.watch(deviceRepositoryProvider);
      return await repo.getDeviceSummaries(deviceId, limit: 20);
    });

// Auth State
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState.initial()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (isLoggedIn) {
      final username = await _authRepository.getUsername();
      state = AuthState.authenticated(username ?? 'User');
    }
  }

  Future<void> login(String username, String password) async {
    state = AuthState.loading();
    try {
      await _authRepository.login(username, password);
      state = AuthState.authenticated(username);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    try {
      await _authRepository.logout();
      state = AuthState.initial();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  void handleUnauthorized() {
    if (state.isAuthenticated) {
      state = AuthState.initial();
    }
  }
}

// Unauthorized Handler Setup
// Breaks the circular dependency by setting up the callback separately
final unauthorizedHandlerProvider = Provider<void>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authNotifier = ref.watch(authStateProvider.notifier);
  apiClient.onUnauthorized = authNotifier.handleUnauthorized;
});

class AuthState {
  final bool isAuthenticated;
  final String? username;
  final bool isLoading;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    this.username,
    required this.isLoading,
    this.error,
  });

  factory AuthState.initial() =>
      AuthState(isAuthenticated: false, isLoading: false);

  factory AuthState.authenticated(String username) =>
      AuthState(isAuthenticated: true, username: username, isLoading: false);

  factory AuthState.loading() =>
      AuthState(isAuthenticated: false, isLoading: true);

  factory AuthState.error(String error) =>
      AuthState(isAuthenticated: false, isLoading: false, error: error);
}

// ──────────────────────────────────────────────────────────────────────────────
// Theme Mode Provider & Persistence Notifier
// ──────────────────────────────────────────────────────────────────────────────

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final storage = ref.watch(secureStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SecureStorageService _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final saved = await _storage.getThemeMode();
      if (saved != null) {
        switch (saved) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
          default:
            state = ThemeMode.system;
            break;
        }
      }
    } catch (_) {
      // Fallback gracefully
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _storage.saveThemeMode(value);
    } catch (_) {}
  }
}
