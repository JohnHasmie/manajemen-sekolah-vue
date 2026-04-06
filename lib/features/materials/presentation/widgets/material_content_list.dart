// Scrollable chapter list for TeacherMaterialScreen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_sub_chapter_list.dart';

class MaterialContentList extends StatelessWidget {
  final List<dynamic> filteredChapterMaterials;
  final List<dynamic> subChapterMaterialList;
  final Map<String, bool> expandedChapter;
  final Map<String, bool> checkedChapter;
  final Map<String, bool> checkedSubChapter;
  final Color Function(String id, {bool isSubChapter}) getCheckboxColor;
  final void Function(String chapterId, bool newExpanded) onChapterExpanded;
  final void Function(String chapterId, bool? value) onChapterCheck;
  final void Function(Map<String, dynamic> subChapter, Map<String, dynamic> chapter) onSubChapterTap;
  final void Function(String subChapterId, String chapterId, bool? value) onSubChapterCheck;

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

  int _subChapterCount(String chapterId) {
    return subChapterMaterialList.where((sc) => sc['bab_id'].toString() == chapterId).length;
  }

  int _checkedSubCount(String chapterId) {
    return subChapterMaterialList
        .where((sc) => sc['bab_id'].toString() == chapterId && checkedSubChapter[sc['id'].toString()] == true)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final totalChapters = filteredChapterMaterials.length;
    final completedChapters = filteredChapterMaterials.where((c) => checkedChapter[c['id'].toString()] == true).length;
    final totalSubs = subChapterMaterialList.length;
    final completedSubs = checkedSubChapter.values.where((v) => v).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Progress summary card ──
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(children: [
            // Stats row
            Row(children: [
              _statItem('$totalChapters', 'Bab', ColorUtils.getRoleColor('guru')),
              _divider(),
              _statItem('$totalSubs', 'Sub-bab', ColorUtils.slate600),
              _divider(),
              _statItem('$completedChapters', 'Selesai', ColorUtils.success600),
              _divider(),
              _statItem('${totalSubs > 0 ? (completedSubs / totalSubs * 100).round() : 0}%', 'Progress', ColorUtils.info600),
            ]),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalSubs > 0 ? completedSubs / totalSubs : 0,
                minHeight: 5,
                backgroundColor: ColorUtils.slate100,
                color: ColorUtils.getRoleColor('guru'),
              ),
            ),
            const SizedBox(height: 10),
            // Legend
            Row(children: [
              _legendDot(ColorUtils.success600, 'Dipilih'),
              const SizedBox(width: 12),
              _legendDot(ColorUtils.violet500, 'AI Generated'),
              const SizedBox(width: 12),
              _legendDot(ColorUtils.info600, 'Digunakan'),
            ]),
          ]),
        ),

        // ── Chapter cards ──
        ...filteredChapterMaterials.asMap().entries.map((entry) {
          final index = entry.key;
          final chapter = entry.value;
          final cardColor = ColorUtils.getColorForIndex(index);
          final chapterIdStr = chapter['id'].toString();
          final isExpanded = expandedChapter[chapterIdStr] ?? false;
          final subCount = _subChapterCount(chapterIdStr);
          final checkedCount = _checkedSubCount(chapterIdStr);
          final isChecked = checkedChapter[chapterIdStr] ?? false;
          final checkColor = getCheckboxColor(chapterIdStr);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChapterExpanded(chapterIdStr, !isExpanded),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isChecked ? checkColor.withValues(alpha: 0.4) : ColorUtils.slate200),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        // Chapter number badge
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardColor.withValues(alpha: 0.25)),
                          ),
                          child: Center(child: Text('${chapter['urutan']}', style: TextStyle(color: cardColor, fontWeight: FontWeight.w700, fontSize: 16))),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Title + sub-chapter count
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            chapter['judul_bab'] ?? 'Judul Bab',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ColorUtils.slate900),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.list_rounded, size: 12, color: ColorUtils.slate400),
                            const SizedBox(width: 4),
                            Text('$subCount sub-bab', style: TextStyle(color: ColorUtils.slate500, fontSize: 12)),
                            if (subCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: checkedCount == subCount && subCount > 0 ? ColorUtils.success600.withValues(alpha: 0.1) : ColorUtils.slate100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$checkedCount/$subCount',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: checkedCount == subCount && subCount > 0 ? ColorUtils.success600 : ColorUtils.slate500),
                                ),
                              ),
                            ],
                          ]),
                        ])),
                        // Status indicator (replaces raw checkbox)
                        Builder(builder: (context) {
                          final bool isIndeterminate = subCount > 0 && checkedCount > 0 && checkedCount < subCount;
                          final bool isAllChecked = (subCount > 0 && checkedCount == subCount) || (subCount == 0 && isChecked);
                          final bool canClick = subCount == 0;

                          return GestureDetector(
                            onTap: canClick 
                                ? () => onChapterCheck(chapterIdStr, !(checkedChapter[chapterIdStr] ?? false)) 
                                : null,
                            child: Container(
                              width: 32, height: 32,
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
                                  width: (isAllChecked || isIndeterminate) ? 1.5 : 1
                                ),
                              ),
                              child: isAllChecked
                                  ? Icon(Icons.check_rounded, size: 18, color: checkColor)
                                  : isIndeterminate
                                      ? Icon(Icons.remove_rounded, size: 18, color: ColorUtils.slate600)
                                      : null,
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        // Expand/collapse
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: ColorUtils.slate100, borderRadius: BorderRadius.circular(8)),
                          child: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: ColorUtils.slate500, size: 20),
                        ),
                      ]),
                    ),

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
                  ]),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: ColorUtils.slate500)),
    ]));
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: ColorUtils.slate200);
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: ColorUtils.slate500)),
    ]);
  }
}
