import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_recommendation_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
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

  // Subjects per class (from teaching schedule)
  List<dynamic> _teacherSchedules = [];
  bool _schedulesLoaded = false;

  // Generate state
  final Map<String, bool> _generating = {};

  @override
  void initState() {
    super.initState();
    _loadAllSummaries();
    _loadTeacherSchedules();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _loadAllSummaries() async {
    for (final cls in widget.classes) {
      final classId = cls['id']?.toString();
      if (classId == null) continue;
      _loadClassSummary(classId);
    }
  }

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

  Future<void> _loadTeacherSchedules() async {
    try {
      final teacherId = widget.teacher['id'] ?? '';
      if (teacherId.isEmpty) return;

      final schedules = await ApiScheduleService.getScheduleByTeacher(
        teacherId: teacherId,
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

  /// Get unique subjects for a specific class from the teacher's schedule
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

  /// Show subject picker and generate recommendations for a class
  Future<void> _generateForClass(String classId, String className) async {
    final subjects = _getSubjectsForClass(classId);

    if (subjects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada mata pelajaran ditemukan untuk kelas ini'),
          ),
        );
      }
      return;
    }

    // If only one subject, use it directly; otherwise show picker
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

    setState(() => _generating[classId] = true);

    try {
      final teacherId = widget.teacher['id'] ?? '';
      final result = await ApiRecommendationService.generateForClass(
        teacherId: teacherId,
        classId: classId,
        subjectId: selectedSubject['id']!,
      );

      if (result['async'] == true) {
        // Async mode - poll for completion
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
                if (kDebugMode) print('Job $jobId: $status (attempt $attempt)');
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
        // Sync mode - data returned directly
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rekomendasi berhasil dibuat!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Refresh summary
      _loadClassSummary(classId);
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

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

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
                await _loadAllSummaries();
                await _loadTeacherSchedules();
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
  }) {
    // API returns by_status as Map: {"pending": 20, "in_progress": 5, ...}
    final byStatus = _toCountMap(summary?['by_status']);
    final byPriority = _toCountMap(summary?['by_priority']);

    // Compute total from by_status values
    final totalRec = byStatus.values.fold<int>(0, (sum, v) => sum + v);

    final pending = byStatus['pending'] ?? 0;
    final inProgress = byStatus['in_progress'] ?? 0;
    final completed = byStatus['completed'] ?? 0;
    final highPriority = byPriority['high'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearningRecommendationStudentScreen(
                teacher: widget.teacher,
                classData: classData,
              ),
            ),
          ).then((_) {
            _loadClassSummary(classId);
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200, width: 1),
            boxShadow: [
              BoxShadow(
                color: _getPrimaryColor().withValues(alpha: 0.08),
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
              Row(
                children: [
                  // Class icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _getPrimaryColor().withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.class_outlined,
                      size: 24,
                      color: _getPrimaryColor(),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Class info
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
                        const SizedBox(height: 6),
                        if (isLoading)
                          Text(
                            'Memuat...',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate400,
                            ),
                          )
                        else if (totalRec > 0)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildMiniTag(
                                '$totalRec rekomendasi',
                                ColorUtils.info600,
                              ),
                              if (highPriority > 0)
                                _buildMiniTag(
                                  '$highPriority prioritas tinggi',
                                  ColorUtils.error600,
                                ),
                              if (pending > 0)
                                _buildMiniTag(
                                  '$pending pending',
                                  ColorUtils.warning600,
                                ),
                              if (inProgress > 0)
                                _buildMiniTag(
                                  '$inProgress proses',
                                  ColorUtils.corporateBlue600,
                                ),
                              if (completed > 0)
                                _buildMiniTag(
                                  '$completed selesai',
                                  ColorUtils.success600,
                                ),
                            ],
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

                  Icon(
                    Icons.chevron_right_rounded,
                    color: ColorUtils.slate400,
                    size: 24,
                  ),
                ],
              ),

              // Generate button
              if (_schedulesLoaded && !isLoading) ...[
                const SizedBox(height: 12),
                SizedBox(
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
                              color: _getPrimaryColor(),
                            ),
                          )
                        : Icon(Icons.auto_awesome, size: 16, color: _getPrimaryColor()),
                    label: Text(
                      isGenerating
                          ? 'Memproses...'
                          : totalRec > 0
                              ? 'Generate Ulang'
                              : 'Generate Rekomendasi AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isGenerating
                            ? ColorUtils.slate400
                            : _getPrimaryColor(),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isGenerating
                            ? ColorUtils.slate300
                            : _getPrimaryColor().withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Convert API response (List or Map) to a {key: count} map.
  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map((k, v) =>
          MapEntry(k.toString(), v is int ? v : int.tryParse(v.toString()) ?? 0));
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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
