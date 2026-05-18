// Generate AI sheet — Frame D of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Single violet-themed AppDraggableSheet that replaces the previous
// two-step scope-picker → subject-picker flow. Body covers (top to
// bottom):
//   1. Cakupan Siswa — 3 radio tiles (Hanya berisiko default,
//      Semua siswa, Pilih per siswa).
//   2. Mata Pelajaran — multi-select FilterChipGrid sourced from the
//      class's subjects.
//   3. Periode — read-only chip showing the active academic year.
//   4. Token estimate banner — violet pill with the rough cost.
// Footer: Batal + violet **Generate** CTA.
//
// Returns a [GenerateConfig] when the teacher hits Generate, null
// when dismissed. The caller fans out one API call per selected
// subject (the existing `generateForClass` endpoint takes a single
// subject_id).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';

/// Picked outputs the host uses to dispatch the generate API call(s).
class GenerateConfig {
  /// One of: 'at_risk', 'all', 'per_student'.
  final String scope;

  /// Subject IDs the teacher chose. Always at least 1.
  final List<String> subjectIds;

  /// Hand-picked student IDs — only populated when [scope] is
  /// `'per_student'`. The host fans out one `generateForStudent`
  /// call per (studentId × subjectId) pair.
  final List<String> studentIds;

  GenerateConfig({
    required this.scope,
    required this.subjectIds,
    this.studentIds = const [],
  });
}

Future<GenerateConfig?> showRecommendationGenerateSheet({
  required BuildContext context,
  required String className,
  required int totalStudents,
  required int atRiskCount,
  required List<Map<String, String>> subjects,
  required String periodeLabel,

  /// Class roster — passed in so the inline `Pilih per siswa` picker
  /// can render without a second sheet. Each map needs at minimum
  /// `id` and `name`. When empty the per-student tile shows a hint
  /// asking the teacher to refresh.
  List<Map<String, String>> students = const [],
  int dailyUsage = 0,
  int dailyLimit = 10,
}) {
  return AppDraggableSheet.show<GenerateConfig>(
    context: context,
    initialSize: 0.85,
    minSize: 0.55,
    maxSize: 0.96,
    builder: (sheetContext, scrollController) => _RecommendationGenerateSheet(
      className: className,
      totalStudents: totalStudents,
      atRiskCount: atRiskCount,
      subjects: subjects,
      periodeLabel: periodeLabel,
      students: students,
      dailyUsage: dailyUsage,
      dailyLimit: dailyLimit,
      scrollController: scrollController,
    ),
  );
}

class _RecommendationGenerateSheet extends StatefulWidget {
  final String className;
  final int totalStudents;
  final int atRiskCount;
  final List<Map<String, String>> subjects;
  final String periodeLabel;
  final List<Map<String, String>> students;
  final int dailyUsage;
  final int dailyLimit;
  final ScrollController scrollController;

  const _RecommendationGenerateSheet({
    required this.className,
    required this.totalStudents,
    required this.atRiskCount,
    required this.subjects,
    required this.periodeLabel,
    required this.students,
    required this.dailyUsage,
    required this.dailyLimit,
    required this.scrollController,
  });

  @override
  State<_RecommendationGenerateSheet> createState() =>
      _RecommendationGenerateSheetState();
}

