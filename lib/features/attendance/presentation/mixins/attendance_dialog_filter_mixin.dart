import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_shared_mixin.dart';

/// Handles the filter bottom-sheet dialog for attendance
mixin AttendanceDialogFilterMixin
    on
        ConsumerState<AttendancePage>,
        AttendanceDataMixin,
        AttendanceDialogSharedMixin {
  // ── Abstract state accessors ──

  @override
  Color get primaryColor;

  @override
  String? get filterClassId;
  set filterClassId(String? v);

  @override
  String? get filterSubjectId;
  set filterSubjectId(String? v);

  @override
  String? get filterDateOption;
  set filterDateOption(String? v);

  List<dynamic> get filterSubjectList;
  set filterSubjectList(List<dynamic> v);

  @override
  Future<void> forceRefresh();

  // ═══════════════════════════════════════════
  // FILTER DIALOG
  // ═══════════════════════════════════════════

  void showFilterDialog(LanguageProvider lp) async {
    String? tClassId = filterClassId;
    String? tSubjectId = filterSubjectId;
    String? tDateOption = filterDateOption;

    if (!mounted) return;

    showFilterSheet(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Filter Attendance',
        'id': 'Filter Presensi',
      }),
      primaryColor: primaryColor,
      onApply: () =>
          _applyFilter(context, tClassId, tSubjectId, tDateOption, lp),
      onReset: () => FilterSheetHelpers.reset(context, () {
        setState(() {
          filterClassId = null;
          filterSubjectId = null;
          filterDateOption = null;
          filterSubjectList = [];
        });
        forceRefresh();
      }),
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          // Brand filter rule: source chips from the pre-fetched
          // roster + cross-axis maps (see filter_roster_provider.dart).
          // No on-tap network round-trips.
          final roster = ref.watch(filterRosterRiverpod);
          final rosterClasses = roster.classesForSubject(
            tSubjectId,
            isHomeroomView: isHomeroomView,
          );
          final rosterSubjects = roster.subjectsForClass(
            tClassId,
            isHomeroomView: isHomeroomView,
          );
          final classes = rosterClasses
              .map(
                (c) => FilterOption<String>(
                  value: c['id']?.toString() ?? '',
                  label: c['name']?.toString() ?? c['nama']?.toString() ?? '-',
                ),
              )
              .toList();
          final subjects = rosterSubjects
              .map(
                (s) => FilterOption<String>(
                  value: s['id']?.toString() ?? '',
                  label: s['name']?.toString() ?? s['nama']?.toString() ?? '-',
                ),
              )
              .toList();

          final dateOptions = [
            FilterOption<String>(
              value: 'today',
              label: lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
            ),
            FilterOption<String>(
              value: 'week',
              label: lp.getTranslatedText({
                'en': 'This Week',
                'id': 'Minggu Ini',
              }),
            ),
            FilterOption<String>(
              value: 'month',
              label: lp.getTranslatedText({
                'en': 'This Month',
                'id': 'Bulan Ini',
              }),
            ),
          ];

          return TeacherFilterContent(
            sections: [
              // Kelas section hides in wali kelas mode — the role
              // toggle in the page header already locked the class.
              if (!isHomeroomView)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: lp.getTranslatedText({
                        'en': 'Class',
                        'id': 'Kelas',
                      }),
                      icon: Icons.class_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: classes,
                      selectedValue: tClassId,
                      onSelected: (v) {
                        setSS(() {
                          tClassId = v;
                          // Cross-axis: drop the subject if the new
                          // class doesn't teach it.
                          if (tSubjectId != null && v != null) {
                            final allowed = roster
                                .subjectsForClass(
                                  v,
                                  isHomeroomView: isHomeroomView,
                                )
                                .map((s) => (s as Map)['id']?.toString());
                            if (!allowed.contains(tSubjectId)) {
                              tSubjectId = null;
                            }
                          }
                          // Auto-select-on-single — if only one
                          // subject for this class, pick it.
                          if (v != null && tSubjectId == null) {
                            final only = roster.subjectsForClass(
                              v,
                              isHomeroomView: isHomeroomView,
                            );
                            if (only.length == 1 && only.first is Map) {
                              tSubjectId = (only.first as Map)['id']
                                  ?.toString();
                            }
                          }
                        });
                      },
                      selectedColor: primaryColor,
                    ),
                  ],
                ),
              if (subjects.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: lp.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mapel',
                      }),
                      icon: Icons.book_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: subjects,
                      selectedValue: tSubjectId,
                      onSelected: (v) {
                        setSS(() {
                          tSubjectId = v;
                          // Cross-axis inverse: auto-select the only
                          // class teaching this subject when no class
                          // is picked yet.
                          if (v != null && tClassId == null) {
                            final only = roster.classesForSubject(
                              v,
                              isHomeroomView: isHomeroomView,
                            );
                            if (only.length == 1 && only.first is Map) {
                              tClassId = (only.first as Map)['id']?.toString();
                            }
                          }
                        });
                      },
                      selectedColor: primaryColor,
                    ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilterSectionHeader(
                    title: lp.getTranslatedText({
                      'en': 'Time Range',
                      'id': 'Rentang Waktu',
                    }),
                    icon: Icons.date_range_rounded,
                    primaryColor: primaryColor,
                  ),
                  FilterChipGrid<String>(
                    options: dateOptions,
                    selectedValue: tDateOption,
                    onSelected: (v) {
                      setSS(() {
                        tDateOption = v;
                      });
                    },
                    selectedColor: primaryColor,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyFilter(
    BuildContext ctx,
    String? classId,
    String? subjectId,
    String? dateOption,
    LanguageProvider lp,
  ) {
    Navigator.pop(ctx);
    setState(() {
      filterClassId = classId;
      filterSubjectId = subjectId;
      filterDateOption = dateOption;
      // `filterSubjectList` is legacy state — used to cache the
      // per-class subject roster across renders. With the unified
      // FilterRosterProvider it's redundant; we leave the setter
      // empty so existing read sites that haven't migrated yet
      // continue to compile.
      filterSubjectList = const [];
    });
    forceRefresh();
  }
}
