// AI-generated RPP detail bottom sheet.
//
// Owns the full lifecycle for AI-generated lesson plans only:
//   • view (structured cards via [AiRppPreviewView])
//   • inline edit (per-section Quill via [AiRppEditorView])
//   • save → kamiledu-ai backend `PATCH /lesson-plans/{id}`
//   • per-field + all-field regen via the AI `regen` endpoints
//   • PDF / text export
//   • optional file-attachment download
//
// Manually-uploaded RPPs go through [ManualRppDetailScreen] instead.
// The dispatcher in `lesson_plan_detail_screen.dart` decides which to
// show once at entry — neither screen re-checks the kind.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/ai/ai_rpp_editor_view.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/ai/ai_rpp_preview_view.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_pdf_builder.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_detail_header.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_regen_sheet.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// AI-RPP detail bottom sheet. Use [show] from outside instead of
/// pushing the widget directly so the modal-sheet plumbing stays
/// centralised.
class AiRppDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lessonPlanData;
  final bool isNew;

  const AiRppDetailScreen({
    super.key,
    required this.lessonPlanData,
    this.isNew = false,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlanData,
    bool isNew = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) =>
          AiRppDetailScreen(lessonPlanData: lessonPlanData, isNew: isNew),
    );
  }

  @override
  State<AiRppDetailScreen> createState() => _AiRppDetailScreenState();
}

class _AiRppDetailScreenState extends State<AiRppDetailScreen> {
  late Map<String, dynamic> _lessonPlanData;
  Map<String, dynamic> _regenLimits = {};

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoadingLimits = false;
  bool _isDownloading = false;
  String? _regeneratingField; // 'all' or a fieldKey

  Color get _primary => ColorUtils.getRoleColor('guru');

