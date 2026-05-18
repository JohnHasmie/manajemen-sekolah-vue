// Frame C from the RPP mockup — the setup form that runs after the
// Frame B format chooser. Collects class + subject + bab + alokasi and
// dispatches either to AI generation or to a blank-draft create
// depending on the AI/Manual segmented toggle at the top.
//
// Theme — teacher cobalt (`ColorUtils.getRoleColor('guru')`) for the
// gradient header, chip selections, and primary CTA. Format identity
// (K13 / 1 Hal / Modul Ajar) shows up as the small colored dot beside
// the "Identitas RPP" title and in the right-hand icon badge, so the
// teacher still sees which format they're filling without breaking
// the consistent teacher chrome.
//
// All four list selects (mapel / kelas / bab / sub-bab) render as
// `FilterChipGrid` — same shared component used by alokasi / semester
// / tahun ajaran. No more separate picker bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// What method the teacher picked inside the setup form.
enum LessonPlanMethod { ai, manual }

/// Result of the setup flow. Returned from the sheet so the caller
/// (the FAB tap on the list screen) knows whether to refresh the list
/// + which detail screen to push next.
class LessonPlanSetupResult {
  final LessonPlanFormat format;
  final LessonPlanMethod method;

  /// The freshly-created lesson plan as the API returned it. Caller
  /// passes this to RPPDetailPage.show so the new row opens
  /// immediately without a re-fetch.
  final Map<String, dynamic> lessonPlan;

  const LessonPlanSetupResult({
    required this.format,
    required this.method,
    required this.lessonPlan,
  });
}

/// Open the setup sheet for [format]. Returns null if the user
/// cancelled, or a [LessonPlanSetupResult] if generation/create
/// succeeded.
Future<LessonPlanSetupResult?> showLessonPlanSetupSheet({
  required BuildContext context,
  required LessonPlanFormat format,
  required String teacherId,
}) {
  return AppDraggableSheet.show<LessonPlanSetupResult>(
    context: context,
    builder: (sheetCtx, scrollController) => _LessonPlanSetupSheet(
      format: format,
      teacherId: teacherId,
      scrollController: scrollController,
    ),
  );
}

class _LessonPlanSetupSheet extends ConsumerStatefulWidget {
  const _LessonPlanSetupSheet({
    required this.format,
    required this.teacherId,
    required this.scrollController,
  });

  final LessonPlanFormat format;
  final String teacherId;
  final ScrollController scrollController;

  @override
  ConsumerState<_LessonPlanSetupSheet> createState() =>
      _LessonPlanSetupSheetState();
}

class _LessonPlanSetupSheetState extends ConsumerState<_LessonPlanSetupSheet> {
  // ── Method axis (AI vs Manual) ──
  // File format defaults to manual implicitly — but the chooser routes
  // file picks to a dedicated upload sheet (F.1), not here.
  late LessonPlanMethod _method = widget.format.supportsAiGeneration
      ? LessonPlanMethod.ai
      : LessonPlanMethod.manual;

  // ── Picker state ──
  String? _subjectId;
  String? _subjectName;
  String? _classId;
  String? _className;
  String? _chapterId;
  String? _chapterTitle;
  String? _subChapterId;
  String? _subChapterTitle;
  String _semester = 'Ganjil';
  late String _academicYear = currentAcademicYearString();
  String _timeAllocation = '2 JP × 45 menit';
  final _extraContextController = TextEditingController();
  final _titleController = TextEditingController();

