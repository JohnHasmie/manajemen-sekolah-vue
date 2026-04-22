import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_cache_manager.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';

/// Helper for dashboard initialization logic.
class DashboardInitializer {
  final Ref ref;

  DashboardInitializer(this.ref);

  /// Load and prepare initial state from cache.
  Future<DashboardState> prepareInitialState(String role) async {
    DashboardState initialState = await DashboardCacheManager.loadLocalCache(
      role,
    );
    initialState = await _resolveTeacherIdIfNeeded(initialState, role);
    return initialState;
  }

  /// Resolve teacher_id from backend if missing.
  Future<DashboardState> _resolveTeacherIdIfNeeded(
    DashboardState state,
    String role,
  ) async {
    if (role != 'guru' ||
        state.userData['teacher_id'] != null ||
        state.userData['id'] == null) {
      return state;
    }

    try {
      final teacherInfo = await ApiTeacherService().getTeacherByUserId(
        state.userData['id'].toString(),
      );
      if (teacherInfo != null && teacherInfo['id'] != null) {
        final updatedUserData = Map<String, dynamic>.from(state.userData);
        updatedUserData['teacher_id'] = teacherInfo['id'].toString();
        return state.copyWith(userData: updatedUserData);
      }
    } catch (e) {
      AppLogger.error(
        'dashboard_initializer',
        'Failed to resolve teacher_id: $e',
      );
    }
    return state;
  }

  /// Ensure academic year is loaded.
  Future<void> ensureAcademicYearLoaded() async {
    final academicYearProvider = ref.read(academicYearRiverpod);
    if (academicYearProvider.selectedAcademicYear == null) {
      await academicYearProvider.fetchAcademicYears();
    }
  }
}
