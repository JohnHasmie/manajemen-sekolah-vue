// Identity edit sheet — Frame E from
// `_design/teacher_rpp_edit_redesign.html`.
//
// Replaces the legacy LessonPlanFormDialog for the structured
// formats (k13 / rpp_1_halaman / modul_ajar). Edits the metadata
// fields only — title / kelas / mapel / semester / tahun ajaran.
// Section content is edited via showLessonPlanSectionEditorSheet
// (draggable sheet at 96% viewport) instead, so this sheet never
// touches `format_data`.
//
// File-format rows use LessonPlanUploadSheet in edit mode
// (Frame H) — both the file swap and metadata edits happen there.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

/// Result returned to the parent after the sheet closes. Carries the
/// updated metadata so the detail screen can rebuild without a
/// re-fetch. Null = user dismissed.
class IdentityEditResult {
  final Map<String, dynamic> updatedFields;
  const IdentityEditResult({required this.updatedFields});
}

/// Open the identity edit sheet for [lessonPlan].
///
/// `lessonPlan` is the current lesson-plan map (used to seed the
/// fields). Returns the patch payload on save, null on dismiss.
Future<IdentityEditResult?> showLessonPlanIdentityEditSheet({
  required BuildContext context,
  required Map<String, dynamic> lessonPlan,
  required String teacherId,
}) {
  return AppBottomSheet.show<IdentityEditResult>(
    context: context,
    title: 'Edit Identitas RPP',
    subtitle: 'Judul · kelas · mapel · semester · alokasi',
    icon: Icons.tune_rounded,
    primaryColor: ColorUtils.getRoleColor('guru'),
    contentPadding: EdgeInsets.zero,
    content: _IdentityEditContent(
      lessonPlan: lessonPlan,
      teacherId: teacherId,
    ),
  );
}

class _IdentityEditContent extends ConsumerStatefulWidget {
  const _IdentityEditContent({
    required this.lessonPlan,
    required this.teacherId,
  });

  final Map<String, dynamic> lessonPlan;
  final String teacherId;

  @override
  ConsumerState<_IdentityEditContent> createState() =>
      _IdentityEditContentState();
}

