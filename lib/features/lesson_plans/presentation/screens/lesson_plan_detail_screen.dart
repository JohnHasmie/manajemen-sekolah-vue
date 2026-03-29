// RPP (lesson plan) detail view/edit screen.
// Like `pages/teacher/LessonPlan/Detail.vue` in a Vue app.
//
// Displays a single RPP with all its sections (competencies, objectives,
// activities, assessment). Supports inline editing, per-field AI regeneration,
// saving, and export to Word/PDF. In Laravel terms: `LessonPlanController@show`
// + `@update` with AI regeneration capabilities.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// RPP detail viewer with inline editing and AI regeneration.
///
/// Shows all RPP sections in a structured view. Teachers can edit content,
/// regenerate individual fields or all fields via AI, and export to PDF/Word.
///
/// Props (like Vue props): [lessonPlanData] -- the RPP object, [isNew] -- whether
/// this is a newly created RPP (shows "new" badge).
class RPPDetailPage extends StatefulWidget {
  final Map<String, dynamic> lessonPlanData;
  final bool isNew;

  const RPPDetailPage({
    super.key,
    required this.lessonPlanData,
    this.isNew = false,
  });

  @override
  RPPDetailPageState createState() => RPPDetailPageState();
}

/// State for [RPPDetailPage].
///
/// Like a Vue component with `data() { return { isSaving, isEditing, lessonPlanData, ... } }`.
/// Manages edit mode toggle, AI regeneration state per field, and export.
class RPPDetailPageState extends State<RPPDetailPage> {
  bool _isSaving = false;
  bool _isEditing = false;
  String _editedContent = '';

  // Regeneration state
  Map<String, dynamic> _regenLimits = {};
  bool _isLoadingLimits = false;
  String? _regeneratingField; // null = not regenerating, 'all' = all fields
  late Map<String, dynamic> _lessonPlanData;

  // RPP content field definitions
  static const List<Map<String, String>> _lessonPlanFields = [
    {
      'key': 'core_competence',
      'label': 'Kompetensi Inti (KI)',
      'altKey': 'kompetensi_inti',
    },
    {
      'key': 'basic_competence',
      'label': 'Kompetensi Dasar (KD)',
      'altKey': 'kompetensi_dasar',
    },
    {'key': 'indicator', 'label': 'Indikator', 'altKey': 'indikator'},
    {
      'key': 'learning_objective',
      'label': 'Tujuan Pembelajaran',
      'altKey': 'tujuan_pembelajaran',
    },
    {'key': 'main_material', 'label': 'Materi Pokok', 'altKey': ''},
    {'key': 'learning_method', 'label': 'Metode Pembelajaran', 'altKey': ''},
    {'key': 'media_tools', 'label': 'Media / Alat', 'altKey': ''},
    {'key': 'learning_source', 'label': 'Sumber Belajar', 'altKey': ''},
    {
      'key': 'learning_activities',
      'label': 'Kegiatan Pembelajaran',
      'altKey': 'kegiatan_inti',
    },
    {
      'key': 'assessment',
      'label': 'Penilaian (Asesmen)',
      'altKey': 'penilaian',
    },
  ];

