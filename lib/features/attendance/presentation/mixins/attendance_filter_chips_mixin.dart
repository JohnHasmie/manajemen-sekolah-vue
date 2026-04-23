import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Handles building active filter chips and filter state management.
/// Provides UI-building methods for display of active filters.
mixin AttendanceFilterChipsMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──

  Color get primaryColor;
  String? get filterClassId;
  set filterClassId(String? v);
  String? get filterSubjectId;
  set filterSubjectId(String? v);
  String? get filterDateOption;
  set filterDateOption(String? v);
  List<dynamic> get classList;
  List<dynamic> get filterSubjectList;

  // Methods to call
  Future<void> refreshGroupedAttendance();

  // ═════════════════════════════════════════
  // FILTER CHIPS BUILDER
  // ═════════════════════════════════════════

  /// Build active filter chips from current filter state
  List<ActiveFilter> buildActiveFilterChips(LanguageProvider lp) =>
      _buildActiveFilterChipsInternal(lp);

  /// Internal implementation for building filter chips
  List<ActiveFilter> _buildActiveFilterChipsInternal(LanguageProvider lp) {
    final chips = <ActiveFilter>[];

    if (filterClassId != null) {
      final className = _resolveClassName();
      chips.add(
        ActiveFilter(
          label: className,
          onRemove: () {
            setState(() {
              filterClassId = null;
              filterSubjectId = null;
              filterSubjectList.clear();
            });
            refreshGroupedAttendance();
          },
          color: primaryColor,
        ),
      );
    }

    if (filterSubjectId != null) {
      final subjectName = _resolveSubjectName();
      chips.add(
        ActiveFilter(
          label: subjectName,
          onRemove: () {
            setState(() => filterSubjectId = null);
            refreshGroupedAttendance();
          },
          color: primaryColor,
        ),
      );
    }

    if (filterDateOption != null) {
      final dateLabel = _resolveDateLabel(lp);
      chips.add(
        ActiveFilter(
          label: dateLabel,
          onRemove: () {
            setState(() => filterDateOption = null);
            refreshGroupedAttendance();
          },
          color: primaryColor,
        ),
      );
    }

    return chips;
  }

  /// Resolve class name from classList by filterClassId
  String _resolveClassName() {
    final c = classList.firstWhere(
      (c) => c['id']?.toString() == filterClassId,
      orElse: () => {'name': '-'},
    );
    return c['name'] ?? '-';
  }

  /// Resolve subject name from filterSubjectList by filterSubjectId
  String _resolveSubjectName() {
    final s = filterSubjectList.firstWhere(
      (s) => s['id']?.toString() == filterSubjectId,
      orElse: () => {'name': '-'},
    );
    return s['name'] ?? '-';
  }

  /// Resolve date filter label from filterDateOption
  String _resolveDateLabel(LanguageProvider lp) {
    if (filterDateOption == 'today') {
      return lp.getTranslatedText({'en': 'Today', 'id': 'Hari ini'});
    }
    if (filterDateOption == 'week') {
      return lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu ini'});
    }
    return lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan ini'});
  }

  /// Clear all active filters and refresh data
  void clearAllFilters() {
    setState(() {
      filterClassId = null;
      filterSubjectId = null;
      filterDateOption = null;
      filterSubjectList.clear();
    });
    refreshGroupedAttendance();
  }

  @override
  void setState(VoidCallback fn);
}
