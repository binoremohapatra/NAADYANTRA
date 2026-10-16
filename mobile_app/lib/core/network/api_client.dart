import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../errors/exceptions.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _secureStorage;
  void Function()? onUnauthorized;
  Future<String?>? _refreshFuture;

  ApiClient({String? baseUrl, SecureStorageService? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.defaultApiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _setupInterceptors();
  }

  Dio get dio => _dio;

  void _setupInterceptors() {
    // Request interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/logout');

          // Never attempt token refresh on authentication endpoints themselves
          if (isAuthEndpoint) {
            if (error.response?.statusCode == 401) {
              await _secureStorage.clearAuthToken();
              onUnauthorized?.call();
            }
            return handler.next(error);
          }

          // Handle 401 on regular endpoints
          if (error.response?.statusCode == 401) {
            try {
              final newToken = await _refreshToken();
              if (newToken != null && newToken.isNotEmpty) {
                // Retry the original request with the renewed token
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $newToken';
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              }
            } catch (_) {
              // Refresh failed
            }

            // Refresh failed or returned null — clear token and broadcast logout
            await _secureStorage.clearAuthToken();
            onUnauthorized?.call();
          }

          return handler.next(error);
        },
      ),
    );

    // Logger for debug mode
    if (AppConfig.isDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
    }
  }

  Future<String?> _refreshToken() async {
    final existingFuture = _refreshFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = () async {
      try {
        final currentToken = await _secureStorage.getAuthToken();
        if (currentToken == null || currentToken.isEmpty) {
          return null;
        }

        // Dedicated lightweight Dio client WITHOUT interceptors to avoid recursive 401 loops
        final refreshDio = Dio(
          BaseOptions(
            baseUrl: _dio.options.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $currentToken',
            },
          ),
        );

        final response = await refreshDio.post('/api/v1/auth/refresh');
        if (response.statusCode == 200 && response.data != null) {
          final newToken = response.data['access_token'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            await _secureStorage.saveAuthToken(newToken);
            return newToken;
          }
        }
        return null;
      } catch (_) {
        return null;
      } finally {
        _refreshFuture = null;
      }
    }();

    _refreshFuture = future;
    return future;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return NetworkException('Connection timeout');
    }

    if (error.type == DioExceptionType.connectionError) {
      return NetworkException('No internet connection');
    }

    final statusCode = error.response?.statusCode;
    final message =
        error.response?.data?['detail'] ?? error.message ?? 'An error occurred';

    switch (statusCode) {
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 422:
        return ValidationException(message);
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerException(message, statusCode);
        }
        return ServerException(message);
    }
  }

  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }
}
