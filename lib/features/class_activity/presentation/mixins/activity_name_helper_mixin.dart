import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';

/// Mixin providing name extraction utilities for chapters and sub-chapters
mixin ActivityNameHelperMixin on ConsumerState<AddActivityDialog> {
  /// Extracts chapter name from chapter data map
  String getChapterName(dynamic chapter) => _extractChapterName(chapter);

  /// Extracts sub-chapter name from sub-chapter data map
  String getSubChapterName(dynamic subChapter) =>
      _extractSubChapterName(subChapter);

  String _extractChapterName(dynamic chapter) {
    return chapter['chapter_title']?.toString() ??
        chapter['judul_bab']?.toString() ??
        chapter['nama']?.toString() ??
        chapter['judul']?.toString() ??
        chapter['title']?.toString() ??
        chapter['name']?.toString() ??
        'Unknown';
  }

  String _extractSubChapterName(dynamic subChapter) {
    return subChapter['sub_chapter_title']?.toString() ??
        subChapter['judul_sub_bab']?.toString() ??
        subChapter['nama']?.toString() ??
        subChapter['judul']?.toString() ??
        subChapter['title']?.toString() ??
        subChapter['name']?.toString() ??
        'Unknown';
  }

  /// Updates title controller text based on selected chapter and sub-chapter
  /// materials
  void updateTitleFromMaterial({
    required String? selectedChapterId,
    required String? selectedSubChapterId,
    required List<dynamic> chapterMaterialList,
    required List<dynamic> subChapterMaterialList,
    required Function(String) onTitleUpdated,
  }) {
    String chapterName = '';
    String subChapterName = '';

    if (selectedChapterId != null && chapterMaterialList.isNotEmpty) {
      final chapter = chapterMaterialList.firstWhere(
        (b) => b['id']?.toString() == selectedChapterId,
        orElse: () => <String, dynamic>{},
      );
      if (chapter.isNotEmpty) {
        chapterName = _extractChapterName(chapter);
      }
    }

    if (selectedSubChapterId != null && subChapterMaterialList.isNotEmpty) {
      final subChapter = subChapterMaterialList.firstWhere(
        (item) => item['id']?.toString() == selectedSubChapterId,
        orElse: () => <String, dynamic>{},
      );
      if (subChapter.isNotEmpty) {
        subChapterName = _extractSubChapterName(subChapter);
      }
    }

    String title = '';
    if (chapterName.isNotEmpty && subChapterName.isNotEmpty) {
      title = '$chapterName - $subChapterName';
    } else if (chapterName.isNotEmpty) {
      title = chapterName;
    } else if (subChapterName.isNotEmpty) {
      title = subChapterName;
    }

    if (title.isNotEmpty && title != 'Unknown') {
      onTitleUpdated(title);
    }
  }
}