  static const List<Map<String, String>> _fields = [
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

  @override
  void initState() {
    super.initState();
    _lessonPlanData = Map<String, dynamic>.from(widget.lessonPlanData);
    if (_lessonPlanId != null) _loadRegenLimits();
  }

  // ── Identity / lookup helpers ──────────────────────────────────

  String? get _lessonPlanId {
    final id = _lessonPlanData['id'] ??
        _lessonPlanData['rpp_id'] ??
        _lessonPlanData['lesson_plan_id'];
    final s = id?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? get _filePath {
    final url = _lessonPlanData['file_url'];
    if (url != null && url.toString().trim().isNotEmpty) {
      return url.toString().trim();
    }
    final fp = _lessonPlanData['file_path'];
    if (fp != null && fp.toString().trim().isNotEmpty) {
      return fp.toString().trim();
    }
    return null;
  }

  String _displayTitle() {
    final title = LessonPlan.fromJson(_lessonPlanData).title;
    return title.isNotEmpty ? title : 'RPP';
  }

  String _getFieldValue(String key, String altKey) {
    final v = _lessonPlanData[key];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
    if (altKey.isNotEmpty) {
      final alt = _lessonPlanData[altKey];
      if (alt != null && alt.toString().trim().isNotEmpty) {
        return alt.toString().trim();
      }
    }
    return '';
  }

  Map<String, dynamic>? _getFieldRegenInfo(String fieldKey) {
    if (_regenLimits.isEmpty) return null;
    final fields = _regenLimits['fields'] ?? _regenLimits;
    return (fields is Map) ? fields[fieldKey] as Map<String, dynamic>? : null;
  }

  String _stripHtml(String html) =>
      LessonPlanContentFormatter.stripHtml(html);

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.95),
        decoration: BoxDecoration(
          color: ColorUtils.lightGray,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LessonPlanDetailHeader(
                  title: 'Detail RPP',
                  subtitle: _displayTitle(),
                  isEditing: _isEditing,
                  isSaving: _isSaving,
                  primaryColor: _primary,
                  onEditTap: _toggleEdit,
                  onSaveTap: _save,
                  onExportTap: _showExportMenu,
                  onCopyTap: _copyToClipboard,
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_isEditing) {
      return AiRppEditorView(
        primaryColor: _primary,
        lessonPlanData: _lessonPlanData,
        fieldDefinitions: _fields,
        onFieldChanged: _updateField,
      );
    }
    return AiRppPreviewView(
      lessonPlanData: _lessonPlanData,
      canRegen: _lessonPlanId != null,
      isRegeneratingAll: _regeneratingField == 'all',
      isLoadingLimits: _isLoadingLimits,
      primaryColor: _primary,
      filePath: _filePath,
      isDownloading: _isDownloading,
      fieldDefinitions: _fields,
      getFieldValue: _getFieldValue,
      getFieldRegenInfo: _getFieldRegenInfo,
      stripHtml: _stripHtml,
      onRegenAllTap: _onRegenAllTap,
      onFieldRegenTap: _onFieldRegenTap,
      onFileDownloadTap: _downloadAndOpenFile,
    );
  }

  // ── Edit + save ───────────────────────────────────────────────

  void _toggleEdit() => setState(() => _isEditing = !_isEditing);

  void _updateField(String fieldKey, String value) {
    _lessonPlanData[fieldKey] = value;
  }

  Future<void> _save() async {
    final id = _lessonPlanId;
    if (id == null) {
      SnackBarUtils.showError(context, 'ID RPP tidak ditemukan.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'title': (_lessonPlanData['title'] ?? _lessonPlanData['judul'] ?? '')
            .toString(),
      };
      for (final f in _fields) {
        final key = f['key']!;
        final altKey = f['altKey'] ?? '';
        final v = _getFieldValue(key, altKey);
        if (v.isNotEmpty) payload[key] = v;
      }

      await getIt<ApiSubjectService>().updateLessonPlanFields(id, payload);

      if (!mounted) return;
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
      setState(() => _isEditing = false);
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Regenerate-limits load ────────────────────────────────────

  Future<void> _loadRegenLimits() async {
    final id = _lessonPlanId;
    if (id == null) return;
    setState(() => _isLoadingLimits = true);
    try {
      final result =
          await getIt<ApiSubjectService>().getLessonPlanRegenLimits(id);
      if (!mounted) return;
      Map<String, dynamic> parsed = {};
      if (result is Map<String, dynamic>) {
        final data = result['data'];
        parsed = data is Map<String, dynamic> ? data : result;
      }
      setState(() {
        _regenLimits = parsed;
        _isLoadingLimits = false;
      });
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  // ── Per-field regen flow ──────────────────────────────────────

  Future<void> _onFieldRegenTap(String fieldKey, String fieldLabel) async {
    final regenInfo = _getFieldRegenInfo(fieldKey);
    final remaining = (regenInfo?['remaining'] ?? 2) as int;
    final maxAttempts = (regenInfo?['max'] ?? 2) as int;

    if (remaining <= 0) {
      _showLimitReachedDialog(fieldLabel);
      return;
    }

    final additionalText = await LessonPlanRegenSheet.getAdditionalInstructions(
      context,
      fieldLabel,
      remaining,
      maxAttempts,
      _primary,
    );
    if (additionalText == null || !mounted) return;
    await _regenerateField(fieldKey, fieldLabel, additionalText);
  }

  Future<void> _onRegenAllTap() async {
    final confirmed =
        await LessonPlanRegenSheet.showRegenAllDialog(context, _primary);
    if (confirmed != true || !mounted) return;
    await _regenerateAllFields('');
  }

  Future<void> _regenerateField(
    String fieldKey,
    String fieldLabel,
    String additionalText,
  ) async {
    final id = _lessonPlanId;
    if (id == null) return;
    setState(() => _regeneratingField = fieldKey);
    try {
      final response = await getIt<ApiSubjectService>().regenLessonPlanFieldRaw(
        id,
        fieldKey,
        additionalText: additionalText.isNotEmpty ? additionalText : null,
      );
      if (!mounted) return;

      // Server-error guard.
      if (response.data is String) {
        final s = (response.data as String).trimLeft();
        if (s.startsWith('<!DOCTYPE') || s.startsWith('<html')) {
          setState(() => _regeneratingField = null);
          SnackBarUtils.showError(
            context,
            'Server AI sedang tidak tersedia (${response.statusCode}).',
          );
          return;
        }
      }

      final body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 429) {
        _showLimitReachedDialog(body['message']?.toString() ?? fieldLabel);
        setState(() => _regeneratingField = null);
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = (body['data'] ?? body) as Map<String, dynamic>;
        if (data[fieldKey] != null) {
          setState(() {
            _lessonPlanData[fieldKey] = data[fieldKey];
            _regeneratingField = null;
          });
        } else {
          _mergeAiResponse(data);
          setState(() => _regeneratingField = null);
        }
        await _loadRegenLimits();
        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}',
          );
        }
        return;
      }

      if (response.statusCode == 202) {
        final jobId = (body['job_id'] ??
                body['data']?['id'] ??
                body['data']?['job_id'])
            ?.toString();
        if (jobId != null) {
          await _pollJob(jobId, fieldKey, fieldLabel);
        } else {
          setState(() => _regeneratingField = null);
          SnackBarUtils.showError(
            context,
            AppLocalizations.failedToGetJobId.tr,
          );
        }
        return;
      }

      setState(() => _regeneratingField = null);
      SnackBarUtils.showError(
        context,
        body['message']?.toString() ??
            '${AppLocalizations.failedToGenerate.tr}: $fieldLabel',
      );
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        setState(() => _regeneratingField = null);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _regenerateAllFields(String additionalText) async {
    final id = _lessonPlanId;
    if (id == null) return;

    setState(() => _regeneratingField = 'all');
    int ok = 0;
    int fail = 0;

    for (final f in _fields) {
      final key = f['key']!;
      final altKey = f['altKey'] ?? '';
      if (_getFieldValue(key, altKey).isEmpty) continue;

      final regenInfo = _getFieldRegenInfo(key);
      final remaining = (regenInfo?['remaining'] ?? 2) as int;
      if (remaining <= 0) {
        fail++;
        continue;
      }

      try {
        final response =
            await getIt<ApiSubjectService>().regenLessonPlanFieldRaw(
          id,
          key,
          additionalText: additionalText.isNotEmpty ? additionalText : null,
        );
        if (!mounted) return;
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = (body['data'] ?? body) as Map<String, dynamic>;
          if (data[key] != null) {
            _lessonPlanData[key] = data[key];
          } else {
            _mergeAiResponse(data);
          }
          ok++;
        } else if (response.statusCode == 202) {
          final jobId =
              (body['job_id'] ?? body['data']?['id'])?.toString();
          if (jobId != null) {
            await _pollJobSync(jobId, key);
            ok++;
          } else {
            fail++;
          }
        } else {
          fail++;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
        fail++;
      }
    }

    if (!mounted) return;
    setState(() => _regeneratingField = null);
    await _loadRegenLimits();
    var msg =
        '$ok field ${AppLocalizations.fieldRegeneratedSuccessfully.tr}';
    if (fail > 0) {
      msg += ', $fail ${AppLocalizations.failedExceededLimit.tr}';
    }
    SnackBarUtils.showInfo(context, msg);
  }

  Future<void> _pollJob(
    String jobId,
    String fieldKey,
    String fieldLabel,
  ) async {
    final token = PreferencesService().getString('token') ?? '';
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final response =
            await getIt<ApiSubjectService>().pollAiJob(jobId, token);
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData =
            (body['data'] ?? body) as Map<String, dynamic>;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result = (jobData['result'] ??
              jobData['data'] ??
              body['result'] ??
              body) as Map<String, dynamic>;
          if (result[fieldKey] != null) {
            setState(() {
              _lessonPlanData[fieldKey] = result[fieldKey];
              _regeneratingField = null;
            });
          } else {
            _mergeAiResponse(result);
            setState(() => _regeneratingField = null);
          }
          await _loadRegenLimits();
          if (mounted) {
            SnackBarUtils.showInfo(
              context,
              '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}',
            );
          }
          return;
        }
        if (status == 'failed' || status == 'error') {
          setState(() => _regeneratingField = null);
          if (mounted) {
            SnackBarUtils.showError(
              context,
              jobData['error_message']?.toString() ?? 'Regenerasi gagal',
            );
          }
          return;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }
    }
    if (mounted) {
      setState(() => _regeneratingField = null);
      SnackBarUtils.showError(context, 'Regenerasi $fieldLabel timeout');
    }
  }

  Future<void> _pollJobSync(String jobId, String fieldKey) async {
    final token = PreferencesService().getString('token') ?? '';
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final response =
            await getIt<ApiSubjectService>().pollAiJob(jobId, token);
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = (body['data'] ?? body) as Map<String, dynamic>;
        final status = jobData['status'] ?? body['status'];
        if (status == 'completed' || status == 'success') {
          final result = (jobData['result'] ??
              jobData['data'] ??
              body['result'] ??
              body) as Map<String, dynamic>;
          if (result[fieldKey] != null) {
            _lessonPlanData[fieldKey] = result[fieldKey];
          } else {
            _mergeAiResponse(result);
          }
          return;
        }
        if (status == 'failed' || status == 'error') return;
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }
    }
  }

  void _mergeAiResponse(Map<String, dynamic> data) {
    for (final f in _fields) {
      final key = f['key']!;
      if (data.containsKey(key) && data[key] != null) {
        _lessonPlanData[key] = data[key];
      }
    }
  }

  void _showLimitReachedDialog(String fieldLabel) {
    AppAlertDialog.show(
      context: context,
      title: 'Batas Tercapai',
      message:
          'Batas regenerasi untuk "$fieldLabel" telah tercapai (maksimal 2 kali per field).',
      icon: Icons.timer_off_rounded,
      confirmText: 'Mengerti',
      showCancel: false,
    );
  }

  // ── Export menu (PDF / text) ──────────────────────────────────

  void _showExportMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export ke PDF'),
              onTap: () {
                AppNavigator.pop(sheetCtx);
                _exportToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export ke Text'),
              onTap: () {
                AppNavigator.pop(sheetCtx);
                _exportToText();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    final formatted = LessonPlanContentFormatter.format(_lessonPlanData);
    await Clipboard.setData(ClipboardData(text: formatted));
    if (mounted) {
      SnackBarUtils.showInfo(
        context,
        AppLocalizations.lessonPlanCopiedToClipboard.tr,
      );
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final body =
          LessonPlanContentFormatter.format(_lessonPlanData);
      final bytes = await LessonPlanPdfBuilder.build(
        data: _lessonPlanData,
        formattedBody: body,
      );

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RPP_${LessonPlan.fromJson(_lessonPlanData).title}_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          'RPP berhasil diexport ke PDF',
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
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RPP_${LessonPlan.fromJson(_lessonPlanData).title}_'
        '${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(
        LessonPlanContentFormatter.format(_lessonPlanData),
        flush: true,
      );
      await OpenFile.open(file.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.lessonPlanExportedToText.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // ── Attachment download ───────────────────────────────────────

  String _resolveDownloadUrl(String filePath) {
    if (filePath.startsWith('http://') ||
        filePath.startsWith('https://')) {
      return filePath;
    }
    final base = ApiService.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final clean =
        filePath.startsWith('/') ? filePath.substring(1) : filePath;
    if (clean.startsWith('storage/')) return '$base/$clean';
    return '$base/storage/$clean';
  }

  Future<void> _downloadAndOpenFile() async {
    final fp = _filePath;
    if (fp == null) return;

    setState(() => _isDownloading = true);
    try {
      final url = _resolveDownloadUrl(fp);
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final fileName = Uri.parse(fp).pathSegments.last;
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(response.data ?? const [], flush: true);
      await OpenFile.open(localFile.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.fileSavedSuccessfully.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
