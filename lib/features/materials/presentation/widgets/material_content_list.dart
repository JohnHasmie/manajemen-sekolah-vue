// Scrollable chapter list for TeacherMaterialScreen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mixins/progress_card_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mixins/chapter_card_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mixins/helpers_mixin.dart';

class MaterialContentList extends StatelessWidget
    with HelpersMixin, ProgressCardMixin, ChapterCardMixin {
  final List<dynamic> filteredChapterMaterials;
  final List<dynamic> subChapterMaterialList;
  final Map<String, bool> expandedChapter;
  final Map<String, bool> checkedChapter;
  final Map<String, bool> checkedSubChapter;

  /// Visual-only signal for the Materi/Kuis/Ref badges on each sub-chapter
  /// row. Does not affect the checkbox lock. (#141)
  final Map<String, bool> generatedSubChapter;
  final Color Function(String id, {bool isSubChapter}) getCheckboxColor;
  final void Function(String chapterId, bool newExpanded) onChapterExpanded;
  final void Function(String chapterId, bool? value) onChapterCheck;
  final void Function(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> chapter,
  )
  onSubChapterTap;
  final void Function(String subChapterId, String chapterId, bool? value)
  onSubChapterCheck;

  const MaterialContentList({
    super.key,
    required this.filteredChapterMaterials,
    required this.subChapterMaterialList,
    required this.expandedChapter,
    required this.checkedChapter,
    required this.checkedSubChapter,
    required this.generatedSubChapter,
    required this.getCheckboxColor,
    required this.onChapterExpanded,
    required this.onChapterCheck,
    required this.onSubChapterTap,
    required this.onSubChapterCheck,
  });

  @override
  Widget build(BuildContext context) {
    final totalChapters = filteredChapterMaterials.length;
    final completedChapters = filteredChapterMaterials
        .where((c) => checkedChapter[c['id'].toString()] == true)
        .length;
    final totalSubs = subChapterMaterialList.length;
    final completedSubs = checkedSubChapter.values.where((v) => v).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        buildProgressCard(
          totalChapters: totalChapters,
          completedChapters: completedChapters,
          totalSubs: totalSubs,
          completedSubs: completedSubs,
        ),
        ...filteredChapterMaterials.asMap().entries.map((entry) {
          final index = entry.key;
          final chapter = entry.value;
          return buildChapterCard(index: index, chapter: chapter);
        }),
      ],
    );
  }

  @override
  List<dynamic> getFilteredChapterMaterials() => filteredChapterMaterials;

  @override
  List<dynamic> getSubChapterMaterialList() => subChapterMaterialList;

  @override
  Map<String, bool> getExpandedChapter() => expandedChapter;

  @override
  Map<String, bool> getCheckedChapter() => checkedChapter;

  @override
  Map<String, bool> getCheckedSubChapter() => checkedSubChapter;

  @override
  Map<String, bool> getGeneratedSubChapter() => generatedSubChapter;

  @override
  Color Function(String id, {bool isSubChapter}) getCheckboxColorFn() =>
      getCheckboxColor;

  @override
  void Function(String chapterId, bool newExpanded) getOnChapterExpanded() =>
      onChapterExpanded;

  @override
  void Function(String chapterId, bool? value) getOnChapterCheck() =>
      onChapterCheck;

  @override
  void Function(Map<String, dynamic> subChapter, Map<String, dynamic> chapter)
  getOnSubChapterTap() => onSubChapterTap;

  @override
  void Function(String subChapterId, String chapterId, bool? value)
  getOnSubChapterCheck() => onSubChapterCheck;
}
