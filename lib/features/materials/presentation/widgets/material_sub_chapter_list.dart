// Expandable sub-chapter list shown inside a chapter card on
// TeacherMaterialScreen — Frame B of the Materi Q.2 redesign.
//
// Visual contract (mockup `_design/teacher_materi_redesign.html`
// Frame B):
//
//   ┌──────────────────────────────────────────────────────┐
//   │  ☑  Planet & Bintang                       [AI]    › │
//   │  ☑  Gravitasi & Orbit                      [AI]    › │
//   │  ☐  Bulan & Pasang Surut              [Belum AI]   › │
//   └──────────────────────────────────────────────────────┘
//
//   • 18dp cobalt-tinted square checkbox (left). When checked the
//     sub-bab title gets struck through and dimmed to slate.
//   • Title (12pt / 700 / slate-700, slate-500 + line-through when
//     checked).
//   • AI status pill on the right: violet `AI` when generated, slate
//     `Belum AI` when not. Same colour mapping the chapter-row stat
//     pill uses.
//   • Slate chevron-right indicator.
//
// All rows are tappable — onSubChapterTap navigates to the
// sub-chapter detail screen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class MaterialSubChapterList extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final List<dynamic> subChapterMaterialList;
  final Map<String, bool> checkedSubChapter;

  /// Whether each sub-chapter has AI-generated content. Drives the
  /// `AI` (violet) vs `Belum AI` (slate) pill on the right of each
  /// row. Does NOT affect the checkbox lock — those two are
  /// independent dimensions.
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(
            color: ColorUtils.slate400,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final cobalt = ColorUtils.brandCobalt;

    return Container(
      // Cobalt-tinted background so the sub-list visually nests
      // inside the chapter card the way the mockup shows.
      color: ColorUtils.slate50.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: List.generate(subChaptersForChapter.length, (i) {
          final subChapter = subChaptersForChapter[i];
          final subChapterIdStr = subChapter['id'].toString();
          final isChecked = checkedSubChapter[subChapterIdStr] ?? false;
          final isGenerated = generatedSubChapter[subChapterIdStr] ?? false;
          final isLast = i == subChaptersForChapter.length - 1;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSubChapterTap(subChapter, chapter),
              child: Container(
                padding: const EdgeInsets.fromLTRB(50, 10, 14, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isLast ? Colors.transparent : ColorUtils.slate100,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SubCheckbox(
                      isChecked: isChecked,
                      cobalt: cobalt,
                      onTap: () => onSubChapterCheck(
                        subChapterIdStr,
                        chapter['id'].toString(),
                        !isChecked,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subChapter['judul_sub_bab']?.toString() ?? 'Sub-Bab',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Bumped from 12 → 14 to narrow the readability
                          // gap with the 15pt parent title above. Sits
                          // one tick smaller so the visual hierarchy is
                          // still clear without straining the teacher's
                          // eye on long sub-bab names.
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isChecked
                              ? ColorUtils.slate500
                              : ColorUtils.slate800,
                          height: 1.3,
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: ColorUtils.slate400,
                          decorationThickness: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AiPill(isGenerated: isGenerated),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: ColorUtils.slate300,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SubCheckbox extends StatelessWidget {
  final bool isChecked;
  final Color cobalt;
  final VoidCallback onTap;

  const _SubCheckbox({
    required this.isChecked,
    required this.cobalt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isChecked ? cobalt : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isChecked ? cobalt : ColorUtils.slate300,
            width: 1.4,
          ),
        ),
        child: isChecked
            ? const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

class _AiPill extends StatelessWidget {
  final bool isGenerated;

  const _AiPill({required this.isGenerated});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = isGenerated
        ? (
            const Color(0xFFEDE9FE),
            const Color(0xFF7C3AED),
            'AI',
          )
        : (
            ColorUtils.slate100,
            ColorUtils.slate500,
            'Belum AI',
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
    );
  }
}