  // ── Loaded option lists ──
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  List<dynamic> _chapters = [];
  List<dynamic> _subChapters = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _extraContextController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final result = await ApiService().get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      if (!mounted) return;
      setState(() {
        if (result is Map && result['data'] is List) {
          _subjects = result['data'];
        } else if (result is List) {
          _subjects = result;
        }
      });
    } catch (e) {
      AppLogger.error('rpp_setup', 'Failed to load subjects: $e');
    }
  }

  Future<void> _loadClassesForSubject(String subjectId) async {
    try {
      final result = await ApiService().get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId',
      );
      if (!mounted) return;
      setState(() {
        if (result is Map && result['data'] is List) {
          _classes = result['data'];
        } else if (result is List) {
          _classes = result;
        } else {
          _classes = [];
        }
      });
    } catch (e) {
      AppLogger.error('rpp_setup', 'Failed to load classes: $e');
      if (mounted) setState(() => _classes = []);
    }
  }

  Future<void> _loadChaptersForSubject(String subjectId) async {
    try {
      final result = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: subjectId,
      );
      if (!mounted) return;
      setState(() => _chapters = result);
    } catch (e) {
      AppLogger.error('rpp_setup', 'Failed to load chapters: $e');
      if (mounted) setState(() => _chapters = []);
    }
  }

  Future<void> _loadSubChaptersForChapter(String chapterId) async {
    try {
      final result = await getIt<ApiSubjectService>().getSubChapterMaterials(
        chapterId: chapterId,
      );
      if (!mounted) return;
      setState(() => _subChapters = result);
    } catch (e) {
      AppLogger.error('rpp_setup', 'Failed to load sub-chapters: $e');
      if (mounted) setState(() => _subChapters = []);
    }
  }

  // ── Validation ──

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_subjectId == null || _classId == null) return false;
    if (_method == LessonPlanMethod.ai && _chapterId == null) return false;
    if (_method == LessonPlanMethod.manual &&
        _titleController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  // ── Submit ──

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final result = _method == LessonPlanMethod.ai
          ? await _submitAi()
          : await _submitManual();
      if (!mounted) return;

      // AI 202 path: the response carries `job_id` + `poll_url` and
      // NOT a finished lesson plan. If we just popped this back to the
      // caller, it would route to the manual file detail screen with
      // an empty payload (the dispatcher can't classify a row with no
      // format / no content). Instead, hand off to the polling result
      // screen so the user sees real progress and lands on the proper
      // editor when the job finishes.
      if (_method == LessonPlanMethod.ai && _isAsyncJobResponse(result)) {
        _routeToAiPolling(result);
        return;
      }

      AppNavigator.pop(
        context,
        LessonPlanSetupResult(
          format: widget.format,
          method: _method,
          lessonPlan: result,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        _method == LessonPlanMethod.ai
            ? 'Gagal generate RPP: $e'
            : 'Gagal membuat draf RPP: $e',
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<Map<String, dynamic>> _submitAi() async {
    final raw = await LessonPlanService.generateLessonPlan(
      teacherId: widget.teacherId,
      subjectId: _subjectId!,
      classId: _classId!,
      chapterId: _chapterId!,
      subChapterId: _subChapterId,
      timeAllocation: _timeAllocation,
      format: widget.format.value,
      extraContext: _extraContextController.text.trim().isEmpty
          ? null
          : _extraContextController.text.trim(),
    );
    return _unwrapData(raw);
  }

  Future<Map<String, dynamic>> _submitManual() async {
    // Pre-populate empty section keys so the editor has stable bindings.
    final formatData = <String, String>{
      for (final key in widget.format.sectionKeys) key: '',
    };

    final body = <String, dynamic>{
      'teacher_id': widget.teacherId,
      'subject_id': _subjectId,
      'class_id': _classId,
      'title': _titleController.text.trim().isEmpty
          ? (_chapterTitle ?? 'RPP Baru')
          : _titleController.text.trim(),
      'format': widget.format.value,
      'format_data': formatData,
      'semester': _semester,
      'academic_year': _academicYear,
      'status': 'draft',
    };
    final raw = await LessonPlanService.createLessonPlan(body);
    return _unwrapData(raw);
  }

  Map<String, dynamic> _unwrapData(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    return <String, dynamic>{};
  }

  /// True when the `/rpp/ai-generate` response is the 202 async envelope
  /// — i.e. the AI backend dispatched a queue job and we got back a
  /// pollable handle (`job_id` + `poll_url`) instead of a finished plan.
  /// The unwrapped data is shaped as `{job_id, status, poll_url}` in
  /// that case.
  bool _isAsyncJobResponse(Map<String, dynamic> data) {
    final hasJobId =
        (data['job_id'] ?? data['jobId'] ?? data['id']) != null &&
        (data['status']?.toString().toLowerCase() == 'pending' ||
            data['status']?.toString().toLowerCase() == 'queued' ||
            data['status']?.toString().toLowerCase() == 'processing');
    final hasPollUrl = (data['poll_url'] ?? data['polling_url']) != null;
    return hasJobId || hasPollUrl;
  }

  /// Hand off the 202 response to the dedicated polling screen. The
  /// setup sheet pops itself first so its DraggableScrollableSheet
  /// doesn't fight with the polling sheet's modal layer; the polling
  /// screen runs over the underlying RPP list and presents the proper
  /// detail screen once the job completes.
  void _routeToAiPolling(Map<String, dynamic> data) {
    final pollUrl = (data['poll_url'] ?? data['polling_url'])?.toString();
    final jobId = (data['job_id'] ?? data['jobId'] ?? data['id'])?.toString();
    final pollingMetadata = <String, dynamic>{
      'mata_pelajaran_id': _subjectId,
      'mata_pelajaran_nama': _subjectName ?? '',
      'kelas_id': _classId,
      'kelas_nama': _className ?? '',
      'satuan_pendidikan': 'SD/MI',
      'bab_nama': _chapterTitle ?? '',
      'sub_bab_nama': _subChapterTitle ?? '',
      'kelas_semester': '${_className ?? ''} · $_semester',
      'alokasi_waktu': _timeAllocation,
      'title': _chapterTitle ?? 'Lesson Plan AI',
      'format': widget.format.value,
    };

    final parentContext = Navigator.of(context, rootNavigator: true).context;
    final tId = widget.teacherId;

    AppNavigator.pop(context); // close setup sheet first

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LessonPlanAiResultScreen.show(
        context: parentContext,
        teacherId: tId,
        // No-op onSaved — the underlying list refreshes itself on
        // its next pull/route return; the polling sheet is the user's
        // source of truth while the job runs.
        onSaved: () {},
        pollUrl: pollUrl,
        jobId: jobId,
        pollingMetadata: pollingMetadata,
      );
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    // Single shared accent — teacher cobalt for everything in the
    // header gradient, chip selections, and CTA. The format identity
    // shows up as the colored dot in the header (handled in
    // `_buildHeader`), so the rest of the page chrome stays
    // consistently teacher-themed.
    final cobalt = ColorUtils.getRoleColor('guru');
    // Slightly darker shade for the gradient start. Matches the look
    // used by every other teacher BrandPageHeader.
    final cobaltDark = Color.lerp(cobalt, Colors.black, 0.18) ?? cobalt;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(cobalt, cobaltDark),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                88,
              ),
              children: [
                if (widget.format.supportsAiGeneration) ...[
                  _fieldLabel('Cara pengisian'),
                  _MethodToggle(
                    selected: _method,
                    onChanged: (m) => setState(() => _method = m),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_method == LessonPlanMethod.manual) ...[
                  _fieldLabel('Judul'),
                  _TextField(
                    controller: _titleController,
                    placeholder: 'Misal: Bab 4 · Trigonometri',
                    onChanged: (_) => setState(() {}),
                  ),
                ],

                // ── Mata Pelajaran (chip select) ──
                _fieldLabel('Mata pelajaran'),
                _buildSubjectChips(cobalt),

                // ── Kelas (chip select, depends on subject) ──
                _fieldLabel('Kelas'),
                _buildClassChips(cobalt),

                // ── Bab & Sub-bab — separated labels + spacing so the
                //    section doesn't feel cramped against the kelas
                //    chips above.
                if (_method == LessonPlanMethod.ai) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _fieldLabel('Bab'),
                  _buildChapterChips(cobalt),
                  const SizedBox(height: AppSpacing.sm),
                  _fieldLabel('Sub-bab (opsional)'),
                  _buildSubChapterChips(cobalt),
                ],

                // ── Small enumerable chip rows ──
                _fieldLabel('Alokasi waktu'),
                FilterChipGrid<String>(
                  options: const [
                    FilterOption(value: '1 JP × 45 menit', label: '1 JP'),
                    FilterOption(value: '2 JP × 45 menit', label: '2 JP'),
                    FilterOption(value: '2 JP × 40 menit', label: '2 JP · 40m'),
                    FilterOption(value: '4 JP × 45 menit', label: '4 JP'),
                  ],
                  selectedValue: _timeAllocation,
                  onSelected: (v) =>
                      setState(() => _timeAllocation = v ?? _timeAllocation),
                  selectedColor: cobalt,
                ),
                _fieldLabel('Semester'),
                FilterChipGrid<String>(
                  options: const [
                    FilterOption(value: 'Ganjil', label: 'Ganjil'),
                    FilterOption(value: 'Genap', label: 'Genap'),
                  ],
                  selectedValue: _semester,
                  onSelected: (v) => setState(() => _semester = v ?? _semester),
                  selectedColor: cobalt,
                ),
                _fieldLabel('Tahun ajaran'),
                FilterChipGrid<String>(
                  options: [
                    for (final y in academicYearChipOptions())
                      FilterOption(value: y, label: y),
                  ],
                  selectedValue: _academicYear,
                  onSelected: (v) =>
                      setState(() => _academicYear = v ?? _academicYear),
                  selectedColor: cobalt,
                ),
                if (_method == LessonPlanMethod.ai) ...[
                  _fieldLabel('Konteks tambahan untuk AI (opsional)'),
                  _TextField(
                    controller: _extraContextController,
                    placeholder:
                        'Misal: fokus contoh kontekstual, gunakan diskusi kelompok…',
                    minLines: 3,
                    maxLines: 6,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          BottomSheetFooter(
            primaryLabel: _isSubmitting
                ? (_method == LessonPlanMethod.ai
                      ? 'Generating…'
                      : 'Menyimpan…')
                : (_method == LessonPlanMethod.ai
                      ? 'Generate dengan AI'
                      : 'Buat draf RPP'),
            // AI mode: violet — the app-wide AI signature.
            // Manual mode: cobalt (teacher role color) — keeps the
            // submit button consistent with the rest of the teacher
            // chrome regardless of which format is being filled out.
            primaryColor: _method == LessonPlanMethod.ai
                ? const Color(0xFF7C3AED)
                : cobalt,
            primaryEnabled: _canSubmit,
            onPrimary: _submit,
            onSecondary: _isSubmitting
                ? () {}
                : () => AppNavigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color cobalt, Color cobaltDark) {
    // Format identity dot — the small colored circle next to "Identitas
    // RPP" tells the teacher which format they're filling out without
    // hijacking the entire page chrome (header used to gradient in
    // K13 indigo / Modul Ajar violet / 1 Hal emerald — that broke the
    // teacher-cobalt consistency the rest of the app uses). The dot
    // gets a soft glow in the same color so it reads at a glance.
    final formatColor = widget.format.brandColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cobaltDark, cobalt],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeaderIconBadge(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => AppNavigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RPP · ${widget.format.shortLabel} · BUAT BARU',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: formatColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: formatColor.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Identitas RPP',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _HeaderIconBadge(icon: widget.format.icon, onTap: null),
            ],
          ),
        ],
      ),
    );
  }

  // ── Field builders ──

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Chip-grid field builders ──
  //
  // All four list selects use the shared `FilterChipGrid` so the form
  // looks like one continuous chip-driven layout (alokasi / semester /
  // tahun ajaran already render this way). Each chip carries the row
  // id as its value; selecting a chip drives the same `setState` +
  // dependent-load logic the old picker sheet did.
  //
  // Empty / locked states (e.g. kelas before mapel is picked, sub-bab
  // before bab is picked) render a small slate hint rather than an
  // empty wrap so the form never collapses into nothing.

  Widget _buildSubjectChips(Color accent) {
    if (_subjects.isEmpty) {
      return const _ChipPlaceholder(text: 'Belum ada mata pelajaran ditugaskan');
    }
    return FilterChipGrid<String>(
      options: [
        for (final s in _subjects)
          FilterOption(
            value: (s['mata_pelajaran_id'] ?? s['id']).toString(),
            label: (s['mata_pelajaran_nama'] ?? s['name'] ?? '-').toString(),
          ),
      ],
      selectedValue: _subjectId,
      onSelected: (id) {
        if (id == null || id == _subjectId) return;
        final picked = _subjects.firstWhere(
          (s) => (s['mata_pelajaran_id'] ?? s['id']).toString() == id,
          orElse: () => null,
        );
        if (picked == null) return;
        setState(() {
          _subjectId = id;
          _subjectName =
              (picked['mata_pelajaran_nama'] ?? picked['name'] ?? '-')
                  .toString();
          // Reset dependent picks — class / chapter / sub-chapter all
          // belong to the previous subject's tree.
          _classId = null;
          _className = null;
          _chapterId = null;
          _chapterTitle = null;
          _subChapterId = null;
          _subChapterTitle = null;
          _classes = [];
          _chapters = [];
          _subChapters = [];
        });
        _loadClassesForSubject(id);
        _loadChaptersForSubject(id);
      },
      selectedColor: accent,
    );
  }

  Widget _buildClassChips(Color accent) {
    if (_subjectId == null) {
      return const _ChipPlaceholder(text: 'Pilih mata pelajaran dulu');
    }
    if (_classes.isEmpty) {
      return const _ChipPlaceholder(text: 'Belum ada kelas untuk mapel ini');
    }
    return FilterChipGrid<String>(
      options: [
        for (final c in _classes)
          FilterOption(
            value: (c['kelas_id'] ?? c['id']).toString(),
            label: (c['kelas_nama'] ?? c['name'] ?? '-').toString(),
          ),
      ],
      selectedValue: _classId,
      onSelected: (id) {
        if (id == null) return;
        final picked = _classes.firstWhere(
          (c) => (c['kelas_id'] ?? c['id']).toString() == id,
          orElse: () => null,
        );
        if (picked == null) return;
        setState(() {
          _classId = id;
          _className = (picked['kelas_nama'] ?? picked['name'] ?? '-')
              .toString();
        });
      },
      selectedColor: accent,
    );
  }

  Widget _buildChapterChips(Color accent) {
    if (_subjectId == null) {
      return const _ChipPlaceholder(text: 'Pilih mata pelajaran dulu');
    }
    if (_chapters.isEmpty) {
      return const _ChipPlaceholder(text: 'Belum ada bab untuk mapel ini');
    }
    return FilterChipGrid<String>(
      options: [
        for (final c in _chapters)
          FilterOption(
            value: c['id'].toString(),
            // Backend `/bab-material` returns `judul_bab` for the
            // chapter title (Chapter model column is `title` — the
            // controller maps it). Fall through to `title` / `judul`
            // / `nama` for legacy responses.
            label:
                (c['judul_bab'] ?? c['title'] ?? c['judul'] ?? c['nama'] ?? '-')
                    .toString(),
          ),
      ],
      selectedValue: _chapterId,
      onSelected: (id) {
        if (id == null) return;
        final picked = _chapters.firstWhere(
          (c) => c['id'].toString() == id,
          orElse: () => null,
        );
        if (picked == null) return;
        setState(() {
          _chapterId = id;
          _chapterTitle =
              (picked['judul_bab'] ??
                      picked['title'] ??
                      picked['judul'] ??
                      picked['nama'] ??
                      '-')
                  .toString();
          _subChapterId = null;
          _subChapterTitle = null;
          _subChapters = [];
        });
        _loadSubChaptersForChapter(id);
      },
      selectedColor: accent,
    );
  }

  Widget _buildSubChapterChips(Color accent) {
    if (_chapterId == null) {
      return const _ChipPlaceholder(text: 'Pilih bab dulu');
    }
    if (_subChapters.isEmpty) {
      return const _ChipPlaceholder(text: 'Tidak ada sub-bab — opsional');
    }
    return FilterChipGrid<String>(
      options: [
        for (final c in _subChapters)
          FilterOption(
            value: c['id'].toString(),
            // `/sub-bab-material` returns `judul_sub_bab`.
            label:
                (c['judul_sub_bab'] ??
                        c['title'] ??
                        c['judul'] ??
                        c['nama'] ??
                        '-')
                    .toString(),
          ),
      ],
      selectedValue: _subChapterId,
      onSelected: (id) {
        if (id == null) {
          setState(() {
            _subChapterId = null;
            _subChapterTitle = null;
          });
          return;
        }
        final picked = _subChapters.firstWhere(
          (c) => c['id'].toString() == id,
          orElse: () => null,
        );
        if (picked == null) return;
        setState(() {
          _subChapterId = id;
          _subChapterTitle =
              (picked['judul_sub_bab'] ??
                      picked['title'] ??
                      picked['judul'] ??
                      picked['nama'] ??
                      '-')
                  .toString();
        });
      },
      selectedColor: accent,
    );
  }
}

/// Slate-tinted hint rendered in place of an empty `FilterChipGrid` so
/// the form keeps its rhythm even when a dependent list is locked or
/// hasn't loaded yet (e.g. "Pilih mata pelajaran dulu" under Kelas).
class _ChipPlaceholder extends StatelessWidget {
  const _ChipPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.selected, required this.onChanged});

  final LessonPlanMethod selected;
  final ValueChanged<LessonPlanMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // slate-100
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MethodChip(
              label: 'AI Generate',
              icon: Icons.auto_awesome_rounded,
              isSelected: selected == LessonPlanMethod.ai,
              activeColor: const Color(0xFF7C3AED), // violet-600
              onTap: () => onChanged(LessonPlanMethod.ai),
            ),
          ),
          Expanded(
            child: _MethodChip(
              label: 'Tulis Manual',
              icon: Icons.edit_rounded,
              isSelected: selected == LessonPlanMethod.manual,
              activeColor: const Color(0xFF0F172A), // slate-900
              onTap: () => onChanged(LessonPlanMethod.manual),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0F0F172A),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.placeholder,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _HeaderIconBadge extends StatelessWidget {
  const _HeaderIconBadge({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
