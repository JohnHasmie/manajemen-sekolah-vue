// Flat timeline view for embedded material mode — shows all
// sub-chapters linearly with chapter headers as dividers.
//
// Extracted from teacher_material_screen.dart `_buildTimelineView()`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Timeline-style list of chapters and sub-chapters for the
/// embedded material screen. Designed for quick scanning and selection.
class MaterialTimelineView extends StatelessWidget {
  final List<dynamic> chapters;
  final List<dynamic> subChapterMaterialList;
  final Map<String, bool> checkedChapter;
  final Map<String, bool> checkedSubChapter;

  /// Controls whether the Materi/Kuis/Ref tags render in colour (true) or
  /// grey (false) for each sub-chapter row. Purely visual. (#141)
  final Map<String, bool> generatedSubChapter;
  final Color primaryColor;
  final void Function(String chapterId, bool? value) onChapterCheck;
  final void Function(String subChapterId, String chapterId, bool? value)
  onSubChapterCheck;
  final void Function(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> chapter,
  )
  onSubChapterTap;

  const MaterialTimelineView({
    super.key,
    required this.chapters,
    required this.subChapterMaterialList,
    required this.checkedChapter,
    required this.checkedSubChapter,
    required this.generatedSubChapter,
    required this.primaryColor,
    required this.onChapterCheck,
    required this.onSubChapterCheck,
    required this.onSubChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: chapters.asMap().entries.expand((entry) {
        final idx = entry.key;
        final chapter = entry.value;
        final chId = chapter['id'].toString();
        final chColor = ColorUtils.getColorForIndex(idx);
        final subs = subChapterMaterialList
            .where((sc) => sc['bab_id'].toString() == chId)
            .toList();

        return [
          _ChapterHeader(
            chapter: chapter,
            index: idx,
            color: chColor,
            subCount: subs.length,
            checkedChapter: checkedChapter,
            checkedSubChapter: checkedSubChapter,
            subs: subs,
            onCheck: onChapterCheck,
          ),
          ...subs.asMap().entries.map((subEntry) {
            final subIdx = subEntry.key;
            final sc = subEntry.value;
            return _SubChapterTimelineItem(
              subChapter: sc,
              chapter: chapter,
              chapterColor: chColor,
              isLast: subIdx == subs.length - 1,
              isChecked: checkedSubChapter[sc['id'].toString()] ?? false,
              isGenerated: generatedSubChapter[sc['id'].toString()] ?? false,
              primaryColor: primaryColor,
              onCheck: onSubChapterCheck,
              onTap: onSubChapterTap,
            );
          }),
        ];
      }).toList(),
    );
  }
}

// ── Chapter header row ──

class _ChapterHeader extends StatelessWidget {
  final dynamic chapter;
  final int index;
  final Color color;
  final int subCount;
  final Map<String, bool> checkedChapter;
  final Map<String, bool> checkedSubChapter;
  final List<dynamic> subs;
  final void Function(String, bool?) onCheck;

