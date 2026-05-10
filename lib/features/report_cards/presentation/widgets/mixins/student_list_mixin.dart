// Student row mixin for the teacher Raport class report — Frame B
// of the `_design/teacher_raport_redesign.html` mockup.
//
// Each row carries:
//   • 40dp circular avatar with 2-letter initials (cobalt tint;
//     red tint when the student has no raport yet so absentees
//     visually pop).
//   • Student name + `NIS · No <urutan>` meta + status pill
//     (TERBIT green / DRAFT amber / FINAL blue / BELUM ISI red).
//   • Boxed `Rerata` pill on the right (green ≥ 80, amber 60-79,
//     em-dash when no raport). Sits in a slate-50 chip with the
//     value above the `RERATA` label.
//   • Slate chevron-right indicator.
//
// All rows are tappable — opens [ReportCardDetailScreen]. After
// the detail pops, the host's onReturnFromDetail() is invoked so
// the list refreshes.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/'
    'screens/report_card_detail_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

mixin StudentListMixin {
  BuildContext get context;
  Widget get widgetParent;

  Map<String, dynamic>? getSelectedClass();
  void Function(Map<String, dynamic> student)? getOnDownloadPdf();
  VoidCallback? getOnReturnFromDetail();

  /// Build the student list view with filtered students.
  Widget buildStudentList(List<dynamic> filteredStudents) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildSectionHead(filteredStudents.length),
          ...filteredStudents.map((s) => _buildStudentCard(context, s)),
        ],
      ),
    );
  }

  Widget _buildSectionHead(int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'DAFTAR SISWA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '$count siswa · urut absen',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, dynamic student) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    final name = model.name.isNotEmpty ? model.name : 'Siswa';
    final nis = model.studentNumber.isNotEmpty ? model.studentNumber : '-';
    final orderNo =
        student['urutan']?.toString() ??
        student['no_urut']?.toString() ??
        student['order']?.toString();
    final hasRaport = student['has_raport'] == true;
    final rawStatus = (student['raport_status'] ?? '').toString().toLowerCase();
    final rerata =
        student['rerata'] ?? student['average'] ?? student['avg_score'];
    final hasRerata = rerata is num && rerata > 0;
    final rerataVal = hasRerata ? (rerata as num).toDouble() : 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _onStudentTap(context, student, name),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(name: name, isBelum: !hasRaport),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(nis, orderNo),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(status: rawStatus, hasRaport: hasRaport),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RerataPill(value: rerataVal, hasValue: hasRerata),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: ColorUtils.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metaLine(String nis, String? orderNo) {
    final bits = <String>[
      if (nis != '-') 'NIS · $nis',
      if (orderNo != null && orderNo.isNotEmpty)
        'No ${orderNo.padLeft(2, '0')}',
    ];
    return bits.isEmpty ? '-' : bits.join(' · ');
  }

  void _onStudentTap(BuildContext context, dynamic student, String name) {
    final classData = getSelectedClass();
    if (classData == null) return;
    final studentClassId =
        (student['student_class_id'] ?? student['id'])?.toString() ?? '';
    AppNavigator.push<void>(
      context,
      ReportCardDetailScreen(
        studentClassId: studentClassId,
        studentName: name,
        className: (classData['nama'] ?? classData['name'])?.toString() ?? '',
      ),
    ).then((_) {
      final cb = getOnReturnFromDetail();
      if (cb != null) cb();
    });
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final bool isBelum;

  const _Avatar({required this.name, required this.isBelum});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = isBelum ? ColorUtils.error600 : ColorUtils.brandCobalt;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool hasRaport;

  const _StatusPill({required this.status, required this.hasRaport});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _resolve(status, hasRaport);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
    );
  }

  static (Color, Color, String) _resolve(String status, bool hasRaport) {
    if (!hasRaport) {
      return (
        ColorUtils.error600.withValues(alpha: 0.08),
        ColorUtils.error600,
        'BELUM ISI',
      );
    }
    switch (status) {
      case 'published':
      case 'terbit':
        return (
          ColorUtils.success600.withValues(alpha: 0.10),
          ColorUtils.success600,
          'TERBIT',
        );
      case 'final':
        return (
          ColorUtils.info600.withValues(alpha: 0.10),
          ColorUtils.info600,
          'FINAL',
        );
      case 'draft':
        return (
          ColorUtils.warning600.withValues(alpha: 0.10),
          ColorUtils.warning600,
          'DRAFT',
        );
      default:
        return (
          ColorUtils.slate100,
          ColorUtils.slate500,
          status.isEmpty ? 'BELUM ISI' : status.toUpperCase(),
        );
    }
  }
}

class _RerataPill extends StatelessWidget {
  final double value;
  final bool hasValue;

  const _RerataPill({required this.value, required this.hasValue});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tint();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasValue ? value.toStringAsFixed(0) : '—',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'RERATA',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _tint() {
    if (!hasValue) {
      return (ColorUtils.slate50, ColorUtils.slate500);
    }
    if (value >= 80) {
      return (
        ColorUtils.success600.withValues(alpha: 0.06),
        ColorUtils.success600,
      );
    }
    if (value >= 60) {
      return (
        ColorUtils.warning600.withValues(alpha: 0.06),
        ColorUtils.warning600,
      );
    }
    return (ColorUtils.error600.withValues(alpha: 0.06), ColorUtils.error600);
  }
}
