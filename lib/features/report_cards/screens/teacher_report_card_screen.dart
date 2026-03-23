// Report card (raport) main screen for teachers.
// Like `pages/teacher/Raport/Index.vue` in a Vue app.
//
// Allows homeroom teachers to select a class, view students, and navigate
// to individual student report card details. Supports Excel export of all
// student reports. In Laravel terms: `RaportController@index`.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/screens/report_card_detail_screen.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/features/report_cards/services/report_card_service.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/core/providers/teacher_provider.dart';

/// Report card list screen -- shows classes and their students for raport entry.
///
/// Props (like Vue props): [teacher] -- current teacher info.
/// Navigates to [RaportDetailScreen] when a student is tapped.
class RaportScreen extends StatefulWidget {
  final Map<String, String> teacher;

  const RaportScreen({super.key, required this.teacher});

  @override
  RaportScreenState createState() => RaportScreenState();
}

/// State for [RaportScreen].
///
/// Like a Vue component with `data() { return { classes, students, selectedClass, ... } }`.
/// Manages class selection, student list loading, and Excel export state.
class RaportScreenState extends State<RaportScreen> {
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
  String? _tourId;

  /// Like Vue's `mounted()` -- loads classes on screen init.
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String? _getAcademicYearId() {
    final provider = Provider.of<AcademicYearProvider>(context, listen: false);
    return (provider.selectedAcademicYear?['id'] ?? provider.activeAcademicYear?['id'])?.toString();
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
        final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
        if (teacherProvider.isLoaded && teacherProvider.homeroomClasses.isNotEmpty) {
          final providerClasses = List<dynamic>.from(teacherProvider.homeroomClasses);
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
          if (kDebugMode) print('📦 RaportScreen: Classes from TeacherProvider (${providerClasses.length})');
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
        if (kDebugMode) print('📦 RaportScreen: Classes from cache (${cached.length})');
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

      final classesResponse = await ApiClassService.getClassPaginated(
        waliclassId: widget.teacher['id'],
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
      Future.delayed(const Duration(milliseconds: 1000), () {
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
        if (kDebugMode) print('📦 RaportScreen: Students from cache (${cached.length})');
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
      final cachedDayData = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
      if (cachedDayData != null && cachedDayData is Map) {
        if (cachedDayData.containsKey('semester') &&
            cachedDayData['semester'].toString().toLowerCase() == 'genap') {
          semester = '2';
        }
        if (kDebugMode) print('📦 RaportScreen: Semester from school_day_data cache');
      } else {
        final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
        if (dateBasedSemester.containsKey('semester') &&
            dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
          semester = '2';
        }
        // Save to shared cache for cross-screen reuse
        if (dateBasedSemester.isNotEmpty) {
          await LocalCacheService.save('school_day_data', dateBasedSemester);
        }
      }

      final response = await ApiRaportService.getRaports(
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
    final cachedDayData = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
    if (cachedDayData != null && cachedDayData is Map) {
      if (cachedDayData.containsKey('semester') &&
          cachedDayData['semester'].toString().toLowerCase() == 'genap') {
        return '2';
      }
      return '1';
    }
    final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
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
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      if (academicYearId == null) {
        throw Exception("Tahun ajaran tidak valid.");
      }

      final semesterId = await _resolveSemester();

      await ExcelRaportService.exportRaportToExcel(
        classId: _selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        className: _selectedClass!['name'] ?? 'Kelas',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Raport belum final, tidak dapat dicetak.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Menyiapkan file PDF untuk ${student['student_name']}...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final semesterId = await _resolveSemester();

      await ExcelRaportService.exportSingleRaportPdf(
        studentClassId: student['student_class_id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        studentName: student['student_name'] ?? 'Unknown',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
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
                  onTap: () => Navigator.pop(context),
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
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
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
                    if (value == 'export_excel' && !_isExporting) _exportToExcel();
                  },
                  icon: Container(
                    key: _exportKey,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                          const SizedBox(width: 8),
                          const Text('Perbarui Data'),
                        ],
                      ),
                    ),
                    if (_selectedClass != null && !_isLoading)
                      PopupMenuItem<String>(
                        value: 'export_excel',
                        child: Row(
                          children: [
                            const Icon(Icons.file_download, size: 20, color: Colors.green),
                            const SizedBox(width: 8),
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
              const SizedBox(height: 16),
              Text(
                'Terjadi kesalahan:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
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
    return Container(
      key: _classSelectorKey,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColorUtils.corporateShadow(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.class_outlined,
              color: ColorUtils.slate600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageProvider.getTranslatedText({
                    'en': 'Select Class',
                    'id': 'Pilih Kelas',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_classes.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: _selectedClass,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: ColorUtils.slate400,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate800,
                      ),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedClass = newValue;
                            _students = [];
                          });
                          _loadStudentsForClass();
                        }
                      },
                      items: _classes.map((cls) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: cls,
                          child: Text(cls['name'] ?? 'Unknown Class'),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Text(
                    _languageProvider.getTranslatedText({
                      'en': 'No classes available',
                      'id': 'Tidak ada kelas',
                    }),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate800,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data siswa',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final bool hasRaport = student['has_raport'] ?? false;
        final String status = student['raport_status'] ?? 'Belum ada';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ColorUtils.corporateShadow(),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RaportDetailScreen(
                      studentClassId: student['student_class_id'].toString(),
                      studentName: student['student_name'] ?? 'Siswa',
                      className: _selectedClass?['name'] ?? '',
                    ),
                  ),
                ).then((_) => _loadStudentsForClass());
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ColorUtils.slate50,
                      child: Text(
                        (student['student_name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['student_name'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: ColorUtils.slate800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NIS: ${student['student_number'] ?? '-'}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(hasRaport, status),
                    const SizedBox(width: 8),
                    if (status.toLowerCase() == 'final' ||
                        status.toLowerCase() == 'published')
                      IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                        tooltip: 'Cetak PDF',
                        onPressed: () => _downloadStudentPdf(student),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: ColorUtils.slate400),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool hasRaport, String status) {
    Color bgColor;
    Color textColor;
    String label;

    if (!hasRaport) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      label = 'Belum Isi';
    } else if (status.toLowerCase() == 'draft') {
      bgColor = Colors.orange.shade50;
      textColor = ColorUtils.warning600;
      label = 'Draft';
    } else {
      bgColor = Colors.green.shade50;
      textColor = ColorUtils.success600;
      label = 'Selesai';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Check cache first (24h TTL)
      const tourCacheKey = 'tour_raport_screen_guru';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (mounted) _showTour();
        }
        return;
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'raport_screen_tour',
      );

      // Cache the result
      await LocalCacheService.save(tourCacheKey, status);

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];

        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_raport_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_raport_screen_guru', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];

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
