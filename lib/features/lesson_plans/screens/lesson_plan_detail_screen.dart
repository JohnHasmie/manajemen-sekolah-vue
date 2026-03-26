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
import 'package:manajemensekolah/features/lesson_plans/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// RPP detail viewer with inline editing and AI regeneration.
///
/// Shows all RPP sections in a structured view. Teachers can edit content,
/// regenerate individual fields or all fields via AI, and export to PDF/Word.
///
/// Props (like Vue props): [rppData] -- the RPP object, [isNew] -- whether
/// this is a newly created RPP (shows "new" badge).
class RPPDetailPage extends StatefulWidget {
  final Map<String, dynamic> rppData;
  final bool isNew;

  const RPPDetailPage({super.key, required this.rppData, this.isNew = false});

  @override
  RPPDetailPageState createState() => RPPDetailPageState();
}

/// State for [RPPDetailPage].
///
/// Like a Vue component with `data() { return { isSaving, isEditing, rppData, ... } }`.
/// Manages edit mode toggle, AI regeneration state per field, and export.
class RPPDetailPageState extends State<RPPDetailPage> {
  bool _isSaving = false;
  bool _isEditing = false;
  String _editedContent = '';

  // Regeneration state
  Map<String, dynamic> _regenLimits = {};
  bool _isLoadingLimits = false;
  String? _regeneratingField; // null = not regenerating, 'all' = all fields
  late Map<String, dynamic> _rppData;

  // RPP content field definitions
  static const List<Map<String, String>> _rppFields = [
    {'key': 'core_competence', 'label': 'Kompetensi Inti (KI)', 'altKey': 'kompetensi_inti'},
    {'key': 'basic_competence', 'label': 'Kompetensi Dasar (KD)', 'altKey': 'kompetensi_dasar'},
    {'key': 'indicator', 'label': 'Indikator', 'altKey': 'indikator'},
    {'key': 'learning_objective', 'label': 'Tujuan Pembelajaran', 'altKey': 'tujuan_pembelajaran'},
    {'key': 'main_material', 'label': 'Materi Pokok', 'altKey': ''},
    {'key': 'learning_method', 'label': 'Metode Pembelajaran', 'altKey': ''},
    {'key': 'media_tools', 'label': 'Media / Alat', 'altKey': ''},
    {'key': 'learning_source', 'label': 'Sumber Belajar', 'altKey': ''},
    {'key': 'learning_activities', 'label': 'Kegiatan Pembelajaran', 'altKey': 'kegiatan_inti'},
    {'key': 'assessment', 'label': 'Penilaian (Asesmen)', 'altKey': 'penilaian'},
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
      // Metadata yang biasanya disimpan dengan AI generation
      'ai_model_used',
      'ai_tokens_used',
      'ai_generated',
    ];

