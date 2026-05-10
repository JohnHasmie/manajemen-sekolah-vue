// Pure-display parts of the modern grade editor sheet.
//
// Why this exists
// ---------------
// The editor is a single ConsumerStatefulWidget with ~10 build helpers
// that all share one State. Two of those helpers — the big score "hero"
// card at the top and the sticky footer at the bottom — are pure
// display: they don't tap into any controllers, only callbacks and
// pre-computed primitives. Pulling them into named widgets here drops
// the editor file by ~150 lines and lets the score-band palette live
// in one place.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Shared score → letter/colour/predikat mapping. Returned as a record
/// so call sites can destructure inline. `score == null` means "no
/// score yet" and yields a slate dash placeholder.
({String letter, Color color, String label}) modernGradeEditorPredikat(
  int? score,
) {
  if (score == null) {
    return (letter: '—', color: ColorUtils.slate300, label: 'Masukkan nilai');
  }
  if (score >= 90) {
    return (letter: 'A', color: const Color(0xFF16A34A), label: 'Sangat Baik');
  }
  if (score >= 80) {
    return (letter: 'B', color: const Color(0xFF2563EB), label: 'Baik');
  }
  if (score >= 70) {
    return (letter: 'C', color: const Color(0xFFCA8A04), label: 'Cukup');
  }
  if (score >= 60) {
    return (letter: 'D', color: const Color(0xFFEA580C), label: 'Kurang');
  }
  return (
    letter: 'E',
    color: const Color(0xFFDC2626),
    label: 'Perlu Bimbingan',
  );
}

/// Big score "hero" tile shown at the top of the grade editor sheet.
/// Reads only the current score; the State recomputes and rebuilds
/// when [score] changes.
class ModernGradeEditorScoreHero extends StatelessWidget {
  final int? score;
  final LanguageProvider lang;

  const ModernGradeEditorScoreHero({
    super.key,
    required this.score,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final predikat = modernGradeEditorPredikat(score);
    final percent = (score ?? 0).clamp(0, 100) / 100.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            predikat.color.withValues(alpha: 0.10),
            predikat.color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: predikat.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.getTranslatedText({
                        'en': 'Current Score',
                        'id': 'Nilai Saat Ini',
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          score?.toString() ?? '—',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: predikat.color,
                            height: 1.0,
                          ),
                        ),
                        if (score != null)
                          Text(
                            ' / 100',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate400,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: predikat.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      predikat.letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      predikat.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Score progress bar with KKM marker. The thin tick at 75
          // gives the teacher a visual reference for where pass/fail
          // lands — matches the Frame D mockup's KKM dotted line.
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    // Track.
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorUtils.slate100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // Filled portion.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: (percent * w).clamp(0.0, w),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              predikat.color.withValues(alpha: 0.85),
                              predikat.color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // KKM tick (75/100). Thin slate-400 vertical
                    // line so the teacher always sees where the pass
                    // threshold sits relative to the current score.
                    Positioned(
                      left: w * 0.75 - 1,
                      top: -2,
                      bottom: -2,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: ColorUtils.slate400,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          // KKM legend — small uppercase caption pointing to the
          // tick mark. Uses Flex spacers (3 left, 1 right) to land
          // under the 75% mark without nesting an unbounded Stack
          // inside a Column (which crashes with "size.isFinite").
          Row(
            children: [
              const Spacer(flex: 3),
              Text(
                'KKM 75',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom footer for the grade editor. Carries Save (always
/// visible) and Delete (only in edit mode). Disables itself while
/// [isSaving] / [isDeleting] is true; greys the Save button when the
/// surface is read-only.
class ModernGradeEditorFooter extends StatelessWidget {
  final LanguageProvider lang;
  final Color primary;
  final bool isEditing;
  final bool isReadOnly;
  final bool isSaving;
  final bool isDeleting;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const ModernGradeEditorFooter({
    super.key,
    required this.lang,
    required this.primary,
    required this.isEditing,
    required this.isReadOnly,
    required this.isSaving,
    required this.isDeleting,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = isSaving || isDeleting;
    // Add the system nav-bar inset on top of the base padding so the buttons
    // don't sit flush against the Samsung/Android navigation bar. Matches
    // the shared BottomSheetFooter pattern used elsewhere in the app.
    final systemBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + systemBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          if (isEditing)
            OutlinedButton.icon(
              onPressed: isBusy ? null : onDelete,
              icon: isDeleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFDC2626),
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                lang.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          if (isEditing) const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: (isBusy || isReadOnly) ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isEditing
                          ? Icons.check_circle_outline_rounded
                          : Icons.save_rounded,
                      size: 18,
                    ),
              label: Text(
                isEditing
                    ? lang.getTranslatedText({
                        'en': 'Update Grade',
                        'id': 'Simpan Perubahan',
                      })
                    : lang.getTranslatedText({
                        'en': 'Save Grade',
                        'id': 'Simpan Nilai',
                      }),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
