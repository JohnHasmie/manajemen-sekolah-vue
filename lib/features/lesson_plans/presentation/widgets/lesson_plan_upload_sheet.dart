// Frame G from the RPP mockup — dedicated upload-file flow.
//
// Replaces the legacy GenerateLessonPlanFormDialog/manual file path
// for `format=file` lesson plans. The sheet drives the full create
// flow in two steps:
//
//   1. Pick + upload a PDF/DOCX via `LessonPlanService.uploadLessonPlanFile`
//      — returns the storage path + size + mime.
//   2. Collect minimal metadata (title, class, subject, optional notes)
//      and POST to /rpp with `format: 'file'`.
//
// Slate brand color across header + footer to match the file format
// axis. Uses AppDraggableSheet so the keyboard pushes content up.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'dart:io';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
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

/// Result of the upload flow.
class LessonPlanUploadResult {
  /// The freshly-created `format=file` lesson plan as the API
  /// returned it. Pass to RPPDetailPage.show to open it immediately.
  final Map<String, dynamic> lessonPlan;
  const LessonPlanUploadResult({required this.lessonPlan});
}

/// Open the upload-file sheet.
///
/// **Create mode** (default) — `existingPlan: null`. Renders Frame G:
/// empty drop zone, blank metadata fields, builds a brand-new
/// `format=file` lesson plan via upload + POST /rpp.
///
/// **Edit mode** — pass `existingPlan: <current lesson plan map>`.
/// Pre-fills the metadata + shows the current file as a card with a
/// **Ganti file** primary action. When a new file is picked the old
/// one is rendered dashed/greyed below with an "Akan diganti"
/// warning. Save → uploads new file (if changed) + PATCHes /rpp/{id}
/// with the updated metadata. The backend's `UpdateLessonPlanAction`
/// auto-deletes the orphaned old file.
///
/// Returns null if dismissed, or the freshly created/updated
/// lesson-plan map on success.
Future<LessonPlanUploadResult?> showLessonPlanUploadSheet({
  required BuildContext context,
  required String teacherId,
  Map<String, dynamic>? existingPlan,
}) {
  return AppDraggableSheet.show<LessonPlanUploadResult>(
    context: context,
    builder: (sheetCtx, scrollController) => _LessonPlanUploadSheet(
      teacherId: teacherId,
      scrollController: scrollController,
      existingPlan: existingPlan,
    ),
  );
}

class _LessonPlanUploadSheet extends ConsumerStatefulWidget {
  const _LessonPlanUploadSheet({
    required this.teacherId,
    required this.scrollController,
    this.existingPlan,
  });

  final String teacherId;
  final ScrollController scrollController;

  /// Non-null → edit mode. The map is the current lesson-plan as the
  /// detail screen has it (returns from `/rpp/{id}` show endpoint).
  final Map<String, dynamic>? existingPlan;

  @override
  ConsumerState<_LessonPlanUploadSheet> createState() =>
      _LessonPlanUploadSheetState();
}

