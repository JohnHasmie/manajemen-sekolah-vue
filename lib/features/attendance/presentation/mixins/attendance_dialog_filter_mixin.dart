import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
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

  /// Fetches only subjects the current teacher teaches for the given class.
  /// `/teacher/:id/subjects?class_id=` merges assignments + teaching
  /// schedule; see TeacherController@getSubjects.
  Future<List<dynamic>> _fetchTeacherSubjectsForClass(String classId) async {
    try {
      final r = await dioClient.get(
        '/teacher/$teacherId/subjects',
        queryParameters: {'class_id': classId},
      );
      final raw = r.data;
      if (raw is List) return raw;
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════
  // FILTER DIALOG
  // ═══════════════════════════════════════════

  void showFilterDialog(LanguageProvider lp) async {
    String? tClassId = filterClassId;
    String? tSubjectId = filterSubjectId;
    String? tDateOption = filterDateOption;
    List<dynamic> tSubjectList = List.from(filterSubjectList);

    if (tClassId != null) {
      tSubjectList = await _fetchTeacherSubjectsForClass(tClassId);
    }

    if (!mounted) return;

    showFilterSheet(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Filter Attendance',
        'id': 'Filter Presensi',
      }),
      primaryColor: primaryColor,
      onApply: () => _applyFilter(context, tClassId, tSubjectId, tDateOption, tSubjectList, lp),
      onReset: () => setState(() {
        filterClassId = null;
        filterSubjectId = null;
        filterDateOption = null;
        filterSubjectList = [];
      }),
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          final classes = classList
              .map((c) => FilterOption<String>(
                    value: c['id']?.toString() ?? '',
                    label: c['name']?.toString() ?? c['nama']?.toString() ?? '-',
                  ))
              .toList();

          final subjects = tSubjectList.isNotEmpty
              ? tSubjectList
                  .map((s) => FilterOption<String>(
                        value: s['id']?.toString() ?? '',
                        label: s['name']?.toString() ?? s['nama']?.toString() ?? '-',
                      ))
                  .toList()
              : <FilterOption<String>>[];

          final dateOptions = [
            FilterOption<String>(
              value: 'today',
              label: lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
            ),
            FilterOption<String>(
              value: 'week',
              label: lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'}),
            ),
            FilterOption<String>(
              value: 'month',
              label: lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'}),
            ),
          ];

          return TeacherFilterContent(
            sections: [
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
                        tSubjectList = [];
                        tSubjectId = null;
                      });
                      if (v != null) {
                        _fetchTeacherSubjectsForClass(v).then((list) {
                          setSS(() {
                            tSubjectList = list;
                          });
                        });
                      }
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
    List<dynamic> subjectList,
    LanguageProvider lp,
  ) {
    Navigator.pop(ctx);
    setState(() {
      filterClassId = classId;
      filterSubjectId = subjectId;
      filterDateOption = dateOption;
      filterSubjectList = subjectList;
    });
    forceRefresh();
  }

}
