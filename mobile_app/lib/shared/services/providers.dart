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

final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
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

// Selected Device ID
final selectedDeviceIdProvider = StateProvider<String?>((ref) {
  return null;
});

// Device List Provider
final devicesProvider = FutureProvider.autoDispose((ref) async {
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  return await deviceRepo.getDevices();
});

// Device Status Provider
// Resolves status for currently selected device or falls back to 'SIH-DEV-01'.
final deviceStatusProvider =
    FutureProvider.autoDispose<DeviceStatus>((ref) async {
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
  final deviceId = selectedDeviceId ?? 'SIH-DEV-01';
  return await deviceRepo.getDeviceStatus(deviceId);
});

// Latest Telemetry Provider
// Fetches /telemetry/latest for the currently selected device or 'SIH-DEV-01'.
final latestTelemetryProvider =
    FutureProvider.autoDispose<LatestTelemetry>((ref) async {
  final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
  final deviceId = selectedDeviceId ?? 'SIH-DEV-01';
  final repo = ref.watch(deviceRepositoryProvider);
  return await repo.getLatestTelemetry(deviceId);
});


// Backend URL Provider
// Reads the persisted URL from SecureStorage; falls back to AppConfig default.
// Use backendUrlProvider.notifier to persist a new URL:
//   ref.read(backendUrlProvider.notifier).setUrl(newUrl)
final backendUrlProvider =
    AsyncNotifierProvider<BackendUrlNotifier, String>(BackendUrlNotifier.new);

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
final deviceEventsProvider =
    FutureProvider.autoDispose.family<List<Event>, String>((ref, deviceId) async {
      final repo = ref.watch(deviceRepositoryProvider);
      return await repo.getDeviceEvents(deviceId, limit: 50);
    });

// Device Summaries Provider
final deviceSummariesProvider =
    FutureProvider.autoDispose.family<List<SessionSummary>, String>((
      ref,
      deviceId,
    ) async {
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
