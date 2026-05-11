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
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_identity_edit_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_section_editor_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/ai/ai_rpp_preview_view.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_pdf_builder.dart';
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
    // Pushed as a full-page route (was a modal bottom sheet) so
    //   • the BrandPageHeader gets the system status bar inside its
    //     SafeArea (no more "05:16" clock clipping the back button)
    //   • the system back / ESC behaviour matches the rest of the
    //     app (you don't lose unsaved per-section state to a stray
    //     barrier-tap or ESC press)
    //   • it feels like the file detail page (ManualRppDetailScreen)
    //     instead of a half-height sheet.
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AiRppDetailScreen(lessonPlanData: lessonPlanData, isNew: isNew),
      ),
    );
  }

  @override
  State<AiRppDetailScreen> createState() => _AiRppDetailScreenState();
}

class _AiRppDetailScreenState extends State<AiRppDetailScreen> {
  late Map<String, dynamic> _lessonPlanData;
  Map<String, dynamic> _regenLimits = {};

  // (Edit toggle dropped — see "Removed" note further down.)
  bool _isSaving = false;
  bool _isLoadingLimits = false;
  bool _isDownloading = false;
  String? _regeneratingField; // 'all' or a fieldKey

  Color get _primary => ColorUtils.getRoleColor('guru');

  /// Format-aware section list. Reads the lesson plan's `format`
  /// column and emits the section keys + labels for that format. Each
  /// section's `key` is what gets written to `format_data` on save and
  /// what the regen sheet uses to know which sections are valid.
  ///
  /// `altKey` is a legacy fallback so K13 rows that haven't been
  /// migrated to format_data yet still render their content from the
  /// dedicated text columns.
  ///
  /// File-format rows route through ManualRppDetailScreen, so they
  /// never reach this getter — falling back to K13 here is fine.
  List<Map<String, String>> get _fields {
    final format = LessonPlanFormat.fromMap(_lessonPlanData);
    switch (format) {
      case LessonPlanFormat.k13:
        return const [
          {'key': 'identitas', 'label': 'Identitas', 'altKey': ''},
          {
            'key': 'kd_indikator',
            'label': 'Kompetensi Dasar & Indikator',
            'altKey': 'basic_competence',
          },
          {
            'key': 'tujuan',
            'label': 'Tujuan Pembelajaran',
            'altKey': 'learning_objective',
          },
          {
            'key': 'langkah_kegiatan',
            'label': 'Langkah Kegiatan',
            'altKey': 'learning_activities',
          },
          {'key': 'penilaian', 'label': 'Penilaian', 'altKey': 'assessment'},
        ];
      case LessonPlanFormat.rpp1Halaman:
        return const [
          {'key': 'tujuan', 'label': 'Tujuan Pembelajaran', 'altKey': ''},
          {'key': 'kegiatan', 'label': 'Kegiatan Pembelajaran', 'altKey': ''},
          {'key': 'asesmen', 'label': 'Asesmen', 'altKey': ''},
        ];
      case LessonPlanFormat.modulAjar:
        return const [
          {'key': 'info_umum', 'label': 'Informasi Umum', 'altKey': ''},
          {'key': 'capaian', 'label': 'Capaian Pembelajaran', 'altKey': ''},
          {'key': 'tujuan', 'label': 'Tujuan Pembelajaran', 'altKey': ''},
          {
            'key': 'pemahaman_pemantik',
            'label': 'Pemahaman Bermakna & Pemantik',
            'altKey': '',
          },
          {'key': 'kegiatan', 'label': 'Kegiatan Pembelajaran', 'altKey': ''},
          {
            'key': 'asesmen_refleksi',
            'label': 'Asesmen & Refleksi',
            'altKey': '',
          },
        ];
      case LessonPlanFormat.file:
        return const [];
    }
  }

  @override
  void initState() {
    super.initState();
    _lessonPlanData = Map<String, dynamic>.from(widget.lessonPlanData);
    if (_lessonPlanId != null) _loadRegenLimits();
  }

  // ── Identity / lookup helpers ──────────────────────────────────

