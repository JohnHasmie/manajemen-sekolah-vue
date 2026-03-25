/// teacher_provider.dart - State management for teacher-related data caching.
/// Like a Vuex store module - holds reactive global state that widgets can listen to.
/// In Laravel terms, this is like a service class that caches the logged-in teacher's
/// profile, assigned classes, and homeroom classes so multiple screens can share the data
/// without redundant API calls (similar to Laravel's request-scoped caching).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Caches teacher-related data fetched by the dashboard so other screens
/// can consume it without making redundant API calls.
/// Like a Vuex store module - holds reactive global state that widgets can listen to.
///
/// Extends [ChangeNotifier] - Flutter's observable pattern (like Vue's `reactive()`).
/// Widgets use `Provider.of<TeacherProvider>(context)` or `context.watch<TeacherProvider>()`
/// to subscribe, similar to `mapState` / `useStore()` in Vuex.
///
/// Data flow:
/// 1. Dashboard fetches teacher data from API and calls [setTeacherData] (primary path).
/// 2. If a screen is opened directly (e.g., deep link), [ensureLoaded] acts as a fallback
///    by reading from SharedPreferences and the API.
/// 3. [refresh] forces a reload (e.g., on pull-to-refresh or academic year change).
/// 4. [clear] wipes all cached state (e.g., on logout or school switch).
class TeacherProvider extends ChangeNotifier {
  String? _userId;
  String? _teacherId;
  String? _teacherName;
  Map<String, dynamic> _teacherData = {};
  List<dynamic> _allClasses = [];
  List<dynamic> _homeroomClasses = [];
  bool _isLoaded = false;
  bool _isLoading = false;

  /// Public getters - like Vuex getters, expose read-only access to private state.
  /// Widgets subscribe to these via `context.watch<TeacherProvider>()`.
  String? get userId => _userId;
  String? get teacherId => _teacherId;
  String? get teacherName => _teacherName;
  Map<String, dynamic> get teacherData => _teacherData;
  List<dynamic> get allClasses => _allClasses;
  List<dynamic> get homeroomClasses => _homeroomClasses;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// Sets all teacher data at once (called from the dashboard after it fetches from API).
  /// Like a Vuex mutation that hydrates the entire module state in one go.
  ///
  /// This is the primary data path - the dashboard fetches teacher info and pushes
  /// it here so other screens don't need to re-fetch.
  ///
  /// Side effects: Sets [_isLoaded] to true, calls [notifyListeners] to trigger
  /// UI rebuilds in all consuming widgets.
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

    AppLogger.debug('teacher', 'TeacherProvider: Data cached (teacherId=$teacherId, classes=${allClasses.length}, homeroom=${homeroomClasses.length})');
  }

  /// Updates only the homeroom classes list (e.g., after the dashboard resolves them).
  /// Like a targeted Vuex mutation that only touches one piece of state.
  ///
  /// [classes] - The resolved list of homeroom class maps.
  void setHomeroomClasses(List<dynamic> classes) {
    _homeroomClasses = classes;
    notifyListeners();
  }

  /// Fetches and caches teacher data if not already loaded.
  /// This is a fallback for screens opened without going through the dashboard
  /// (e.g., deep links or direct navigation). Like a Laravel service method
  /// with lazy initialization.
  ///
  /// [academicYearId] - Optional academic year context for scoped API calls.
  ///
  /// Flow:
  /// 1. Reads user data from SharedPreferences (like Laravel's `Auth::user()`).
  /// 2. Resolves the teacher ID - either from cached user data or via API call.
  /// 3. Fetches the teacher's assigned classes and filters homeroom classes.
  ///
  /// No-op if already loaded or currently loading (guard clause prevents duplicate calls).
  Future<void> ensureLoaded({String? academicYearId}) async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;

    try {
      final prefs = PreferencesService();
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

        AppLogger.warning('teacher', 'TeacherProvider: Fallback load complete (teacherId=$resolvedTeacherId)');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('teacher', e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Forces a full reload of teacher data (e.g., on pull-to-refresh or academic year change).
  /// Resets [_isLoaded] flag so [ensureLoaded] will re-fetch from the API.
  ///
  /// [academicYearId] - Optional academic year to scope the refresh.
  Future<void> refresh({String? academicYearId}) async {
    _isLoaded = false;
    _isLoading = false;
    await ensureLoaded(academicYearId: academicYearId);
  }

  /// Clears all cached teacher data (e.g., on logout or school switch).
  /// Resets everything to initial state. Like calling `Vuex commit('RESET_MODULE')`.
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
