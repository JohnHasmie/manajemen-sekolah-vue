import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/mixins/search_bar_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/mixins/student_list_mixin.dart';

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

class _ReportCardStudentListState extends State<ReportCardStudentList>
    with SearchBarMixin, StudentListMixin {
  String _searchQuery = '';

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  set searchQuery(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  @override
  Widget get widgetParent => widget;

  @override
  Map<String, dynamic>? getSelectedClass() {
    return widget.selectedClass;
  }

  @override
  void Function(Map<String, dynamic> student)? getOnDownloadPdf() {
    return widget.onDownloadPdf;
  }

  @override
  VoidCallback? getOnReturnFromDetail() {
    return widget.onReturnFromDetail;
  }

  /// Compute filtered student list based on search query.
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
    if (widget.students.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate statistics
    final total = widget.students.length;
    final filled = widget.students.where((s) => s['has_raport'] == true).length;
    final drafts = widget.students
        .where(
          (s) => (s['raport_status'] ?? '').toString().toLowerCase() == 'draft',
        )
        .length;
    final notFilled = total - filled;
    final filtered = _filteredStudents;

    // Note: SummaryBar + ProgressBar were dropped in the Raport T.2
    // redesign — the 4-cell KPI overlap strip in the brand header
    // already surfaces Siswa / Terbit / Draft / Rerata, so the
    // duplicated bars below were just visual noise.
    // ignore: unused_local_variable
    final _ = (total, filled, drafts, notFilled);
    return Column(children: [buildSearchBar(), buildStudentList(filtered)]);
  }

  /// Build the empty state widget.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.people_outline,
              size: 32,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data siswa',
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