  bool get _hasAiAdditionalData {
    const aiKeys = [
      'core_competence',
      'basic_competence',
      'indicator',
      'learning_objective',
      'main_material',
      'learning_method',
      'media_tools',
      'learning_source',
      'learning_activities',
      'assessment',
      // Metadata typically saved with AI generation
      'ai_model_used',
      'ai_tokens_used',
      'ai_generated',
    ];

    return aiKeys.any((key) {
      final value = _lessonPlanData[key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  String get _teacherId {
    return (_lessonPlanData['guru_id'] ?? _lessonPlanData['teacher_id'] ?? '')
        .toString();
  }

  void _openAiLessonPlanScreen() {
    AppNavigator.push(
      context,
      LessonPlanAiResultScreen(
        lessonPlanData: _lessonPlanData,
        teacherId: _teacherId,
        onSaved: () {
          // If you want to refresh the page after saving, add logic here.
          if (mounted) {
            SnackBarUtils.showInfo(context, AppLocalizations.rppSavedSuccessfully.tr);
          }
        },
      ),
    );
  }

  /// Like Vue's `mounted()` -- copies lessonPlanData to local mutable state and loads
  /// regeneration limits from the API.
  @override
  void initState() {
    super.initState();
    _lessonPlanData = Map<String, dynamic>.from(widget.lessonPlanData);
    _editedContent = _formatLessonPlanContent();
    if (_hasAiAdditionalData && _lessonPlanId != null) {
      _loadRegenLimits();
    }
  }

  String? get _lessonPlanId {
    final id =
        _lessonPlanData['id'] ??
        _lessonPlanData['rpp_id'] ??
        _lessonPlanData['lesson_plan_id'];
    return id?.toString();
  }

  Future<void> _loadRegenLimits() async {
    final lessonPlanId = _lessonPlanId;
    if (lessonPlanId == null) return;

    setState(() => _isLoadingLimits = true);
    try {
      final result = await getIt<ApiSubjectService>().getLessonPlanRegenLimits(
        lessonPlanId,
      );
      if (mounted) {
        setState(() {
          _regenLimits = (result is Map<String, dynamic>)
              ? (result['data'] ?? result)
              : {};
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  String _getFieldValue(String key, String altKey) {
    final val = _lessonPlanData[key];
    if (val != null && val.toString().trim().isNotEmpty)
      return val.toString().trim();
    if (altKey.isNotEmpty) {
      final altVal = _lessonPlanData[altKey];
      if (altVal != null && altVal.toString().trim().isNotEmpty)
        return altVal.toString().trim();
    }
    return '';
  }

  Map<String, dynamic>? _getFieldRegenInfo(String fieldKey) {
    if (_regenLimits.isEmpty) return null;
    final fields = _regenLimits['fields'] ?? _regenLimits;
    if (fields is Map) return fields[fieldKey] as Map<String, dynamic>?;
    return null;
  }

  Future<void> _showRegenDialog(String fieldKey, String fieldLabel) async {
    final regenInfo = _getFieldRegenInfo(fieldKey);
    final remaining = regenInfo?['remaining'] ?? 2;

    if (remaining <= 0) {
      _showLimitReachedDialog(fieldLabel);
      return;
    }

    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Regenerasi $fieldLabel',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sisa regenerasi: $remaining dari ${regenInfo?['max'] ?? 2}',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tambahan instruksi (opsional)',
                hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor),
                ),
                contentPadding: EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(
              AppLocalizations.cancel.tr,
              style: TextStyle(color: ColorUtils.slate500),
            ),
          ),
          ElevatedButton(
            onPressed: () => AppNavigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(AppLocalizations.regenerate.tr),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _regenerateField(fieldKey, fieldLabel, textController.text);
    }
  }

  Future<void> _showRegenAllDialog() async {
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.auto_awesome, color: _primaryColor, size: 40),
        title: Text(
          'Regenerasi Semua Field',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Semua field RPP akan di-generate ulang. Setiap field memiliki batas regenerasi masing-masing.',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tambahan instruksi untuk semua field (opsional)',
                hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor),
                ),
                contentPadding: EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(
              AppLocalizations.cancel.tr,
              style: TextStyle(color: ColorUtils.slate500),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => AppNavigator.pop(context, true),
            icon: Icon(Icons.auto_awesome, size: 18),
            label: Text(AppLocalizations.regenerateAll.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _regenerateAllFields(textController.text);
    }
  }

  void _showLimitReachedDialog(String fieldLabel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.timer_off_rounded,
          color: ColorUtils.warning600,
          size: 48,
        ),
        title: Text(
          'Batas Tercapai',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Batas regenerasi untuk "$fieldLabel" telah tercapai (maksimal 2 kali per field).',
          style: TextStyle(fontSize: 14, color: ColorUtils.slate600),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => AppNavigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Regenerates a single RPP field using AI with optional custom prompt.
  /// Like calling `axios.post('/api/rpp/{id}/regenerate-field')` in Vue.
  /// Uses polling to wait for the AI job to complete.
  Future<void> _regenerateField(
    String fieldKey,
    String fieldLabel,
    String additionalText,
  ) async {
    final lessonPlanId = _lessonPlanId;
    AppLogger.debug(
      'lesson_plan',
      'Regen field: $fieldKey, lessonPlanId: $lessonPlanId',
    );
    AppLogger.debug(
      'lesson_plan',
      'RPP data keys: ${_lessonPlanData.keys.toList()}',
    );
    AppLogger.debug(
      'lesson_plan',
      'RPP id fields: id=${_lessonPlanData['id']}, rpp_id=${_lessonPlanData['rpp_id']}, lesson_plan_id=${_lessonPlanData['lesson_plan_id']}',
    );
    if (lessonPlanId == null) return;

    setState(() => _regeneratingField = fieldKey);

    try {
      final response = await getIt<ApiSubjectService>().regenLessonPlanFieldRaw(
        lessonPlanId,
        fieldKey,
        additionalText: additionalText.isNotEmpty ? additionalText : null,
      );

      if (!mounted) return;

      // Check if response is HTML (server error page from proxy/CDN)
      // Dio returns data as String when content-type is text/html
      if (response.data is String) {
        final bodyStr = (response.data as String).trimLeft();
        if (bodyStr.startsWith('<!DOCTYPE') || bodyStr.startsWith('<html')) {
          AppLogger.error(
            'lesson_plan',
            'Got HTML response (status ${response.statusCode}) - server error',
          );
          setState(() => _regeneratingField = null);
          SnackBarUtils.showError(
            context,
            'Server AI sedang tidak tersedia (${response.statusCode}). Coba lagi nanti.',
          );
          return;
        }
      }

      // Dio auto-decodes JSON, so response.data is already a Map
      final body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 429) {
        _showLimitReachedDialog(body['message'] ?? fieldLabel);
        setState(() => _regeneratingField = null);
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Direct response with updated field
        final data = body['data'] ?? body;
        if (data[fieldKey] != null) {
          setState(() {
            _lessonPlanData[fieldKey] = data[fieldKey];
            _editedContent = _formatLessonPlanContent();
            _regeneratingField = null;
          });
          _loadRegenLimits();
          SnackBarUtils.showInfo(context, '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}');
        } else {
          // Maybe full RPP data returned
          _updateLessonPlanDataFromResponse(data);
          setState(() => _regeneratingField = null);
          _loadRegenLimits();
          SnackBarUtils.showInfo(context, '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}');
        }
      } else if (response.statusCode == 202) {
        // Async job - need to poll
        final jobId =
            (body['job_id'] ?? body['data']?['id'] ?? body['data']?['job_id'])
                ?.toString();
        final pollUrl = (body['poll_url'] ?? body['polling_url'])?.toString();
        if (jobId != null) {
          _pollRegenJob(jobId, pollUrl, fieldKey, fieldLabel);
        } else {
          setState(() => _regeneratingField = null);
          SnackBarUtils.showError(context, AppLocalizations.failedToGetJobId.tr);
        }
      } else {
        setState(() => _regeneratingField = null);
        final msg = body['message'] ?? '${AppLocalizations.failedToGenerate.tr}: $fieldLabel';
        SnackBarUtils.showError(context, msg);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        setState(() => _regeneratingField = null);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _regenerateAllFields(String additionalText) async {
    final lessonPlanId = _lessonPlanId;
    if (lessonPlanId == null) return;

    setState(() => _regeneratingField = 'all');

    int successCount = 0;
    int failCount = 0;

    for (final field in _lessonPlanFields) {
      final fieldKey = field['key']!;
      final fieldValue = _getFieldValue(fieldKey, field['altKey'] ?? '');
      if (fieldValue.isEmpty) continue; // Skip empty fields

      final regenInfo = _getFieldRegenInfo(fieldKey);
      final remaining = regenInfo?['remaining'] ?? 2;
      if (remaining <= 0) {
        failCount++;
        continue;
      }

      try {
        final response = await getIt<ApiSubjectService>()
            .regenLessonPlanFieldRaw(
              lessonPlanId,
              fieldKey,
              additionalText: additionalText.isNotEmpty ? additionalText : null,
            );

        if (!mounted) return;

        // Dio auto-decodes JSON, so response.data is already a Map
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = body['data'] ?? body;
          if (data[fieldKey] != null) {
            _lessonPlanData[fieldKey] = data[fieldKey];
          } else {
            _updateLessonPlanDataFromResponse(data);
          }
          successCount++;
        } else if (response.statusCode == 202) {
          final jobId = (body['job_id'] ?? body['data']?['id'])?.toString();
          if (jobId != null) {
            await _pollRegenJobSync(jobId, fieldKey);
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
        failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _editedContent = _formatLessonPlanContent();
        _regeneratingField = null;
      });
      _loadRegenLimits();

      String msg = '$successCount field ${AppLocalizations.fieldRegeneratedSuccessfully.tr}';
      if (failCount > 0) msg += ', $failCount ${AppLocalizations.failedExceededLimit.tr}';
      SnackBarUtils.showInfo(context, msg);
    }
  }

  Future<void> _pollRegenJob(
    String jobId,
    String? pollUrl,
    String fieldKey,
    String fieldLabel,
  ) async {
    final prefs = PreferencesService();
    final token = prefs.getString('token') ?? '';

    for (int i = 0; i < 60; i++) {
      await Future.delayed(Duration(seconds: 5));
      if (!mounted) return;

      try {
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token,
        );
        // Dio auto-decodes JSON
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = body['data'] ?? body;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result =
              jobData['result'] ?? jobData['data'] ?? body['result'] ?? body;
          if (result[fieldKey] != null) {
            setState(() {
              _lessonPlanData[fieldKey] = result[fieldKey];
              _editedContent = _formatLessonPlanContent();
              _regeneratingField = null;
            });
          } else {
            _updateLessonPlanDataFromResponse(result);
            setState(() => _regeneratingField = null);
          }
          _loadRegenLimits();
          if (mounted) {
            SnackBarUtils.showInfo(
              context,
              '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}',
            );
          }
          return;
        } else if (status == 'failed' || status == 'error') {
          final errMsg = jobData['error_message'] ?? 'Regenerasi gagal';
          setState(() => _regeneratingField = null);
          if (mounted) {
            SnackBarUtils.showError(context, errMsg);
          }
          return;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }
    }

    // Timeout
    if (mounted) {
      setState(() => _regeneratingField = null);
      SnackBarUtils.showError(context, 'Regenerasi $fieldLabel timeout');
    }
  }

  Future<void> _pollRegenJobSync(String jobId, String fieldKey) async {
    final prefs = PreferencesService();
    final token = prefs.getString('token') ?? '';

    for (int i = 0; i < 60; i++) {
      await Future.delayed(Duration(seconds: 5));
      if (!mounted) return;

      try {
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token,
        );
        // Dio auto-decodes JSON
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = body['data'] ?? body;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result =
              jobData['result'] ?? jobData['data'] ?? body['result'] ?? body;
          if (result[fieldKey] != null) {
            _lessonPlanData[fieldKey] = result[fieldKey];
          } else {
            _updateLessonPlanDataFromResponse(result);
          }
          return;
        } else if (status == 'failed' || status == 'error') {
          return;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }
    }
  }

  void _updateLessonPlanDataFromResponse(Map<String, dynamic> data) {
    for (final field in _lessonPlanFields) {
      final key = field['key']!;
      if (data.containsKey(key) && data[key] != null) {
        _lessonPlanData[key] = data[key];
      }
    }
    setState(() => _editedContent = _formatLessonPlanContent());
  }

  String _formatLessonPlanContent() {
    final buffer = StringBuffer();

    String getField(List<String> keys, {String defaultValue = ''}) {
      for (final key in keys) {
        final value = _lessonPlanData[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return defaultValue;
    }

    final title = getField(['judul', 'title'], defaultValue: 'RPP');
    final subjectName = getField(['mata_pelajaran_nama', 'subject_name']);
    final className = getField(['kelas_nama', 'class_name']);
    final semester = getField(['semester']);
    final academicYear = getField(['tahun_ajaran', 'academic_year']);
    final teacherName = getField(['guru_nama', 'teacher_name']);
    final status = getField(['status']);

    // Header fields that may come from AI generation or manual input
    final unit = getField(['satuan_pendidikan', 'education_unit']);
    final theme = getField(['tema', 'theme']);
    final subTheme = getField(['sub_tema', 'sub_theme']);
    final sequence = getField(['pembelajaran_ke', 'learning_sequence']);
    final timeAllocation = getField(['alokasi_waktu', 'time_allocation']);

    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln();

    // Header information from database
    buffer.writeln('Judul\t\t\t: $title');
    if (subjectName.isNotEmpty) {
      buffer.writeln('Mata Pelajaran\t: $subjectName');
    }
    if (className.isNotEmpty) {
      buffer.writeln('Kelas\t\t\t: $className');
    }
    if (semester.isNotEmpty) {
      buffer.writeln('Semester\t\t: $semester');
    }
    if (academicYear.isNotEmpty) {
      buffer.writeln('Tahun Ajaran\t\t: $academicYear');
    }
    if (teacherName.isNotEmpty) {
      buffer.writeln('Guru\t\t\t: $teacherName');
    }
    if (status.isNotEmpty) {
      buffer.writeln('Status\t\t\t: $status');
    }

    // Additional header (from AI generation or manual input)
    if (unit.isNotEmpty) {
      buffer.writeln('Satuan Pendidikan\t: $unit');
    }
    if (theme.isNotEmpty) {
      buffer.writeln('Tema\t\t\t: $theme');
    }
    if (subTheme.isNotEmpty) {
      buffer.writeln('Sub Tema\t\t: $subTheme');
    }
    if (sequence.isNotEmpty) {
      buffer.writeln('Pembelajaran ke\t: $sequence');
    }
    if (timeAllocation.isNotEmpty) {
      buffer.writeln('Alokasi waktu\t: $timeAllocation');
    }
    buffer.writeln();

    // Check if RPP is AI-generated (10-component API format)
    final bool isAi =
        _lessonPlanData['ai_generated'] == true ||
        _lessonPlanData['is_ai_generated'] == true;

    // Core Competencies & Basic Competencies (if available)
    final String coreCompetency = getField([
      'kompetensi_inti',
      'coreCompetency',
      'ki',
      'core_competence',
    ]);
    final String basicCompetency = getField([
      'kompetensi_dasar',
      'basicCompetency',
      'kd',
      'basic_competence',
    ]);
    final String indikator = getField(['indikator', 'indicator']);

    int sectionIndex = 1;
    if (coreCompetency.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI INTI (KI)',
      );
      buffer.writeln(_stripHtml(coreCompetency));
      buffer.writeln();
      sectionIndex++;
    }

    if (basicCompetency.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI DASAR (KD)',
      );
      buffer.writeln(_stripHtml(basicCompetency));
      buffer.writeln();
      sectionIndex++;
    }

    if (indikator.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. INDIKATOR');
      buffer.writeln(_stripHtml(indikator));
      buffer.writeln();
      sectionIndex++;
    }

    // TUJUAN PEMBELAJARAN
    final objectives = getField([
      'learning_objective',
      'tujuan_pembelajaran',
      'learning_objectives',
    ]);

    if (objectives.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. TUJUAN PEMBELAJARAN',
      );
      sectionIndex++;
      if (isAi) {
        buffer.writeln(_stripHtml(objectives));
      } else {
        final objectiveLines = objectives.split('\n');
        for (int i = 0; i < objectiveLines.length; i++) {
          if (objectiveLines[i].trim().isNotEmpty) {
            buffer.writeln('${i + 1}. ${objectiveLines[i].trim()}');
          }
        }
      }
      buffer.writeln();
    }

    // KEGIATAN PEMBELAJARAN
    final preliminaryActivities = getField([
      'kegiatan_pendahuluan',
      'preliminary_activities',
    ]);
    final coreActivities = getField([
      'learning_activities',
      'kegiatan_inti',
      'core_activities',
    ]);
    final closingActivities = getField([
      'kegiatan_penutup',
      'closing_activities',
    ]);

    if (coreActivities.isNotEmpty ||
        preliminaryActivities.isNotEmpty ||
        closingActivities.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KEGIATAN PEMBELAJARAN',
      );
      buffer.writeln();
      sectionIndex++;

      if (preliminaryActivities.isEmpty && closingActivities.isEmpty) {
        // Data from DB (learning_activities) or AI - single field only
        buffer.writeln(_stripHtml(coreActivities));
      } else {
        // Separate data (introduction, main, closing)
        if (preliminaryActivities.isNotEmpty) {
          final preliminaryTime = getField(['waktu_pendahuluan']);
          buffer.writeln(
            'Kegiatan Pendahuluan${preliminaryTime.isNotEmpty ? ' ($preliminaryTime menit)' : ''}',
          );
          for (var line in preliminaryActivities.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln('• ${line.trim()}');
            }
          }
          buffer.writeln();
        }

        if (coreActivities.isNotEmpty) {
          final coreTime = getField(['waktu_inti']);
          buffer.writeln(
            'Kegiatan Inti${coreTime.isNotEmpty ? ' ($coreTime menit)' : ''}',
          );
          for (var line in coreActivities.split('\n')) {
            if (line.trim().isNotEmpty) {
              if (line.trim().startsWith('A.') ||
                  line.trim().startsWith('B.') ||
                  line.trim().startsWith('C.')) {
                buffer.writeln(line.trim());
              } else {
                buffer.writeln('• ${line.trim()}');
              }
            }
          }
          buffer.writeln();
        }

        if (closingActivities.isNotEmpty) {
          final closingTime = getField(['waktu_penutup']);
          buffer.writeln(
            'Kegiatan Penutup${closingTime.isNotEmpty ? ' ($closingTime menit)' : ''}',
          );
          for (var line in closingActivities.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln('• ${line.trim()}');
            }
          }
        }
      }
      buffer.writeln();
    }

    // PENILAIAN
    final assessment = getField(['assessment', 'penilaian']);
    if (assessment.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. PENILAIAN (ASESMEN)',
      );
      if (isAi) {
        buffer.writeln(_stripHtml(assessment));
      } else {
        buffer.writeln(assessment);
      }
      buffer.writeln();
    }

    // Materials and Learning Resources (if available)
    final String mainMaterial = getField(['main_material']);
    final String learningMethod = getField(['learning_method']);
    final String mediaTools = getField(['media_tools']);
    final String learningSource = getField(['learning_source']);

    if (mainMaterial.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. MATERI POKOK');
      sectionIndex++;
      buffer.writeln(_stripHtml(mainMaterial));
      buffer.writeln();
    }

    if (learningMethod.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. METODE PEMBELAJARAN',
      );
      sectionIndex++;
      buffer.writeln(_stripHtml(learningMethod));
      buffer.writeln();
    }

    if (mediaTools.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. MEDIA / ALAT');
      sectionIndex++;
      buffer.writeln(_stripHtml(mediaTools));
      buffer.writeln();
    }

    if (learningSource.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. SUMBER BELAJAR',
      );
      sectionIndex++;
      buffer.writeln(_stripHtml(learningSource));
      buffer.writeln();
    }

