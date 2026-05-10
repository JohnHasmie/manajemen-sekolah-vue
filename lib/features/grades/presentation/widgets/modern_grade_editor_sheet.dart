// Modern grade editor — a single, self-contained modal bottom sheet that
// replaces the old full-screen `GradeInputForm` + its four ad-hoc mixins.
//
// Why this file exists
// --------------------
// The old flow had the teacher tap a grade cell, which pushed a whole new
// Scaffold (`GradeInputForm`) built from four mixins (`GradeFormDataMixin`,
// `GradeFormUIBuilderMixin`, `GradeFormBuilderMixin`, `GradeFormSubmissionMixin`).
// The mixins spread ~650 lines across five files, hid the save/update branch
// behind indirection, and the full-screen push felt heavy for a single-score
// edit. A bottom sheet keeps the grade book context visible underneath and
// lets teachers crank through edits faster.
//
// Design
// ------
// - Draggable bottom sheet, Material-3 surface, big score hero at the top.
// - Live predikat preview (A/B/C/D) + colored progress bar — teachers get
//   instant feedback on what grade the score maps to.
// - Stepper buttons (-5, -1, +1, +5) so score tweaks don't require the keyboard.
// - Collapsible "Detail lainnya" section holds the rarely-changed fields
//   (title, date, notes) so the common case (type a score, tap Save) stays
//   one-glance.
// - Save + Delete in a sticky footer that respects the keyboard inset.
//
// Consumers
// ---------
// Call the static `show()` helper — it wires up `showModalBottomSheet` with
// the right defaults (`isScrollControlled`, transparent background, keyboard
// inset handling). `grade_book_navigation_mixin.dart` is the only caller.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/drag_handle.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/modern_grade_editor_parts.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Result returned when the sheet closes. `saved` is true when the teacher
/// successfully created/updated/deleted a grade — callers use it to decide
/// whether to refresh the grade book.
class GradeEditorResult {
  final bool saved;
  const GradeEditorResult({this.saved = false});
}

class ModernGradeEditorSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Student student;
  final String gradeType;
  final Map<String, dynamic>? existingGrade;
  final dynamic assessmentId;
  final DateTime? initialDate;
  final String? initialTitle;

  const ModernGradeEditorSheet({
    super.key,
    required this.teacher,
    required this.subject,
    required this.student,
    required this.gradeType,
    this.existingGrade,
    this.assessmentId,
    this.initialDate,
    this.initialTitle,
  });

  /// Opens this sheet as a modal. Returns a [GradeEditorResult] describing
  /// whether any grade data changed so the caller can refresh.
  static Future<GradeEditorResult?> show({
    required BuildContext context,
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> subject,
    required Student student,
    required String gradeType,
    Map<String, dynamic>? existingGrade,
    dynamic assessmentId,
    DateTime? initialDate,
    String? initialTitle,
  }) {
    return showModalBottomSheet<GradeEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ModernGradeEditorSheet(
        teacher: teacher,
        subject: subject,
        student: student,
        gradeType: gradeType,
        existingGrade: existingGrade,
        assessmentId: assessmentId,
        initialDate: initialDate,
        initialTitle: initialTitle,
      ),
    );
  }

  @override
  ConsumerState<ModernGradeEditorSheet> createState() =>
      _ModernGradeEditorSheetState();
}

