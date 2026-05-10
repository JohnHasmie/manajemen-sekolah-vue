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
    final cardColor = ColorUtils.brandCobalt;
    final chapterIdStr = chapter['id'].toString();
    final isExpanded = isChapterExpanded(chapterIdStr);
    final subCount = getSubChapterCount(chapterIdStr);
    final checkedCount = getCheckedSubCount(chapterIdStr);
    final aiCount = getGeneratedSubCount(chapterIdStr);
    final isChecked = isChapterChecked(chapterIdStr);
    final checkColor = getCheckboxColorFn()(chapterIdStr);

    final isAllChecked =
        subCount > 0 ? checkedCount == subCount : isChecked;
    final isIndeterminate =
        subCount > 0 && checkedCount > 0 && checkedCount < subCount;

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
                color: isAllChecked
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
                      // Header order matches the mockup:
                      //   [check] [#] [title + subtitle] [3/3] [AI 2] [chevron]
                      _buildStatusIndicator(
                        isAllChecked: isAllChecked,
                        isIndeterminate: isIndeterminate,
                        canClick: subCount == 0,
                        checkColor: checkColor,
                        chapterIdStr: chapterIdStr,
                      ),
                      const SizedBox(width: 10),
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
                      if (subCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildProgressBadge(
                            checkedCount: checkedCount,
                            subCount: subCount,
                          ),
                        ),
                      if (aiCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildAiCountBadge(aiCount),
                        ),
                      const SizedBox(width: 6),
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

  /// Purple "AI N" pill — surfaces the count of AI-generated sub-babs
  /// under the chapter on the card header. Only shown when the count
  /// is greater than zero so it doesn't compete with the green "X/Y"
  /// progress badge on cards that haven't been generated yet.
  Widget _buildAiCountBadge(int count) {
    const violet = Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'AI $count',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: violet,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildChapterBadge({
    required Color cardColor,
    required dynamic chapterNumber,
  }) {
    // Mockup uses a softer slate badge (the cobalt fill on the
    // checkbox already carries the brand identity). 36×36 leaves room
    // for the new check-first → number → title → pills → chevron row.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          '$chapterNumber',
          style: TextStyle(
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w800,
            fontSize: 14,
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
    // Subtitle reads as descriptive text rather than icon + count, to
    // match the mockup ("3 sub-bab · semua tercatat" / "3 sub-bab · 2
    // belum tercatat" / "3 sub-bab · belum tercatat"). The progress
    // pill is rendered separately in the card header so the subtitle
    // can use the freed horizontal space for the longer phrasing.
    final pending = (subCount - checkedCount).clamp(0, subCount);
    final String statusText;
    if (subCount == 0) {
      statusText = 'belum ada sub-bab';
    } else if (pending == 0) {
      statusText = 'semua tercatat';
    } else if (checkedCount == 0) {
      statusText = 'belum tercatat';
    } else {
      statusText = '$pending belum tercatat';
    }

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
          Text(
            '$subCount sub-bab · $statusText',
            style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    // Pill matches the AI count badge's shape — pill-rounded, taller,
    // bolder. Tinted green when complete, neutral slate otherwise.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAllChecked
            ? ColorUtils.success600.withValues(alpha: 0.12)
            : ColorUtils.slate100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$checkedCount/$subCount',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: isAllChecked ? ColorUtils.success600 : ColorUtils.slate600,
          letterSpacing: 0.2,
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
    // Visual contract: same shape as the sub-bab checkbox in
    // [_SubCheckbox] (square, rounded 5, solid cobalt fill + white
    // tick when checked) so a teacher tracking progress reads the
    // parent and child as one consistent control. Slightly larger
    // (22dp vs 18dp) so the parent still feels weightier.
    final filled = isAllChecked || isIndeterminate;
    final fillColor = isAllChecked ? checkColor : ColorUtils.slate500;
    return GestureDetector(
      onTap: canClick
          ? () => getOnChapterCheck()(
              chapterIdStr,
              !(getCheckedChapter()[chapterIdStr] ?? false),
            )
          : null,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: filled ? fillColor : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: filled ? fillColor : ColorUtils.slate300,
            width: 1.4,
          ),
        ),
        child: isAllChecked
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : isIndeterminate
            ? const Icon(Icons.remove_rounded, size: 14, color: Colors.white)
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