    // Tanda Tangan
    buffer.writeln('Mengetahui');
    buffer.writeln();
    buffer.writeln('Kepala Sekolah');
    buffer.writeln();
    buffer.writeln('...................................');
    buffer.writeln('NIP ..............................');
    buffer.writeln();
    buffer.writeln('Guru Mata Pelajaran');
    buffer.writeln();
    buffer.writeln('...................................');
    buffer.writeln('NIP ..............................');

    if (_lessonPlanData['ai_generated'] == true ||
        _lessonPlanData['is_ai_generated'] == true) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('*RPP ini digenerate secara otomatis menggunakan AI*');
    }

    return buffer.toString();
  }

  // Simple HTML stripper helper
  String _stripHtml(String html) {
    if (html.isEmpty) return '';

    // Replace list tags with newlines and bullets/numbers
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

    // Remove all remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Clean up extra whitespace and decode common entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");

    // Remove consecutive empty lines (more than 2)
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  /// Saves the RPP to the API.
  /// Like `axios.put('/api/rpp/{id}')` in Vue.
  Future<void> _saveLessonPlan() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Map data (falling back to known AI-generated key names if available)
      String fallback(List<String> keys) {
        for (final k in keys) {
          if (_lessonPlanData.containsKey(k) && _lessonPlanData[k] != null) {
            return _lessonPlanData[k].toString();
          }
        }
        return '';
      }

      await getIt<ApiSubjectService>().saveRPP({
        'teacher_id': fallback(['teacher_id', 'guru_id']),
        'subject_id': fallback(['subject_id', 'mata_pelajaran_id']),
        'class_id': fallback(['class_id']),
        'title': fallback(['title', 'judul']),
        'semester': fallback(['semester']),
        'academic_year': fallback(['academic_year', 'tahun_ajaran']),
        'core_competence': fallback([
          'core_competence',
          'kompetensi_inti',
          'coreCompetency',
          'ki',
        ]),
        'basic_competence': fallback([
          'basic_competence',
          'kompetensi_dasar',
          'basicCompetency',
          'kd',
        ]),
        'indicator': fallback(['indicator', 'indikator']),
        'learning_objective': fallback([
          'learning_objective',
          'tujuan_pembelajaran',
          'learning_objectives',
        ]),
        'main_material': fallback(['main_material']),
        'learning_method': fallback(['learning_method']),
        'media_tools': fallback(['media_tools']),
        'learning_source': fallback(['learning_source']),
        'learning_activities': fallback([
          'learning_activities',
          'kegiatan_inti',
          'core_activities',
        ]),
        'assessment': fallback(['assessment', 'penilaian']),
        'status': fallback(['status']),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Lesson plan saved successfully',
              'id': 'RPP berhasil disimpan',
            }),
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _exportToWord() async {
    try {
      // Wait briefly to ensure the plugin is ready
      await Future.delayed(Duration(milliseconds: 100));

      // Create a new PDF document
      final PdfDocument document = PdfDocument();

      // Add a page
      final PdfPage page = document.pages.add();

      // Create PDF graphics
      final PdfGraphics graphics = page.graphics;

      // Create PDF font
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );

      // Draw title
      graphics.drawString(
        'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Draw content
      final List<String> lines = _editedContent.split('\n');
      double yPosition = 40;

      for (String line in lines) {
        if (line.trim().isEmpty) {
          yPosition += 10;
          continue;
        }

        graphics.drawString(
          line,
          font,
          bounds: Rect.fromLTWH(50, yPosition, page.size.width - 100, 15),
        );
        yPosition += 18;

        // Check for page break
        if (yPosition > page.size.height - 50) {
          document.pages.add();
          yPosition = 40;
        }
      }

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory with error handling
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${_lessonPlanData['judul']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Lesson plan exported to PDF successfully',
                'id': 'RPP berhasil diexport ke PDF',
              }),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _exportToText() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${_lessonPlanData['judul']}_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(_editedContent, flush: true);

      await OpenFile.open(file.path);

      if (mounted) {
        SnackBarUtils.showInfo(context, AppLocalizations.rppExportedToText.tr);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  bool _isDownloading = false;

  String? get _filePath {
    final fp = _lessonPlanData['file_path'];
    if (fp != null && fp.toString().trim().isNotEmpty) {
      return fp.toString().trim();
    }
    return null;
  }

  String _getFileExtension(String filePath) {
    final fileName = _getFileName(filePath);
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex).toLowerCase();
  }

  String _getFileName(String filePath) {
    return Uri.parse(filePath).pathSegments.last;
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String ext) {
    switch (ext) {
      case '.pdf':
        return Colors.red;
      case '.doc':
      case '.docx':
        return Colors.blue;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _downloadAndOpenFile() async {
    final filePath = _filePath;
    if (filePath == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      // Use a plain Dio instance for downloading external file URLs (not API calls)
      final dio = Dio();
      final response = await dio.get<List<int>>(
        filePath,
        options: Options(responseType: ResponseType.bytes),
      );

      final directory = await getTemporaryDirectory();
      final fileName = _getFileName(filePath);
      final localFile = File('${directory.path}/$fileName');
      await localFile.writeAsBytes(response.data ?? [], flush: true);

      await OpenFile.open(localFile.path);

      if (mounted) {
        SnackBarUtils.showInfo(context, AppLocalizations.fileSavedSuccessfully.tr);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _updateContent(String newContent) {
    setState(() {
      _editedContent = newContent;
    });
  }

  Color get _primaryColor => ColorUtils.getRoleColor('guru');

  LinearGradient get _headerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          // Gradient Header
          _buildHeader(),
          // Body
          Expanded(child: _isEditing ? _buildEditor() : _buildPreview()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _headerGradient,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit RPP' : 'Detail RPP',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _lessonPlanData['judul']?.toString() ??
                          _lessonPlanData['title']?.toString() ??
                          'RPP',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action buttons
              ..._buildHeaderActions(),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    if (_isEditing) {
      return [
        _buildHeaderButton(
          icon: Icons.save_rounded,
          onTap: () {
            _toggleEdit();
            _saveLessonPlan();
          },
        ),
        SizedBox(width: AppSpacing.sm),
        _buildHeaderButton(icon: Icons.close_rounded, onTap: _toggleEdit),
      ];
    }

    return [
      if (widget.isNew)
        _buildHeaderButton(
          icon: _isSaving ? null : Icons.save_rounded,
          isLoading: _isSaving,
          onTap: _isSaving ? null : _saveLessonPlan,
        ),
      if (!widget.isNew) ...[
        _buildHeaderButton(icon: Icons.edit_outlined, onTap: _toggleEdit),
        SizedBox(width: AppSpacing.sm),
        if (_hasAiAdditionalData) ...[
          _buildHeaderButton(
            icon: Icons.smart_toy_rounded,
            onTap: _openAiLessonPlanScreen,
          ),
          SizedBox(width: AppSpacing.sm),
        ],
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'text') _exportToText();
            if (value == 'pdf') _exportToWord();
            if (value == 'copy') _copyToClipboard();
          },
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Export ke PDF'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'text',
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Text('Export ke Text'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.content_copy, color: _primaryColor, size: 20),
                  SizedBox(width: 10),
                  Text('Copy ke Clipboard'),
                ],
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _buildHeaderButton({
    IconData? icon,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isLoading
            ? Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFormatButton('B', Icons.format_bold, () {}),
                _buildFormatButton('I', Icons.format_italic, () {}),
                _buildFormatButton('U', Icons.format_underlined, () {}),
                _buildFormatButton('H1', Icons.title, () {}),
                _buildFormatButton('Table', Icons.table_chart, () {}),
                _buildFormatButton('List', Icons.list, () {}),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: TextEditingController(text: _editedContent),
                onChanged: _updateContent,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(AppSpacing.lg),
                  hintText: 'Ketik RPP disini...',
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Courier',
                  height: 1.5,
                  color: ColorUtils.slate800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20, color: ColorUtils.slate600),
      onPressed: onPressed,
      tooltip: text,
    );
  }

  Widget _buildPreview() {
    final bool canRegen = _hasAiAdditionalData && _lessonPlanId != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // File attachment card
          if (_filePath != null) _buildFileCard(),

          // Regenerate All button
          if (canRegen) ...[
            _buildRegenAllButton(),
            SizedBox(height: AppSpacing.lg),
          ],

          // RPP content - structured fields with regen buttons
          if (canRegen)
            _buildStructuredFieldsView()
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: _buildFormattedContent(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegenAllButton() {
    final isRegenerating = _regeneratingField == 'all';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withValues(alpha: 0.08),
            _primaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isRegenerating ? null : _showRegenAllDialog,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: isRegenerating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.auto_awesome,
                          color: _primaryColor,
                          size: 20,
                        ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRegenerating
                            ? 'Sedang memproses...'
                            : 'Regenerasi Semua Field',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Generate ulang seluruh konten RPP dengan AI',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ColorUtils.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredFieldsView() {
    // Header info card
    final headerWidgets = <Widget>[
      _buildHeaderInfoCard(),
      SizedBox(height: AppSpacing.md),
    ];

    // Field cards
    final fieldWidgets = _lessonPlanFields.map((field) {
      final fieldKey = field['key']!;
      final fieldLabel = field['label']!;
      final altKey = field['altKey'] ?? '';
      final value = _getFieldValue(fieldKey, altKey);
      if (value.isEmpty) return SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _buildFieldCard(fieldKey, fieldLabel, value),
      );
    }).toList();

    // Signature section
    final signatureWidget = _buildSignatureCard();

    return Column(
      children: [...headerWidgets, ...fieldWidgets, signatureWidget],
    );
  }

  Widget _buildHeaderInfoCard() {
    String getField(List<String> keys, {String defaultValue = ''}) {
      for (final key in keys) {
        final value = _lessonPlanData[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return defaultValue;
    }

    final title = getField(['judul', 'title'], defaultValue: 'RPP');
    final subjectName = getField(['mata_pelajaran_nama', 'subject_name']);
    final className = getField(['kelas_nama', 'class_name']);
    final semester = getField(['semester']);
    final academicYear = getField(['tahun_ajaran', 'academic_year']);
    final teacherName = getField(['guru_nama', 'teacher_name']);
    final status = getField(['status']);

    final infoItems = <MapEntry<String, String>>[
      if (subjectName.isNotEmpty) MapEntry('Mata Pelajaran', subjectName),
      if (className.isNotEmpty) MapEntry('Kelas', className),
      if (semester.isNotEmpty) MapEntry('Semester', semester),
      if (academicYear.isNotEmpty) MapEntry('Tahun Ajaran', academicYear),
      if (teacherName.isNotEmpty) MapEntry('Guru', teacherName),
      if (status.isNotEmpty) MapEntry('Status', status),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
            if (infoItems.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              ...infoItems.map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          item.key,
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ),
                      Text(
                        ': ',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorUtils.slate700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(String fieldKey, String fieldLabel, String value) {
    final regenInfo = _getFieldRegenInfo(fieldKey);
    final remaining = regenInfo?['remaining'] ?? 2;
    final max = regenInfo?['max'] ?? 2;
    final used = regenInfo?['used'] ?? 0;
    final isRegeneratingThis =
        _regeneratingField == fieldKey || _regeneratingField == 'all';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field header with regen button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fieldLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                ),
                // Regen limit indicator
                if (regenInfo != null && !_isLoadingLimits) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: remaining > 0
                          ? _primaryColor.withValues(alpha: 0.1)
                          : ColorUtils.slate200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$used/$max',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: remaining > 0
                            ? _primaryColor
                            : ColorUtils.slate400,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                ],
                // Regen button
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: isRegeneratingThis
                        ? null
                        : () => _showRegenDialog(fieldKey, fieldLabel),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: remaining > 0
                            ? _primaryColor.withValues(alpha: 0.1)
                            : ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: remaining > 0
                              ? _primaryColor.withValues(alpha: 0.2)
                              : ColorUtils.slate200,
                        ),
                      ),
                      child: isRegeneratingThis
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryColor,
                              ),
                            )
                          : Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: remaining > 0
                                  ? _primaryColor
                                  : ColorUtils.slate400,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Field content
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(
              _stripHtml(value),
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: ColorUtils.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard() {
    return Container(
      margin: EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Mengetahui',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text('Kepala Sekolah', style: TextStyle(fontSize: 13)),
                      SizedBox(height: 40),
                      Text(
                        '...................................',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'NIP ..............................',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('', style: TextStyle(fontSize: 13)),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Guru Mata Pelajaran',
                        style: TextStyle(fontSize: 13),
                      ),
                      SizedBox(height: 40),
                      Text(
                        '...................................',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'NIP ..............................',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_lessonPlanData['ai_generated'] == true ||
                _lessonPlanData['is_ai_generated'] == true) ...[
              SizedBox(height: AppSpacing.lg),
              Divider(color: ColorUtils.slate200),
              SizedBox(height: AppSpacing.sm),
              Text(
                'RPP ini digenerate secara otomatis menggunakan AI',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: ColorUtils.slate400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard() {
    final filePath = _filePath!;
    final ext = _getFileExtension(filePath);
    final fileName = _getFileName(filePath);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isDownloading ? null : _downloadAndOpenFile,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getFileIconColor(ext).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getFileIconColor(ext).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    _getFileIcon(ext),
                    color: _getFileIconColor(ext),
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Lampiran RPP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _isDownloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      )
                    : Container(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.download_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedContent() {
    final lines = _editedContent.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) {
          return SizedBox(height: AppSpacing.lg);
        }

        if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN')) {
          return Column(
            children: [
              Text(
                line,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
            ],
          );
        }

        if (line.startsWith('=')) {
          return Container(
            height: 2,
            color: ColorUtils.slate200,
            margin: EdgeInsets.symmetric(vertical: 8),
          );
        }

        if (line.startsWith('|')) {
          return _buildTableRow(line);
        }

        if (line.startsWith('A.') ||
            line.startsWith('B.') ||
            line.startsWith('C.')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.lg),
              Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
            ],
          );
        }

        if (line.contains('Media :') || line.contains('Alat/Bahan :')) {
          return Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
          );
        }

        if (line.startsWith('•') ||
            line.startsWith('1.') ||
            line.startsWith('2.')) {
          return Padding(
            padding: EdgeInsets.only(left: 16, bottom: 4),
            child: Text(line, style: TextStyle(fontSize: 14, height: 1.5)),
          );
        }

        if (line.contains('Mengetahui') ||
            line.contains('Kepala Sekolah') ||
            line.contains('Guru Mata Pelajaran')) {
          return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              line,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(line, style: TextStyle(fontSize: 14, height: 1.5)),
        );
      }).toList(),
    );
  }

  Widget _buildTableRow(String line) {
    final cells = line
        .split('|')
        .where((cell) => cell.trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(border: Border.all(color: ColorUtils.slate200)),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Text(
                cell.trim(),
                style: TextStyle(fontSize: 12, color: ColorUtils.slate700),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _editedContent));
    SnackBarUtils.showInfo(context, AppLocalizations.rppCopiedToClipboard.tr);
  }
}
