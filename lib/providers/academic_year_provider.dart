import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/services/api_academic_services.dart';

class AcademicYearProvider with ChangeNotifier {
  List<dynamic> _academicYears = [];
  Map<String, dynamic>? _activeAcademicYear;
  Map<String, dynamic>? _selectedAcademicYear;
  bool _isLoading = false;

  List<dynamic> get academicYears => _academicYears;
  Map<String, dynamic>? get activeAcademicYear => _activeAcademicYear;
  Map<String, dynamic>? get selectedAcademicYear => _selectedAcademicYear;
  bool get isLoading => _isLoading;

  bool get isReadOnly {
    if (_activeAcademicYear == null || _selectedAcademicYear == null)
      return false;
    return _activeAcademicYear!['id'] != _selectedAcademicYear!['id'];
  }

  Future<void> fetchAcademicYears() async {
    _isLoading = true;
    notifyListeners();

    try {
      _academicYears = await ApiAcademicServices.getAcademicYears();

      // Also fetch active year to ensure sync
      _activeAcademicYear = await ApiAcademicServices.getActiveAcademicYear();

      // Calculate date-based year first
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
      if (kDebugMode) {
        print('Error fetching academic years: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedYear(String yearId) {
    print('Searching for year ID: $yearId in ${_academicYears.length} years');
    try {
      final year = _academicYears.firstWhere(
        (y) => y['id'].toString() == yearId.toString(),
        orElse: () => null,
      );

      print('Found year: $year');

      if (year != null) {
        _selectedAcademicYear = year;
        print(
          'Selected year set to: ${_selectedAcademicYear?['year']} (ID: ${_selectedAcademicYear?['id']})',
        );
        print('Is Read Only: $isReadOnly');
        notifyListeners();
      }
    } catch (e) {
      print('Error selecting year: $e');
    }
  }

  // Refetch only active year if needed
  Future<void> refreshActiveYear() async {
    try {
      _activeAcademicYear = await ApiAcademicServices.getActiveAcademicYear();
      notifyListeners();
    } catch (e) {
      print('Error refreshing active year: $e');
    }
  }
}

// Global instance if needed (but prefer Provider)
