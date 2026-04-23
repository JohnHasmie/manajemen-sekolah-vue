import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/grade_tab_filtering_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/grade_tab_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/subject_card.dart';

class ReportCardGradeTab extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  final void Function(int index, String field, String value) onSubjectChanged;
  final VoidCallback onMarkUnsaved;

  const ReportCardGradeTab({
    super.key,
    required this.subjects,
    required this.onSubjectChanged,
    required this.onMarkUnsaved,
  });

  @override
  State<ReportCardGradeTab> createState() => _ReportCardGradeTabState();
}

class _ReportCardGradeTabState extends State<ReportCardGradeTab>
    with GradeTabFilteringMixin, GradeTabDataMixin {
  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    subjectKeys = {};
    for (int i = 0; i < widget.subjects.length; i++) {
      subjectKeys[i] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant ReportCardGradeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (int i = 0; i < widget.subjects.length; i++) {
      subjectKeys.putIfAbsent(i, GlobalKey.new);
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _handleApplyRecap(int index) {
    applyRecapSuggestion(
      index,
      widget.subjects,
      widget.onSubjectChanged,
      widget.onMarkUnsaved,
      () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    final visibleIndices = getVisibleIndices(widget.subjects.length);

    return Column(
      children: [
        _buildFilterChips(p),
        _buildFilterIndicator(p),
        _buildSubjectList(p, visibleIndices),
      ],
    );
  }

  Widget _buildFilterChips(Color p) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: widget.subjects.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => _buildChipItem(i, p),
        ),
      ),
    );
  }

  Widget _buildChipItem(int i, Color p) {
    final subject = widget.subjects[i];
    final name = subject['subject_name']?.toString() ?? 'Mapel';
    final scored = hasScore(subject);
    final isActive = activeFilterIndex == i;

    return GestureDetector(
      onTap: () => onChipTap(i, setState),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: _buildChipDecoration(p, isActive, scored),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChipText(name, p, isActive, scored),
            if (scored && !isActive) _buildScoreIndicator(),
            if (isActive) _buildCloseIcon(),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildChipDecoration(Color p, bool isActive, bool scored) {
    return BoxDecoration(
      color: isActive
          ? p
          : (scored ? p.withValues(alpha: 0.08) : ColorUtils.slate50),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isActive
            ? p
            : (scored ? p.withValues(alpha: 0.2) : ColorUtils.slate200),
        width: isActive ? 1.5 : 1,
      ),
    );
  }

  Widget _buildChipText(String name, Color p, bool isActive, bool scored) {
    return Text(
      name,
      style: TextStyle(
        fontSize: 11,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        color: isActive ? Colors.white : (scored ? p : ColorUtils.slate500),
      ),
    );
  }

  Widget _buildScoreIndicator() {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: ColorUtils.success600,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCloseIcon() {
    return const Padding(
      padding: EdgeInsets.only(left: 4),
      child: Icon(Icons.close, size: 12, color: Colors.white),
    );
  }

  Widget _buildFilterIndicator(Color p) {
    if (activeFilterIndex == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: p.withValues(alpha: 0.04),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 14, color: p),
          const SizedBox(width: 6),
          Text(
            'Menampilkan: '
            '${widget.subjects[activeFilterIndex!]['subject_name']}',
            style: TextStyle(
              fontSize: 11,
              color: p,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => activeFilterIndex = null),
            child: Text(
              'Tampilkan Semua',
              style: TextStyle(
                fontSize: 11,
                color: p,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectList(Color p, List<int> visibleIndices) {
    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: visibleIndices.length,
        itemBuilder: (context, listIndex) {
          final index = visibleIndices[listIndex];
          final subject = widget.subjects[index];

          return SubjectCard(
            key: subjectKeys[index],
            subject: subject,
            roleColor: p,
            onScoreChanged: (field, value) {
              widget.onSubjectChanged(index, field, value);
              widget.onMarkUnsaved();
            },
            onApplyRecap: () => _handleApplyRecap(index),
          );
        },
      ),
    );
  }
}