class _ModernGradeEditorSheetState
    extends ConsumerState<ModernGradeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _scoreFocus = FocusNode();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _showDetails = false;

  /// Current score parsed from the text field. Drives the live predikat
  /// preview and the colored ring on the hero card. Falls back to null
  /// while the field is empty or holds a non-numeric value (the user is
  /// mid-edit) so we don't flash a misleading predikat.
  int? get _currentScore {
    final raw = _scoreController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  bool get _isEditing => widget.existingGrade != null;

  bool get _isReadOnly => ref.read(academicYearRiverpod).isReadOnly;

  @override
  void initState() {
    super.initState();
    _hydrateFromExisting();
    // Always start with details collapsed ("sembunyikan detail" by default),
    // including in the edit flow. The hero score card is the focus; title,
    // date, and notes stay tucked away until the teacher explicitly asks
    // for them.
    _showDetails = false;
    _scoreController.addListener(() => setState(() {}));

    // Auto-focus the score field on new entries; for edits, let the teacher
    // read the existing score first and tap in if they want to change it.
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scoreFocus.requestFocus();
      });
    }
  }

  void _hydrateFromExisting() {
    final grade = widget.existingGrade;
    if (grade != null) {
      _scoreController.text = (grade['score'] ?? grade['nilai'] ?? '')
          .toString();
      _notesController.text = grade['deskripsi']?.toString() ?? '';
      _titleController.text = grade['title']?.toString() ?? '';
      final dateStr = grade['tanggal']?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          _selectedDate = DateTime.parse(dateStr);
        } catch (_) {
          // Leave _selectedDate at now(); API will reject bad formats anyway.
        }
      }
    } else {
      if (widget.initialDate != null) _selectedDate = widget.initialDate!;
      if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
        _titleController.text = widget.initialTitle!;
      }
    }

    // Ensure the title is never empty — if we have no existing title, seed
    // a sensible default using the grade-type label so downstream reports
    // don't show "—" rows.
    if (_titleController.text.trim().isEmpty) {
      final lang = ref.read(languageRiverpod);
      _titleController.text = 'Nilai ${_typeLabel(widget.gradeType, lang)}';
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _scoreFocus.dispose();
    super.dispose();
  }

  // --- Score math helpers -------------------------------------------------

  /// Indonesian-school predikat mapping. Mirrors the thresholds used on the
  /// grade recap screen so teachers see the same letter grade in both places.
  ({String letter, Color color, String label}) _predikat(int? score) =>
      modernGradeEditorPredikat(score);

  void _bumpScore(int delta) {
    HapticFeedback.selectionClick();
    final current = _currentScore ?? 0;
    final next = (current + delta).clamp(0, 100);
    setState(() {
      _scoreController.text = next.toString();
      _scoreController.selection = TextSelection.fromPosition(
        TextPosition(offset: _scoreController.text.length),
      );
    });
  }

  // --- Labels -------------------------------------------------------------

  String _typeLabel(String type, LanguageProvider lang) {
    switch (type) {
      case 'uh':
        return lang.getTranslatedText({'en': 'Daily', 'id': 'UH'});
      case 'tugas':
        return lang.getTranslatedText({'en': 'Assignment', 'id': 'Tugas'});
      case 'uts':
        return lang.getTranslatedText({'en': 'Midterm', 'id': 'UTS'});
      case 'uas':
        return lang.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return lang.getTranslatedText({'en': 'Midterm Exam', 'id': 'PTS'});
      case 'pas':
        return lang.getTranslatedText({'en': 'Final Exam', 'id': 'PAS'});
      default:
        return type.toUpperCase();
    }
  }

  Color _primaryColor() {
    return ColorUtils.getRoleColor(Teacher.fromJson(widget.teacher).role);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --- Actions ------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showModernDatePicker(
      context: context,
      initialDate: _selectedDate,
      title: ref.read(languageRiverpod).getTranslatedText({
        'en': 'Pick Grade Date',
        'id': 'Pilih Tanggal Nilai',
      }),
      primaryColor: _primaryColor(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final lang = ref.read(languageRiverpod);

    if (_isReadOnly) {
      SnackBarUtils.showError(
        context,
        lang.getTranslatedText({
          'en': 'Cannot save grades for an inactive academic year',
          'id':
              'Tidak dapat menyimpan nilai untuk tahun ajaran yang tidak aktif',
        }),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Guard: the API requires a non-null student_class_id. When the cached
    // student row is missing one (e.g. cache predates the AY-pivot fix),
    // the POST comes back as a 422 — surface a clearer hint pointing to
    // pull-to-refresh instead of the cryptic API error.
    if (widget.student.studentClassId == null ||
        widget.student.studentClassId!.isEmpty) {
      SnackBarUtils.showError(
        context,
        lang.getTranslatedText({
          'en': 'Student data is outdated. Pull to refresh and try again.',
          'id':
              'Data siswa kadaluarsa. Tarik untuk memuat ulang dan coba lagi.',
        }),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'student_id': widget.student.id,
        'student_class_id': widget.student.studentClassId,
        'teacher_id': Teacher.fromJson(widget.teacher).id,
        'subject_id': widget.subject['id'],
        'type': widget.gradeType,
        'assessment_id':
            widget.assessmentId ?? widget.existingGrade?['assessment_id'],
        'score': int.parse(_scoreController.text.trim()),
        'notes': _notesController.text.trim(),
        'title': _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        'date': _formatDate(_selectedDate),
      };

      if (_isEditing) {
        await GradeService.updateGrade(widget.existingGrade!['id'], payload);
      } else {
        await GradeService.createGrade(payload);
      }

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({
          'en': _isEditing ? 'Grade updated' : 'Grade saved',
          'id': _isEditing
              ? 'Nilai berhasil diupdate'
              : 'Nilai berhasil disimpan',
        }),
      );
      Navigator.of(context).pop(const GradeEditorResult(saved: true));
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final lang = ref.read(languageRiverpod);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang.getTranslatedText({
            'en': 'Delete this grade?',
            'id': 'Hapus nilai ini?',
          }),
        ),
        content: Text(
          lang.getTranslatedText({
            'en':
                'The score will be removed from the grade book. This cannot be undone.',
            'id':
                'Nilai akan dihapus dari buku nilai. Tindakan ini tidak bisa dibatalkan.',
          }),
          style: TextStyle(color: ColorUtils.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      // Delete = zero-out the score via update. We don't expose a hard
      // single-grade DELETE route on purpose — batch deletes go through
      // `deleteAssessmentBatch`. Setting score to null keeps the row but
      // removes it from averages and the card view's chip list.
      await GradeService.updateGrade(widget.existingGrade!['id'], {
        'score': null,
      });
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({'en': 'Grade cleared', 'id': 'Nilai dihapus'}),
      );
      Navigator.of(context).pop(const GradeEditorResult(saved: true));
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final primary = _primaryColor();
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandHeader(lang, primary),
              Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStudentStrip(lang, primary),
                      const SizedBox(height: AppSpacing.lg),
                      ModernGradeEditorScoreHero(
                        score: _currentScore,
                        lang: lang,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildScoreFieldRow(lang, primary),
                      const SizedBox(height: AppSpacing.sm),
                      _buildStepperRow(primary),
                      const SizedBox(height: AppSpacing.md),
                      _buildDetailsToggle(lang, primary),
                      if (_showDetails) ...[
                        const SizedBox(height: AppSpacing.md),
                        _buildTitleField(lang, primary),
                        const SizedBox(height: AppSpacing.md),
                        _buildDateField(lang, primary),
                        const SizedBox(height: AppSpacing.md),
                        _buildNotesField(lang, primary),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
              ModernGradeEditorFooter(
                lang: lang,
                primary: primary,
                isEditing: _isEditing,
                isReadOnly: _isReadOnly,
                isSaving: _isSaving,
                isDeleting: _isDeleting,
                onSave: _save,
                onDelete: _confirmDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cobalt gradient brand header — replaces the legacy white top
  /// bar (small primary-tinted "TUGAS" pill + slate-800 "Ubah
  /// Nilai"). Matches the same chrome used by RPP / Presensi /
  /// Kegiatan Kelas sheets so the editor feels native to the new
  /// teacher tool kit.
  Widget _buildBrandHeader(LanguageProvider lang, Color primary) {
    final cobaltDark = Color.lerp(primary, Colors.black, 0.18) ?? primary;
    final typeLabel = _typeLabel(widget.gradeType, lang).toUpperCase();
    final title = _isEditing
        ? lang.getTranslatedText({'en': 'Edit Grade', 'id': 'Ubah Nilai'})
        : lang.getTranslatedText({'en': 'Input Grade', 'id': 'Input Nilai'});
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cobaltDark, primary],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'NILAI · $typeLabel',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.78),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(LanguageProvider lang, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined, size: 13, color: primary),
                const SizedBox(width: 6),
                Text(
                  _typeLabel(widget.gradeType, lang).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEditing
                  ? lang.getTranslatedText({
                      'en': 'Edit Grade',
                      'id': 'Ubah Nilai',
                    })
                  : lang.getTranslatedText({
                      'en': 'Input Grade',
                      'id': 'Input Nilai',
                    }),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: ColorUtils.slate500),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: lang.getTranslatedText({'en': 'Close', 'id': 'Tutup'}),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStrip(LanguageProvider lang, Color primary) {
    final subject = Subject.fromJson(widget.subject).name;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primary.withValues(alpha: 0.75)],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              // 2-letter initials for visual consistency with the
              // class+subject card avatars and the create-assessment
              // dialog. The Student model's built-in `initials` getter
              // only returns the first letter — works for the legacy
              // avatar but reads as a typo next to "AA / BS / DK"
              // initials elsewhere.
              _twoLetterInitials(widget.student.name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.student.studentNumber.isNotEmpty ? "${widget.student.studentNumber} · " : ""}$subject',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: ColorUtils.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreFieldRow(LanguageProvider lang, Color primary) {
    return TextFormField(
      controller: _scoreController,
      focusNode: _scoreFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate900,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: lang.getTranslatedText({
          'en': 'Score (0-100)',
          'id': 'Nilai (0-100)',
        }),
        labelStyle: TextStyle(color: ColorUtils.slate500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      validator: (raw) {
        final v = raw?.trim() ?? '';
        if (v.isEmpty) {
          return lang.getTranslatedText({
            'en': 'Enter a score',
            'id': 'Masukkan nilai',
          });
        }
        final n = int.tryParse(v);
        if (n == null) {
          return lang.getTranslatedText({
            'en': 'Must be a whole number',
            'id': 'Harus angka bulat',
          });
        }
        if (n < 0 || n > 100) {
          return lang.getTranslatedText({
            'en': 'Must be between 0 and 100',
            'id': 'Harus antara 0 dan 100',
          });
        }
        return null;
      },
    );
  }

  Widget _buildStepperRow(Color primary) {
    // Four steppers so teachers can dial in a score with zero keyboard taps.
    // Order is -5, -1, +1, +5 — mirrors the +/- cluster on a calculator.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepperButton('-5', -5, primary),
        _stepperButton('-1', -1, primary),
        _stepperButton('+1', 1, primary),
        _stepperButton('+5', 5, primary),
      ],
    );
  }

  /// Cobalt-tinted pill stepper. Plus deltas tint stronger so they
  /// read as primary actions, minus deltas stay slate-on-cobalt for
  /// contrast.
  Widget _stepperButton(String label, int delta, Color primary) {
    final isPlus = delta > 0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _bumpScore(delta),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isPlus
                    ? primary.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPlus
                      ? primary.withValues(alpha: 0.30)
                      : ColorUtils.slate200,
                ),
                boxShadow: isPlus
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: isPlus ? primary : ColorUtils.slate700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Inline cobalt-tinted chip toggle for the optional Detail
  /// lainnya section. Replaces the legacy bare row of icon+text so
  /// the affordance reads as an interactive control.
  Widget _buildDetailsToggle(LanguageProvider lang, Color primary) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _showDetails = !_showDetails),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _showDetails
                ? primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _showDetails
                  ? primary.withValues(alpha: 0.25)
                  : ColorUtils.slate200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showDetails
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: primary,
              ),
              const SizedBox(width: 4),
              Text(
                lang.getTranslatedText({
                  'en': _showDetails ? 'Hide details' : 'More details',
                  'id': _showDetails ? 'Sembunyikan detail' : 'Detail lainnya',
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(LanguageProvider lang, Color primary) {
    return _labeledField(
      label: lang.getTranslatedText({
        'en': 'Assessment Title',
        'id': 'Judul Penilaian',
      }),
      icon: Icons.title_rounded,
      primary: primary,
      child: TextFormField(
        controller: _titleController,
        decoration: _inputDecoration(
          hint: lang.getTranslatedText({
            'en': 'e.g. Quiz 1, Midterm Project',
            'id': 'cth. Ulangan 1, Proyek UTS',
          }),
          primary: primary,
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate900),
      ),
    );
  }

  Widget _buildDateField(LanguageProvider lang, Color primary) {
    final formatted =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    return _labeledField(
      label: lang.getTranslatedText({
        'en': 'Assessment Date',
        'id': 'Tanggal Penilaian',
      }),
      icon: Icons.calendar_today_rounded,
      primary: primary,
      // Cobalt-tinted tap target instead of the legacy white-with-
      // slate-border field. Matches the date chip in the create-
      // assessment dialog so the two surfaces feel like one design.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(Icons.edit_calendar_outlined, size: 16, color: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField(LanguageProvider lang, Color primary) {
    return _labeledField(
      label: lang.getTranslatedText({
        'en': 'Notes (optional)',
        'id': 'Catatan (opsional)',
      }),
      icon: Icons.sticky_note_2_outlined,
      primary: primary,
      child: TextFormField(
        controller: _notesController,
        maxLines: 3,
        decoration: _inputDecoration(
          hint: lang.getTranslatedText({
            'en': 'Short feedback for this score…',
            'id': 'Catatan singkat untuk nilai ini…',
          }),
          primary: primary,
        ),
        style: TextStyle(fontSize: 13.5, color: ColorUtils.slate800),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required Color primary,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: ColorUtils.slate400,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
    );
  }

  /// Labeled section header — small cobalt icon + slate uppercase
  /// label with letter-spacing. Matches the `_fieldLabel` style used
  /// in the RPP setup / upload sheets so all teacher form sections
  /// read the same.
  Widget _labeledField({
    required String label,
    required IconData icon,
    required Color primary,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 12, color: primary),
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// 1-2 character initials for the avatar. Same logic as the
  /// student card list / create-assessment dialog helpers — picks
  /// the first letter of the first two whitespace-separated tokens;
  /// falls back to the first two letters of single-word names; falls
  /// back to "?" for empty.
  String _twoLetterInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
