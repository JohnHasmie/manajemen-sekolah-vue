// Admin RPP review-hub filter sheet — Mockup Frame E1.
//
// Replaces the bare status-only sheet on admin_rpp_review_hub_screen
// with an AppFilterBottomSheet that composes FilterChipGrid sections
// for: status, format, mapel (mata pelajaran), kelas, guru, periode.
//
// Returns a [LessonPlanAdminFilter] on Apply or null on Cancel. The
// caller stores the value in screen state and passes it to the queue
// service as query parameters.
//
// All lookup options (mapel / kelas / guru) come from the cached
// FilterOptionsService — same source the rest of the admin app uses.
// Picker UX is single-select chip per section to keep the sheet
// short; multi-select would clobber the available height on small
// phones once you stack 5 sections.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/services/filter_options_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';

/// All the dimensions an admin can filter the RPP queue by.
///
/// Each field is null when the section is "any" — null status means
/// any-status, null format means any-format, etc. Empty (vs null) is
/// intentionally never used here so server-side query building can
/// treat null as "skip this filter."
class LessonPlanAdminFilter {
  /// Pending / Approved / Rejected — match backend status values.
  final String? status;

  /// k13 / rpp_1_halaman / modul_ajar / file — match the format enum.
  final String? format;

  /// Subject UUID.
  final String? subjectId;

  /// Class UUID.
  final String? classId;

  /// Teacher UUID.
  final String? teacherId;

  /// One of the predefined window keys (today / week / month /
  /// semester). The screen translates that into from_date+to_date
  /// before hitting the API.
  final String? period;

  const LessonPlanAdminFilter({
    this.status,
    this.format,
    this.subjectId,
    this.classId,
    this.teacherId,
    this.period,
  });

  /// Empty filter — used for "Reset" and the default state.
  const LessonPlanAdminFilter.empty()
    : status = null,
      format = null,
      subjectId = null,
      classId = null,
      teacherId = null,
      period = null;

  /// True when no filters are active. Drives the "Filter (N)" badge
  /// on the hub header.
  bool get isEmpty =>
      status == null &&
      format == null &&
      subjectId == null &&
      classId == null &&
      teacherId == null &&
      period == null;

  /// How many sections currently have a value selected. Surfaces on
  /// the header chip as a counter badge.
  int get activeCount =>
      (status != null ? 1 : 0) +
      (format != null ? 1 : 0) +
      (subjectId != null ? 1 : 0) +
      (classId != null ? 1 : 0) +
      (teacherId != null ? 1 : 0) +
      (period != null ? 1 : 0);

  LessonPlanAdminFilter copyWith({
    Object? status = _unset,
    Object? format = _unset,
    Object? subjectId = _unset,
    Object? classId = _unset,
    Object? teacherId = _unset,
    Object? period = _unset,
  }) {
    return LessonPlanAdminFilter(
      status: identical(status, _unset) ? this.status : status as String?,
      format: identical(format, _unset) ? this.format : format as String?,
      subjectId: identical(subjectId, _unset)
          ? this.subjectId
          : subjectId as String?,
      classId: identical(classId, _unset) ? this.classId : classId as String?,
      teacherId: identical(teacherId, _unset)
          ? this.teacherId
          : teacherId as String?,
      period: identical(period, _unset) ? this.period : period as String?,
    );
  }
}

/// Sentinel for copyWith to distinguish "not passed" from "explicit
/// null." Dart doesn't have an Optional<T> in the language proper.
const _unset = Object();

/// Backend-facing status keys. Display labels stay short so chips
/// don't wrap to 2 lines on narrow phones.
const List<FilterOption<String>> _statusOptions = [
  FilterOption(value: 'Pending', label: 'Menunggu'),
  FilterOption(value: 'Approved', label: 'Disetujui'),
  FilterOption(value: 'Rejected', label: 'Ditolak'),
];

/// Format options mirror LessonPlanFormat enum values.
const List<FilterOption<String>> _formatOptions = [
  FilterOption(value: 'k13', label: 'K13'),
  FilterOption(value: 'rpp_1_halaman', label: '1 Halaman'),
  FilterOption(value: 'modul_ajar', label: 'Modul Ajar'),
  FilterOption(value: 'file', label: 'Upload'),
];

/// Period buckets — the hub screen translates these into a date
/// range. Kept as 4 options so the sheet stays scannable.
const List<FilterOption<String>> _periodOptions = [
  FilterOption(value: 'week', label: 'Minggu ini'),
  FilterOption(value: 'month', label: 'Bulan ini'),
  FilterOption(value: 'semester', label: 'Semester berjalan'),
  FilterOption(value: 'all', label: 'Semua periode'),
];

