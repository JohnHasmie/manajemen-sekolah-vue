import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_sub_chapter_list.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mixins/helpers_mixin.dart';

mixin ChapterCardMixin on HelpersMixin {
  void Function(String chapterId, bool newExpanded) getOnChapterExpanded();

  void Function(String chapterId, bool? value) getOnChapterCheck();

  void Function(Map<String, dynamic> subChapter, Map<String, dynamic> chapter)
  getOnSubChapterTap();

  void Function(String subChapterId, String chapterId, bool? value)
  getOnSubChapterCheck();

  Widget buildChapterCard({
    required int index,
    required Map<String, dynamic> chapter,
  }) {
    final cardColor = ColorUtils.getColorForIndex(index);
    final chapterIdStr = chapter['id'].toString();
    final isExpanded = isChapterExpanded(chapterIdStr);
    final subCount = getSubChapterCount(chapterIdStr);
    final checkedCount = getCheckedSubCount(chapterIdStr);
    final isChecked = isChapterChecked(chapterIdStr);
    final checkColor = getCheckboxColorFn()(chapterIdStr);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => getOnChapterExpanded()(chapterIdStr, !isExpanded),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isChecked
                    ? checkColor.withValues(alpha: 0.4)
                    : ColorUtils.slate200,
              ),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _buildChapterBadge(
                        cardColor: cardColor,
                        chapterNumber: chapter['urutan'],
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildChapterTitle(
                        chapter: chapter,
                        subCount: subCount,
                        checkedCount: checkedCount,
                      ),
                      _buildStatusIndicator(
                        isAllChecked: subCount > 0
                            ? checkedCount == subCount
                            : isChecked,
                        isIndeterminate:
                            subCount > 0 &&
                            checkedCount > 0 &&
                            checkedCount < subCount,
                        canClick: subCount == 0,
                        checkColor: checkColor,
                        chapterIdStr: chapterIdStr,
                      ),
                      const SizedBox(width: 8),
                      _buildExpandIcon(isExpanded),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  Divider(height: 1, color: ColorUtils.slate200),
                  MaterialSubChapterList(
                    chapter: chapter,
                    subChapterMaterialList: getSubChapterMaterialList(),
                    checkedSubChapter: getCheckedSubChapter(),
                    generatedSubChapter: getGeneratedSubChapter(),
                    getCheckboxColor: getCheckboxColorFn(),
                    onSubChapterTap: getOnSubChapterTap(),
                    onSubChapterCheck: getOnSubChapterCheck(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterBadge({
    required Color cardColor,
    required dynamic chapterNumber,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardColor.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          '$chapterNumber',
          style: TextStyle(
            color: cardColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildChapterTitle({
    required Map<String, dynamic> chapter,
    required int subCount,
    required int checkedCount,
  }) {
    return Expanded(
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
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.list_rounded, size: 12, color: ColorUtils.slate400),
              const SizedBox(width: 4),
              Text(
                '$subCount sub-bab',
                style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
              ),
              if (subCount > 0) ...[
                const SizedBox(width: 8),
                _buildProgressBadge(
                  checkedCount: checkedCount,
                  subCount: subCount,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBadge({
    required int checkedCount,
    required int subCount,
  }) {
    final isAllChecked = checkedCount == subCount && subCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isAllChecked
            ? ColorUtils.success600.withValues(alpha: 0.1)
            : ColorUtils.slate100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$checkedCount/$subCount',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isAllChecked ? ColorUtils.success600 : ColorUtils.slate500,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required bool isAllChecked,
    required bool isIndeterminate,
    required bool canClick,
    required Color checkColor,
    required String chapterIdStr,
  }) {
    return GestureDetector(
      onTap: canClick
          ? () => getOnChapterCheck()(
              chapterIdStr,
              !(getCheckedChapter()[chapterIdStr] ?? false),
            )
          : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isAllChecked
              ? checkColor.withValues(alpha: 0.15)
              : isIndeterminate
              ? ColorUtils.slate500.withValues(alpha: 0.15)
              : ColorUtils.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAllChecked
                ? checkColor
                : isIndeterminate
                ? ColorUtils.slate500
                : ColorUtils.slate300,
            width: (isAllChecked || isIndeterminate) ? 1.5 : 1,
          ),
        ),
        child: isAllChecked
            ? Icon(Icons.check_rounded, size: 18, color: checkColor)
            : isIndeterminate
            ? Icon(Icons.remove_rounded, size: 18, color: ColorUtils.slate600)
            : null,
      ),
    );
  }

  Widget _buildExpandIcon(bool isExpanded) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        color: ColorUtils.slate500,
        size: 20,
      ),
    );
  }
}
