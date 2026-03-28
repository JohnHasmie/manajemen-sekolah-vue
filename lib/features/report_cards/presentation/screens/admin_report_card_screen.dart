// Admin report card (raport) management screen.
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/admin/report-cards.vue` - allows admins to select a class,
// view student report cards, export to Excel, and publish/unpublish raports.
//
// In Laravel terms, this consumes RaportController with class-based filtering.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_detail_screen.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Admin report card screen - select class, view students, export/publish raports.
///
/// This is a [StatefulWidget] - like a Vue page with local state for class selection
/// and student list display. Uses cache-first loading pattern.
class AdminRaportScreen extends ConsumerStatefulWidget {
  const AdminRaportScreen({super.key});

  @override
  ConsumerState createState() => _AdminRaportScreenState();
}

/// Mutable state for [AdminRaportScreen].
///
/// Key state (like Vue `data()`):
/// - [_classes] - list of classes to choose from
/// - [_selectedClass] - currently selected class for viewing students
/// - [_students] - students in the selected class with raport status
/// - [_isExporting] / [_isPublishing] - loading states for bulk actions
class _AdminRaportScreenState extends ConsumerState<AdminRaportScreen> {
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

  /// Like Vue's `mounted()` - initializes language provider and loads class list.
  @override
  void initState() {
    super.initState();
    _languageProvider = ref.read(languageRiverpod);
    _loadInitialData();
  }

  String? _buildClassesCacheKey() {
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'raport_classes_$yearId';
  }

  String? _buildStudentsCacheKey() {
    if (_selectedClass == null) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'raport_students_${_selectedClass!['id']}_$yearId';
  }

  Future<void> _forceRefresh() async {
    final classesKey = _buildClassesCacheKey();
    if (classesKey != null) await LocalCacheService.invalidate(classesKey);
    await LocalCacheService.clearStartingWith('tour_raport_screen_');
    if (_selectedClass != null) {
      final studentsKey = _buildStudentsCacheKey();
      if (studentsKey != null) await LocalCacheService.invalidate(studentsKey);
      _loadStudents(useCache: false);
    } else {
      _loadInitialData(useCache: false);
    }
  }

  /// Loads the class list with cache-first pattern.
  /// Like calling `GET /api/classes` in Vue's `mounted()` with localStorage fallback.
  Future<void> _loadInitialData({bool useCache = true}) async {
    // Step 1: Try cache for instant display
    if (useCache) {
      final cacheKey = _buildClassesCacheKey();
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached['data'] != null && mounted) {
          final cachedList = cached['data'] as List<dynamic>;
          if (cachedList.isNotEmpty) {
            setState(() {
              _classes = cachedList;
              _isLoading = false;
            });
            AppLogger.info('report_card', 'Classes loaded from cache');
            return;
          }
        }
      }
    }

    // Show loading only if classes empty
    if (_classes.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    // Step 2: Fetch fresh from API
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final classesResponse = await getIt<ApiClassService>().getClassPaginated(
        limit: 100,
        academicYearId: academicYearId,
      );

      if (mounted) {
        setState(() {
          _classes = classesResponse['data'] ?? [];
          _isLoading = false;
        });

        // Step 3: Save to cache (non-blocking)
        final cacheKey = _buildClassesCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'data': classesResponse['data'] ?? [],
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (_classes.isEmpty) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _loadStudents({bool useCache = true}) async {
    if (_selectedClass == null) return;

    _errorMessage = '';

    // Step 1: Try cache for instant display
    if (useCache) {
      final cacheKey = _buildStudentsCacheKey();
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached['data'] != null && mounted) {
          final cachedList = cached['data'] as List<dynamic>;
          if (cachedList.isNotEmpty) {
            setState(() {
              _students = cachedList;
              _isLoadingStudents = false;
            });
            AppLogger.info('report_card', 'Students loaded from cache');
            // Trigger tour from cache path
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _students.isNotEmpty) _checkAndShowTour();
            });
            return;
          }
        }
      }
    }

    // Show loading only if students empty
    if (_students.isEmpty && mounted) {
      setState(() {
        _isLoadingStudents = true;
      });
    }

    // Step 2: Fetch fresh from API
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      if (academicYearId == null) throw Exception("Tahun ajaran tidak valid.");

      final studentsData = await getIt<ApiRaportService>().getRaports(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
      );

      if (mounted) {
        setState(() {
          _students = studentsData;
          _isLoadingStudents = false;
        });

        // Step 3: Save to cache (non-blocking)
        final cacheKey = _buildStudentsCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {'data': studentsData});
        }

        // Show tour after students are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _students.isNotEmpty) _checkAndShowTour();
        });
      }
    } catch (e) {
      if (mounted) {
        if (_students.isEmpty) {
          setState(() {
            _errorMessage = e.toString();
            _isLoadingStudents = false;
          });
        } else {
          setState(() => _isLoadingStudents = false);
        }
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_selectedClass == null) return;

    setState(() => _isExporting = true);
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      if (academicYearId == null) throw Exception("Tahun ajaran tidak valid.");

      await ExcelRaportService.exportReportCardToExcel(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        className: _selectedClass!['name'] ?? 'Kelas',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _publishReportCards() async {
    if (_selectedClass == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.sendReportCard.tr),
        content: Text(AppLocalizations.sendReportCardConfirm.tr),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(AppLocalizations.cancel.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.corporateBlue600,
            ),
            onPressed: () => AppNavigator.pop(context, true),
            child: Text(
              AppLocalizations.yesSend.tr,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPublishing = true);
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      await dioClient.post(
        '/raports/publish',
        data: {
          'class_id': _selectedClass!['id'],
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        },
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Raport berhasil dipublikasi dan dikirim ke wali murid!',
        );
        _loadStudents(useCache: false); // Reload status
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  Future<void> _viewReportCardDetail(Map<String, dynamic> student) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      Map<String, dynamic>? detail = await getIt<ApiRaportService>()
          .getRaportDetail(
            studentClassId: student['student_class_id'].toString(),
            academicYearId: academicYearId,
            semesterId: semesterId,
          );

      if (detail == null) {
        final initialData = await getIt<ApiRaportService>().getInitialData(
          studentClassId: student['student_class_id'].toString(),
          academicYearId: academicYearId,
          semesterId: semesterId,
        );

        if (initialData != null) {
          final att = initialData['attendance'] ?? {};

          detail = {
            'student_class_id': student['student_class_id'],
            'academic_year_id': academicYearId,
            'semester_id': semesterId,
            'status': 'draft',

            // Populate defaults from initial data
            'sick': att['sick'] ?? 0,
            'permit': att['permit'] ?? 0,
            'absent': att['absent'] ?? 0,

            // Empty defaults for editable fields
            'spiritual_predicate': null,
            'spiritual_description': null,
            'social_predicate': null,
            'social_description': null,
            'notes': null,
            'promotion_decision': null,

            // Map initial subjects
            'raport_subjects':
                (initialData['grades'] as List?)?.map((g) {
                  return {
                    'subject_id': g['subject_id'],
                    'knowledge_score': g['knowledge_score']?.toString(),
                    'knowledge_predicate': g['knowledge_predicate'],
                    'knowledge_description': g['knowledge_description'],
                    'skill_score': null,
                    'skill_predicate': null,
                    'skill_description': null,
                    'subject': {
                      'id': g['subject_id'],
                      'name': g['subject_name'],
                    },
                  };
                }).toList() ??
                [],

            'extracurriculars': [],
            'achievements': [],
          };
        }
      }

      if (!mounted) return;
      AppNavigator.pop(context); // Close loading dialog

      if (detail != null) {
        AppNavigator.push(
          context,
          ParentRaportDetailScreen(
            reportCardData: detail,
            studentName: student['student_name'] ?? 'Unknown',
            userRole: 'admin',
            studentData: {
              'nis': student['student_number'] ?? '-',
              'nisn':
                  '-', // Admin API list doesnt fetch NISN by default, fallback
            },
          ),
        );
      } else {
        throw Exception("Data raport tidak ditemukan.");
      }
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context); // Close loading dialog
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _downloadStudentPdf(Map<String, dynamic> student) async {
    final status = student['raport_status'] ?? 'draft';
    if (status == 'draft') {
      SnackBarUtils.showInfo(context, 'Raport Draft belum bisa dicetak.');
      return;
    }

    SnackBarUtils.showInfo(
      context,
      'Menyiapkan PDF untuk ${student['student_name']}...',
    );

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      await ExcelRaportService.exportSingleRaportPdf(
        studentClassId: student['student_class_id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        studentName: student['student_name'] ?? 'Unknown',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
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
                onPressed: _loadInitialData,
                child: const Text('Coba Lagi'),
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
          // Header with Gradient
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
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
                      borderRadius: BorderRadius.circular(10),
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
                      _forceRefresh();
                    }
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 20,
                            color: ColorUtils.info600,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Perbarui Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar:
          _selectedClass != null && !_isLoadingStudents && _students.isNotEmpty
          ? Container(
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
                            : const Icon(
                                Icons.download,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: const Text(
                          'Export Excel',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isExporting ? null : _exportToExcel,
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
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: const Text(
                          'Kirim ke Wali',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.corporateBlue600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isPublishing ? null : _publishReportCards,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Class Selection
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Kelas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: _selectClassKey,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _selectedClass,
                    hint: const Text('Pilih Kelas'),
                    items: _classes.map((cls) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: cls,
                        child: Text(cls['name']?.toString() ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClass = value;
                        _students = [];
                      });
                      _loadStudents();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Students List
        Expanded(
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : _selectedClass == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Silakan pilih kelas terlebih dahulu',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : _students.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada data siswa',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  key: _studentListKey,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final status = student['raport_status'] ?? 'draft';

                    Color statusColor;
                    String statusText;
                    IconData statusIcon;

                    if (status == 'published') {
                      statusColor = Colors.green;
                      statusText = 'Terkirim';
                      statusIcon = Icons.check_circle;
                    } else if (status == 'final') {
                      statusColor = Colors.blue;
                      statusText = 'Final';
                      statusIcon = Icons.save;
                    } else {
                      statusColor = Colors.orange;
                      statusText = 'Draft';
                      statusIcon = Icons.edit_note;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _viewReportCardDetail(student),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  (student['student_name'] ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getPrimaryColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['student_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'NIS: ${student['student_number'] ?? '-'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                                onPressed: () => _downloadStudentPdf(student),
                                tooltip: 'Cetak PDF',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(AppSpacing.xs),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('raport_screen', 'admin');
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('report_card', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: _languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_raport_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_screen', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_raport_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_screen', 'admin'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "RaportClassSelector",
        keyTarget: _selectClassKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _languageProvider.getTranslatedText({
                      'en': 'Select Class',
                      'id': 'Pilih Kelas',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _languageProvider.getTranslatedText({
                        'en':
                            'Choose a class to view and manage students\' records here.',
                        'id':
                            'Pilih kelas untuk melihat dan mengelola raport siswa.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "RaportStudentList",
        keyTarget: _studentListKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _languageProvider.getTranslatedText({
                      'en': 'Student List',
                      'id': 'Daftar Siswa',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _languageProvider.getTranslatedText({
                        'en':
                            'Tap on a student to see or edit their individual raport details.',
                        'id':
                            'Ketuk pada siswa untuk melihat atau mengedit detail raport mereka secara individu.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "RaportExportBtn",
        keyTarget: _exportBtnKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _languageProvider.getTranslatedText({
                      'en': 'Export to Excel',
                      'id': 'Ekspor ke Excel',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _languageProvider.getTranslatedText({
                        'en':
                            'Download the whole class raport data in an Excel format.',
                        'id':
                            'Unduh seluruh data raport kelas dalam format Excel.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "RaportPublishBtn",
        keyTarget: _publishBtnKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _languageProvider.getTranslatedText({
                      'en': 'Publish Raport',
                      'id': 'Publikasikan Raport',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _languageProvider.getTranslatedText({
                        'en':
                            'Publish the raport and send a notification directly to the parents/guardians.',
                        'id':
                            'Publikasikan raport dan kirim notifikasi langsung kepada wali murid.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}
