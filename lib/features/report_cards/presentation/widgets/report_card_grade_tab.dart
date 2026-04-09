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
  int? _activeFilterIndex;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.subjects.length; i++) {
      _subjectKeys[i] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant ReportCardGradeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (int i = 0; i < widget.subjects.length; i++) {
      _subjectKeys.putIfAbsent(i, GlobalKey.new);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onChipTap(int index) {
    setState(() {
      if (_activeFilterIndex == index) {
        _activeFilterIndex = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSubject(index));
      } else {
        _activeFilterIndex = index;
      }
    });
  }

  void _scrollToSubject(int index) {
    final key = _subjectKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: 0.1);
    }
  }

  bool _hasScore(Map<String, dynamic> subject) {
    final score = subject['knowledge_score']?.toString() ?? '';
    return score.isNotEmpty && score != '0';
  }

  /// Auto-fill nilai from recap_final_score and mark unsaved
  void _applyRecapSuggestion(int index) {
    final subject = widget.subjects[index];
    final recapFinal = _parseNum(subject['recap_final_score']);
    if (recapFinal != null) {
      final scoreStr = recapFinal == recapFinal.roundToDouble()
          ? recapFinal.toInt().toString()
          : recapFinal.toStringAsFixed(1);
      widget.onSubjectChanged(index, 'knowledge_score', scoreStr);
      widget.onMarkUnsaved();
      setState(() {});
    }
  }

  double? _parseNum(dynamic value) {
    if (value == null) return null;
    final d = double.tryParse(value.toString());
    return (d == null || d == 0) ? null : d;
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    final List<int> visibleIndices;
    if (_activeFilterIndex != null && _activeFilterIndex! < widget.subjects.length) {
      visibleIndices = [_activeFilterIndex!];
    } else {
      visibleIndices = List.generate(widget.subjects.length, (i) => i);
    }

    return Column(children: [
      // Subject quick-nav / filter chips
      Container(
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
            itemBuilder: (_, i) {
              final subject = widget.subjects[i];
              final name = subject['subject_name']?.toString() ?? 'Mapel';
              final scored = _hasScore(subject);
              final isActive = _activeFilterIndex == i;

              return GestureDetector(
                onTap: () => _onChipTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? p : (scored ? p.withValues(alpha: 0.08) : ColorUtils.slate50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? p : (scored ? p.withValues(alpha: 0.2) : ColorUtils.slate200),
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? Colors.white : (scored ? p : ColorUtils.slate500),
                      ),
                    ),
                    if (scored && !isActive) ...[
                      const SizedBox(width: 4),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: ColorUtils.success600, shape: BoxShape.circle)),
                    ],
                    if (isActive) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.close, size: 12, color: Colors.white),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
      ),

      // Filter indicator
      if (_activeFilterIndex != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: p.withValues(alpha: 0.04),
          child: Row(children: [
            Icon(Icons.filter_list, size: 14, color: p),
            const SizedBox(width: 6),
            Text(
              'Menampilkan: ${widget.subjects[_activeFilterIndex!]['subject_name']}',
              style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _activeFilterIndex = null),
              child: Text('Tampilkan Semua', style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
            ),
          ]),
        ),

      // Subject list
      Expanded(child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: visibleIndices.length,
        itemBuilder: (context, listIndex) {
          final index = visibleIndices[listIndex];
          final subject = widget.subjects[index];

          return _SubjectCard(
            key: _subjectKeys[index],
            subject: subject,
            roleColor: p,
            onScoreChanged: (field, value) {
              widget.onSubjectChanged(index, field, value);
              widget.onMarkUnsaved();
            },
            onApplyRecap: () => _applyRecapSuggestion(index),
          );
        },
      )),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Subject card with recap reference + input fields
// ---------------------------------------------------------------------------

