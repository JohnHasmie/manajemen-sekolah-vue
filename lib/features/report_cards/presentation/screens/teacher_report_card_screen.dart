// Report card (raport) main screen for teachers.
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
// Like `pages/teacher/Raport/Index.vue` in a Vue app.
//
// Allows homeroom teachers to select a class, view students, and navigate
// to individual student report card details. Supports Excel export of all
// student reports. In Laravel terms: `RaportController@index`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_class_selector.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_student_list.dart';

/// Report card list screen -- shows classes and their students for raport entry.
///
/// Props (like Vue props): [teacher] -- current teacher info.
/// Navigates to [ReportCardDetailScreen] when a student is tapped.
class ReportCardScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;

  const ReportCardScreen({super.key, required this.teacher});

  @override
  ReportCardScreenState createState() => ReportCardScreenState();
}

/// State for [ReportCardScreen].
///
/// Like a Vue component with `data() { return { classes, students, selectedClass, ... } }`.
/// Manages class selection, student list loading, and Excel export state.
class ReportCardScreenState extends ConsumerState<ReportCardScreen> {
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

  /// Like Vue's `mounted()` -- loads classes on screen init.
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String? _getAcademicYearId() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  String _buildClassesCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'raport_classes_${widget.teacher['id']}_$academicYearId';
  }

  String _buildStudentsCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    final classId = _selectedClass?['id']?.toString() ?? '';
    return 'raport_students_${classId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('raport_');
    await LocalCacheService.clearStartingWith('tour_raport_');
    _loadInitialData(useCache: false);
  }

  /// Loads homeroom classes using a 3-tier cache strategy:
  /// 1. TeacherProvider (in-memory, fastest)
  /// 2. LocalCacheService (disk cache with TTL)
  /// 3. API call (network, slowest)
  /// Like a Vue Vuex getter with localStorage fallback to axios.
  Future<void> _loadInitialData({bool useCache = true}) async {
    final classesCacheKey = _buildClassesCacheKey();

    // Step 1: Try TeacherProvider (populated by dashboard)
    if (useCache) {
      try {
        final teacherProvider = ref.read(teacherRiverpod);
        if (teacherProvider.isLoaded &&
            teacherProvider.homeroomClasses.isNotEmpty) {
          final providerClasses = List<dynamic>.from(
            teacherProvider.homeroomClasses,
          );
          if (mounted) {
            setState(() {
              _classes = providerClasses;
              _selectedClass = _classes.first;
              _isLoading = false;
              _errorMessage = '';
            });
            _loadStudentsForClass();
            _checkAndShowTour();
          }
          AppLogger.debug(
            'report_card',
            'ReportCardScreen: Classes from TeacherProvider (${providerClasses.length})',
          );
          return;
        }
      } catch (_) {}
    }

    // Step 2: Try local cache → return early
    if (useCache) {
      final cached = await LocalCacheService.load(classesCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _classes = List<dynamic>.from(cached);
            _selectedClass = _classes.first;
            _isLoading = false;
            _errorMessage = '';
          });
          _loadStudentsForClass();
          _checkAndShowTour();
        }
        AppLogger.debug(
          'report_card',
          'ReportCardScreen: Classes from cache (${cached.length})',
        );
        return;
      }
    }

    // Step 3: Show loading & fetch from API
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final academicYearId = _getAcademicYearId();

      final classesResponse = await getIt<ApiClassService>().getClassPaginated(
        homeroomTeacherId: widget.teacher['id'],
        academicYearId: academicYearId,
        limit: 100,
      );

      final uniqueClassesMap = <String, dynamic>{};
      if (classesResponse['data'] != null) {
        for (var classData in classesResponse['data']) {
          if (classData != null && classData['id'] != null) {
            uniqueClassesMap[classData['id'].toString()] = classData;
          }
        }
      }

      final freshClasses = uniqueClassesMap.values.toList();

      if (mounted) {
        setState(() {
          _classes = freshClasses;
          if (_classes.isNotEmpty) {
            _selectedClass = _classes.first;
            _loadStudentsForClass();
          }
          _isLoading = false;
        });
      }

      // Save to cache
      await LocalCacheService.save(classesCacheKey, freshClasses);
    } catch (e) {
      if (mounted && _classes.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  Future<void> _loadStudentsForClass({bool useCache = true}) async {
    if (_selectedClass == null) return;

    final studentsCacheKey = _buildStudentsCacheKey();

    // Step 1: Try cache → return early
    if (useCache) {
      final cached = await LocalCacheService.load(studentsCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _students = List<dynamic>.from(cached);
            _isLoadingStudents = false;
            _isLoading = false;
          });
        }
        AppLogger.debug(
          'report_card',
          'ReportCardScreen: Students from cache (${cached.length})',
        );
        return;
      }
    }

    // Step 2: Show loading & fetch from API
    if (mounted) {
      setState(() {
        _isLoadingStudents = true;
      });
    }

    try {
      final academicYearId = _getAcademicYearId();
      if (academicYearId == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "Tahun ajaran tidak valid.";
            _isLoadingStudents = false;
            _isLoading = false;
          });
        }
        return;
      }

      // Use shared school_day_data cache for semester (24h TTL)
      String semester = '1';
      final cachedDayData = await LocalCacheService.load(
        'school_day_data',
        ttl: const Duration(hours: 24),
      );
      if (cachedDayData != null && cachedDayData is Map) {
        if (cachedDayData.containsKey('semester') &&
            cachedDayData['semester'].toString().toLowerCase() == 'genap') {
          semester = '2';
        }
        AppLogger.debug(
          'report_card',
          'ReportCardScreen: Semester from school_day_data cache',
        );
      } else {
        final dateBasedSemester = await getIt<ApiScheduleService>()
            .getDateBasedSemester();
        if (dateBasedSemester.containsKey('semester') &&
            dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
          semester = '2';
        }
        // Save to shared cache for cross-screen reuse
        if (dateBasedSemester.isNotEmpty) {
          await LocalCacheService.save('school_day_data', dateBasedSemester);
        }
      }

      final response = await getIt<ApiReportCardService>().getRaports(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semester,
      );

      if (mounted) {
        setState(() {
          _students = response;
          _isLoadingStudents = false;
          _isLoading = false;
        });
      }

      // Save to cache
      await LocalCacheService.save(studentsCacheKey, response);
    } catch (e) {
      if (mounted && _students.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingStudents = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Resolve semester using shared cache, falling back to API
  Future<String> _resolveSemester() async {
    final cachedDayData = await LocalCacheService.load(
      'school_day_data',
      ttl: const Duration(hours: 24),
    );
    if (cachedDayData != null && cachedDayData is Map) {
      if (cachedDayData.containsKey('semester') &&
          cachedDayData['semester'].toString().toLowerCase() == 'genap') {
        return '2';
      }
      return '1';
    }
    final dateBasedSemester = await getIt<ApiScheduleService>()
        .getDateBasedSemester();
    if (dateBasedSemester.isNotEmpty) {
      await LocalCacheService.save('school_day_data', dateBasedSemester);
    }
    if (dateBasedSemester.containsKey('semester') &&
        dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
      return '2';
    }
    return '1';
  }

  Future<void> _exportToExcel() async {
    if (_selectedClass == null) return;

    setState(() => _isExporting = true);
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      if (academicYearId == null) {
        throw Exception("Tahun ajaran tidak valid.");
      }

      final semesterId = await _resolveSemester();

      await ExcelReportCardService.exportReportCardToExcel(
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
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  Future<void> _downloadStudentPdf(Map<String, dynamic> student) async {
    final status = student['raport_status'] ?? 'Belum ada';
    if (status.toLowerCase() != 'final' &&
        status.toLowerCase() != 'published') {
      SnackBarUtils.showInfo(
        context,
        'Raport belum final, tidak dapat dicetak.',
      );
      return;
    }

    SnackBarUtils.showInfo(
      context,
      'Menyiapkan file PDF untuk ${student['student_name']}...',
    );

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final semesterId = await _resolveSemester();

      await ExcelReportCardService.exportSingleRaportPdf(
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
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
                      Text(
                        _languageProvider.getTranslatedText({
                          'en': 'Report Cards',
                          'id': 'Raport Siswa',
                        }),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _languageProvider.getTranslatedText({
                          'en': 'Manage student report cards',
                          'id': 'Kelola nilai raport siswa',
                        }),
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
                    if (value == 'refresh') _forceRefresh();
                    if (value == 'export_excel' && !_isExporting)
                      _exportToExcel();
                  },
                  icon: Container(
                    key: _exportKey,
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
                  itemBuilder: (BuildContext context) => [
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
                          Text(AppLocalizations.updateData.tr),
                        ],
                      ),
                    ),
                    if (_selectedClass != null && !_isLoading)
                      PopupMenuItem<String>(
                        value: 'export_excel',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.file_download,
                              size: 20,
                              color: Colors.green,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Text('Export Excel'),
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
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonListLoading();
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Terjadi kesalahan:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.tryAgain.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildClassSelector(),
        Expanded(
          child: _isLoadingStudents
              ? const SkeletonListLoading()
              : _buildStudentList(),
        ),
      ],
    );
  }

  Widget _buildClassSelector() {
    return ReportCardClassSelector(
      selectorKey: _classSelectorKey,
      classes: _classes,
      selectedClass: _selectedClass,
      languageProvider: _languageProvider,
      onClassChanged: (newValue) {
        setState(() {
          _selectedClass = newValue;
          _students = [];
        });
        _loadStudentsForClass();
      },
    );
  }

  Widget _buildStudentList() {
    return ReportCardStudentList(
      students: _students,
      selectedClass: _selectedClass,
      onDownloadPdf: _downloadStudentPdf,
      onReturnFromDetail: _loadStudentsForClass,
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('raport_screen', 'guru');
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
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'raport_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'raport_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_screen', 'guru'),
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
        identify: "ClassSelector",
        keyTarget: _classSelectorKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Pilih Kelas Evaluasi",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Karena Anda bertugas sebagai wali kelas, gunakan area ini untuk memilih salah satu dari kelas perwalian Anda untuk mengevaluasi data raport siswa-siswinya.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (_selectedClass != null && !_isLoading) {
      targets.add(
        TargetFocus(
          identify: "ExportRaport",
          keyTarget: _exportKey,
          alignSkip: Alignment.bottomLeft,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Unduh Seluruh Raport",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Dapatkan rekapan gabungan keseluruhan nilai raport untuk seisi kelas di dalam dokumen Excel (.xlsx).",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }
}
