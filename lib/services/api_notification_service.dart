import 'package:manajemensekolah/services/api_services.dart';

class ApiNotificationService {
  final ApiService _apiService = ApiService();

  Future<List<dynamic>> getNotifications({int page = 1, String? role}) async {
    try {
      final url = role != null
          ? '/notifications?page=$page&role=$role'
          : '/notifications?page=$page';
      final response = await _apiService.get(url);
      return response['data'] ?? [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTodaySchedule() async {
    try {
      return await _apiService.get('/notifications/today-schedule');
    } catch (e) {
      return [];
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _apiService.put('/notifications/$id', {'is_read': true});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    try {
      await _apiService.post('/notifications/mark-all-read', {});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _apiService.delete('/notifications/$id');
    } catch (e) {
      rethrow;
    }
  }
}
