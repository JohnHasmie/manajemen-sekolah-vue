/// Report card (raport) main screen for teachers.
///
/// Like `pages/teacher/Raport/Index.vue` in a Vue app.
/// Allows homeroom teachers to select a class, view students, and navigate
/// to individual student report card details. Supports Excel export of all
/// student reports. In Laravel terms: `RaportController@index`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/teacher_report_card_cache_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/teacher_report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/teacher_report_card_export_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/teacher_report_card_tour_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/teacher_report_card_ui_mixin.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Report card list screen -- shows classes and their students for raport entry.
///
/// Props (like Vue props): [teacher] -- current teacher info.
/// Navigates to [ReportCardDetailScreen] when a student is tapped.
class ReportCardScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final String? initialClassId;

  const ReportCardScreen({
    super.key,
    required this.teacher,
    this.initialClassId,
  });

  @override
  ReportCardScreenState createState() => ReportCardScreenState();
}

/// State for [ReportCardScreen].
///
/// Like a Vue component with `data() { return { classes, students, ... } }`.
/// Manages class selection, student list loading, and Excel export state.
class ReportCardScreenState extends ConsumerState<ReportCardScreen>
    with
        TeacherReportCardCacheMixin,
        TeacherReportCardDataMixin,
        TeacherReportCardExportMixin,
        TeacherReportCardTourMixin,
        TeacherReportCardUiMixin {
  final LanguageProvider _languageProvider = LanguageProvider();

  bool _isLoading = true;
  bool _isLoadingStudents = false;
  bool _isExporting = false;
  String _errorMessage = '';

  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;
  List<dynamic> _students = [];

  final GlobalKey _classSelectorKey = GlobalKey();
  final GlobalKey _exportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    loadInitialClassesData();
  }

  @override
  Future<void> onRefresh() async {
    await clearReportCardCache();
    await loadInitialClassesData(useCache: false);
  }

  // Mixin implementation: TeacherReportCardCacheMixin
  @override
  String getTeacherId() => Teacher.fromJson(widget.teacher).id;

  @override
  String getSelectedClassId() => _selectedClass?['id']?.toString() ?? '';

  // Mixin implementation: TeacherReportCardDataMixin
  @override
  String getAcademicYearId() =>
      ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
      '';

  @override
  Map<String, dynamic>? getSelectedClass() => _selectedClass;

  @override
  void onClassesLoaded(List<dynamic> classes) {
    setState(() {
      _classes = classes;
      _selectedClass = _classes.isNotEmpty ? _classes.first : null;
      _errorMessage = '';
    });
  }

  @override
  void onStudentsLoaded(List<dynamic> students) {
    setState(() {
      _students = students;
    });
  }

  @override
  void onStartLoading() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
  }

  @override
  void onStartLoadingStudents() {
    setState(() {
      _isLoadingStudents = true;
    });
  }

  @override
  void onLoadingComplete() {
    setState(() {
      _isLoading = false;
      _isLoadingStudents = false;
    });
  }

  @override
  void onClassesLoadError(String error) {
    if (_classes.isEmpty) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  @override
  void onStudentsLoadError(String error) {
    if (_students.isEmpty) {
      setState(() {
        _errorMessage = error;
        _isLoadingStudents = false;
        _isLoading = false;
      });
    }
  }

  String? _getAcademicYearId() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  // Mixin implementation: TeacherReportCardExportMixin
  @override
  void setExporting(bool value) {
    setState(() => _isExporting = value);
  }

  // Mixin implementation: TeacherReportCardTourMixin
  @override
  GlobalKey getClassSelectorKey() => _classSelectorKey;

  @override
  GlobalKey getExportKey() => _exportKey;

  @override
  bool shouldShowExportTour() =>
      _selectedClass != null && !_isLoading && !_isLoadingStudents;

  // Mixin implementation: TeacherReportCardUiMixin
  @override
  String getTeacherRole() => Teacher.fromJson(widget.teacher).role;

  @override
  String? getInitialClassId() => widget.initialClassId;

  @override
  bool isLoading() => _isLoading;

  @override
  bool isLoadingStudents() => _isLoadingStudents;

  @override
  String getErrorMessage() => _errorMessage;

  @override
  List<dynamic> getClasses() => _classes;

  @override
  List<dynamic> getStudents() => _students;

  @override
  LanguageProvider getLanguageProvider() => _languageProvider;

  @override
  void onRetryLoading() => loadInitialClassesData();

  @override
  void onClassChanged(Map<String, dynamic> newClass) {
    setState(() {
      _selectedClass = newClass;
      _students = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = getPrimaryColor();
    final className = _selectedClass?['nama'] ?? _selectedClass?['name'] ?? '';

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p, p.withValues(alpha: 0.85)],
              ),
              borderRadius: isDialogMode
                  ? const BorderRadius.vertical(top: Radius.circular(20))
                  : null,
            ),
            child: Column(
              children: [
                if (isDialogMode)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  SizedBox(height: MediaQuery.of(context).padding.top),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                  child: Row(
                    children: [
                      if (!isDialogMode) ...[
                        GestureDetector(
                          onTap: () => AppNavigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _languageProvider.getTranslatedText({
                                'en': 'Report Cards',
                                'id': 'Raport Siswa',
                              }),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (className.isNotEmpty)
                              Text(
                                'Kelas $className',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_selectedClass != null && !_isLoading)
                        GestureDetector(
                          key: _exportKey,
                          onTap: _isExporting ? null : exportToExcel,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isDialogMode ? Icons.close : Icons.more_vert,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: buildBody()),
        ],
      ),
    );
  }
}