    return aiKeys.any((key) {
      final value = _rppData[key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  String get _teacherId {
    return (_rppData['guru_id'] ?? _rppData['teacher_id'] ?? '')
        .toString();
  }

  void _openAiRppScreen() {
    AppNavigator.push(context, RppAiResultScreen(
          rppData: _rppData,
          teacherId: _teacherId,
          onSaved: () {
            // Jika ingin refresh halaman setelah menyimpan, bisa tambahkan logika di sini.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('RPP AI berhasil disimpan')),
              );
            }
          },
        ));
  }

  /// Like Vue's `mounted()` -- copies rppData to local mutable state and loads
  /// regeneration limits from the API.
  @override
  void initState() {
    super.initState();
    _rppData = Map<String, dynamic>.from(widget.rppData);
    _editedContent = _formatRPPContent();
    if (_hasAiAdditionalData && _rppId != null) {
      _loadRegenLimits();
    }
  }

  String? get _rppId {
    final id = _rppData['id'] ?? _rppData['rpp_id'] ?? _rppData['lesson_plan_id'];
    return id?.toString();
  }

  Future<void> _loadRegenLimits() async {
    final rppId = _rppId;
    if (rppId == null) return;

    setState(() => _isLoadingLimits = true);
    try {
      final result = await getIt<ApiSubjectService>().getRppRegenLimits(rppId);
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
    final val = _rppData[key];
    if (val != null && val.toString().trim().isNotEmpty) return val.toString().trim();
    if (altKey.isNotEmpty) {
      final altVal = _rppData[altKey];
      if (altVal != null && altVal.toString().trim().isNotEmpty) return altVal.toString().trim();
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
            SizedBox(height: 12),
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
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: ColorUtils.slate500)),
          ),
          ElevatedButton(
            onPressed: () => AppNavigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Regenerasi'),
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
            SizedBox(height: 12),
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
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: ColorUtils.slate500)),
          ),
          ElevatedButton.icon(
            onPressed: () => AppNavigator.pop(context, true),
            icon: Icon(Icons.auto_awesome, size: 18),
            label: Text('Regenerasi Semua'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        icon: Icon(Icons.timer_off_rounded, color: ColorUtils.warning600, size: 48),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  Future<void> _regenerateField(String fieldKey, String fieldLabel, String additionalText) async {
    final rppId = _rppId;
    AppLogger.debug('lesson_plan', 'Regen field: $fieldKey, rppId: $rppId');
    AppLogger.debug('lesson_plan', 'RPP data keys: ${_rppData.keys.toList()}');
    AppLogger.debug('lesson_plan', 'RPP id fields: id=${_rppData['id']}, rpp_id=${_rppData['rpp_id']}, lesson_plan_id=${_rppData['lesson_plan_id']}');
    if (rppId == null) return;

    setState(() => _regeneratingField = fieldKey);

    try {
      final response = await getIt<ApiSubjectService>().regenRppFieldRaw(
        rppId,
        fieldKey,
        additionalText: additionalText.isNotEmpty ? additionalText : null,
      );

      if (!mounted) return;

      // Check if response is HTML (server error page from proxy/CDN)
      // Dio returns data as String when content-type is text/html
      if (response.data is String) {
        final bodyStr = (response.data as String).trimLeft();
        if (bodyStr.startsWith('<!DOCTYPE') || bodyStr.startsWith('<html')) {
          AppLogger.error('lesson_plan', 'Got HTML response (status ${response.statusCode}) - server error');
          setState(() => _regeneratingField = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server AI sedang tidak tersedia (${response.statusCode}). Coba lagi nanti.'),
              backgroundColor: Colors.red,
            ),
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
            _rppData[fieldKey] = data[fieldKey];
            _editedContent = _formatRPPContent();
            _regeneratingField = null;
          });
          _loadRegenLimits();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fieldLabel berhasil di-regenerasi')),
          );
        } else {
          // Maybe full RPP data returned
          _updateRppDataFromResponse(data);
          setState(() => _regeneratingField = null);
          _loadRegenLimits();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fieldLabel berhasil di-regenerasi')),
          );
        }
      } else if (response.statusCode == 202) {
        // Async job - need to poll
        final jobId = (body['job_id'] ?? body['data']?['id'] ?? body['data']?['job_id'])?.toString();
        final pollUrl = (body['poll_url'] ?? body['polling_url'])?.toString();
        if (jobId != null) {
          _pollRegenJob(jobId, pollUrl, fieldKey, fieldLabel);
        } else {
          setState(() => _regeneratingField = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mendapatkan job ID'), backgroundColor: Colors.red),
          );
        }
      } else {
        setState(() => _regeneratingField = null);
        final msg = body['message'] ?? 'Gagal regenerasi $fieldLabel';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        setState(() => _regeneratingField = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _regenerateAllFields(String additionalText) async {
    final rppId = _rppId;
    if (rppId == null) return;

    setState(() => _regeneratingField = 'all');

    int successCount = 0;
    int failCount = 0;

    for (final field in _rppFields) {
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
        final response = await getIt<ApiSubjectService>().regenRppFieldRaw(
          rppId,
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
            _rppData[fieldKey] = data[fieldKey];
          } else {
            _updateRppDataFromResponse(data);
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
        _editedContent = _formatRPPContent();
        _regeneratingField = null;
      });
      _loadRegenLimits();

      String msg = '$successCount field berhasil di-regenerasi';
      if (failCount > 0) msg += ', $failCount gagal/melewati batas';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pollRegenJob(String jobId, String? pollUrl, String fieldKey, String fieldLabel) async {
    final prefs = PreferencesService();
    final token = prefs.getString('token') ?? '';

    for (int i = 0; i < 60; i++) {
      await Future.delayed(Duration(seconds: 5));
      if (!mounted) return;

      try {
        final response = await getIt<ApiSubjectService>().pollAiJob(jobId, token);
        // Dio auto-decodes JSON
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = body['data'] ?? body;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result = jobData['result'] ?? jobData['data'] ?? body['result'] ?? body;
          if (result[fieldKey] != null) {
            setState(() {
              _rppData[fieldKey] = result[fieldKey];
              _editedContent = _formatRPPContent();
              _regeneratingField = null;
            });
          } else {
            _updateRppDataFromResponse(result);
            setState(() => _regeneratingField = null);
          }
          _loadRegenLimits();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$fieldLabel berhasil di-regenerasi')),
            );
          }
          return;
        } else if (status == 'failed' || status == 'error') {
          final errMsg = jobData['error_message'] ?? 'Regenerasi gagal';
          setState(() => _regeneratingField = null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
            );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regenerasi $fieldLabel timeout'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pollRegenJobSync(String jobId, String fieldKey) async {
    final prefs = PreferencesService();
    final token = prefs.getString('token') ?? '';

    for (int i = 0; i < 60; i++) {
      await Future.delayed(Duration(seconds: 5));
      if (!mounted) return;

      try {
        final response = await getIt<ApiSubjectService>().pollAiJob(jobId, token);
        // Dio auto-decodes JSON
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = body['data'] ?? body;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result = jobData['result'] ?? jobData['data'] ?? body['result'] ?? body;
          if (result[fieldKey] != null) {
            _rppData[fieldKey] = result[fieldKey];
          } else {
            _updateRppDataFromResponse(result);
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

  void _updateRppDataFromResponse(Map<String, dynamic> data) {
    for (final field in _rppFields) {
      final key = field['key']!;
      if (data.containsKey(key) && data[key] != null) {
        _rppData[key] = data[key];
      }
    }
    setState(() => _editedContent = _formatRPPContent());
  }

  String _formatRPPContent() {
    final buffer = StringBuffer();

    String getField(List<String> keys, {String defaultValue = ''}) {
      for (final key in keys) {
        final value = _rppData[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return defaultValue;
    }

    final title = getField(['judul', 'title'], defaultValue: 'RPP');
    final subjectName = getField([
      'mata_pelajaran_nama',
      'subject_name',
    ]);
    final className = getField(['kelas_nama', 'class_name']);
    final semester = getField(['semester']);
    final academicYear = getField(['tahun_ajaran', 'academic_year']);
    final teacherName = getField(['guru_nama', 'teacher_name']);
    final status = getField(['status']);

    // Header fields yang mungkin ada dari AI generation atau input manual
    final unit = getField(['satuan_pendidikan', 'education_unit']);
    final theme = getField(['tema', 'theme']);
    final subTheme = getField(['sub_tema', 'sub_theme']);
    final sequence = getField(['pembelajaran_ke', 'learning_sequence']);
    final timeAllocation = getField(['alokasi_waktu', 'time_allocation']);

    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln();

    // Informasi Header dari database
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

    // Header tambahan (dari AI generation atau input manual)
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

    // Cek apakah RPP hasil genrasi AI (format 10 komponen API)
    final bool isAi =
        _rppData['ai_generated'] == true ||
        _rppData['is_ai_generated'] == true;

    // Kompetensi Inti & Kompetensi Dasar (jika tersedia)
    final String kompetensiInti = getField([
      'kompetensi_inti',
      'kompetensiInti',
      'ki',
      'core_competence',
    ]);
    final String kompetensiDasar = getField([
      'kompetensi_dasar',
      'kompetensiDasar',
      'kd',
      'basic_competence',
    ]);
    final String indikator = getField(['indikator', 'indicator']);

    int sectionIndex = 1;
    if (kompetensiInti.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI INTI (KI)',
      );
      buffer.writeln(_stripHtml(kompetensiInti));
      buffer.writeln();
      sectionIndex++;
    }

    if (kompetensiDasar.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI DASAR (KD)',
      );
      buffer.writeln(_stripHtml(kompetensiDasar));
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
    final tujuan = getField([
      'learning_objective',
      'tujuan_pembelajaran',
      'learning_objectives',
    ]);

    if (tujuan.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. TUJUAN PEMBELAJARAN',
      );
      sectionIndex++;
      if (isAi) {
        buffer.writeln(_stripHtml(tujuan));
      } else {
        final tujuanLines = tujuan.split('\n');
        for (int i = 0; i < tujuanLines.length; i++) {
          if (tujuanLines[i].trim().isNotEmpty) {
            buffer.writeln('${i + 1}. ${tujuanLines[i].trim()}');
          }
        }
      }
      buffer.writeln();
    }

    // KEGIATAN PEMBELAJARAN
    final kegiatanPendahuluan = getField([
      'kegiatan_pendahuluan',
      'preliminary_activities',
    ]);
    final kegiatanInti = getField([
      'learning_activities',
      'kegiatan_inti',
      'core_activities',
    ]);
    final kegiatanPenutup = getField([
      'kegiatan_penutup',
      'closing_activities',
    ]);

    if (kegiatanInti.isNotEmpty ||
        kegiatanPendahuluan.isNotEmpty ||
        kegiatanPenutup.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KEGIATAN PEMBELAJARAN',
      );
      buffer.writeln();
      sectionIndex++;

      if (kegiatanPendahuluan.isEmpty && kegiatanPenutup.isEmpty) {
        // Data dari DB (learning_activities) atau AI - 1 field saja
        buffer.writeln(_stripHtml(kegiatanInti));
      } else {
        // Data terpisah (pendahuluan, inti, penutup)
        if (kegiatanPendahuluan.isNotEmpty) {
          final pendahuluanTime = getField(['waktu_pendahuluan']);
          buffer.writeln(
            'Kegiatan Pendahuluan${pendahuluanTime.isNotEmpty ? ' ($pendahuluanTime menit)' : ''}',
          );
          for (var line in kegiatanPendahuluan.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln('• ${line.trim()}');
            }
          }
          buffer.writeln();
        }

        if (kegiatanInti.isNotEmpty) {
          final intiTime = getField(['waktu_inti']);
          buffer.writeln(
            'Kegiatan Inti${intiTime.isNotEmpty ? ' ($intiTime menit)' : ''}',
          );
          for (var line in kegiatanInti.split('\n')) {
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

        if (kegiatanPenutup.isNotEmpty) {
          final penutupTime = getField(['waktu_penutup']);
          buffer.writeln(
            'Kegiatan Penutup${penutupTime.isNotEmpty ? ' ($penutupTime menit)' : ''}',
          );
          for (var line in kegiatanPenutup.split('\n')) {
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

    // Materi dan Sumber Belajar (jika tersedia)
    final String mainMaterial = getField(['main_material']);
    final String learningMethod = getField(['learning_method']);
    final String mediaTools = getField(['media_tools']);
    final String learningSource = getField(['learning_source']);

    if (mainMaterial.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. MATERI POKOK',
      );
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
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. MEDIA / ALAT',
      );
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

    if (_rppData['ai_generated'] == true ||
        _rppData['is_ai_generated'] == true) {
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
  Future<void> _saveRPP() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Map data (falling back to known AI-generated key names if available)
      String fallback(List<String> keys) {
        for (final k in keys) {
          if (_rppData.containsKey(k) && _rppData[k] != null) {
            return _rppData[k].toString();
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
          'kompetensiInti',
          'ki',
        ]),
        'basic_competence': fallback([
          'basic_competence',
          'kompetensi_dasar',
          'kompetensiDasar',
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('RPP berhasil disimpan')));
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _exportToWord() async {
    try {
      // Tunggu sebentar untuk memastikan plugin siap
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

      // Get directory dengan error handling
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${_rppData['judul']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('RPP berhasil diexport ke PDF')));
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
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

  Future<void> _exportToText() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${_rppData['judul']}_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(_editedContent, flush: true);

      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RPP berhasil diexport ke file text')),
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
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

  bool _isDownloading = false;

  String? get _filePath {
    final fp = _rppData['file_path'];
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File berhasil diunduh')),
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
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
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Gradient Header
          _buildHeader(),
          // Body
          Expanded(
            child: _isEditing ? _buildEditor() : _buildPreview(),
          ),
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
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),
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
                      _rppData['judul']?.toString() ??
                          _rppData['title']?.toString() ??
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
            _saveRPP();
          },
        ),
        SizedBox(width: 8),
        _buildHeaderButton(
          icon: Icons.close_rounded,
          onTap: _toggleEdit,
        ),
      ];
    }

    return [
      if (widget.isNew)
        _buildHeaderButton(
          icon: _isSaving ? null : Icons.save_rounded,
          isLoading: _isSaving,
          onTap: _isSaving ? null : _saveRPP,
        ),
      if (!widget.isNew) ...[
        _buildHeaderButton(
          icon: Icons.edit_outlined,
          onTap: _toggleEdit,
        ),
        SizedBox(width: 8),
        if (_hasAiAdditionalData) ...[
          _buildHeaderButton(
            icon: Icons.smart_toy_rounded,
            onTap: _openAiRppScreen,
          ),
          SizedBox(width: 8),
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
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 16),
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
                  contentPadding: EdgeInsets.all(16),
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
    final bool canRegen = _hasAiAdditionalData && _rppId != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // File attachment card
          if (_filePath != null) _buildFileCard(),

          // Regenerate All button
          if (canRegen) ...[
            _buildRegenAllButton(),
            SizedBox(height: 16),
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
                padding: EdgeInsets.all(24),
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
                    border: Border.all(color: _primaryColor.withValues(alpha: 0.15)),
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
                      : Icon(Icons.auto_awesome, color: _primaryColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRegenerating ? 'Sedang memproses...' : 'Regenerasi Semua Field',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Generate ulang seluruh konten RPP dengan AI',
                        style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
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
      SizedBox(height: 12),
    ];

    // Field cards
    final fieldWidgets = _rppFields.map((field) {
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
      children: [
        ...headerWidgets,
        ...fieldWidgets,
        signatureWidget,
      ],
    );
  }

  Widget _buildHeaderInfoCard() {
    String getField(List<String> keys, {String defaultValue = ''}) {
      for (final key in keys) {
        final value = _rppData[key];
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
        padding: EdgeInsets.all(16),
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
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
            if (infoItems.isNotEmpty) ...[
              SizedBox(height: 12),
              ...infoItems.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.key,
                        style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
                      ),
                    ),
                    Text(': ', style: TextStyle(fontSize: 13, color: ColorUtils.slate500)),
                    Expanded(
                      child: Text(
                        item.value,
                        style: TextStyle(fontSize: 13, color: ColorUtils.slate700),
                      ),
                    ),
                  ],
                ),
              )),
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
    final isRegeneratingThis = _regeneratingField == fieldKey || _regeneratingField == 'all';

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
                        color: remaining > 0 ? _primaryColor : ColorUtils.slate400,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
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
            padding: EdgeInsets.all(16),
            child: SelectableText(
              _stripHtml(value),
              style: TextStyle(fontSize: 14, height: 1.6, color: ColorUtils.slate700),
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
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Mengetahui', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Kepala Sekolah', style: TextStyle(fontSize: 13)),
                      SizedBox(height: 40),
                      Text('...................................', style: TextStyle(fontSize: 12)),
                      Text('NIP ..............................', style: TextStyle(fontSize: 11, color: ColorUtils.slate500)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('', style: TextStyle(fontSize: 13)),
                      SizedBox(height: 4),
                      Text('Guru Mata Pelajaran', style: TextStyle(fontSize: 13)),
                      SizedBox(height: 40),
                      Text('...................................', style: TextStyle(fontSize: 12)),
                      Text('NIP ..............................', style: TextStyle(fontSize: 11, color: ColorUtils.slate500)),
                    ],
                  ),
                ),
              ],
            ),
            if (_rppData['ai_generated'] == true || _rppData['is_ai_generated'] == true) ...[
              SizedBox(height: 16),
              Divider(color: ColorUtils.slate200),
              SizedBox(height: 8),
              Text(
                'RPP ini digenerate secara otomatis menggunakan AI',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ColorUtils.slate400),
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
            padding: EdgeInsets.all(16),
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
                      SizedBox(height: 4),
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
                SizedBox(width: 8),
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
                        padding: EdgeInsets.all(8),
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
          return SizedBox(height: 16);
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
              SizedBox(height: 8),
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
              SizedBox(height: 16),
              Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 8),
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
      decoration: BoxDecoration(
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(8),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('RPP berhasil disalin ke clipboard')),
    );
  }
}
