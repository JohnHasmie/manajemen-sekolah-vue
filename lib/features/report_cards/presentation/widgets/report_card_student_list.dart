import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

class ReportCardStudentList extends StatefulWidget {
  final List<dynamic> students;
  final Map<String, dynamic>? selectedClass;
  final void Function(Map<String, dynamic> student) onDownloadPdf;
  final VoidCallback onReturnFromDetail;

  const ReportCardStudentList({
    super.key,
    required this.students,
    required this.selectedClass,
    required this.onDownloadPdf,
    required this.onReturnFromDetail,
  });

  @override
  State<ReportCardStudentList> createState() => _ReportCardStudentListState();
}

class _ReportCardStudentListState extends State<ReportCardStudentList> {
  String _searchQuery = '';

  List<dynamic> get _filteredStudents {
    if (_searchQuery.isEmpty) return widget.students;
    final q = _searchQuery.toLowerCase();
    return widget.students.where((s) {
      final name = (s['student_name'] ?? '').toString().toLowerCase();
      final nis = (s['student_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || nis.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    if (widget.students.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: ColorUtils.slate100, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.people_outline, size: 32, color: ColorUtils.slate400),
          ),
          const SizedBox(height: 16),
          Text('Tidak ada data siswa', style: TextStyle(fontSize: 14, color: ColorUtils.slate500, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    // Stats
    final total = widget.students.length;
    final filled = widget.students.where((s) => s['has_raport'] == true).length;
    final drafts = widget.students.where((s) => (s['raport_status'] ?? '').toString().toLowerCase() == 'draft').length;
    final notFilled = total - filled;
    final filtered = _filteredStudents;

    return Column(children: [
      // Summary bar
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          _StatChip(label: 'Total', value: '$total', color: ColorUtils.slate600),
          const SizedBox(width: 6),
          _StatChip(label: 'Selesai', value: '${filled - drafts}', color: ColorUtils.success600),
          const SizedBox(width: 6),
          _StatChip(label: 'Draft', value: '$drafts', color: ColorUtils.warning600),
          const SizedBox(width: 6),
          _StatChip(label: 'Belum', value: '$notFilled', color: ColorUtils.error600),
        ]),
      ),

      // Progress bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Progress', style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${total > 0 ? (filled * 100 / total).round() : 0}%', style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: total > 0 ? filled / total : 0,
                backgroundColor: ColorUtils.slate100,
                valueColor: AlwaysStoppedAnimation(p),
              ),
            ),
          ),
        ]),
      ),

      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Cari siswa...',
            hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 18, color: ColorUtils.slate400),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ColorUtils.slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ColorUtils.slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),

      // Student list
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final student = filtered[index];
          final bool hasRaport = student['has_raport'] ?? false;
          final String status = student['raport_status'] ?? 'Belum ada';
          final String name = student['student_name'] ?? 'Siswa';
          final String nis = student['student_number'] ?? '-';
          final bool isFinal = status.toLowerCase() == 'final' || status.toLowerCase() == 'published';

          // Status styling
          final Color statusBg;
          final Color statusFg;
          final IconData statusIcon;
          final String statusLabel;
          if (!hasRaport) {
            statusBg = ColorUtils.slate100;
            statusFg = ColorUtils.slate500;
            statusIcon = Icons.edit_note;
            statusLabel = 'Belum Isi';
          } else if (status.toLowerCase() == 'draft') {
            statusBg = ColorUtils.warning600.withValues(alpha: 0.08);
            statusFg = ColorUtils.warning600;
            statusIcon = Icons.save_outlined;
            statusLabel = 'Draft';
          } else {
            statusBg = ColorUtils.success600.withValues(alpha: 0.08);
            statusFg = ColorUtils.success600;
            statusIcon = Icons.check_circle_outline;
            statusLabel = 'Selesai';
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  AppNavigator.push(
                    context,
                    ReportCardDetailScreen(
                      studentClassId: student['student_class_id'].toString(),
                      studentName: name,
                      className: widget.selectedClass?['name'] ?? '',
                    ),
                  ).then((_) => widget.onReturnFromDetail());
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate100),
                  ),
                  child: Row(children: [
                    // Number badge
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [p.withValues(alpha: 0.12), p.withValues(alpha: 0.06)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(
                        '${index + 1}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p),
                      )),
                    ),
                    const SizedBox(width: 10),

                    // Name + NIS
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800)),
                        const SizedBox(height: 2),
                        Text('NIS: $nis', style: TextStyle(fontSize: 11, color: ColorUtils.slate400)),
                      ],
                    )),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 12, color: statusFg),
                        const SizedBox(width: 4),
                        Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusFg)),
                      ]),
                    ),

                    // PDF download
                    if (isFinal) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.onDownloadPdf(student as Map<String, dynamic>),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(color: ColorUtils.error600.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.picture_as_pdf_outlined, size: 14, color: ColorUtils.error600),
                        ),
                      ),
                    ],

                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: ColorUtils.slate300),
                  ]),
                ),
              ),
            ),
          );
        },
      )),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
      ]),
    ));
  }
}
