import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
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

  /// Brand-pattern filter chips that always render (3 dimensions:
  /// Periode, Kelas, Mapel). Each chip's value previews the current
  /// selection — defaulting to `Semua` / `Bulan ini` when not
  /// filtered — and `onTap` opens the same filter sheet so the chip
  /// is a tap target as well as a state read-out.
  ///
  /// Mirrors the parent role's `BrandFilterChipStrip` usage on
  /// `parent_billing_screen.dart` so the brand-migrated teacher
  /// surfaces feel identical to a parent navigating their bills.
  List<BrandFilterChip> buildBrandFilterChips({
    required LanguageProvider lp,
    required VoidCallback onTap,
  }) {
    return [
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Period', 'id': 'Periode'}),
        value: filterDateOption == null
            ? lp.getTranslatedText({'en': 'This month', 'id': 'Bulan ini'})
            : _resolveDateLabel(lp),
        onTap: onTap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
        value: filterClassId == null
            ? lp.getTranslatedText({'en': 'All', 'id': 'Semua'})
            : _resolveClassName(),
        onTap: onTap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}),
        value: filterSubjectId == null
            ? lp.getTranslatedText({'en': 'All', 'id': 'Semua'})
            : _resolveSubjectName(),
        onTap: onTap,
      ),
    ];
  }

  /// Count of dimensions with a non-null filter applied — drives the
  /// red badge on the filter icon in the header.
  int get activeFilterCount {
    var n = 0;
    if (filterClassId != null) n++;
    if (filterSubjectId != null) n++;
    if (filterDateOption != null) n++;
    return n;
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
