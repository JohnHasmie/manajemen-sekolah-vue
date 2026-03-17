import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that caches teacher-related data fetched by the dashboard.
/// Other screens can consume this instead of making redundant API calls.
class TeacherProvider extends ChangeNotifier {
  String? _userId;
  String? _teacherId;
  String? _teacherName;
  Map<String, dynamic> _teacherData = {};
  List<dynamic> _allClasses = [];
  List<dynamic> _homeroomClasses = [];
  bool _isLoaded = false;
  bool _isLoading = false;

  // Getters
  String? get userId => _userId;
  String? get teacherId => _teacherId;
  String? get teacherName => _teacherName;
  Map<String, dynamic> get teacherData => _teacherData;
  List<dynamic> get allClasses => _allClasses;
  List<dynamic> get homeroomClasses => _homeroomClasses;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Set data directly (called from dashboard after it fetches)
  void setTeacherData({
    required String userId,
    required String teacherId,
    required String teacherName,
    required Map<String, dynamic> teacherData,
    required List<dynamic> allClasses,
    required List<dynamic> homeroomClasses,
  }) {
    _userId = userId;
    _teacherId = teacherId;
    _teacherName = teacherName;
    _teacherData = teacherData;
    _allClasses = allClasses;
    _homeroomClasses = homeroomClasses;
    _isLoaded = true;
    _isLoading = false;
    notifyListeners();

    if (kDebugMode) {
      print('📦 TeacherProvider: Data cached (teacherId=$teacherId, classes=${allClasses.length}, homeroom=${homeroomClasses.length})');
    }
  }

  /// Update only homeroom classes (e.g. after dashboard resolves them)
  void setHomeroomClasses(List<dynamic> classes) {
    _homeroomClasses = classes;
    notifyListeners();
  }

  /// Fetch teacher data if not already loaded.
  /// This is a fallback for screens opened without going through dashboard.
  Future<void> ensureLoaded({String? academicYearId}) async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user');
      if (userDataStr == null) {
        _isLoading = false;
        return;
      }

      final userData = json.decode(userDataStr);
      final id = userData['id']?.toString() ?? '';
      if (id.isEmpty) {
        _isLoading = false;
        return;
      }

      _userId = id;
      _teacherName = userData['nama']?.toString() ?? 'Guru';

      // Check if userData already has teacher info
      final looksLikeTeacher = userData.containsKey('teacher_id') &&
          userData['teacher_id'] != null;

      String? resolvedTeacherId;

      if (looksLikeTeacher) {
        resolvedTeacherId = userData['teacher_id'].toString();
      } else {
        // Fetch from API
        final teacherRecord = await ApiTeacherService.getGuruByUserId(
          id,
          academicYearId: academicYearId,
        );
        if (teacherRecord != null && teacherRecord['id'] != null) {
          resolvedTeacherId = teacherRecord['id'].toString();
          _teacherData = Map<String, dynamic>.from(teacherRecord);
        }
      }

      if (resolvedTeacherId != null) {
        _teacherId = resolvedTeacherId;

        // Fetch classes
        final classes = await ApiTeacherService.getTeacherClasses(
          resolvedTeacherId,
          academicYearId: academicYearId,
        );

        _allClasses = classes;
        _homeroomClasses = classes.where((cls) {
          final isH = cls['is_homeroom'];
          return isH == true || isH == 1 || isH.toString() == 'true';
        }).toList();

        _isLoaded = true;

        if (kDebugMode) {
          print('📦 TeacherProvider: Fallback load complete (teacherId=$resolvedTeacherId)');
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherProvider: ensureLoaded failed: $e');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh (e.g. on pull-to-refresh or academic year change)
  Future<void> refresh({String? academicYearId}) async {
    _isLoaded = false;
    _isLoading = false;
    await ensureLoaded(academicYearId: academicYearId);
  }

  /// Clear all cached data (e.g. on school switch or logout)
  void clear() {
    _userId = null;
    _teacherId = null;
    _teacherName = null;
    _teacherData = {};
    _allClasses = [];
    _homeroomClasses = [];
    _isLoaded = false;
    _isLoading = false;
    notifyListeners();
  }
}