class _IdentityEditContentState extends ConsumerState<_IdentityEditContent> {
  late final TextEditingController _titleController;
  late String? _subjectId;
  late String? _subjectName;
  late String? _classId;
  late String? _className;
  late String _semester;
  late String _academicYear;
  String _timeAllocation = '2 JP × 45 menit';

  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];

  bool _isSaving = false;

  Color get _accent => ColorUtils.getRoleColor('guru');

  // ── Initial snapshot (used to detect dirty state) ──
  late final String _initialTitle;
  late final String? _initialSubjectId;
  late final String? _initialClassId;
  late final String _initialSemester;
  late final String _initialAcademicYear;
  late final String _initialTimeAllocation;

  @override
  void initState() {
    super.initState();
    final lp = widget.lessonPlan;
    _titleController = TextEditingController(
      text: (lp['title'] ?? lp['judul'] ?? '').toString(),
    );
    _subjectId = (lp['subject_id'] ?? '').toString();
    _subjectId = (_subjectId?.isEmpty ?? true) ? null : _subjectId;
    _subjectName = (lp['subject_name'] ??
            lp['mata_pelajaran_nama'] ??
            lp['subject']?['name'] ??
            '')
        .toString();
    _subjectName = _subjectName!.isEmpty ? null : _subjectName;
    _classId = (lp['class_id'] ?? '').toString();
    _classId = (_classId?.isEmpty ?? true) ? null : _classId;
    _className = (lp['class_name'] ??
            lp['kelas_nama'] ??
            lp['class']?['name'] ??
            '')
        .toString();
    _className = _className!.isEmpty ? null : _className;
    _semester = (lp['semester']?.toString() ?? '').isEmpty
        ? 'Ganjil'
        : lp['semester'].toString();
    _academicYear = (lp['academic_year']?.toString() ?? '').isEmpty
        ? currentAcademicYearString()
        : lp['academic_year'].toString();
    final ta = (lp['time_allocation']?.toString() ?? '').trim();
    if (ta.isNotEmpty) _timeAllocation = ta;

    _initialTitle = _titleController.text;
    _initialSubjectId = _subjectId;
    _initialClassId = _classId;
    _initialSemester = _semester;
    _initialAcademicYear = _academicYear;
    _initialTimeAllocation = _timeAllocation;

    _titleController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadSubjects();
    if (_subjectId != null) _loadClassesForSubject(_subjectId!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    return _titleController.text != _initialTitle ||
        _subjectId != _initialSubjectId ||
        _classId != _initialClassId ||
        _semester != _initialSemester ||
        _academicYear != _initialAcademicYear ||
        _timeAllocation != _initialTimeAllocation;
  }

  Future<void> _loadSubjects() async {
    try {
      final result = await ApiService()
          .get('/guru/${widget.teacherId}/mata-pelajaran');
      if (!mounted) return;
      setState(() {
        if (result is Map && result['data'] is List) {
          _subjects = result['data'];
        } else if (result is List) {
          _subjects = result;
        }
      });
    } catch (e) {
      AppLogger.error('rpp_identity', 'load subjects failed: $e');
    }
  }

  Future<void> _loadClassesForSubject(String subjectId) async {
    try {
      final result = await ApiService()
          .get('/class-by-mata-pelajaran?mata_pelajaran_id=$subjectId');
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
      AppLogger.error('rpp_identity', 'load classes failed: $e');
      if (mounted) setState(() => _classes = []);
    }
  }

  Future<void> _save() async {
    if (!_isDirty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final id = (widget.lessonPlan['id'] ?? '').toString();
      if (id.isEmpty) {
        throw Exception('ID RPP tidak ditemukan');
      }

      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'subject_id': _subjectId,
        'class_id': _classId,
        'semester': _semester,
        'academic_year': _academicYear,
      };
      // The backend ignores unknown keys (passes through Form Request
      // validation); time_allocation isn't a column today but adding
      // it here is safe — it'll be ignored cleanly.
      if (_timeAllocation.isNotEmpty) {
        payload['time_allocation'] = _timeAllocation;
      }

      await LessonPlanService.updateLessonPlan(id, payload);

      if (!mounted) return;
      AppNavigator.pop(
        context,
        IdentityEditResult(updatedFields: payload),
      );
    } catch (e) {
      AppLogger.error('rpp_identity', 'save failed: $e');
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal menyimpan: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Judul'),
              _textField(
                controller: _titleController,
                hint: 'Misal: Bab 4 · Trigonometri',
              ),
              _label('Mata pelajaran & kelas'),
              Row(
                children: [
                  Expanded(child: _buildSubjectField()),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: _buildClassField()),
                ],
              ),
              _label('Alokasi waktu'),
              FilterChipGrid<String>(
                options: const [
                  FilterOption(value: '1 JP × 45 menit', label: '1 JP'),
                  FilterOption(value: '2 JP × 45 menit', label: '2 JP'),
                  FilterOption(value: '2 JP × 40 menit', label: '2 JP · 40m'),
                  FilterOption(value: '4 JP × 45 menit', label: '4 JP'),
                ],
                selectedValue: _timeAllocation,
                onSelected: (v) => setState(
                  () => _timeAllocation = v ?? _timeAllocation,
                ),
                selectedColor: _accent,
              ),
              _label('Semester'),
              FilterChipGrid<String>(
                options: const [
                  FilterOption(value: 'Ganjil', label: 'Ganjil'),
                  FilterOption(value: 'Genap', label: 'Genap'),
                ],
                selectedValue: _semester,
                onSelected: (v) =>
                    setState(() => _semester = v ?? _semester),
                selectedColor: _accent,
              ),
              _label('Tahun ajaran'),
              FilterChipGrid<String>(
                options: [
                  for (final y in academicYearChipOptions())
                    FilterOption(value: y, label: y),
                ],
                selectedValue: _academicYear,
                onSelected: (v) =>
                    setState(() => _academicYear = v ?? _academicYear),
                selectedColor: _accent,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        BottomSheetFooter(
          primaryLabel: _isSaving ? 'Menyimpan…' : 'Simpan',
          primaryColor: _accent,
          primaryEnabled: _isDirty && !_isSaving,
          onPrimary: _save,
          onSecondary: _isSaving ? () {} : () => AppNavigator.pop(context),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: ColorUtils.slate700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: ColorUtils.slate400,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSubjectField() {
    return _PickerField(
      icon: Icons.menu_book_rounded,
      label: _subjectName ?? 'Pilih mapel',
      placeholder: _subjectName == null,
      onTap: () => _pickFromList(
        title: 'Pilih mapel',
        options: _subjects,
        labelOf: (s) =>
            (s['mata_pelajaran_nama'] ?? s['name'] ?? '-').toString(),
        idOf: (s) => (s['mata_pelajaran_id'] ?? s['id']).toString(),
        onPicked: (id, name) {
          setState(() {
            _subjectId = id;
            _subjectName = name;
            _classId = null;
            _className = null;
          });
          _loadClassesForSubject(id);
        },
      ),
    );
  }

  Widget _buildClassField() {
    return _PickerField(
      icon: Icons.school_rounded,
      label: _className ?? 'Pilih kelas',
      placeholder: _className == null,
      onTap: _subjectId == null
          ? null
          : () => _pickFromList(
                title: 'Pilih kelas',
                options: _classes,
                labelOf: (c) =>
                    (c['kelas_nama'] ?? c['name'] ?? '-').toString(),
                idOf: (c) => (c['kelas_id'] ?? c['id']).toString(),
                onPicked: (id, name) {
                  setState(() {
                    _classId = id;
                    _className = name;
                  });
                },
              ),
    );
  }

  Future<void> _pickFromList({
    required String title,
    required List<dynamic> options,
    required String Function(dynamic) labelOf,
    required String Function(dynamic) idOf,
    required void Function(String id, String label) onPicked,
  }) async {
    if (options.isEmpty) {
      SnackBarUtils.showError(context, 'Belum ada $title');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: ColorUtils.slate100),
                itemBuilder: (_, i) {
                  final opt = options[i];
                  final label = labelOf(opt);
                  return ListTile(
                    title: Text(label),
                    onTap: () {
                      onPicked(idOf(opt), label);
                      AppNavigator.pop(sheetCtx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: ColorUtils.slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: ColorUtils.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: placeholder
                        ? ColorUtils.slate400
                        : ColorUtils.slate900,
                    fontWeight:
                        placeholder ? FontWeight.w500 : FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: onTap == null
                    ? ColorUtils.slate200
                    : ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