  String? get _lessonPlanId {
    final id =
        _lessonPlanData['id'] ??
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

  String _getFieldValue(String key, String altKey) {
    // 1. New format-data path. The backend writes structured sections
    //    into format_data JSONB on every save; reads from there are
    //    the source of truth.
    final formatData = _lessonPlanData['format_data'];
    if (formatData is Map) {
      final v = formatData[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }

    // 2. Top-level column fallback. K13 rows whose format_data was
    //    backfilled by the migration also live here, and pre-format
    //    legacy rows still write to these columns.
    final v = _lessonPlanData[key];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }

    // 3. Legacy K13 column alias (e.g. tujuan ↔ learning_objective).
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

  String _stripHtml(String html) => LessonPlanContentFormatter.stripHtml(html);

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Full-page Scaffold (was modal bottom sheet) — lets the
    // BrandPageHeader claim the system status bar area for its
    // gradient and back-button row, matching ManualRppDetailScreen
    // (file detail) and every other teacher detail screen.
    //
    // Frame D chrome — shared BrandPageLayout with cobalt
    // BrandPageHeader + 3-cell KPI overlap (Section · Alokasi ·
    // Status). Body is scrollable and only carries the file card +
    // section cards. The legacy "Detail RPP / Rencana Pelaksanaan…"
    // double-title block + the "Regenerasi Semua Field" hero are
    // gone — title lives in the brand header, regen lives per-section.
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: true,
      body: BrandPageLayout(
        role: 'guru',
        header: _buildBrandHeader(),
        kpiCard: _buildBrandKpi(),
        bodyChildren: [_body()],
      ),
    );
  }

  // ── Brand chrome (Frame D) ──

