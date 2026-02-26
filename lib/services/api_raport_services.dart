import 'api_services.dart';

class ApiRaportService {
  static Future<List<dynamic>> getRaports({
    required String classId,
    required String academicYearId,
    required String semesterId,
  }) async {
    final response = await ApiService().get(
      '/raports',
      params: {
        'class_id': classId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
      },
    );

    if (response != null && response['success'] == true) {
      return response['data'] as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getInitialData({
    required String studentClassId,
    required String academicYearId,
    required String semesterId,
  }) async {
    final response = await ApiService().get(
      '/raport/initial-data',
      params: {
        'student_class_id': studentClassId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
      },
    );

    if (response != null &&
        response['success'] == true &&
        response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getRaportDetail({
    required String studentClassId,
    required String academicYearId,
    required String semesterId,
  }) async {
    // Note: The backend route is /raport/show but we use show method in controller
    final response = await ApiService().get(
      '/raport/show',
      params: {
        'student_class_id': studentClassId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
      },
    );

    if (response != null &&
        response['success'] == true &&
        response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> saveRaport(
    Map<String, dynamic> data,
  ) async {
    final response = await ApiService().post('/raport', data);

    if (response != null && response['success'] == true) {
      return response['data'] as Map<String, dynamic>;
    }
    return null;
  }
}
