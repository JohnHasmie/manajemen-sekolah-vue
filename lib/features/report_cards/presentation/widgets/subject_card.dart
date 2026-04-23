import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/recap_ref_item.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/aspect_row.dart';

class SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final Color roleColor;
  final void Function(String field, String value) onScoreChanged;
  final VoidCallback onApplyRecap;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.roleColor,
    required this.onScoreChanged,
    required this.onApplyRecap,
  });

  @override
  Widget build(BuildContext context) {
    final (recapFinal, recapUhAvg, recapUts, recapUas) = _parseRecapScores();
    final hasRecapData =
        recapFinal != null ||
        recapUhAvg != null ||
        recapUts != null ||
        recapUas != null;
    final scoreEmpty = _isScoreEmpty();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(recapFinal),
          _buildRecapSection(
            recapFinal,
            recapUhAvg,
            recapUts,
            recapUas,
            hasRecapData,
            scoreEmpty,
          ),
          _buildAspectFields(),
        ],
      ),
    );
  }

  (String?, String?, String?, String?) _parseRecapScores() {
    return (
      _numStr(subject['recap_final_score']),
      _numStr(subject['recap_uh_avg']),
      _numStr(subject['recap_uts']),
      _numStr(subject['recap_uas']),
    );
  }

  bool _isScoreEmpty() {
    final currentScore = subject['knowledge_score']?.toString() ?? '';
    return currentScore.isEmpty || currentScore == '0';
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ColorUtils.slate200),
      boxShadow: [
        BoxShadow(
          color: ColorUtils.slate900.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildHeader(String? recapFinal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject['subject_name'] ?? 'Mapel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: roleColor,
              ),
            ),
          ),
          if (recapFinal != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ColorUtils.success600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'NA: $recapFinal',
                style: TextStyle(
                  fontSize: 10,
                  color: ColorUtils.success600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecapSection(
    String? recapFinal,
    String? recapUhAvg,
    String? recapUts,
    String? recapUas,
    bool hasRecapData,
    bool scoreEmpty,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: ColorUtils.info600.withValues(alpha: 0.03),
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecapHeader(recapFinal, scoreEmpty),
          const SizedBox(height: 8),
          _buildRecapContent(
            hasRecapData,
            recapUhAvg,
            recapUts,
            recapUas,
            recapFinal,
          ),
        ],
      ),
    );
  }

  Widget _buildRecapHeader(String? recapFinal, bool scoreEmpty) {
    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 13, color: ColorUtils.info600),
        const SizedBox(width: 5),
        Text(
          'Referensi Nilai dari Rekap',
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.info600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (scoreEmpty && recapFinal != null) _buildApplyButton(),
      ],
    );
  }

  Widget _buildApplyButton() {
    return GestureDetector(
      onTap: onApplyRecap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: roleColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_downward, size: 10, color: roleColor),
            const SizedBox(width: 3),
            Text(
              'Gunakan',
              style: TextStyle(
                fontSize: 10,
                color: roleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecapContent(
    bool hasRecapData,
    String? recapUhAvg,
    String? recapUts,
    String? recapUas,
    String? recapFinal,
  ) {
    if (!hasRecapData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Belum ada data rekap nilai',
          style: TextStyle(
            fontSize: 11,
            color: ColorUtils.slate400,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Row(
      children: [
        if (recapUhAvg != null)
          Expanded(
            child: RecapRefItem(
              label: 'Rata-rata UH',
              value: recapUhAvg,
              color: ColorUtils.info600,
            ),
          ),
        if (recapUts != null)
          Expanded(
            child: RecapRefItem(
              label: 'UTS',
              value: recapUts,
              color: ColorUtils.warning600,
            ),
          ),
        if (recapUas != null)
          Expanded(
            child: RecapRefItem(
              label: 'UAS',
              value: recapUas,
              color: ColorUtils.error600,
            ),
          ),
        if (recapFinal != null)
          Expanded(
            child: RecapRefItem(
              label: 'Nilai Akhir',
              value: recapFinal,
              color: ColorUtils.success600,
            ),
          ),
      ],
    );
  }

  Widget _buildAspectFields() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRow(
            icon: Icons.menu_book_rounded,
            label: 'Pengetahuan',
            scoreValue: subject['knowledge_score'] ?? '',
            predicateValue: subject['knowledge_predicate'] ?? '',
            descriptionValue: subject['knowledge_description'] ?? '',
            onScoreChanged: (v) => onScoreChanged('knowledge_score', v),
            onPredicateChanged: (v) => onScoreChanged('knowledge_predicate', v),
            onDescChanged: (v) => onScoreChanged('knowledge_description', v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: ColorUtils.slate100),
          ),
          AspectRow(
            icon: Icons.build_rounded,
            label: 'Keterampilan',
            scoreValue: subject['skill_score'] ?? '',
            predicateValue: subject['skill_predicate'] ?? '',
            descriptionValue: subject['skill_description'] ?? '',
            onScoreChanged: (v) => onScoreChanged('skill_score', v),
            onPredicateChanged: (v) => onScoreChanged('skill_predicate', v),
            onDescChanged: (v) => onScoreChanged('skill_description', v),
          ),
        ],
      ),
    );
  }

  String? _numStr(dynamic value) {
    if (value == null) return null;
    final d = double.tryParse(value.toString());
    if (d == null || d == 0) return null;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }
}