  Widget _buildBrandHeader() {
    final model = LessonPlan.fromJson(_lessonPlanData);
    final format = LessonPlanFormat.fromMap(_lessonPlanData);
    final subject = (model.subjectName ?? '').trim();
    final className = (model.className ?? '').trim();
    final kicker = [
      'RPP · ${format.shortLabel}',
      if (className.isNotEmpty) className.toUpperCase(),
      if (subject.isNotEmpty) subject.toUpperCase(),
    ].join(' · ');

    return BrandPageHeader(
      role: 'guru',
      title: model.title.isNotEmpty ? model.title : 'Detail RPP',
      subtitle: kicker,
      isRealtimeFresh: true,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.edit_rounded,
          onTap: _openIdentityEditor,
        ),
        BrandHeaderIconButton(
          icon: Icons.more_vert_rounded,
          onTap: _showExportMenu,
        ),
      ],
    );
  }

  /// 3-cell KPI overlap card per Frame D — Section count · Alokasi
  /// (best-effort from time_allocation if set, else "-") · Status.
  Widget _buildBrandKpi() {
    final fields = _fields;
    final filled = fields.where((f) {
      final v = _getFieldValue(f['key']!, f['altKey'] ?? '');
      return v.isNotEmpty;
    }).length;
    final alokasi =
        (_lessonPlanData['time_allocation'] ??
                _lessonPlanData['alokasi_waktu'] ??
                '')
            .toString();
    final statusRaw = (_lessonPlanData['status'] ?? '').toString();
    final stat = _statusBadge(statusRaw);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            _kpi(
              label: 'Section',
              value: fields.isEmpty ? '-' : '$filled/${fields.length}',
              color: _primary,
            ),
            _kpiDivider(),
            _kpi(
              label: 'Alokasi',
              value: alokasi.isEmpty ? '-' : _shortenAlokasi(alokasi),
              color: ColorUtils.info600,
              compact: true,
            ),
            _kpiDivider(),
            _kpi(
              label: 'Status',
              value: stat.label,
              color: stat.color,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi({
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 13 : 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
              letterSpacing: compact ? 0 : -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() =>
      Container(width: 1, height: 28, color: ColorUtils.slate100);

  ({String label, Color color}) _statusBadge(String raw) {
    final s = raw.toLowerCase();
    if (s == 'approved' || s == 'disetujui') {
      return (label: 'Disetujui', color: ColorUtils.success600);
    }
    if (s == 'rejected' || s == 'ditolak' || s == 'revision') {
      return (label: 'Revisi', color: ColorUtils.error600);
    }
    if (s == 'pending' || s == 'submitted' || s == 'menunggu') {
      return (label: 'Pending', color: ColorUtils.warning600);
    }
    return (label: 'Draf', color: ColorUtils.slate500);
  }

  String _shortenAlokasi(String raw) {
    // "2 JP × 45 menit" → "2 JP". KPI cell only has room for ~6 chars.
    final m = RegExp(r'^(\d+\s*JP)', caseSensitive: false).firstMatch(raw);
    if (m != null) return m.group(1)!.toUpperCase();
    return raw.length <= 8 ? raw : '${raw.substring(0, 7)}…';
  }

  Widget _body() {
    // Always-preview rendering — the legacy global edit toggle is
    // gone. Editing happens in scoped sheets opened by the per-section
    // pencil button (showLessonPlanSectionEditorSheet — draggable
    // sheet at 96% viewport, covers the bottom nav) or the header
    // pencil (LessonPlanIdentityEditSheet).
    return AiRppPreviewView(
      lessonPlanData: _lessonPlanData,
      format: LessonPlanFormat.fromMap(_lessonPlanData),
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
      onFieldEditTap: _onFieldEditTap,
      onFileDownloadTap: _downloadAndOpenFile,
    );
  }

  // ── New scoped-edit handlers ─────────────────────────────────

  /// Open the per-section editor sheet for the tapped field. Save
  /// merges the new HTML back into local format_data so the card
  /// re-renders with the edit. PATCH already happened inside the
  /// sheet — no further save needed here.
  Future<void> _onFieldEditTap(String fieldKey, String fieldLabel) async {
    final id = _lessonPlanId;
    if (id == null) {
      SnackBarUtils.showError(context, 'ID RPP tidak ditemukan.');
      return;
    }
    final altKey = _altKeyFor(fieldKey);
    final currentHtml = _getFieldValue(fieldKey, altKey);
    final regen = _getFieldRegenInfo(fieldKey);

    final result = await showLessonPlanSectionEditorSheet(
      context: context,
      lessonPlanId: id,
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      currentHtml: currentHtml,
      regenInfo: regen,
      formatLabel: LessonPlanFormat.fromMap(_lessonPlanData).label,
    );

    if (result == null || !mounted) return;

    setState(() {
      // Mirror the saved HTML into both stores so the next read sees
      // the new value regardless of which path it checks first.
      final fd = _lessonPlanData['format_data'];
      final formatData = fd is Map<String, dynamic>
          ? Map<String, dynamic>.from(fd)
          : <String, dynamic>{};
      formatData[result.fieldKey] = result.newHtml;
      _lessonPlanData['format_data'] = formatData;
      _lessonPlanData[result.fieldKey] = result.newHtml;
    });
    SnackBarUtils.showInfo(context, '$fieldLabel tersimpan');
    // Refresh regen quota — the sheet may have consumed one regen
    // attempt during the edit session.
    _loadRegenLimits();
  }

  /// Open the identity edit sheet (header pencil). On save, merge the
  /// metadata patch into local data so the title in the AppBar updates
  /// without a re-fetch.
  Future<void> _openIdentityEditor() async {
    if (_isSaving) return;
    final teacherId =
        (_lessonPlanData['teacher_id'] ??
                _lessonPlanData['teacher']?['id'] ??
                '')
            .toString();
    final result = await showLessonPlanIdentityEditSheet(
      context: context,
      lessonPlan: _lessonPlanData,
      teacherId: teacherId,
    );
    if (result == null || !mounted) return;
    setState(() {
      _lessonPlanData.addAll(result.updatedFields);
    });
    SnackBarUtils.showInfo(context, 'Identitas RPP tersimpan');
  }

  String _altKeyFor(String fieldKey) {
    for (final f in _fields) {
      if (f['key'] == fieldKey) return f['altKey'] ?? '';
    }
    return '';
  }

  // ── (Removed) global edit-mode + bulk save ──
  //
  // The legacy `_toggleEdit` / `_updateField` / `_save` trio is gone.
  // Edits now flow through scoped sheets:
  //   • per-section content → showLessonPlanSectionEditorSheet
  //     (draggable sheet at 96% viewport, Quill editor that PATCHes
  //     only that key in format_data)
  //   • metadata (title/kelas/mapel/semester/year) →
  //     LessonPlanIdentityEditSheet (PATCHes top-level fields only)
  // The detail screen never holds dirty state across the whole row,
  // so there's no risk of a partial save wiping unrelated sections.

  // ── Regenerate-limits load ────────────────────────────────────

  Future<void> _loadRegenLimits() async {
    final id = _lessonPlanId;
    if (id == null) return;
    setState(() => _isLoadingLimits = true);
    try {
      final result = await getIt<ApiSubjectService>().getLessonPlanRegenLimits(
        id,
      );
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
    final confirmed = await LessonPlanRegenSheet.showRegenAllDialog(
      context,
      _primary,
    );
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
        final jobId =
            (body['job_id'] ?? body['data']?['id'] ?? body['data']?['job_id'])
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
        final response = await getIt<ApiSubjectService>()
            .regenLessonPlanFieldRaw(
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
          final jobId = (body['job_id'] ?? body['data']?['id'])?.toString();
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
    var msg = '$ok field ${AppLocalizations.fieldRegeneratedSuccessfully.tr}';
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
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token,
        );
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = (body['data'] ?? body) as Map<String, dynamic>;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result =
              (jobData['result'] ?? jobData['data'] ?? body['result'] ?? body)
                  as Map<String, dynamic>;
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
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token,
        );
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = (body['data'] ?? body) as Map<String, dynamic>;
        final status = jobData['status'] ?? body['status'];
        if (status == 'completed' || status == 'success') {
          final result =
              (jobData['result'] ?? jobData['data'] ?? body['result'] ?? body)
                  as Map<String, dynamic>;
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

  Future<void> _exportToPdf() async {
    try {
      final body = LessonPlanContentFormatter.format(_lessonPlanData);
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
        SnackBarUtils.showInfo(context, 'RPP berhasil diexport ke PDF');
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
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    final base = ApiService.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final clean = filePath.startsWith('/') ? filePath.substring(1) : filePath;
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