class _SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final Color roleColor;
  final void Function(String field, String value) onScoreChanged;
  final VoidCallback onApplyRecap;

  const _SubjectCard({
    super.key,
    required this.subject,
    required this.roleColor,
    required this.onScoreChanged,
    required this.onApplyRecap,
  });

  @override
  Widget build(BuildContext context) {
    final recapFinal = _numStr(subject['recap_final_score']);
    final recapUhAvg = _numStr(subject['recap_uh_avg']);
    final recapUts = _numStr(subject['recap_uts']);
    final recapUas = _numStr(subject['recap_uas']);
    final hasRecapData = recapFinal != null || recapUhAvg != null || recapUts != null || recapUas != null;

    // Check if knowledge_score is empty (can be auto-filled)
    final currentScore = subject['knowledge_score']?.toString() ?? '';
    final scoreEmpty = currentScore.isEmpty || currentScore == '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Subject header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.04), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Expanded(child: Text(subject['subject_name'] ?? 'Mapel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: roleColor))),
            if (recapFinal != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ColorUtils.success600.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: Text('NA: $recapFinal', style: TextStyle(fontSize: 10, color: ColorUtils.success600, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),

        // Recap reference section — shows grade breakdown from rekap nilai
        if (hasRecapData)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: ColorUtils.info600.withValues(alpha: 0.03),
              border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 13, color: ColorUtils.info600),
                const SizedBox(width: 5),
                Text('Referensi Nilai dari Rekap', style: TextStyle(fontSize: 10, color: ColorUtils.info600, fontWeight: FontWeight.w600)),
                const Spacer(),
                // "Gunakan" button to auto-fill
                if (scoreEmpty && recapFinal != null)
                  GestureDetector(
                    onTap: onApplyRecap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.arrow_downward, size: 10, color: roleColor),
                        const SizedBox(width: 3),
                        Text('Gunakan', style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              // Score breakdown grid
              Row(children: [
                if (recapUhAvg != null) Expanded(child: _RecapRefItem(label: 'Rata-rata UH', value: recapUhAvg, color: ColorUtils.info600)),
                if (recapUts != null) Expanded(child: _RecapRefItem(label: 'UTS', value: recapUts, color: ColorUtils.warning600)),
                if (recapUas != null) Expanded(child: _RecapRefItem(label: 'UAS', value: recapUas, color: ColorUtils.error600)),
                if (recapFinal != null) Expanded(child: _RecapRefItem(label: 'Nilai Akhir', value: recapFinal, color: ColorUtils.success600)),
              ]),
            ]),
          ),

        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Pengetahuan
          _AspectRow(
            icon: Icons.menu_book_rounded,
            label: 'Pengetahuan',
            scoreValue: subject['knowledge_score'] ?? '',
            predicateValue: subject['knowledge_predicate'] ?? '',
            descriptionValue: subject['knowledge_description'] ?? '',
            onScoreChanged: (v) => onScoreChanged('knowledge_score', v),
            onPredicateChanged: (v) => onScoreChanged('knowledge_predicate', v),
            onDescChanged: (v) => onScoreChanged('knowledge_description', v),
          ),

          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: ColorUtils.slate100)),

          // Keterampilan
          _AspectRow(
            icon: Icons.build_rounded,
            label: 'Keterampilan',
            scoreValue: subject['skill_score'] ?? '',
            predicateValue: subject['skill_predicate'] ?? '',
            descriptionValue: subject['skill_description'] ?? '',
            onScoreChanged: (v) => onScoreChanged('skill_score', v),
            onPredicateChanged: (v) => onScoreChanged('skill_predicate', v),
            onDescChanged: (v) => onScoreChanged('skill_description', v),
          ),
        ])),
      ]),
    );
  }

  String? _numStr(dynamic value) {
    if (value == null) return null;
    final d = double.tryParse(value.toString());
    if (d == null || d == 0) return null;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }
}

// ---------------------------------------------------------------------------
// Recap reference item — single score with label
// ---------------------------------------------------------------------------

class _RecapRefItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RecapRefItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Aspect row (Pengetahuan / Keterampilan)
// ---------------------------------------------------------------------------

class _AspectRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String scoreValue;
  final String predicateValue;
  final String descriptionValue;
  final ValueChanged<String> onScoreChanged;
  final ValueChanged<String> onPredicateChanged;
  final ValueChanged<String> onDescChanged;

  const _AspectRow({
    required this.icon,
    required this.label,
    required this.scoreValue,
    required this.predicateValue,
    required this.descriptionValue,
    required this.onScoreChanged,
    required this.onPredicateChanged,
    required this.onDescChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: ColorUtils.slate400),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ColorUtils.slate500)),
      ]),
      const SizedBox(height: 8),
      // Score + Predicate row
      Row(children: [
        SizedBox(width: 80, child: _CompactTextField(label: 'Nilai', initialValue: scoreValue, isNumber: true, onChanged: onScoreChanged)),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: _CompactTextField(label: 'Predikat', initialValue: predicateValue, onChanged: onPredicateChanged)),
      ]),
      const SizedBox(height: 8),
      // Description full width
      _CompactTextField(label: 'Deskripsi', initialValue: descriptionValue, onChanged: onDescChanged),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Compact text field
// ---------------------------------------------------------------------------

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
