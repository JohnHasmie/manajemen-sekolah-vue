/// academic_year_provider.dart - State management for academic year selection.
/// Like a Vuex store module - holds reactive global state that widgets can listen to.
/// In Laravel terms, this is like a service/singleton that tracks which "Tahun Ajaran"
/// (academic year) is currently active and selected across the entire app.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart' as riverpod_legacy;

import 'package:manajemensekolah/features/settings/data/academic_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Manages the list of academic years and tracks which one is currently selected.
/// Like a Vuex store module - holds reactive global state that widgets can listen to.
///
/// Extends [ChangeNotifier] (Flutter's built-in observable pattern), which is the
/// Flutter equivalent of Vue's `reactive()` or Vuex's state. When properties change,
/// `notifyListeners()` is called - similar to how Vuex mutations trigger re-renders.
///
/// Key state:
/// - [_academicYears]: Full list fetched from API (like Vuex state).
/// - [_activeAcademicYear]: The backend-designated "current" year.
/// - [_selectedAcademicYear]: The user's chosen year (may differ from active).
/// - [isReadOnly]: Computed property - inactive years are read-only (like a Vuex getter).
/// - [isCurrent]: Computed property - whether the selected year is the current one.
class AcademicYearProvider with ChangeNotifier {
  List<dynamic> _academicYears = [];
  Map<String, dynamic>? _activeAcademicYear;
  Map<String, dynamic>? _selectedAcademicYear;
  bool _isLoading = false;

  /// Public getters - like Vuex getters, these expose read-only access to private state.
  List<dynamic> get academicYears => _academicYears;
  Map<String, dynamic>? get activeAcademicYear => _activeAcademicYear;
  Map<String, dynamic>? get selectedAcademicYear => _selectedAcademicYear;
  bool get isLoading => _isLoading;

  /// Returns true if the selected academic year is inactive (past/archived).
  /// When true, the UI should prevent edits - like a Laravel policy check.
  bool get isReadOnly {
    if (_selectedAcademicYear == null) return false;
    // status 'inactive' means read-only
    return _selectedAcademicYear!['status'] == 'inactive';
  }

  /// Returns true if the selected year is marked as "current" by the backend.
  /// Handles both boolean `true` and integer `1` formats from the API.
  bool get isCurrent {
    if (_selectedAcademicYear == null) return false;
    return _selectedAcademicYear!['current'] == true ||
        _selectedAcademicYear!['current'] == 1;
  }

  /// Fetches all academic years from the API and auto-selects the best one.
  /// Like a Vuex action that commits mutations after an async API call.
  ///
  /// Selection priority (only when no year is already selected):
  /// 1. Backend's active year (from a separate API endpoint).
  /// 2. Date-based match: if current month >= July, use "currentYear/nextYear";
  ///    otherwise use "prevYear/currentYear". This handles the Indonesian school
  ///    year which starts in July.
  /// 3. Fallback to the first year in the list.
  ///
  /// Side effects: Sets [_isLoading] true during fetch, calls [notifyListeners]
  /// to trigger UI rebuilds (like Vuex mutations).
  Future<void> fetchAcademicYears() async {
    _isLoading = true;
    notifyListeners();

    try {
      _academicYears = await getIt<ApiAcademicServices>().getAcademicYears();

      // Also fetch active year to ensure sync
      _activeAcademicYear = await getIt<ApiAcademicServices>()
          .getActiveAcademicYear();

      // Calculate date-based year first
      // Indonesian school year starts in July, so month >= 7 means "currentYear/nextYear"
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      String targetYearString;
      if (currentMonth >= 7) {
        targetYearString = '$currentYear/${currentYear + 1}';
      } else {
        targetYearString = '${currentYear - 1}/$currentYear';
      }

      final dateBasedYear = _academicYears.firstWhere(
        (ay) => (ay['year'] ?? '').toString() == targetYearString,
        orElse: () => null,
      );

      // Priority 1: Use Active from Backend
      if (_selectedAcademicYear == null && _activeAcademicYear != null) {
        _selectedAcademicYear = _activeAcademicYear;
      }
      // Priority 2: Match by Date (Fallback)
      else if (_selectedAcademicYear == null && dateBasedYear != null) {
        _selectedAcademicYear = dateBasedYear;
      }
      // Priority 3: Fallback to first
      else if (_selectedAcademicYear == null && _academicYears.isNotEmpty) {
        _selectedAcademicYear = _academicYears.first;
      }
    } catch (e) {
      AppLogger.error('academic_year', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the selected academic year by its ID.
  /// Like a Vuex mutation - finds the year in the cached list and sets it as selected.
  ///
  /// [yearId] - The ID of the academic year to select (matched as string).
  /// Side effects: Calls [notifyListeners] to trigger UI rebuilds in all consuming widgets.
  void setSelectedYear(String yearId) {
    AppLogger.debug(
      'academic_year',
      'Searching for year ID: $yearId in ${_academicYears.length} years',
    );
    try {
      final year = _academicYears.firstWhere(
        (y) => y['id'].toString() == yearId.toString(),
        orElse: () => null,
      );

      AppLogger.debug('academic_year', 'Found year: $year');

      if (year != null) {
        _selectedAcademicYear = year;
        AppLogger.debug(
          'academic_year',
          'Selected year set to: ${_selectedAcademicYear?['year']} (ID: ${_selectedAcademicYear?['id']})',
        );
        AppLogger.debug('academic_year', 'Is Read Only: $isReadOnly');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('academic_year', e);
    }
  }

  /// Refetches only the active academic year from the backend.
  /// Lighter than [fetchAcademicYears] - useful when you just need to
  /// check if the backend's active year has changed.
  Future<void> refreshActiveYear() async {
    try {
      _activeAcademicYear = await getIt<ApiAcademicServices>()
          .getActiveAcademicYear();
      notifyListeners();
    } catch (e) {
      AppLogger.error('academic_year', e);
    }
  }
}

/// Riverpod provider for [AcademicYearProvider].
/// Wraps the existing ChangeNotifier so both old and new code can access it.
///
/// Usage: `ref.watch(academicYearRiverpod)` or `ref.read(academicYearRiverpod)`
final academicYearRiverpod =
    riverpod_legacy.ChangeNotifierProvider<AcademicYearProvider>((ref) {
      return AcademicYearProvider();
    });
