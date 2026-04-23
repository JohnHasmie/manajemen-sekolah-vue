/// Admin report card (raport) management screen.
///
/// Like `pages/admin/report-cards.vue` - allows admins to select a
/// class, view student report cards, export to Excel, and
/// publish/unpublish raports.
///
/// In Laravel terms, this consumes RaportController with
/// class-based filtering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_actions_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_tour_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/admin_report_card_utils_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/admin_report_card_body.dart';

/// Admin report card screen - select class, view students,
/// export/publish raports.
///
/// This is a [ConsumerStatefulWidget] with local state for class
/// selection and student list display. Uses cache-first loading.
class AdminReportCardScreen extends ConsumerStatefulWidget {
  const AdminReportCardScreen({super.key});

  @override
  ConsumerState createState() => _AdminReportCardScreenState();
}

/// Mutable state for [AdminReportCardScreen].
///
/// Key state (like Vue `data()`):
/// - [classes] - list of classes to choose from
/// - [selectedClass] - currently selected class for viewing
/// - [students] - students in the selected class with status
/// - [isExporting] / [isPublishing] - loading states
class _AdminReportCardScreenState extends ConsumerState<AdminReportCardScreen>
    with
        AdminReportCardDataMixin,
        AdminReportCardActionsMixin,
        AdminReportCardTourMixin,
        AdminReportCardUtilsMixin {
  late LanguageProvider _languageProvider;

  bool _isLoading = true;
  bool _isLoadingStudents = false;
  bool _isExporting = false;
  bool _isPublishing = false;
  String _errorMessage = '';

  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;
  List<dynamic> _students = [];

  final GlobalKey _selectClassKey = GlobalKey();
  final GlobalKey _studentListKey = GlobalKey();
  final GlobalKey _exportBtnKey = GlobalKey();
  final GlobalKey _publishBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _languageProvider = ref.read(languageRiverpod);
    loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty && _classes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: AppSpacing.lg),
              Text('Error: $_errorMessage'),
              TextButton(
                onPressed: loadInitialData,
                child: Text(AppLocalizations.tryAgain.tr),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AdminReportCardBody(
              classes: _classes,
              selectedClass: _selectedClass,
              students: _students,
              isLoadingStudents: _isLoadingStudents,
              primaryColor: getPrimaryColor(),
              selectClassKey: _selectClassKey,
              studentListKey: _studentListKey,
              onClassChanged: (value) {
                setState(() {
                  _selectedClass = value;
                  _students = [];
                });
                loadStudents();
              },
              onViewDetail: viewReportCardDetail,
              onDownloadPdf: downloadStudentPdf,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manajemen Raport',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Unduh dan publikasikan raport kelas',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                forceRefresh();
              }
            },
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                    const SizedBox(width: AppSpacing.sm),
                    Text(AppLocalizations.updateData.tr),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_selectedClass == null || _isLoadingStudents || _students.isEmpty) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: _exportBtnKey,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, color: Colors.white, size: 18),
                label: const Text(
                  'Export Excel',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isExporting ? null : exportToExcel,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                key: _publishBtnKey,
                icon: _isPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                label: const Text(
                  'Kirim ke Wali',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.corporateBlue600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isPublishing ? null : publishReportCards,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mixin property accessors
  @override
  List<dynamic> get classes => _classes;
  @override
  set classes(List<dynamic> value) => _classes = value;

  @override
  Map<String, dynamic>? get selectedClass => _selectedClass;
  @override
  set selectedClass(Map<String, dynamic>? value) => _selectedClass = value;

  @override
  List<dynamic> get students => _students;
  @override
  set students(List<dynamic> value) => _students = value;

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  bool get isLoadingStudents => _isLoadingStudents;
  @override
  set isLoadingStudents(bool value) => _isLoadingStudents = value;

  @override
  String get errorMessage => _errorMessage;
  @override
  set errorMessage(String value) => _errorMessage = value;

  @override
  bool get isExporting => _isExporting;
  @override
  set isExporting(bool value) => _isExporting = value;

  @override
  bool get isPublishing => _isPublishing;
  @override
  set isPublishing(bool value) => _isPublishing = value;

  @override
  LanguageProvider get languageProvider => _languageProvider;

  @override
  GlobalKey get selectClassKey => _selectClassKey;

  @override
  GlobalKey get studentListKey => _studentListKey;

  @override
  GlobalKey get exportBtnKey => _exportBtnKey;

  @override
  GlobalKey get publishBtnKey => _publishBtnKey;
}
