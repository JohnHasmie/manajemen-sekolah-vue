import 'package:flutter/material.dart';

mixin HelpersMixin {
  List<dynamic> getFilteredChapterMaterials();
  List<dynamic> getSubChapterMaterialList();
  Map<String, bool> getExpandedChapter();
  Map<String, bool> getCheckedChapter();
  Map<String, bool> getCheckedSubChapter();
  /// Map of subChapterId → is_generated. Purely a visual signal for the
  /// three Materi/Kuis/Ref badges; does not drive the checkbox lock. (#141)
  Map<String, bool> getGeneratedSubChapter();
  Color Function(String id, {bool isSubChapter}) getCheckboxColorFn();

  int getSubChapterCount(String chapterId) {
    return getSubChapterMaterialList()
        .where((sc) => sc['bab_id'].toString() == chapterId)
        .length;
  }

  int getCheckedSubCount(String chapterId) {
    return getSubChapterMaterialList()
        .where(
          (sc) =>
              sc['bab_id'].toString() == chapterId &&
              getCheckedSubChapter()[sc['id'].toString()] == true,
        )
        .length;
  }

  bool isChapterExpanded(String chapterId) {
    return getExpandedChapter()[chapterId] ?? false;
  }

  bool isChapterChecked(String chapterId) {
    return getCheckedChapter()[chapterId] ?? false;
  }

  bool isSubChapterChecked(String subChapterId) {
    return getCheckedSubChapter()[subChapterId] ?? false;
  }
}