class _LessonPlanUploadSheetState
    extends ConsumerState<_LessonPlanUploadSheet> {
  // ── Picked file + upload response ──
  File? _pickedFile;
  String? _pickedFileName;
  int? _pickedFileSize;
  Map<String, dynamic>? _uploadResponse; // {file_path, file_url, ...}
  bool _isUploading = false;

  // ── Metadata ──
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String? _subjectId;
  String? _subjectName;
  String? _classId;
  String? _className;
  String _semester = 'Ganjil';
  late String _academicYear = currentAcademicYearString();

  // ── Loaded option lists ──
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];

  bool _isSubmitting = false;

  // ── Edit-mode snapshot ──
  /// True when `existingPlan` is non-null. Drives "Ganti file" CTA
  /// + PATCH-instead-of-POST save behavior + dirty-detection.
  bool get _isEditMode => widget.existingPlan != null;

  /// Original metadata snapshot — used to disable Simpan when no
  /// field has changed and no new file is picked.
  late final String _initialTitle;
  late final String? _initialSubjectId;
  late final String? _initialClassId;
  late final String _initialSemester;
  late final String _initialAcademicYear;
  late final String _initialNotes;

  /// Existing-file display (edit mode only). Read directly from
  /// `existingPlan` so the file-card shows the live values.
  String? get _existingFileName {
    final raw = widget.existingPlan?['file_name'];
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  int? get _existingFileSize {
    final raw = widget.existingPlan?['file_size'];
    return raw is num ? raw.toInt() : null;
  }

  bool get _isDirty {
    if (_uploadResponse != null) return true; // new file picked
    if (!_isEditMode) return _uploadResponse != null;
    return _titleController.text != _initialTitle ||
        _subjectId != _initialSubjectId ||
        _classId != _initialClassId ||
        _semester != _initialSemester ||
        _academicYear != _initialAcademicYear ||
        _notesController.text != _initialNotes;
  }

  @override
  void initState() {
    super.initState();
    _hydrateFromExisting();
    _titleController.addListener(_onChanged);
    _notesController.addListener(_onChanged);
    _loadSubjects();
    if (_isEditMode && _subjectId != null) {
      _loadClassesForSubject(_subjectId!);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _hydrateFromExisting() {
    final existing = widget.existingPlan;
    if (existing == null) {
      _initialTitle = '';
      _initialSubjectId = null;
      _initialClassId = null;
      _initialSemester = _semester;
      _initialAcademicYear = _academicYear;
      _initialNotes = '';
      return;
    }

    _titleController.text = (existing['title'] ?? existing['judul'] ?? '')
        .toString();

    final subjectId = (existing['subject_id'] ?? '').toString();
    final classId = (existing['class_id'] ?? '').toString();
    _subjectId = subjectId.isEmpty ? null : subjectId;
    _subjectName =
        (existing['subject_name'] ??
                existing['mata_pelajaran_nama'] ??
                existing['subject']?['name'] ??
                '')
            .toString();
    if (_subjectName!.isEmpty) _subjectName = null;
    _classId = classId.isEmpty ? null : classId;
    _className =
        (existing['class_name'] ??
                existing['kelas_nama'] ??
                existing['class']?['name'] ??
                '')
            .toString();
    if (_className!.isEmpty) _className = null;

    final semester = (existing['semester']?.toString() ?? '').trim();
    if (semester.isNotEmpty) _semester = semester;
    final ay = (existing['academic_year']?.toString() ?? '').trim();
    if (ay.isNotEmpty) _academicYear = ay;
    final notes = (existing['notes'] ?? existing['catatan'] ?? '').toString();
    _notesController.text = notes;

    _initialTitle = _titleController.text;
    _initialSubjectId = _subjectId;
    _initialClassId = _classId;
    _initialSemester = _semester;
    _initialAcademicYear = _academicYear;
    _initialNotes = _notesController.text;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
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
      AppLogger.error('rpp_upload', 'Failed to load subjects: $e');
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
      AppLogger.error('rpp_upload', 'Failed to load classes: $e');
      if (mounted) setState(() => _classes = []);
    }
  }

  // ── Pickers ──

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.path == null) return;

      // Upload starts immediately so the metadata fields fill while
      // the network round-trip happens.
      setState(() {
        _pickedFile = File(file.path!);
        _pickedFileName = file.name;
        _pickedFileSize = file.size;
        _isUploading = true;
        _uploadResponse = null;
      });

      final response = await LessonPlanService.uploadLessonPlanFile(
        _pickedFile!,
      );
      if (!mounted) return;
      setState(() {
        _uploadResponse = response;
        _isUploading = false;
        // Auto-fill the title from the file name (without extension)
        // if the teacher hasn't typed one yet.
        if (_titleController.text.isEmpty) {
          final base = (_pickedFileName ?? '').replaceAll(
            RegExp(r'\.(pdf|docx?|jpe?g|png)$', caseSensitive: false),
            '',
          );
          _titleController.text = base;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadResponse = null;
        _pickedFile = null;
        _pickedFileName = null;
        _pickedFileSize = null;
      });
      SnackBarUtils.showError(context, 'Upload gagal: $e');
    }
  }

  void _removeFile() {
    setState(() {
      _pickedFile = null;
      _pickedFileName = null;
      _pickedFileSize = null;
      _uploadResponse = null;
    });
  }

  bool get _canSubmit {
    if (_isSubmitting || _isUploading) return false;
    if (_subjectId == null || _classId == null) return false;
    if (_titleController.text.trim().isEmpty) return false;
    if (_isEditMode) {
      // Edit mode: a new file is optional — saving metadata-only
      // edits is fine. Just require *some* change vs the snapshot.
      return _isDirty;
    }
    // Create mode: a new file is mandatory.
    return _uploadResponse != null;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final raw = _isEditMode
          ? await _patchExisting()
          : await LessonPlanService.createFileFormatLessonPlan(
              teacherId: widget.teacherId,
              subjectId: _subjectId!,
              classId: _classId,
              title: _titleController.text.trim(),
              uploadResponse: _uploadResponse!,
              semester: _semester,
              academicYear: _academicYear,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

      Map<String, dynamic> data;
      if (raw is Map<String, dynamic>) {
        final inner = raw['data'];
        data = inner is Map<String, dynamic> ? inner : raw;
      } else {
        data = <String, dynamic>{};
      }
      // Edit mode patches in place. Merge the API response onto the
      // existing plan so unchanged fields aren't lost (the PATCH
      // response sometimes only echoes the touched columns).
      if (_isEditMode) {
        final base = Map<String, dynamic>.from(widget.existingPlan!);
        base.addAll(data);
        data = base;
      }
      // Make sure the format field is present so the dispatcher
      // routes to the file detail.
      data.putIfAbsent('format', () => LessonPlanFormat.file.value);

      if (!mounted) return;
      AppNavigator.pop(context, LessonPlanUploadResult(lessonPlan: data));
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal menyimpan: $e');
      setState(() => _isSubmitting = false);
    }
  }

  /// Edit-mode save — PATCH only the changed fields. When a new file
  /// was picked, the upload already completed in `_pickAndUploadFile`,
  /// so we just bundle the new file_path/name/size/mime alongside the
  /// metadata patch. The backend's UpdateLessonPlanAction auto-deletes
  /// the orphaned old file from storage.
  Future<dynamic> _patchExisting() async {
    final id = (widget.existingPlan!['id'] ?? '').toString();
    if (id.isEmpty) {
      throw Exception('ID RPP tidak ditemukan');
    }
    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'subject_id': _subjectId,
      'class_id': _classId,
      'semester': _semester,
      'academic_year': _academicYear,
    };
    final note = _notesController.text.trim();
    body['notes'] = note.isEmpty ? null : note;

    if (_uploadResponse != null) {
      body['file_path'] = _uploadResponse!['file_path'];
      body['file_name'] = _uploadResponse!['file_name'];
      body['file_size'] = _uploadResponse!['file_size'];
      body['file_mime'] = _uploadResponse!['file_mime'];
    }

    return LessonPlanService.updateLessonPlan(id, body);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    // Cobalt header — keeps the upload sheet visually consistent
    // with the rest of the teacher chrome (Presensi, Kegiatan,
    // Rekap Nilai). The FILE format is communicated by the kicker
    // text + the file-icon avatar, not by a slate page chrome.
    final brand = ColorUtils.getRoleColor('guru');
    final brandDark = ColorUtils.brandDarkBlue;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(brand, brandDark),
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
                // ── File zone — three states ──
                //   1. No file picked (create mode) → drop zone
                //   2. Edit mode, no replacement yet → existing file
                //      card with "Ganti file" CTA
                //   3. New file picked → fresh file card with BARU
                //      tag + (edit mode only) old-file warning below
                if (_pickedFile == null && !_isEditMode)
                  _UploadDropZone(onTap: _pickAndUploadFile)
                else if (_pickedFile == null && _isEditMode)
                  _ExistingFileCard(
                    fileName: _existingFileName ?? 'File terlampir',
                    fileSize: _existingFileSize ?? 0,
                    onReplace: _pickAndUploadFile,
                    accent: ColorUtils.getRoleColor('guru'),
                  )
                else ...[
                  _SelectedFileCard(
                    fileName: _pickedFileName ?? 'File',
                    fileSize: _pickedFileSize ?? 0,
                    isUploading: _isUploading,
                    isReplacement: _isEditMode,
                    onRemove: _isUploading ? null : _removeFile,
                  ),
                  if (_isEditMode &&
                      !_isUploading &&
                      _existingFileName != null) ...[
                    const SizedBox(height: 6),
                    _OldFileWarning(
                      fileName: _existingFileName!,
                      fileSize: _existingFileSize ?? 0,
                    ),
                  ],
                ],

                const SizedBox(height: AppSpacing.sm),

                _fieldLabel('Judul'),
                _TextField(
                  controller: _titleController,
                  placeholder: 'Misal: Bab 5 · Teks Eksplanasi',
                  onChanged: (_) => setState(() {}),
                ),

                // ── Mata pelajaran (chip select) ──
                _fieldLabel('Mata pelajaran'),
                _buildSubjectChips(brand),

                // ── Kelas (chip select, depends on subject) ──
                _fieldLabel('Kelas'),
                _buildClassChips(brand),

                // ── Semester ──
                _fieldLabel('Semester'),
                FilterChipGrid<String>(
                  options: const [
                    FilterOption(value: 'Ganjil', label: 'Ganjil'),
                    FilterOption(value: 'Genap', label: 'Genap'),
                  ],
                  selectedValue: _semester,
                  onSelected: (v) => setState(() => _semester = v ?? _semester),
                  selectedColor: brand,
                ),

                // ── Tahun ajaran ──
                _fieldLabel('Tahun ajaran'),
                FilterChipGrid<String>(
                  options: [
                    for (final y in academicYearChipOptions())
                      FilterOption(value: y, label: y),
                  ],
                  selectedValue: _academicYear,
                  onSelected: (v) =>
                      setState(() => _academicYear = v ?? _academicYear),
                  selectedColor: brand,
                ),

                _fieldLabel('Catatan singkat (opsional)'),
                _TextField(
                  controller: _notesController,
                  placeholder:
                      'Misal: revisi versi 2025, sumber Buku Siswa hal. 88…',
                  minLines: 3,
                  maxLines: 6,
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          BottomSheetFooter(
            primaryLabel: _isUploading
                ? 'Mengunggah file…'
                : (_isSubmitting
                      ? 'Menyimpan…'
                      : (_isEditMode && _uploadResponse != null
                            ? 'Simpan ganti file'
                            : 'Simpan')),
            // Cobalt for both modes — keeps the button consistent
            // with the rest of the teacher chrome regardless of
            // whether we're creating or editing.
            primaryColor: ColorUtils.getRoleColor('guru'),
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

  Widget _buildHeader(Color brand, Color brandDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandDark, brand],
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
              _HeaderIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => AppNavigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'RPP · EDIT FILE' : 'RPP · UPLOAD FILE',
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
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditMode
                              ? 'Edit RPP File'
                              : 'Lampirkan PDF / DOCX',
                          style: const TextStyle(
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
              const _HeaderIcon(icon: Icons.upload_rounded, onTap: null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
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

  // ── Chip-grid field builders (matches setup sheet pattern) ──
  //
  // Replaces the legacy `_PickerField` + `_pickFromList` modal
  // pickers with the shared `FilterChipGrid` so the form looks
  // continuous with the alokasi / semester / tahun ajaran chip rows
  // below. Empty / locked states render a slate-tinted placeholder
  // so the layout doesn't collapse when a dependent list isn't loaded
  // yet (e.g. kelas before mapel is picked).

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
          // Reset kelas — it belongs to the previous subject's tree.
          _classId = null;
          _className = null;
          _classes = [];
        });
        _loadClassesForSubject(id);
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
}

/// Slate-tinted hint rendered in place of an empty `FilterChipGrid` so
/// the form keeps its rhythm even when a dependent list is locked or
/// hasn't loaded yet.
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

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const slate100 = Color(0xFFF1F5F9);
    const slate300 = Color(0xFFCBD5E1);
    const slate500 = Color(0xFF64748B);
    const slate900 = Color(0xFF0F172A);
    const cobalt = Color(0xFF1B6FB8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC), // slate-50
            border: Border.all(
              color: slate300,
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: slate100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  size: 20,
                  color: cobalt,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pilih file dari perangkat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PDF, DOC, DOCX · Maks 10 MB',
                style: TextStyle(fontSize: 11, color: slate500, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cobalt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Pilih file',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({
    required this.fileName,
    required this.fileSize,
    required this.isUploading,
    required this.onRemove,
    this.isReplacement = false,
  });

  final String fileName;
  final int fileSize;
  final bool isUploading;
  final VoidCallback? onRemove;

  /// Edit-mode flag — tints the card emerald and adds a `BARU` chip
  /// so the teacher can see at a glance this is the replacement file.
  final bool isReplacement;

  String get _humanSize {
    if (fileSize <= 0) return '-';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    const red50 = Color(0xFFFEE2E2);
    const red600 = Color(0xFFB91C1C);
    const slate100 = Color(0xFFF1F5F9);
    const slate200 = Color(0xFFE2E8F0);
    const slate500 = Color(0xFF64748B);
    const slate900 = Color(0xFF0F172A);
    const green50 = Color(0xFFDCFCE7);
    const green600 = Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReplacement ? green50.withValues(alpha: 0.45) : Colors.white,
        border: Border.all(
          color: isReplacement ? green600 : slate200,
          width: isReplacement ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: red50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 20,
              color: red600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReplacement)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: green600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BARU',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isUploading
                      ? '$_humanSize · mengunggah…'
                      : (isReplacement
                            ? '$_humanSize · siap diunggah'
                            : _humanSize),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isReplacement ? green600 : slate500,
                  ),
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: red600),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              style: IconButton.styleFrom(
                backgroundColor: slate100,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
        ],
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

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