/// Opens the admin RPP filter sheet. Returns the new filter on Apply
/// or null when the admin dismisses.
Future<LessonPlanAdminFilter?> showLessonPlanAdminFilterSheet({
  required BuildContext context,
  required LessonPlanAdminFilter initial,
  required String role,
  String? academicYearId,
}) {
  return showModalBottomSheet<LessonPlanAdminFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(
      initial: initial,
      role: role,
      academicYearId: academicYearId,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  final LessonPlanAdminFilter initial;
  final String role;
  final String? academicYearId;

  const _FilterSheet({
    required this.initial,
    required this.role,
    this.academicYearId,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LessonPlanAdminFilter _draft;

  bool _loadingOptions = true;
  List<FilterOption<String>> _subjects = const [];
  List<FilterOption<String>> _classes = const [];
  List<FilterOption<String>> _teachers = const [];

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _loadOptions();
  }

  /// Pull mapel / kelas / guru lists from the cached filter-options
  /// endpoint. Falls back to empty when the call fails so the sheet
  /// still opens — the user can still filter by status / format /
  /// periode even if the dropdown lookups are unavailable.
  Future<void> _loadOptions() async {
    try {
      final data = await FilterOptionsService.getFilterOptions(
        role: widget.role,
        academicYearId: widget.academicYearId,
      );
      if (!mounted) return;
      setState(() {
        _subjects = _mapToOptions(data['subjects']);
        _classes = _mapToOptions(data['classes']);
        _teachers = _mapToOptions(
          data['teachers'],
          labelKeys: const ['name', 'full_name', 'nama'],
        );
        _loadingOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
    }
  }

  List<FilterOption<String>> _mapToOptions(
    dynamic raw, {
    List<String> labelKeys = const ['name', 'label', 'nama'],
  }) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) {
          final id = (m['id'] ?? m['value'])?.toString() ?? '';
          if (id.isEmpty) return null;
          String? label;
          for (final k in labelKeys) {
            if (m[k] != null && m[k].toString().trim().isNotEmpty) {
              label = m[k].toString();
              break;
            }
          }
          if (label == null || label.isEmpty) return null;
          return FilterOption<String>(value: id, label: label);
        })
        .whereType<FilterOption<String>>()
        .toList(growable: false);
  }

  void _apply() => Navigator.of(context).pop(_draft);

  void _reset() {
    setState(() => _draft = const LessonPlanAdminFilter.empty());
  }

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');

    return AppFilterBottomSheet(
      title: 'Filter RPP',
      headerSubtitle: 'Pilih kombinasi filter — terapkan saat selesai',
      icon: Icons.tune_rounded,
      primaryColor: navy,
      onApply: _apply,
      onReset: _reset,
      applyLabel: _draft.isEmpty
          ? 'Terapkan'
          : 'Terapkan (${_draft.activeCount})',
      content: _buildContent(navy),
    );
  }

  Widget _buildContent(Color navy) {
    // Section order mirrors mockup Frame E1:
    //   Status → Format → Mapel → Kelas → Guru → Periode
    // Periode lives at the bottom because it's a coarse, last-resort
    // filter — the admin usually narrows by status/format/subject
    // first.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChipGrid<String>(
          title: 'Status',
          options: _statusOptions,
          selectedValue: _draft.status,
          onSelected: (v) =>
              setState(() => _draft = _draft.copyWith(status: v)),
          selectedColor: navy,
        ),
        const SizedBox(height: 14),
        FilterChipGrid<String>(
          title: 'Format',
          options: _formatOptions,
          selectedValue: _draft.format,
          onSelected: (v) =>
              setState(() => _draft = _draft.copyWith(format: v)),
          selectedColor: navy,
        ),
        const SizedBox(height: 14),
        if (_loadingOptions) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: navy),
                ),
                const SizedBox(width: 10),
                Text(
                  'Memuat pilihan…',
                  style: TextStyle(
                    color: ColorUtils.slate500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          if (_subjects.isNotEmpty) ...[
            FilterChipGrid<String>(
              title: 'Mata Pelajaran',
              options: _subjects,
              selectedValue: _draft.subjectId,
              onSelected: (v) =>
                  setState(() => _draft = _draft.copyWith(subjectId: v)),
              selectedColor: navy,
            ),
            const SizedBox(height: 14),
          ],
          if (_classes.isNotEmpty) ...[
            FilterChipGrid<String>(
              title: 'Kelas',
              options: _classes,
              selectedValue: _draft.classId,
              onSelected: (v) =>
                  setState(() => _draft = _draft.copyWith(classId: v)),
              selectedColor: navy,
            ),
            const SizedBox(height: 14),
          ],
          if (_teachers.isNotEmpty) ...[
            FilterChipGrid<String>(
              title: 'Guru',
              options: _teachers,
              selectedValue: _draft.teacherId,
              onSelected: (v) =>
                  setState(() => _draft = _draft.copyWith(teacherId: v)),
              selectedColor: navy,
            ),
            const SizedBox(height: 14),
          ],
        ],
        FilterChipGrid<String>(
          title: 'Periode',
          options: _periodOptions,
          selectedValue: _draft.period,
          onSelected: (v) =>
              setState(() => _draft = _draft.copyWith(period: v)),
          selectedColor: navy,
        ),
      ],
    );
  }
}
