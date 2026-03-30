// Scrollable chapter list for TeacherMaterialScreen.
//
// Extracted from TeacherMaterialScreen._buildContentList to keep the main
// screen under the line-count limit. Equivalent to a Vue child component
// that renders a list and emits events upward.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_sub_chapter_list.dart';

/// Renders the expandable chapter (bab) list with checkboxes and sub-chapters.
///
/// Each card can be tapped to expand/collapse its sub-chapter list.
/// Checkbox interactions are forwarded to TeacherMaterialScreenState via
/// [onChapterExpanded] and [onChapterCheck].
class MaterialContentList extends StatelessWidget {
  /// The filtered (search/filter applied) list of chapter maps to render.
  final List<dynamic> filteredChapterMaterials;

  /// Full flat list of sub-chapters — used to find children of each chapter.
  final List<dynamic> subChapterMaterialList;

  /// Current expand/collapse state keyed by chapter id (as String).
  final Map<String, bool> expandedChapter;

  /// Current checkbox state for chapters, keyed by chapter id (as String).
  final Map<String, bool> checkedChapter;

  /// Current checkbox state for sub-chapters, keyed by sub-chapter id.
  final Map<String, bool> checkedSubChapter;

  /// Returns the active checkbox colour for a given id.
  /// [isSubChapter] controls which map is consulted.
  final Color Function(String id, {bool isSubChapter}) getCheckboxColor;

  /// Called when the user taps a chapter card to toggle expand/collapse.
  final void Function(String chapterId, bool newExpanded) onChapterExpanded;

  /// Called when the user ticks/unticks a chapter checkbox.
  final void Function(String chapterId, bool? value) onChapterCheck;

  /// Called when the user taps a sub-chapter row to open its detail page.
  final void Function(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> chapter,
  ) onSubChapterTap;

  /// Called when the user ticks/unticks a sub-chapter checkbox.
  final void Function(String subChapterId, String chapterId, bool? value)
  onSubChapterCheck;

  const MaterialContentList({
    super.key,
    required this.filteredChapterMaterials,
    required this.subChapterMaterialList,
    required this.expandedChapter,
    required this.checkedChapter,
    required this.checkedSubChapter,
    required this.getCheckboxColor,
    required this.onChapterExpanded,
    required this.onChapterCheck,
    required this.onSubChapterTap,
    required this.onSubChapterCheck,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: filteredChapterMaterials.length,
      itemBuilder: (context, index) {
        final chapter = filteredChapterMaterials[index];
        final cardColor = ColorUtils.getColorForIndex(index);
        final chapterIdStr = chapter['id'].toString();
        final isExpanded = expandedChapter[chapterIdStr] ?? false;

        return Container(
          margin: EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                onChapterExpanded(chapterIdStr, !isExpanded);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorUtils.slate200),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cardColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${chapter['urutan']}',
                                style: TextStyle(
                                  color: cardColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter['judul_bab'] ?? 'Judul Bab',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: ColorUtils.slate900,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Bab ${chapter['urutan']}',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: checkedChapter[chapterIdStr] ?? false,
                            onChanged: (value) {
                              onChapterCheck(chapterIdStr, value);
                            },
                            activeColor: getCheckboxColor(chapterIdStr),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: ColorUtils.slate500,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sub Bab List (Expandable)
                    if (isExpanded) ...[
                      Divider(height: 1, color: ColorUtils.slate200),
                      MaterialSubChapterList(
                        chapter: chapter,
                        subChapterMaterialList: subChapterMaterialList,
                        checkedSubChapter: checkedSubChapter,
                        getCheckboxColor: getCheckboxColor,
                        onSubChapterTap: onSubChapterTap,
                        onSubChapterCheck: onSubChapterCheck,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
