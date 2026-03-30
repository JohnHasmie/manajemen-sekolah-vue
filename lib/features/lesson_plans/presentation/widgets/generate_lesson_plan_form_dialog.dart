// Dialog form for AI-generating a lesson plan (RPP).
// Extracted from teacher_lesson_plan_screen.dart to reduce file size.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:manajemensekolah/core/services/preferences_service.dart';

class GenerateLessonPlanFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;

  const GenerateLessonPlanFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
  });

  @override
  ConsumerState<GenerateLessonPlanFormDialog> createState() =>
      _GenerateLessonPlanFormDialogState();
}

class _GenerateLessonPlanFormDialogState
    extends ConsumerState<GenerateLessonPlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _academicYearController = TextEditingController();

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedChapterId;
  String? _selectedSubChapterId;
  String? _selectedSemester = 'Ganjil';
  bool _isAutoGenerating = false;
  String _generationStatus = '';

  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _chapterList = [];
  List<dynamic> _subChapterList = [];

  @override
  void initState() {
    super.initState();
    _loadSubjectsByTeacher();
    _academicYearController.text = DateTime.now().year.toString();
  }

  Future<void> _loadSubjectsByTeacher() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _subjectList = result['data'];
        } else if (result is List) {
          _subjectList = result;
        } else {
          _subjectList = [];
        }
      });
    } catch (e) {
      _loadAllSubjects();
    }
  }

  Future<void> _loadAllSubjects() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        if (result is Map && result['data'] is List) {
          _subjectList = result['data'];
        } else if (result is List) {
          _subjectList = result;
        } else {
          _subjectList = [];
        }
      });
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error loading all mata pelajaran: $e');
    }
  }

  Future<void> _loadClassesBySubject(String subjectId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _classList = result['data'];
        } else if (result is List) {
          _classList = result;
        } else {
          _classList = [];
        }
      });
    } catch (e) {
      setState(() {
        _classList = [];
      });
    }
  }

  Future<void> _loadChaptersBySubject(String subjectId) async {
    try {
      final result = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: subjectId,
      );
      setState(() {
        _chapterList = result;
      });
    } catch (e) {
      setState(() {
        _chapterList = [];
      });
    }
  }

  Future<void> _loadSubChaptersByChapter(String chapterId) async {
    try {
      final result = await getIt<ApiSubjectService>().getSubChapterMaterials(
        chapterId: chapterId,
      );
      setState(() {
        _subChapterList = result;
      });
    } catch (e) {
      setState(() {
        _subChapterList = [];
      });
    }
  }

  // Helper to strip HTML tags into plain text
  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (html.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  Future<void> _submitForm() async {
    AppLogger.debug('lesson_plan', '_submitForm called');
    if (!_formKey.currentState!.validate()) {
      AppLogger.error('lesson_plan', 'Validation failed');
      SnackBarUtils.showWarning(
        context,
        'Mohon lengkapi semua field yang wajib diisi',
      );
      return;
    }

    AppLogger.info('lesson_plan', 'Validation passed, starting API call');
    setState(() {
      _isAutoGenerating = true;
      _generationStatus = 'Sedang menghubungi AI KamillLabs...';
    });

    try {
      final prefs = PreferencesService();
      final token = prefs.getString('token');
      final userJson = prefs.getString('user');
      String? schoolId;

      if (userJson != null) {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString();
      }

      if (kDebugMode) {
        AppLogger.debug(
          'lesson_plan',
          'Current ApiService.baseUrl: ${ApiService.baseUrl}',
        );
        AppLogger.debug(
          'lesson_plan',
          'Using Token: ${token != null ? "Available" : "NULL"}',
        );
        if (token != null && token.length > 5) {
          AppLogger.debug(
            'lesson_plan',
            'Token Prefix: ${token.substring(0, 5)}...',
          );
        }
        AppLogger.debug(
          'lesson_plan',
          'Using School ID: ${schoolId ?? "NULL"} (Removed from AI request headers)',
        );
      }

      final requestBody = {
        'title': _titleController.text,
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'chapter_id': _selectedChapterId,
        'sub_chapter_id': _selectedSubChapterId,
        'semester': _selectedSemester,
        'academic_year': _academicYearController.text,
        'teacher_id': widget.teacherId,
      };

      AppLogger.debug(
        'lesson_plan',
        '🌐 Sending POST request to KamillLabs...',
      );
      AppLogger.debug('lesson_plan', 'Payload: ${json.encode(requestBody)}');

      // Panggilan API asli ke KamillLabs Edu AI via Dio
      final aiDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (_) => true, // Don't throw on non-2xx
        ),
      );

      final response = await aiDio.post(
        'https://edu-ai-api.kamillabs.com/api/lesson-plans/generate',
        data: requestBody,
      );

      AppLogger.debug(
        'lesson_plan',
        '📥 Response Status: ${response.statusCode}',
      );

      // Dio auto-decodes JSON, so response.data is already a Map
      final resultBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 202) {
        // Async Mode - navigate to result screen with polling
        AppLogger.debug('lesson_plan', 'Full 202 Response: ${response.data}');

        // Try multiple field names for poll_url and job_id
        final pollUrl =
            (resultBody['poll_url'] ??
                    resultBody['polling_url'] ??
                    resultBody['status_url'])
                as String?;
        final jobId =
            (resultBody['job_id'] ??
                    resultBody['jobId'] ??
                    resultBody['id'] ??
                    resultBody['data']?['id'] ??
                    resultBody['data']?['job_id'])
                as String?;

        AppLogger.debug(
          'lesson_plan',
          '⏳ Job Queued: $jobId | Polling at: $pollUrl',
        );

        // Build metadata for the result screen
        final pollingMetadata = await _buildPollingMetadata();

        if (!mounted) return;

        AppNavigator.pushReplacement(
          context,
          LessonPlanAiResultScreen(
            teacherId: widget.teacherId,
            onSaved: widget.onSaved,
            pollUrl: pollUrl,
            jobId: jobId,
            token: token,
            pollingMetadata: pollingMetadata,
          ),
        );
        return;
      }

      if (response.statusCode == 429) {
        AppLogger.warning('lesson_plan', 'Rate limit reached');
        final message =
            resultBody['message'] ??
            'Batas pembuatan RPP AI harian/bulanan telah tercapai.';
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: Icon(
                Icons.timer_off_rounded,
                color: ColorUtils.warning600,
                size: 48,
              ),
              title: Text(
                'Batas Tercapai',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.warning600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('Mengerti'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        AppLogger.error('lesson_plan', 'API Error Body: ${response.data}');
        final message = resultBody['message'] ?? 'Gagal generate RPP';
        throw Exception(message);
      }

      final lessonPlanResponse = resultBody['data'] ?? resultBody;

      await _processAndNavigate(lessonPlanResponse);
    } catch (e) {
      AppLogger.error('lesson_plan', '🚨 _submitForm error: $e');
      if (mounted) {
        SnackBarUtils.showInfo(context, '${AppLocalizations.error.tr}: $e');
      }
    } finally {
      AppLogger.debug(
        'lesson_plan',
        '🏁 _submitForm finished (isAutoGenerating: false)',
      );
      if (mounted) {
        setState(() {
          _isAutoGenerating = false;
          _generationStatus = '';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _buildPollingMetadata() async {
    final userData = await TokenService().getUserData();
    final schoolObj = userData?['school'] as Map<String, dynamic>?;
    final schoolNameStr = schoolObj != null
        ? (schoolObj['school_name'] ?? schoolObj['nama_sekolah'] ?? 'SD/MI')
        : (userData?['school_name'] ?? userData?['nama_sekolah'] ?? 'SD/MI');

    final selectedSubject = _subjectList.firstWhere(
      (m) => m['id'].toString() == _selectedSubjectId,
      orElse: () => {'name': 'Mata Pelajaran'},
    );
    final subjectName =
        selectedSubject['name'] ?? selectedSubject['nama'] ?? 'Mata Pelajaran';

    final selectedClass = _classList.firstWhere(
      (k) => k['id'].toString() == _selectedClassId,
      orElse: () => {'name': 'Kelas'},
    );
    final className = selectedClass['name'] ?? selectedClass['nama'] ?? 'Kelas';

    final chapterMap = _selectedChapterId != null
        ? _chapterList.firstWhere(
            (b) => b['id'].toString() == _selectedChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final chapterName = chapterMap.isNotEmpty
        ? (chapterMap['judul_bab'] ??
              chapterMap['title'] ??
              chapterMap['judul'] ??
              '')
        : '';

    final subChapterMap = _selectedSubChapterId != null
        ? _subChapterList.firstWhere(
            (s) => s['id'].toString() == _selectedSubChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final subChapterName = subChapterMap.isNotEmpty
        ? (subChapterMap['judul_sub_bab'] ??
              subChapterMap['title'] ??
              subChapterMap['judul'] ??
              '')
        : '';

    return {
      'title': _titleController.text,
      'mata_pelajaran_id': _selectedSubjectId,
      'mata_pelajaran_nama': subjectName,
      'satuan_pendidikan': schoolNameStr,
      'bab_nama': chapterName,
      'sub_bab_nama': subChapterName,
      'kelas_semester': '$className / ${_selectedSemester ?? 'Ganjil'}',
      'alokasi_waktu': _academicYearController.text,
    };
  }

  Future<void> _processAndNavigate(dynamic lessonPlanResponse) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final languageProvider = ref.read(languageRiverpod);

    final userData = await TokenService().getUserData();
    final schoolObj = userData?['school'] as Map<String, dynamic>?;
    final schoolNameStr = schoolObj != null
        ? (schoolObj['school_name'] ?? schoolObj['nama_sekolah'] ?? 'SD/MI')
        : (userData?['school_name'] ?? userData?['nama_sekolah'] ?? 'SD/MI');

    final selectedSubject = _subjectList.firstWhere(
      (m) => m['id'].toString() == _selectedSubjectId,
      orElse: () => {'name': 'Mata Pelajaran'},
    );
    final subjectName =
        lessonPlanResponse['mata_pelajaran_nama'] ??
        selectedSubject['name'] ??
        selectedSubject['nama'] ??
        'Mata Pelajaran';

    final selectedClass = _classList.firstWhere(
      (k) => k['id'].toString() == _selectedClassId,
      orElse: () => {'name': 'Kelas'},
    );
    final className =
        lessonPlanResponse['kelas_nama'] ??
        selectedClass['name'] ??
        selectedClass['nama'] ??
        'Kelas';

    final chapterMap = _selectedChapterId != null
        ? _chapterList.firstWhere(
            (b) => b['id'].toString() == _selectedChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final chapterName = chapterMap.isNotEmpty
        ? (chapterMap['judul_bab'] ??
              chapterMap['title'] ??
              chapterMap['judul'] ??
              'Tanpa Nama')
        : '';

    final subChapterMap = _selectedSubChapterId != null
        ? _subChapterList.firstWhere(
            (s) => s['id'].toString() == _selectedSubChapterId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final subChapterName = subChapterMap.isNotEmpty
        ? (subChapterMap['judul_sub_bab'] ??
              subChapterMap['title'] ??
              subChapterMap['judul'] ??
              'Tanpa Nama')
        : '';

    final mappedLessonPlanData = {
      'id': null,
      'judul': lessonPlanResponse['title'] ?? _titleController.text,
      'mata_pelajaran_id': _selectedSubjectId,
      'mata_pelajaran_nama': subjectName,
      'satuan_pendidikan': schoolNameStr,
      'bab_nama': chapterName,
      'sub_bab_nama': subChapterName,
      'kelas_semester':
          '$className / ${lessonPlanResponse['semester'] ?? _selectedSemester}',
      'tema': lessonPlanResponse['title'],
      'sub_tema': '',
      'pembelajaran_ke': '',
      'alokasi_waktu': _academicYearController.text,
      'waktu_pendahuluan': '15',
      'waktu_inti': '140',
      'waktu_penutup': '15',
      'kompetensi_inti': _stripHtml(
        lessonPlanResponse['core_competence'] as String? ?? '',
      ),
      'kompetensi_dasar': _stripHtml(
        lessonPlanResponse['basic_competence'] as String? ?? '',
      ),
      'tujuan_pembelajaran': _stripHtml(
        lessonPlanResponse['learning_objective'] as String? ?? '',
      ),
      'kegiatan_pendahuluan':
          '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya dengan Materi yang akan dipelajari',
      'kegiatan_inti': _stripHtml(
        lessonPlanResponse['learning_activities'] as String? ?? '',
      ),
      'kegiatan_penutup':
          '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa\n• Pemberian hadiah/pujian untuk pekerjaan yang benar',
      'penilaian': _stripHtml(
        lessonPlanResponse['assessment'] as String? ?? '',
      ),
      'is_ai_generated': true,
    };

    if (!mounted) return;
    AppNavigator.pushReplacement(
      context,
      LessonPlanAiResultScreen(
        lessonPlanData: mappedLessonPlanData,
        teacherId: widget.teacherId,
        onSaved: () {
          widget.onSaved();
        },
      ),
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.getTranslatedText({
            'en': 'RPP successfully AI-generated.',
            'id': 'RPP berhasil di-generate AI.',
          }),
        ),
        backgroundColor: ColorUtils.success600,
      ),
    );
  }

  Color _getPrimaryColor() => ColorUtils.success600;

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final primaryColor = _getPrimaryColor();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Generate RPP with AI',
                              'id': 'Generate RPP dengan AI',
                            }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            languageProvider.getTranslatedText({
                              'en':
                                  'Create interactive RPP documents automatically',
                              'id': 'Buat dokumen RPP secara otomatis',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: _titleController,
                      label: '${AppLocalizations.title.tr} *',
                      icon: Icons.title_rounded,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Enter RPP title',
                        'id': 'Masukkan judul RPP',
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.titleRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildDialogDropdown(
                      value: _selectedSubjectId,
                      label: '${AppLocalizations.subject.tr} *',
                      icon: Icons.book_outlined,
                      items: _subjectList.map((mp) {
                        return DropdownMenuItem(
                          value: mp['id'],
                          child: Text(
                            mp['name'] ??
                                mp['nama'] ??
                                mp['subject_name'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSubjectId = value.toString();
                          _selectedClassId = null;
                          _selectedChapterId = null;
                          _selectedSubChapterId = null;
                          _chapterList = [];
                          _subChapterList = [];
                        });
                        _loadClassesBySubject(value.toString());
                        _loadChaptersBySubject(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return AppLocalizations.subjectRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedClassId,
                            label: '${AppLocalizations.class_.tr} *',
                            icon: Icons.class_outlined,
                            items: _classList.map((classItem) {
                              return DropdownMenuItem(
                                value: classItem['id'],
                                child: Text(
                                  classItem['name'] ??
                                      classItem['nama'] ??
                                      classItem['class_name'] ??
                                      'Tanpa Nama',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClassId = value.toString();
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.classNameRequired.tr;
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedSemester,
                            label: '${AppLocalizations.academicTerm.tr} *',
                            icon: Icons.calendar_view_month_rounded,
                            items: ['Ganjil', 'Genap'].map((semester) {
                              return DropdownMenuItem(
                                value: semester,
                                child: Text(semester),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSemester = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildDialogDropdown(
                      value: _selectedChapterId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Chapter', 'id': 'Bab'})} *',
                      icon: Icons.bookmark_border_rounded,
                      items: _chapterList.map((chapter) {
                        return DropdownMenuItem(
                          value: chapter['id'],
                          child: Text(
                            chapter['judul_bab'] ??
                                chapter['title'] ??
                                chapter['judul'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChapterId = value.toString();
                          _selectedSubChapterId = null;
                          _subChapterList = [];
                        });
                        _loadSubChaptersByChapter(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Chapter is required',
                            'id': 'Bab harus dipilih',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildDialogDropdown(
                      value: _selectedSubChapterId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Sub Chapter', 'id': 'Sub Bab'})} (Opsional)',
                      icon: Icons.bookmark_add_outlined,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'None',
                              'id': 'Tidak ada',
                            }),
                            style: TextStyle(color: ColorUtils.slate400),
                          ),
                        ),
                        ..._subChapterList.map((subChapter) {
                          return DropdownMenuItem(
                            value: subChapter['id'],
                            child: Text(
                              subChapter['judul_sub_bab'] ??
                                  subChapter['title'] ??
                                  subChapter['judul'] ??
                                  'Tanpa Nama',
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSubChapterId = value?.toString();
                        });
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildDialogTextField(
                      controller: _academicYearController,
                      label: '${AppLocalizations.academicYear.tr} *',
                      icon: Icons.calendar_today_rounded,
                      hintText: '2024/2025',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.academicYearRequired.tr;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Buttons
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAutoGenerating
                          ? null
                          : () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        AppLocalizations.cancel.tr,
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAutoGenerating ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isAutoGenerating
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_generationStatus.isNotEmpty) ...[
                                  SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _generationStatus,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Text(
                              languageProvider.getTranslatedText({
                                'en': 'Generate',
                                'id': 'Generate',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
