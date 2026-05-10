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
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
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
    Map<String, dynamic>? matched;
    // In dialog mode (opened from overview), auto-select the class
    // matching initialClassId so students load immediately.
    final targetId = widget.initialClassId;
    if (targetId != null && classes.isNotEmpty) {
      matched = classes.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id']?.toString() == targetId,
        orElse: () => classes.first as Map<String, dynamic>,
      );
    }
    setState(() {
      _classes = classes;
      _selectedClass = matched;
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

  /// Compute the per-class KPI tuple from the loaded student list.
  /// Used to populate the 4-cell KPI overlap strip below the brand
  /// header. Falls back to all-zero when students haven't loaded yet.
  ({int siswa, int terbit, int draft, double rerata}) _kpiStats() {
    var siswa = _students.length;
    var terbit = 0;
    var draft = 0;
    double sumScore = 0;
    int scoreCount = 0;
    for (final s in _students) {
      if (s is! Map) continue;
      final status =
          (s['raport_status'] ?? s['status'])?.toString().toLowerCase() ?? '';
      if (status == 'published' || status == 'terbit') terbit++;
      if (status == 'draft') draft++;
      final rerata = s['rerata'] ?? s['average'] ?? s['avg_score'];
      if (rerata is num && rerata > 0) {
        sumScore += rerata.toDouble();
        scoreCount++;
      }
    }
    return (
      siswa: siswa,
      terbit: terbit,
      draft: draft,
      rerata: scoreCount > 0 ? sumScore / scoreCount : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    final className = _selectedClass?['nama'] ?? _selectedClass?['name'] ?? '';
    final ayLabel = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['year']
        ?.toString();
    final kicker = [
      if (ayLabel != null) 'Tahun $ayLabel',
      if (className.toString().isNotEmpty) 'Kelas $className',
    ].join(' · ');

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              BrandPageHeader(
                role: 'guru',
                subtitle: kicker.isEmpty
                    ? lp.getTranslatedText({
                        'en': 'Report Cards',
                        'id': 'Raport Siswa',
                      })
                    : kicker,
                title: lp.getTranslatedText({
                  'en': 'Class Report',
                  'id': 'Raport Kelas',
                }),
                kpiOverlayHeight: 45,
                actionIcons: [
                  if (_selectedClass != null && !_isLoading)
                    BrandHeaderIconButton(
                      key: _exportKey,
                      icon: Icons.download_rounded,
                      onTap: _isExporting ? () {} : exportToExcel,
                    ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: Transform.translate(
                  offset: const Offset(0, 22),
                  child: _buildKpiStrip(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(child: buildBody()),
        ],
      ),
    );
  }

  Widget _buildKpiStrip() {
    final stats = _kpiStats();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpiCell('${stats.siswa}', 'SISWA', ColorUtils.brandCobalt),
            _kpiDivider(),
            _kpiCell('${stats.terbit}', 'TERBIT', ColorUtils.success600),
            _kpiDivider(),
            _kpiCell('${stats.draft}', 'DRAFT', ColorUtils.warning600),
            _kpiDivider(),
            _kpiCell(
              stats.rerata > 0 ? stats.rerata.toStringAsFixed(1) : '—',
              'RERATA',
              ColorUtils.info600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: ColorUtils.slate100,
  );
}
