import '../models/dashboard.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/storage/local_database.dart';

class DashboardRepository {
  final ApiClient _apiClient;
  final LocalDatabase _cache;

  DashboardRepository({ApiClient? apiClient, LocalDatabase? cache})
    : _apiClient = apiClient ?? ApiClient(),
      _cache = cache ?? LocalDatabase();

  /// Fetch live system overview statistics from the backend with SQLite cache fallback.
  Future<DashboardOverview> getOverview() async {
    try {
      final response = await _apiClient.get(ApiConstants.dashboardOverview);
      return DashboardOverview.fromJson(response.data as Map<String, dynamic>);
    } on NetworkException {
      final cached = await _cache.getDashboardOverview();
      return DashboardOverview.fromJson(cached);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch dashboard overview');
    }
  }

  /// Fetch the most recent activity items (sessions + alert events) with SQLite fallback.
  Future<List<RecentActivityItem>> getRecentActivity({
    int pageSize = 10,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.dashboardRecentActivity,
        queryParameters: <String, dynamic>{'page': 1, 'page_size': pageSize},
      );
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => RecentActivityItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on NetworkException {
      final cached = await _cache.getCachedRecentActivity(limit: pageSize);
      if (cached.isNotEmpty) {
        return cached.map((e) => RecentActivityItem.fromJson(e)).toList();
      }
      return [];
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch recent activity');
    }
  }
}
