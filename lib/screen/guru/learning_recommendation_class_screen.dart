import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/services/api_recommendation_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'learning_recommendation_student_screen.dart';

class LearningRecommendationClassScreen extends StatefulWidget {
  final Map<String, String> teacher;
  final List<dynamic> classes;

  const LearningRecommendationClassScreen({
    super.key,
    required this.teacher,
    required this.classes,
  });

  @override
  State<LearningRecommendationClassScreen> createState() =>
      _LearningRecommendationClassScreenState();
}

class _LearningRecommendationClassScreenState
    extends State<LearningRecommendationClassScreen> {
  final GlobalKey _classListKey = GlobalKey();
  String? _tourId;

  // Summary data per class ID
  final Map<String, Map<String, dynamic>> _classSummaries = {};
  final Map<String, bool> _loadingSummaries = {};

  // Recommendation history per class (grouped by date)
  final Map<String, List<Map<String, dynamic>>> _classHistory = {};
  final Map<String, bool> _loadingHistory = {};

  // Subjects per class (from teaching schedule)
  List<dynamic> _teacherSchedules = [];
  bool _schedulesLoaded = false;

  // Teacher profile ID (resolved from user_id)
  String? _teacherProfileId;

  // Generate state
  final Map<String, bool> _generating = {};

  // Expanded class cards
  final Map<String, bool> _expandedClass = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _loadAllData() async {
    // Resolve teacher profile ID (user_id → teacher_id)
    await _resolveTeacherProfileId();
    _loadTeacherSchedules();
    for (final cls in widget.classes) {
      final classId = cls['id']?.toString();
      if (classId == null) continue;
      _loadClassSummary(classId);
      _loadClassHistory(classId);
    }
  }

  Future<void> _resolveTeacherProfileId() async {
    try {
      final userId = widget.teacher['id'] ?? '';
      if (kDebugMode) {
        print('👤 Resolving teacher profile for user: $userId');
        print('👤 widget.teacher keys: ${widget.teacher.keys.toList()}');
        print('👤 widget.teacher: ${widget.teacher}');
      }
      if (userId.isEmpty) return;

      final apiTeacherService = ApiTeacherService();
      final profileData = await apiTeacherService.getTeacherById(userId);
      if (kDebugMode) {
        print('👤 getTeacherById response: ${profileData?.toString().substring(0, (profileData.toString().length > 300) ? 300 : profileData.toString().length)}');
      }
      if (profileData != null) {
        _teacherProfileId = profileData['id']?.toString();
        if (kDebugMode) {
          print(
              '👤 Teacher Profile ID resolved: $_teacherProfileId (user: $userId)');
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not resolve teacher profile ID: $e');
    }
  }

  /// Get the effective teacher ID for API calls
  String get _effectiveTeacherId =>
      _teacherProfileId ?? widget.teacher['id'] ?? '';

  Future<void> _loadClassSummary(String classId) async {
    if (!mounted) return;
    setState(() => _loadingSummaries[classId] = true);

    try {
      final summary = await ApiRecommendationService.getClassSummary(classId);
      if (mounted) {
        setState(() {
          _classSummaries[classId] = summary['data'] ?? {};
          _loadingSummaries[classId] = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading summary for $classId: $e');
      if (mounted) {
        setState(() => _loadingSummaries[classId] = false);
      }
    }
  }

  Future<void> _loadClassHistory(String classId) async {
    if (!mounted) return;
    setState(() => _loadingHistory[classId] = true);

    try {
      if (kDebugMode) {
        print('📋 Loading history for class $classId, teacher: $_effectiveTeacherId');
      }

      final result = await ApiRecommendationService.getRecommendations(
        teacherId: _effectiveTeacherId,
        classId: classId,
        perPage: 50,
      );

      if (kDebugMode) {
        final dataList = (result['data'] as List?) ?? [];
        print('📋 History result for $classId: ${dataList.length} recommendations, meta: ${result['meta']}');
        if (dataList.isNotEmpty) {
          print('📋 First rec: trigger_source=${dataList.first['trigger_source']}, created_at=${dataList.first['created_at']}, teacher_id=${dataList.first['teacher_id']}');
        }
      }

      if (!mounted) return;

      // Group by date + trigger_source so different periods on same day are separate
      final recommendations = (result['data'] as List?) ?? [];
      final grouped = <String, Map<String, dynamic>>{};

      for (final rec in recommendations) {
        final createdAt = rec['created_at']?.toString() ?? '';
        if (createdAt.isEmpty) continue;

        final dateKey = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : createdAt;
        final triggerSource = rec['trigger_source']?.toString() ?? 'on_demand';

        // Composite key: date + trigger_source
        final groupKey = '${dateKey}_$triggerSource';

        if (!grouped.containsKey(groupKey)) {
          grouped[groupKey] = {
            'date': dateKey,
            'trigger_source': triggerSource,
            'count': 0,
            'by_status': <String, int>{},
            'by_priority': <String, int>{},
            'by_category': <String, int>{},
          };
        }

        final group = grouped[groupKey]!;
        group['count'] = (group['count'] as int) + 1;

        final status = rec['status']?.toString() ?? 'pending';
        final statusMap = group['by_status'] as Map<String, int>;
        statusMap[status] = (statusMap[status] ?? 0) + 1;

        final priority = rec['priority']?.toString() ?? 'medium';
        final priorityMap = group['by_priority'] as Map<String, int>;
        priorityMap[priority] = (priorityMap[priority] ?? 0) + 1;

        final category = rec['category']?.toString() ?? '';
        if (category.isNotEmpty) {
          final catMap = group['by_category'] as Map<String, int>;
          catMap[category] = (catMap[category] ?? 0) + 1;
        }
      }

      // Sort by date descending, then by trigger_source
      final history = grouped.values.toList()
        ..sort((a, b) {
          final dateCompare =
              (b['date'] as String).compareTo(a['date'] as String);
          if (dateCompare != 0) return dateCompare;
          return (a['trigger_source'] as String)
              .compareTo(b['trigger_source'] as String);
        });

      setState(() {
        _classHistory[classId] = history;
        _loadingHistory[classId] = false;
      });
    } catch (e) {
      if (kDebugMode) print('Error loading history for $classId: $e');
      if (mounted) {
        setState(() {
          _classHistory[classId] = [];
          _loadingHistory[classId] = false;
        });
      }
    }
  }

  Future<void> _loadTeacherSchedules() async {
    try {
      final teacherIdForSchedule = widget.teacher['id'] ?? '';
      if (teacherIdForSchedule.isEmpty) return;

      final schedules = await ApiScheduleService.getScheduleByTeacher(
        teacherId: teacherIdForSchedule,
      );
      if (mounted) {
        setState(() {
          _teacherSchedules = schedules;
          _schedulesLoaded = true;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading schedules: $e');
      if (mounted) setState(() => _schedulesLoaded = true);
    }
  }

  List<Map<String, String>> _getSubjectsForClass(String classId) {
    final seen = <String>{};
    final subjects = <Map<String, String>>[];

    for (final schedule in _teacherSchedules) {
      final scheduleClassId = schedule['class_id']?.toString() ??
          schedule['class']?['id']?.toString();
      if (scheduleClassId != classId) continue;

      final subjectId = schedule['subject_id']?.toString() ??
          schedule['subject']?['id']?.toString();
      final subjectName = schedule['subject']?['name']?.toString() ??
          schedule['subject_name']?.toString() ??
          'Mata Pelajaran';

      if (subjectId != null && seen.add(subjectId)) {
        subjects.add({'id': subjectId, 'name': subjectName});
      }
    }

    return subjects;
  }

  // ==================== GENERATE FLOW ====================

  Future<void> _generateForClass(String classId, String className) async {
    // Step 1: Pick scope (all students or only those who need recommendations)
    final includeOnTrack = await _showScopePicker(className);
    if (includeOnTrack == null || !mounted) return;

    // Step 2: Pick subject
    final subjects = _getSubjectsForClass(classId);
    if (subjects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Tidak ada mata pelajaran ditemukan untuk kelas ini'),
          ),
        );
      }
      return;
    }

    Map<String, String>? selectedSubject;
    if (subjects.length == 1) {
      selectedSubject = subjects.first;
    } else {
      selectedSubject = await showModalBottomSheet<Map<String, String>>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _SubjectPickerSheet(
          subjects: subjects,
          className: className,
          primaryColor: _getPrimaryColor(),
        ),
      );
    }

    if (selectedSubject == null || !mounted) return;

    // Step 3: Generate
    setState(() => _generating[classId] = true);

    if (kDebugMode) {
      print('🚀 Generate Recommendation Params:');
      print('   teacherId: $_effectiveTeacherId');
      print('   classId: $classId');
      print('   subjectId: ${selectedSubject['id']}');
      print('   subjectName: ${selectedSubject['name']}');
      print('   includeOnTrack: $includeOnTrack');
      print('   className: $className');
    }

    try {
      final result = await ApiRecommendationService.generateForClass(
        teacherId: _effectiveTeacherId,
        classId: classId,
        subjectId: selectedSubject['id']!,
        includeOnTrack: includeOnTrack,
      );

      if (result['async'] == true) {
        final jobId = result['job_id']?.toString();
        if (jobId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Sedang memproses...'),
              duration: const Duration(seconds: 3),
            ),
          );

          try {
            await ApiRecommendationService.pollJobUntilComplete(
              jobId,
              onProgress: (status, attempt) {
                if (kDebugMode) {
                  print('Job $jobId: $status (attempt $attempt)');
                }
              },
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rekomendasi berhasil dibuat!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rekomendasi berhasil dibuat!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Refresh data
      _loadClassSummary(classId);
      _loadClassHistory(classId);
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating[classId] = false);
    }
  }

  Future<bool?> _showScopePicker(String className) async {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorUtils.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Cakupan Siswa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate rekomendasi AI untuk $className',
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate500,
              ),
            ),
            const SizedBox(height: 16),
            _buildScopeOption(
              ctx: ctx,
              value: true,
              icon: Icons.groups_rounded,
              title: 'Semua Siswa',
              subtitle:
                  'Generate rekomendasi untuk semua siswa termasuk yang sudah baik',
              color: const Color(0xFF3B82F6),
            ),
            _buildScopeOption(
              ctx: ctx,
              value: false,
              icon: Icons.person_search_rounded,
              title: 'Siswa yang Perlu Saja',
              subtitle:
                  'Hanya siswa yang membutuhkan rekomendasi berdasarkan data performa',
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeOption({
    required BuildContext ctx,
    required bool value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(ctx, value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: ColorUtils.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TOUR ====================

  Future<void> _checkAndShowTour() async {
    try {
      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'learning_recommendation_class_tour',
      );

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

    final languageProvider = context.read<LanguageProvider>();

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

    targets.add(
      TargetFocus(
        identify: "ClassList",
        keyTarget: _classListKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.all(16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Class List',
                        'id': 'Daftar Kelas',
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
                        languageProvider.getTranslatedText({
                          'en':
                              'Choose one of your classes to see student learning recommendations.',
                          'id':
                              'Pilih salah satu kelas Anda untuk melihat rekomendasi belajar siswa.',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  // ==================== HELPERS ====================

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getRelativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return 'Hari ini';
      if (diff == 1) return 'Kemarin';
      if (diff < 7) return '$diff hari lalu';
      return _formatDate(dateStr);
    } catch (_) {
      return dateStr;
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header
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
                      const Text(
                        'Rekomendasi Belajar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih kelas untuk melihat rekomendasi siswa',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadAllData();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.classes.length,
                itemBuilder: (context, index) {
                  final cls = widget.classes[index];
                  final classId = cls['id']?.toString() ?? '';
                  final className = cls['name'] ?? cls['nama'] ?? 'Kelas';
                  final summary = _classSummaries[classId];
                  final isLoading = _loadingSummaries[classId] == true;
                  final isGenerating = _generating[classId] == true;
                  final history = _classHistory[classId] ?? [];
                  final isLoadingHistory =
                      _loadingHistory[classId] == true;
                  final isExpanded = _expandedClass[classId] == true;

                  return Padding(
                    key: index == 0 ? _classListKey : null,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildClassCard(
                      className: className,
                      classId: classId,
                      classData: cls,
                      summary: summary,
                      isLoading: isLoading,
                      isGenerating: isGenerating,
                      history: history,
                      isLoadingHistory: isLoadingHistory,
                      isExpanded: isExpanded,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard({
    required String className,
    required String classId,
    required Map<String, dynamic> classData,
    Map<String, dynamic>? summary,
    bool isLoading = false,
    bool isGenerating = false,
    List<Map<String, dynamic>> history = const [],
    bool isLoadingHistory = false,
    bool isExpanded = false,
  }) {
    final byStatus = _toCountMap(summary?['by_status']);
    final totalRec = byStatus.values.fold<int>(0, (sum, v) => sum + v);
    final primaryColor = _getPrimaryColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row - tap to expand
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedClass[classId] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: isExpanded
                    ? Radius.zero
                    : const Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.class_outlined,
                        size: 24,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isLoading)
                            Text(
                              'Memuat...',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate400,
                              ),
                            )
                          else if (totalRec > 0)
                            Text(
                              '$totalRec rekomendasi  •  ${history.length} sesi',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate500,
                              ),
                            )
                          else
                            Text(
                              'Belum ada rekomendasi',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: ColorUtils.slate400,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Divider(height: 1, color: ColorUtils.slate200),

            // History list
            if (isLoadingHistory)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                ),
              )
            else if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 32, color: ColorUtils.slate300),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada riwayat rekomendasi',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tekan tombol Generate untuk membuat rekomendasi AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate400,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: history.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final entry = history[index];
                  return _buildHistoryItem(
                    entry: entry,
                    classData: classData,
                    classId: classId,
                  );
                },
              ),

            // Generate button
            if (_schedulesLoaded) ...[
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isGenerating
                        ? null
                        : () => _generateForClass(classId, className),
                    icon: isGenerating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : Icon(Icons.auto_awesome,
                            size: 16, color: primaryColor),
                    label: Text(
                      isGenerating
                          ? 'Memproses...'
                          : 'Generate Rekomendasi AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isGenerating
                            ? ColorUtils.slate400
                            : primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isGenerating
                            ? ColorUtils.slate300
                            : primaryColor.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required Map<String, dynamic> entry,
    required Map<String, dynamic> classData,
    required String classId,
  }) {
    final date = entry['date'] as String;
    final count = entry['count'] as int;
    final triggerSource = entry['trigger_source']?.toString() ?? 'on_demand';
    final byStatus = entry['by_status'] as Map<String, int>;
    final byPriority = entry['by_priority'] as Map<String, int>;
    final highCount = byPriority['high'] ?? 0;
    final pendingCount = byStatus['pending'] ?? 0;
    final completedCount = byStatus['completed'] ?? 0;

    final periodInfo = _getPeriodInfo(triggerSource);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Pass resolved teacher_id so student/result screens can query correctly
          final teacherWithProfileId = Map<String, String>.from(widget.teacher);
          if (_teacherProfileId != null) {
            teacherWithProfileId['teacher_id'] = _teacherProfileId!;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearningRecommendationStudentScreen(
                teacher: teacherWithProfileId,
                classData: classData,
              ),
            ),
          ).then((_) {
            _loadClassSummary(classId);
            _loadClassHistory(classId);
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              // Period icon with color
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: periodInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: periodInfo.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  periodInfo.icon,
                  size: 18,
                  color: periodInfo.color,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getRelativeDate(date),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ),
                        // Period badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: periodInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: periodInfo.color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            periodInfo.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: periodInfo.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildMiniTag(
                          '$count rekomendasi',
                          ColorUtils.slate600,
                        ),
                        if (highCount > 0)
                          _buildMiniTag(
                            '$highCount prioritas tinggi',
                            const Color(0xFFEF4444),
                          ),
                        if (pendingCount > 0)
                          _buildMiniTag(
                            '$pendingCount pending',
                            const Color(0xFFF59E0B),
                          ),
                        if (completedCount > 0)
                          _buildMiniTag(
                            '$completedCount selesai',
                            const Color(0xFF10B981),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Map trigger_source back to period display info
  ({Color color, String label, IconData icon}) _getPeriodInfo(
      String triggerSource) {
    switch (triggerSource) {
      case 'weekly_review':
        return (
          color: const Color(0xFF3B82F6),
          label: 'Pekanan',
          icon: Icons.date_range_rounded,
        );
      case 'post_exam':
        return (
          color: const Color(0xFF8B5CF6),
          label: 'Bulanan/UTS',
          icon: Icons.calendar_month_rounded,
        );
      case 'attendance_alert':
        return (
          color: const Color(0xFFEF4444),
          label: 'Kehadiran',
          icon: Icons.warning_amber_rounded,
        );
      case 'on_demand':
      default:
        return (
          color: const Color(0xFFF59E0B),
          label: 'Semester',
          icon: Icons.emoji_events_rounded,
        );
    }
  }

  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map((k, v) => MapEntry(
          k.toString(), v is int ? v : int.tryParse(v.toString()) ?? 0));
    }
    if (data is List) {
      final map = <String, int>{};
      for (final item in data) {
        if (item is Map) {
          final key = (item['status'] ??
                  item['priority'] ??
                  item['category'] ??
                  '')
              .toString();
          final count = item['count'] is int
              ? item['count']
              : int.tryParse(item['count'].toString()) ?? 0;
          if (key.isNotEmpty) map[key] = count;
        }
      }
      return map;
    }
    return {};
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a subject
class _SubjectPickerSheet extends StatelessWidget {
  final List<Map<String, String>> subjects;
  final String className;
  final Color primaryColor;

  const _SubjectPickerSheet({
    required this.subjects,
    required this.className,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pilih Mata Pelajaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate rekomendasi AI untuk $className',
            style: TextStyle(
              fontSize: 13,
              color: ColorUtils.slate500,
            ),
          ),
          const SizedBox(height: 16),
          ...subjects.map((subject) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, subject),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ColorUtils.slate200,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.menu_book_outlined,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subject['name'] ?? 'Mata Pelajaran',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
