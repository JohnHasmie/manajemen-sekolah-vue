import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

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

class _ReportCardGradeTabState extends State<ReportCardGradeTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _subjectKeys = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.subjects.length; i++) {
      _subjectKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSubject(int index) {
    final key = _subjectKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: 0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return Column(children: [
      // Subject quick-nav chips
      if (widget.subjects.length > 3)
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.subjects.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final name = widget.subjects[i]['subject_name']?.toString() ?? 'Mapel';
              final score = widget.subjects[i]['knowledge_score']?.toString() ?? '';
              final hasScore = score.isNotEmpty && score != '0' && score != '';
              return GestureDetector(
                onTap: () => _scrollToSubject(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasScore ? p.withValues(alpha: 0.08) : ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hasScore ? p.withValues(alpha: 0.2) : ColorUtils.slate200),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: hasScore ? p : ColorUtils.slate500)),
                    if (hasScore) ...[
                      const SizedBox(width: 4),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: ColorUtils.success600, shape: BoxShape.circle)),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),

      // Subject list
      Expanded(child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: widget.subjects.length,
        itemBuilder: (context, index) {
          final subject = widget.subjects[index];
          final recapScore = subject['recap_final_score']?.toString();
          final hasRecap = recapScore != null && recapScore.isNotEmpty && recapScore != 'null';

          return Container(
            key: _subjectKeys[index],
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Subject header with recap info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: p.withValues(alpha: 0.04), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                child: Row(children: [
                  Expanded(child: Text(subject['subject_name'] ?? 'Mapel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p))),
                  if (hasRecap)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: ColorUtils.success600.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                      child: Text('Rekap: $recapScore', style: TextStyle(fontSize: 9, color: ColorUtils.success600, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),

              Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Pengetahuan
                _aspectRow(
                  icon: Icons.menu_book_rounded,
                  label: 'Pengetahuan',
                  scoreValue: subject['knowledge_score'] ?? '',
                  predicateValue: subject['knowledge_predicate'] ?? '',
                  descriptionValue: subject['knowledge_description'] ?? '',
                  onScoreChanged: (v) { widget.onSubjectChanged(index, 'knowledge_score', v); widget.onMarkUnsaved(); },
                  onPredicateChanged: (v) { widget.onSubjectChanged(index, 'knowledge_predicate', v); widget.onMarkUnsaved(); },
                  onDescChanged: (v) { widget.onSubjectChanged(index, 'knowledge_description', v); widget.onMarkUnsaved(); },
                ),

                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: ColorUtils.slate100)),

                // Keterampilan
                _aspectRow(
                  icon: Icons.build_rounded,
                  label: 'Keterampilan',
                  scoreValue: subject['skill_score'] ?? '',
                  predicateValue: subject['skill_predicate'] ?? '',
                  descriptionValue: subject['skill_description'] ?? '',
                  onScoreChanged: (v) { widget.onSubjectChanged(index, 'skill_score', v); widget.onMarkUnsaved(); },
                  onPredicateChanged: (v) { widget.onSubjectChanged(index, 'skill_predicate', v); widget.onMarkUnsaved(); },
                  onDescChanged: (v) { widget.onSubjectChanged(index, 'skill_description', v); widget.onMarkUnsaved(); },
                ),
              ])),
            ]),
          );
        },
      )),
    ]);
  }

  Widget _aspectRow({
    required IconData icon, required String label,
    required String scoreValue, required String predicateValue, required String descriptionValue,
    required ValueChanged<String> onScoreChanged, required ValueChanged<String> onPredicateChanged, required ValueChanged<String> onDescChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: ColorUtils.slate400),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ColorUtils.slate500)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(width: 70, child: _CompactTextField(label: 'Nilai', initialValue: scoreValue, isNumber: true, onChanged: onScoreChanged)),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: _CompactTextField(label: 'Predikat', initialValue: predicateValue, onChanged: onPredicateChanged)),
        const SizedBox(width: 8),
        Expanded(child: _CompactTextField(label: 'Deskripsi', initialValue: descriptionValue, onChanged: onDescChanged)),
      ]),
    ]);
  }
}

class _CompactTextField extends StatelessWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool isNumber;

  const _CompactTextField({required this.label, required this.initialValue, required this.onChanged, this.isNumber = false});

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return TextFormField(
      initialValue: initialValue.isNotEmpty && initialValue != '0' ? initialValue : null,
      maxLines: 1,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 12),
        hintText: isNumber ? '' : label,
        hintStyle: TextStyle(color: ColorUtils.slate300, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}
