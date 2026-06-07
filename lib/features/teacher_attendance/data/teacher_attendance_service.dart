// teacher_attendance_service.dart — the thin data layer for "Presensi
// Guru" (teacher daily attendance). Talks to the backend Attendance
// module's TeacherAttendanceController (backend MR !108) via the shared
// `dioClient` (which already injects the Bearer token + X-School-ID
// header through AuthInterceptor — see core/network/dio_client.dart).
//
// Analogy: this is the Laravel-side equivalent of a thin Service class
// that wraps `Http::withToken(...)->post(...)` — no business logic, just
// shaping the request (multipart for the photo) and parsing the typed
// response. The geofence/late/idempotency rules all live SERVER-side;
// the app never decides "present vs late" or stamps the clock itself.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/teacher_attendance/domain/models/'
    'teacher_attendance_models.dart';

/// Service facade for the teacher's own daily check-in / check-out flow.
class TeacherAttendanceService {
  /// Bootstrap call the Presensi screen makes on open. Returns the
  /// per-school settings + today's schedule + the teacher's current
  /// day-state in one shot (see [TeacherAttendanceConfig]).
  Future<TeacherAttendanceConfig> getConfig() async {
    final response = await dioClient.get(ApiEndpoints.teacherAttendanceConfig);
    return TeacherAttendanceConfig.fromJson(_dataMap(response.data));
  }

  /// POST check-in (multipart). The [photoFile] is a LIVE camera capture
  /// (the screen enforces the camera source — no gallery). Coordinates
  /// are only sent when the school requires location. The SERVER stamps
  /// `check_in_at` and computes present/late + geofence distance — we
  /// never pass a client timestamp. Returns the created record (201).
  Future<TeacherAttendanceRecord> checkIn({
    File? photoFile,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final formData = await _buildMultipart(
      photoFile: photoFile,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
    );
    final response = await dioClient.post(
      ApiEndpoints.teacherAttendanceCheckIn,
      data: formData,
    );
    return TeacherAttendanceRecord.fromJson(_dataMap(response.data));
  }

  /// POST check-out (multipart). Same fields/rules as check-in; the
  /// server requires an existing same-day check-in, blocks double
  /// check-out, and only allows it when `checkout_enabled`. Returns the
  /// updated record (200).
  Future<TeacherAttendanceRecord> checkOut({
    File? photoFile,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final formData = await _buildMultipart(
      photoFile: photoFile,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
    );
    final response = await dioClient.post(
      ApiEndpoints.teacherAttendanceCheckOut,
      data: formData,
    );
    return TeacherAttendanceRecord.fromJson(_dataMap(response.data));
  }

  /// The authenticated teacher's own paginated history. Returns the raw
  /// Laravel resource-collection envelope ({data, links, meta}) so the
  /// caller can read pagination — the records are parsed via
  /// [TeacherAttendanceRecord.fromJson] on `data[]`.
  Future<List<TeacherAttendanceRecord>> getHistory({
    String? startDate,
    String? endDate,
    int? perPage,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['end_date'] = endDate;
    }
    if (perPage != null) params['per_page'] = perPage;

    final response = await dioClient.get(
      ApiEndpoints.teacherAttendanceHistory,
      queryParameters: params,
    );
    final data = response.data;
    final list = data is Map && data['data'] is List
        ? data['data'] as List
        : (data is List ? data : const []);
    return list
        .whereType<Map>()
        .map(
          (e) => TeacherAttendanceRecord.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  /// Builds the shared multipart body for check-in / check-out. The
  /// photo (when present) is attached as `photo` with an explicit image
  /// MIME so the backend's `mimes:jpeg,jpg,png` rule passes — mirrors
  /// how AnnouncementService attaches its `file`. Coordinates are sent
  /// as strings to keep the multipart encoding predictable.
  Future<FormData> _buildMultipart({
    File? photoFile,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final map = <String, dynamic>{};
    if (photoFile != null) {
      map['photo'] = await MultipartFile.fromFile(
        photoFile.path,
        filename: photoFile.path.split('/').last,
        contentType: DioMediaType('image', _imageSubtype(photoFile.path)),
      );
    }
    if (latitude != null) map['latitude'] = latitude.toString();
    if (longitude != null) map['longitude'] = longitude.toString();
    if (notes != null && notes.trim().isNotEmpty) {
      map['notes'] = notes.trim();
    }
    return FormData.fromMap(map);
  }

  /// Maps a file extension to the image subtype the backend accepts.
  /// image_picker's camera capture is JPEG on both platforms, so this
  /// almost always resolves to `jpeg`; png is handled defensively.
  String _imageSubtype(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    return 'jpeg';
  }

  /// Pulls the `data` object out of the standard {success, message, data}
  /// envelope. Falls back to the raw map if the server returned the
  /// record at the top level.
  Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    AppLogger.warning(
      'teacher_attendance',
      'Unexpected response shape: ${body.runtimeType}',
    );
    return <String, dynamic>{};
  }
}
