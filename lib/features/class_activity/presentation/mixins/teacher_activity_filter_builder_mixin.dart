import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_ui_helpers_mixin.dart';

mixin TeacherActivityFilterBuilderMixin
    implements TeacherActivityUIHelpersMixin {
  final _dio = getIt<Dio>();

  void setState(VoidCallback fn);

  List<dynamic> get classList;
  String get teacherId;

  Widget buildClassFilter(
    StateSetter setSS,
    LanguageProvider lp,
    String? Function() getClassId,
    void Function(String?) setClassId,
    void Function(String?) setSubjectId,
    void Function(List<dynamic>) setSubjectList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSheetSectionHeader(
          lp.getTranslatedText({'en': 'Select Class', 'id': 'Pilih Kelas'}),
          Icons.school_rounded,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildSheetChip(
              lp.getTranslatedText({'en': 'All Classes', 'id': 'Semua Kelas'}),
              getClassId() == null,
              () {
                setSS(() {
                  setClassId(null);
                  setSubjectId(null);
                  setSubjectList([]);
                });
              },
            ),
            ...classList.map((c) {
              final cid = c['id']?.toString();
              final cname = c['name'] ?? c['nama'] ?? '-';
              return buildSheetChip(cname, getClassId() == cid, () async {
                setSS(() {
                  setClassId(cid);
                  setSubjectId(null);
                  setSubjectList([]);
                });
                if (cid != null) {
                  await _fetchSubjects(cid, setSS, setSubjectList);
                }
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget buildSubjectFilter(
    LanguageProvider lp,
    String? Function() getSubjectId,
    void Function(String?) setSubjectId,
    List<dynamic> Function() getSubjectList,
  ) {
    final subjectList = getSubjectList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSheetSectionHeader(
          lp.getTranslatedText({'en': 'Select Subject', 'id': 'Pilih Mapel'}),
          Icons.menu_book_rounded,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildSheetChip(
              lp.getTranslatedText({'en': 'All Subjects', 'id': 'Semua Mapel'}),
              getSubjectId() == null,
              () {
                setSubjectId(null);
              },
            ),
            ...subjectList.map((s) {
              final sid = s['id']?.toString();
              final sname = s['name'] ?? s['nama'] ?? '-';
              return buildSheetChip(sname, getSubjectId() == sid, () {
                setSubjectId(sid);
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget buildDateFilter(
    StateSetter setSS,
    LanguageProvider lp,
    String? Function() getDateOption,
    void Function(String?) setDateOption,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSheetSectionHeader(
          lp.getTranslatedText({'en': 'Time Range', 'id': 'Rentang Waktu'}),
          Icons.calendar_today_rounded,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildSheetChip(
              lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
              getDateOption() == 'today',
              () => setSS(
                () =>
                    setDateOption(_toggleDateOption(getDateOption(), 'today')),
              ),
            ),
            buildSheetChip(
              lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'}),
              getDateOption() == 'week',
              () => setSS(
                () => setDateOption(_toggleDateOption(getDateOption(), 'week')),
              ),
            ),
            buildSheetChip(
              lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'}),
              getDateOption() == 'month',
              () => setSS(
                () =>
                    setDateOption(_toggleDateOption(getDateOption(), 'month')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _toggleDateOption(String? current, String option) {
    return current == option ? null : option;
  }

  /// Fetches only subjects the current teacher teaches for the given class.
  /// `/teacher/:id/subjects?class_id=` merges assignments + teaching
  /// schedule; see TeacherController@getSubjects.
  Future<void> _fetchSubjects(
    String classId,
    StateSetter setSS,
    void Function(List<dynamic>) setSubjectList,
  ) async {
    try {
      final r = await _dio.get(
        '/teacher/$teacherId/subjects',
        queryParameters: {'class_id': classId},
      );
      final raw = r.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : <dynamic>[]);
      setSS(() => setSubjectList(list));
    } catch (_) {
      // Handle error silently
    }
  }

  @override
  Color get primaryColor;
}
