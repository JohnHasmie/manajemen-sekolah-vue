// =====================================================================
// Deskripsi Capaian sheet (Frame 2 of the parent rapor redesign)
// =====================================================================
//
// Surfaces knowledge_description + skill_description for one mata pelajaran.
// Backend already populates both fields (wali kelas redesign TA.22–26); this
// is the parent-facing read-only view that mirrors the wali kelas KI 3/KI 4
// section. Triggered by tapping a [ParentRaporSubjectCard].
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_tokens.dart';

/// Opens the per-mapel deskripsi capaian sheet. Returns when dismissed.
Future<void> showParentRaporDeskripsiSheet(
  BuildContext context, {
  required Map subject,
}) {
  return AppBottomSheet.show<void>(
    context: context,
    title: _readSubjectName(subject),
    subtitle: 'Deskripsi capaian belajar',
    icon: Icons.menu_book_rounded,
    primaryColor: ColorUtils.brandCobalt,
    contentPadding: EdgeInsets.zero,
    content: _ParentRaporDeskripsiBody(subject: subject),
  );
}

String _readSubjectName(Map subject) {
  if (subject['subject'] is Map) {
    return ((subject['subject'] as Map)['name'] ?? 'Mata Pelajaran').toString();
  }
  return 'Mata Pelajaran';
}

class _ParentRaporDeskripsiBody extends StatelessWidget {
  const _ParentRaporDeskripsiBody({required this.subject});

  final Map subject;

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _predikat(dynamic raw, double? score) {
    final stored = (raw ?? '').toString().trim();
    if (stored.isNotEmpty && stored != '–') return stored;
    if (score == null) return '';
    return parentRaporBandLetter(score);
  }

  @override
  Widget build(BuildContext context) {
    final teacher =
        (subject['teacher_name'] ??
                (subject['subject'] is Map
                    ? (subject['subject'] as Map)['teacher_name']
                    : null) ??
                '')
            .toString();
    final knowledge = _toDouble(subject['knowledge_score']);
    final skill = _toDouble(subject['skill_score']);
    final kkm = _toDouble(subject['kkm']) ?? 75;

    final knowledgeDesc = (subject['knowledge_description'] ?? '')
        .toString()
        .trim();
    final skillDesc = (subject['skill_description'] ?? '').toString().trim();

    final knowledgePred = _predikat(subject['knowledge_predicate'], knowledge);
    final skillPred = _predikat(subject['skill_predicate'], skill);

    final knowledgeFailing = knowledge != null && knowledge < kkm;
    final skillFailing = skill != null && skill < kkm;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (teacher.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: ColorUtils.slate500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Guru mapel: $teacher',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          // KI 3 block
          _ParentRaporDeskripsiBlock(
            ki: 'KI 3',
            label: 'Pengetahuan',
            accent: kParentRaporKi3,
            score: knowledge,
            predikat: knowledgePred,
            description: knowledgeDesc,
            failing: knowledgeFailing,
          ),
          const SizedBox(height: 12),
          // KI 4 block
          _ParentRaporDeskripsiBlock(
            ki: 'KI 4',
            label: 'Keterampilan',
            accent: kParentRaporKi4,
            score: skill,
            predikat: skillPred,
            description: skillDesc,
            failing: skillFailing,
          ),
          if (knowledgeDesc.isEmpty && skillDesc.isEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ColorUtils.brandAzure.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: ColorUtils.brandAzure.withValues(alpha: 0.20),
                  width: 0.75,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: ColorUtils.brandAzureDeep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wali kelas belum menulis deskripsi capaian untuk '
                      'mata pelajaran ini. Hubungi wali kelas via menu '
                      'Pesan jika dibutuhkan.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.brandAzureDeep,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: ColorUtils.slate100,
                foregroundColor: ColorUtils.slate700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onPressed: () => AppNavigator.pop(context),
              child: const Text(
                'Tutup',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentRaporDeskripsiBlock extends StatelessWidget {
  const _ParentRaporDeskripsiBlock({
    required this.ki,
    required this.label,
    required this.accent,
    required this.score,
    required this.predikat,
    required this.description,
    required this.failing,
  });

  final String ki;
  final String label;
  final Color accent;
  final double? score;
  final String predikat;
  final String description;
  final bool failing;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = failing ? const Color(0xFFDC2626) : accent;
    final hasScore = score != null;
    final pillLetter =
        predikat.isNotEmpty &&
            const ['A', 'B', 'C', 'D', 'E'].contains(predikat.toUpperCase())
        ? predikat.toUpperCase()
        : (hasScore ? parentRaporBandLetter(score!) : '');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [effectiveAccent.withValues(alpha: 0.05), Colors.white],
          stops: const [0.0, 0.7],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: effectiveAccent.withValues(alpha: 0.18),
          width: 0.75,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: effectiveAccent,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  ki,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label · ${hasScore ? score!.toStringAsFixed(0) : '–'} / 100',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pillLetter.isNotEmpty)
                Text(
                  'Predikat $pillLetter',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: failing ? kParentRaporFailFg : effectiveAccent,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description.isEmpty
                ? '— Belum ada deskripsi capaian dari wali kelas.'
                : description,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: description.isEmpty
                  ? ColorUtils.slate400
                  : ColorUtils.slate700,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
