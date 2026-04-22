// Expandable sub-chapter list shown inside a chapter card on TeacherMaterialScreen.
// Extracted from TeacherMaterialScreenState._buildSubChapterList() to keep
// the screen file lean. Like a Vue <SubChapterList /> sub-component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Vertical list of sub-chapter rows rendered inside an expanded chapter card.
///
/// Purely presentational — all state maps and callbacks come from the parent
/// screen via constructor params, so this widget never calls setState itself.
/// In Vue terms this is a dumb child component that emits events upward.
///
/// [chapter]               — the parent chapter map (needs 'id').
/// [subChapterMaterialList]— full list of sub-chapters across all chapters.
/// [checkedSubChapter]     — map of subChapterId → bool (checkbox state).
/// [generatedSubChapter]   — map of subChapterId → bool. Controls whether
///                           the three Materi/Kuis/Ref badges render in
///                           colour (true) or grey (false). Purely visual —
///                           does NOT affect the checkbox lock. (#141)
/// [getCheckboxColor]      — resolves colour for a given subChapterId.
/// [onSubChapterTap]       — called when a row is tapped (navigate to detail).
/// [onSubChapterCheck]     — called when a checkbox is toggled.
class MaterialSubChapterList extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final List<dynamic> subChapterMaterialList;
  final Map<String, bool> checkedSubChapter;
  final Map<String, bool> generatedSubChapter;
  final Color Function(String id, {bool isSubChapter}) getCheckboxColor;
  final void Function(Map<String, dynamic> subChapter, Map<String, dynamic> bab)
  onSubChapterTap;
  final void Function(String subChapterId, String chapterId, bool? value)
  onSubChapterCheck;

  const MaterialSubChapterList({
    super.key,
    required this.chapter,
    required this.subChapterMaterialList,
    required this.checkedSubChapter,
    required this.generatedSubChapter,
    required this.getCheckboxColor,
    required this.onSubChapterTap,
    required this.onSubChapterCheck,
  });

  @override
  Widget build(BuildContext context) {
    final subChaptersForChapter = subChapterMaterialList
        .where((sc) => sc['bab_id'].toString() == chapter['id'].toString())
        .toList();

    if (subChaptersForChapter.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(color: ColorUtils.slate400),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: subChaptersForChapter.map((subChapter) {
        final subChapterIdStr = subChapter['id'].toString();
        final subChapterColor = ColorUtils.getColorForIndex(
          int.parse(subChapter['urutan']?.toString() ?? '0'),
        );
        final isGenerated = generatedSubChapter[subChapterIdStr] ?? false;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSubChapterTap(subChapter, chapter),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: subChapterColor.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(
                        color: subChapterColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${subChapter['urutan']}',
                        style: TextStyle(
                          color: subChapterColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subChapter['judul_sub_bab'] ?? 'Judul Sub Bab',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ColorUtils.slate800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Content indicator badges — coloured when the
                        // sub-chapter's AI materi/quiz/refs are generated,
                        // grey otherwise. Purely informational. (#141)
                        Row(
                          children: [
                            _infoBadge(
                              Icons.menu_book_outlined,
                              'Materi',
                              ColorUtils.success600,
                              isActive: isGenerated,
                            ),
                            const SizedBox(width: 6),
                            _infoBadge(
                              Icons.quiz_outlined,
                              'Kuis',
                              ColorUtils.warning600,
                              isActive: isGenerated,
                            ),
                            const SizedBox(width: 6),
                            _infoBadge(
                              Icons.bookmark_outline,
                              'Ref',
                              ColorUtils.info600,
                              isActive: isGenerated,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onSubChapterCheck(
                      subChapterIdStr,
                      chapter['id'].toString(),
                      !(checkedSubChapter[subChapterIdStr] ?? false),
                    ),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (checkedSubChapter[subChapterIdStr] ?? false)
                            ? getCheckboxColor(
                                subChapterIdStr,
                                isSubChapter: true,
                              ).withValues(alpha: 0.15)
                            : ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: (checkedSubChapter[subChapterIdStr] ?? false)
                              ? getCheckboxColor(
                                  subChapterIdStr,
                                  isSubChapter: true,
                                )
                              : ColorUtils.slate300,
                          width: (checkedSubChapter[subChapterIdStr] ?? false)
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: (checkedSubChapter[subChapterIdStr] ?? false)
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: getCheckboxColor(
                                subChapterIdStr,
                                isSubChapter: true,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: ColorUtils.slate400,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _infoBadge(
    IconData icon,
    String label,
    Color color, {
    required bool isActive,
  }) {
    // When the sub-chapter's AI content isn't generated yet, the badge uses
    // a slate palette to communicate "not available" — still visible but
    // clearly muted compared to the coloured post-generation state. (#141)
    final effectiveColor = isActive ? color : ColorUtils.slate400;
    final bgAlpha = isActive ? 0.08 : 0.06;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: effectiveColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: effectiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