  const _ChapterHeader({
    required this.chapter,
    required this.index,
    required this.color,
    required this.subCount,
    required this.checkedChapter,
    required this.checkedSubChapter,
    required this.subs,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final chId = chapter['id'].toString();
    final checkState = _resolveCheckState(chId);

    return Padding(
      padding: EdgeInsets.only(top: index > 0 ? 20 : 4, bottom: 8),
      child: Row(
        children: [
          _indexBadge(),
          const SizedBox(width: 12),
          _titleColumn(),
          _checkButton(chId, checkState),
        ],
      ),
    );
  }

  ({bool isAll, bool isPartial}) _resolveCheckState(String chId) {
    final isChChecked = checkedChapter[chId] ?? false;
    final checkedCount = subs
        .where((sc) => checkedSubChapter[sc['id'].toString()] == true)
        .length;
    final isAll = subs.isNotEmpty ? checkedCount == subs.length : isChChecked;
    final isPartial = subs.isNotEmpty && checkedCount > 0 && !isAll;
    return (isAll: isAll, isPartial: isPartial);
  }

  Widget _indexBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          '${chapter['urutan'] ?? index + 1}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _titleColumn() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter['judul_bab'] ?? chapter['title'] ?? '-',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ColorUtils.slate900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subCount > 0)
            Text(
              '$subCount sub-bab',
              style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _checkButton(String chId, ({bool isAll, bool isPartial}) state) {
    Color bgColor = ColorUtils.slate50;
    Color borderColor = ColorUtils.slate300;
    double borderWidth = 1;
    Widget? icon;

    if (state.isAll) {
      bgColor = ColorUtils.success600;
      borderColor = ColorUtils.success600;
      borderWidth = 1.5;
      icon = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
    } else if (state.isPartial) {
      bgColor = ColorUtils.slate500;
      borderColor = ColorUtils.slate500;
      borderWidth = 1.5;
      icon = const Icon(Icons.remove_rounded, size: 16, color: Colors.white);
    }

    return GestureDetector(
      onTap: () => onCheck(chId, !state.isAll),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: icon,
      ),
    );
  }
}

// ── Sub-chapter timeline item ──

class _SubChapterTimelineItem extends StatelessWidget {
  final dynamic subChapter;
  final dynamic chapter;
  final Color chapterColor;
  final bool isLast;
  final bool isChecked;
  final bool isGenerated;
  final Color primaryColor;
  final void Function(String, String, bool?) onCheck;
  final void Function(Map<String, dynamic>, Map<String, dynamic>) onTap;

  const _SubChapterTimelineItem({
    required this.subChapter,
    required this.chapter,
    required this.chapterColor,
    required this.isLast,
    required this.isChecked,
    required this.isGenerated,
    required this.primaryColor,
    required this.onCheck,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scId = subChapter['id'].toString();
    final chId = chapter['id'].toString();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _timelineConnector(),
          const SizedBox(width: 12),
          _subChapterCard(scId, chId),
        ],
      ),
    );
  }

  Widget _timelineConnector() {
    final lineColor = chapterColor.withValues(alpha: 0.3);
    return SizedBox(
      width: 36,
      child: Column(
        children: [
          Container(width: 2, height: 8, color: lineColor),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked ? ColorUtils.success600 : lineColor,
            ),
          ),
          if (!isLast) Expanded(child: Container(width: 2, color: lineColor)),
        ],
      ),
    );
  }

  Widget _subChapterCard(String scId, String chId) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(
              Map<String, dynamic>.from(subChapter),
              Map<String, dynamic>.from(chapter),
            ),
            child: _cardContent(scId, chId),
          ),
        ),
      ),
    );
  }

  Widget _cardContent(String scId, String chId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked
              ? ColorUtils.success600.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subChapter['judul_sub_bab'] ?? subChapter['title'] ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: 4),
                _tagRow(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _checkbox(scId, chId),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: primaryColor),
        ],
      ),
    );
  }

  Widget _tagRow() {
    return Row(
      children: [
        _tag(Icons.auto_stories_rounded, 'Materi', ColorUtils.success600),
        const SizedBox(width: 8),
        _tag(Icons.quiz_rounded, 'Kuis', ColorUtils.warning600),
        const SizedBox(width: 8),
        _tag(Icons.bookmark_rounded, 'Ref', ColorUtils.info600),
      ],
    );
  }

  Widget _tag(IconData icon, String label, Color color) {
    // Matches the palette in `MaterialSubChapterList._infoBadge` so both
    // list and timeline views stay visually consistent. (#141)
    final effectiveColor = isGenerated ? color : ColorUtils.slate400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: effectiveColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: effectiveColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _checkbox(String scId, String chId) {
    return GestureDetector(
      onTap: () => onCheck(scId, chId, !isChecked),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isChecked ? ColorUtils.success600 : ColorUtils.slate50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isChecked ? ColorUtils.success600 : ColorUtils.slate300,
            width: isChecked ? 1.5 : 1,
          ),
        ),
        child: isChecked
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