/// Existing-file card shown in edit mode when no replacement has
/// been picked yet. The single primary action is "Ganti file" — tap
/// opens the picker and the card morphs into the [_SelectedFileCard]
/// with `isReplacement: true`.
class _ExistingFileCard extends StatelessWidget {
  const _ExistingFileCard({
    required this.fileName,
    required this.fileSize,
    required this.onReplace,
    required this.accent,
  });

  final String fileName;
  final int fileSize;
  final VoidCallback onReplace;
  final Color accent;

  String get _humanSize {
    if (fileSize <= 0) return 'file saat ini';
    if (fileSize < 1024) return '$fileSize B · file saat ini';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB · file saat ini';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB · file saat ini';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 18,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _humanSize,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: accent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onReplace,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Ganti file',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
  }
}

/// Old-file warning shown beneath the new [_SelectedFileCard] when a
/// teacher has picked a replacement during edit mode. Greyed out,
/// dashed border, single line — purely informational so the teacher
/// can confirm what's about to be removed.
class _OldFileWarning extends StatelessWidget {
  const _OldFileWarning({required this.fileName, required this.fileSize});

  final String fileName;
  final int fileSize;

  String get _humanSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return ' · $fileSize B';
    if (fileSize < 1024 * 1024) {
      return ' · ${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return ' · ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          style: BorderStyle.solid,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            size: 13,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                  height: 1.3,
                ),
                children: [
                  const TextSpan(
                    text: 'Akan diganti: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '$fileName$_humanSize'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