class _RecommendationGenerateSheetState
    extends State<_RecommendationGenerateSheet> {
  String _scope = 'at_risk';
  late Set<String> _selectedSubjectIds;
  Set<String> _selectedStudentIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Default: pre-select first subject so the teacher only needs one
    // tap to generate. Empty subjects list (which shouldn't happen in
    // practice) starts empty and disables the CTA.
    _selectedSubjectIds = widget.subjects.isNotEmpty
        ? {widget.subjects.first['id']!}
        : <String>{};
  }

  int get _scopeStudentCount {
    switch (_scope) {
      case 'all':
        return widget.totalStudents;
      case 'at_risk':
        return widget.atRiskCount;
      case 'per_student':
        return _selectedStudentIds.length;
      default:
        return widget.totalStudents;
    }
  }

  int get _estimatedRecCount {
    final perSubject = _scopeStudentCount;
    return perSubject * _selectedSubjectIds.length;
  }

  @override
  Widget build(BuildContext context) {
    final violet = ColorUtils.violet700;
    final hasEnoughStudents =
        _scope != 'per_student' || _selectedStudentIds.isNotEmpty;
    final canGenerate =
        _selectedSubjectIds.isNotEmpty &&
        hasEnoughStudents &&
        widget.dailyUsage < widget.dailyLimit;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          _buildGrabber(),
          _buildHeader(violet),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                const _FieldLabel('Cakupan Siswa'),
                const SizedBox(height: 6),
                _ScopeTile(
                  selected: _scope == 'at_risk',
                  title: 'Hanya berisiko',
                  subtitle:
                      'Siswa dengan rerata < KKM atau trend nilai turun. '
                      'Lebih hemat token AI.',
                  trailing: '${widget.atRiskCount} siswa',
                  trailingColor: ColorUtils.error600,
                  violet: violet,
                  onTap: () => setState(() => _scope = 'at_risk'),
                ),
                _ScopeTile(
                  selected: _scope == 'all',
                  title: 'Semua siswa',
                  subtitle:
                      'Termasuk siswa di atas KKM untuk apresiasi & '
                      'tantangan lanjutan.',
                  trailing: '${widget.totalStudents} siswa',
                  trailingColor: ColorUtils.brandCobalt,
                  violet: violet,
                  onTap: () => setState(() => _scope = 'all'),
                ),
                _ScopeTile(
                  selected: _scope == 'per_student',
                  title: 'Pilih per siswa',
                  subtitle: 'Pilih sendiri siswa mana yang dianalisa AI.',
                  trailing: _scope == 'per_student'
                      ? '${_selectedStudentIds.length} dipilih'
                      : null,
                  trailingColor: _scope == 'per_student' ? violet : null,
                  violet: violet,
                  onTap: () => setState(() => _scope = 'per_student'),
                ),
                if (_scope == 'per_student') ...[
                  const SizedBox(height: 8),
                  _buildStudentPicker(violet),
                ],
                const SizedBox(height: 14),
                const _FieldLabel('Mata Pelajaran', trailing: '· multi-select'),
                const SizedBox(height: 6),
                _buildSubjectGrid(violet),
                const SizedBox(height: 14),
                const _FieldLabel('Periode'),
                const SizedBox(height: 6),
                _buildPeriodChip(),
                const SizedBox(height: 14),
                _buildEstimateBanner(violet, canGenerate),
              ],
            ),
          ),
          BottomSheetFooter(
            primaryLabel: 'Generate',
            primaryColor: violet,
            primaryEnabled: canGenerate,
            onPrimary: () {
              Navigator.of(context).pop(
                GenerateConfig(
                  scope: _scope,
                  subjectIds: _selectedSubjectIds.toList(),
                  studentIds: _scope == 'per_student'
                      ? _selectedStudentIds.toList()
                      : const [],
                ),
              );
            },
            onSecondary: () => Navigator.of(context).pop(null),
            secondaryLabel: 'Batal',
          ),
        ],
      ),
    );
  }

  Widget _buildGrabber() => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: ColorUtils.slate200,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );

  Widget _buildHeader(Color violet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: violet.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 16, color: violet),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buat Rekomendasi AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelas ${widget.className} · ${widget.totalStudents} siswa',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: ColorUtils.slate500,
            ),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
    );
  }

  /// Inline student multi-picker that appears beneath the
  /// "Pilih per siswa" tile when active. Uses the same
  /// FilterChipGrid pattern as the subject picker so the brand
  /// vocabulary stays consistent.
  Widget _buildStudentPicker(Color violet) {
    if (widget.students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          border: Border.all(color: ColorUtils.slate200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: ColorUtils.slate500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Daftar siswa belum dimuat. Tarik ke bawah untuk refresh.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.04),
        border: Border.all(color: violet.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, size: 13, color: violet),
              const SizedBox(width: 6),
              Text(
                'PILIH SISWA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: violet,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedStudentIds.length == widget.students.length) {
                      _selectedStudentIds.clear();
                    } else {
                      _selectedStudentIds = widget.students
                          .map((s) => s['id'] ?? '')
                          .where((id) => id.isNotEmpty)
                          .toSet();
                    }
                  });
                },
                child: Text(
                  _selectedStudentIds.length == widget.students.length
                      ? 'Bersihkan'
                      : 'Pilih semua',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: violet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilterChipGrid<String>(
            options: widget.students
                .map(
                  (s) => FilterOption<String>(
                    value: s['id'] ?? '',
                    label: s['name'] ?? 'Siswa',
                  ),
                )
                .toList(),
            selectedValues: _selectedStudentIds,
            multiSelect: true,
            selectedColor: violet,
            onMultiSelected: (set) =>
                setState(() => _selectedStudentIds = Set<String>.from(set)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectGrid(Color violet) {
    if (widget.subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          border: Border.all(color: ColorUtils.slate200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Belum ada mata pelajaran terdaftar untuk kelas ini.',
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return FilterChipGrid<String>(
      options: widget.subjects
          .map(
            (s) => FilterOption<String>(
              value: s['id'] ?? '',
              label: s['name'] ?? 'Mata Pelajaran',
            ),
          )
          .toList(),
      selectedValues: _selectedSubjectIds,
      multiSelect: true,
      selectedColor: violet,
      onMultiSelected: (set) =>
          setState(() => _selectedSubjectIds = Set<String>.from(set)),
    );
  }

  Widget _buildPeriodChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: ColorUtils.brandCobalt,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.periodeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Periode aktif · data semester berjalan',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateBanner(Color violet, bool canGenerate) {
    final overLimit = widget.dailyUsage >= widget.dailyLimit;
    final accent = overLimit ? ColorUtils.error600 : violet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            overLimit
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  if (overLimit) ...[
                    const TextSpan(
                      text:
                          'Batas harian tercapai. Coba lagi besok atau hubungi admin sekolah.',
                    ),
                  ] else ...[
                    const TextSpan(text: 'Estimasi '),
                    TextSpan(
                      text: '~$_estimatedRecCount rekomendasi',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text:
                          ' · ${_selectedSubjectIds.length} mapel × $_scopeStudentCount siswa. '
                          'Anda telah pakai ${widget.dailyUsage}/${widget.dailyLimit} hari ini.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final String? trailing;
  final Color? trailingColor;
  final Color violet;
  final VoidCallback onTap;

  const _ScopeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
    required this.violet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? violet.withValues(alpha: 0.04) : Colors.white,
          border: Border.all(
            color: selected ? violet : ColorUtils.slate200,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? violet : Colors.white,
                border: Border.all(
                  color: selected ? violet : ColorUtils.slate300,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (trailingColor ?? violet).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: trailingColor ?? violet,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String? trailing;

  const _FieldLabel(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate700,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null)
            TextSpan(
              text: ' $trailing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate400,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}
