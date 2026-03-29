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
/// [getCheckboxColor]      — resolves colour for a given subChapterId.
/// [onSubChapterTap]       — called when a row is tapped (navigate to detail).
/// [onSubChapterCheck]     — called when a checkbox is toggled.
class MaterialSubChapterList extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final List<dynamic> subChapterMaterialList;
  final Map<String, bool> checkedSubChapter;
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
        padding: EdgeInsets.all(AppSpacing.lg),
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

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSubChapterTap(subChapter, chapter),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: subChapterColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
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
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      subChapter['judul_sub_bab'] ?? 'Judul Sub Bab',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ColorUtils.slate800,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: checkedSubChapter[subChapterIdStr] ?? false,
                    onChanged: (value) {
                      onSubChapterCheck(
                        subChapterIdStr,
                        chapter['id'].toString(),
                        value,
                      );
                    },
                    activeColor: getCheckboxColor(
                      subChapterIdStr,
                      isSubChapter: true,
                    ),
                  ),
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
}
