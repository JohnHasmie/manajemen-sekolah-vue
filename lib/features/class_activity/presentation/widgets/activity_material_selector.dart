import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Widget for selecting material source (manual or from chapters)
class ActivityMaterialSelector extends StatelessWidget {
  final bool useMaterialTitle;
  final String? selectedSubjectId;
  final VoidCallback onMaterialModeToggle;
  final Function(bool) onMaterialModeChanged;

  const ActivityMaterialSelector({
    super.key,
    required this.useMaterialTitle,
    required this.selectedSubjectId,
    required this.onMaterialModeToggle,
    required this.onMaterialModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: [
          const ButtonSegment<bool>(
            value: false,
            label: Text('Tulis Manual'),
            icon: Icon(Icons.edit_note_rounded, size: 16),
          ),
          ButtonSegment<bool>(
            value: true,
            label: const Text('Dari Materi'),
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            enabled: selectedSubjectId != null,
          ),
        ],
        selected: {useMaterialTitle},
        onSelectionChanged: (sel) {
          onMaterialModeChanged(sel.first);
        },
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.withValues(alpha: 0.1),
          selectedForegroundColor: p,
          foregroundColor: ColorUtils.slate500,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: ColorUtils.slate200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying chapter selection chips
class ActivityChapterSelector extends StatelessWidget {
  final List<dynamic> chapters;
  final bool isLoading;
  final String? selectedChapterId;
  final Function(String) onChapterSelected;
  final String Function(dynamic) getChapterName;

  const ActivityChapterSelector({
    super.key,
    required this.chapters,
    required this.isLoading,
    required this.selectedChapterId,
    required this.onChapterSelected,
    required this.getChapterName,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    if (isLoading) {
      return Row(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(right: 8),
            width: 72,
            height: 32,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (chapters.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: ColorUtils.slate400,
            ),
            const SizedBox(width: 8),
            Text(
              'Tidak ada bab tersedia',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chapters.map((ch) {
        final id = ch['id'].toString();
        final isSelected = id == selectedChapterId;
        return ChoiceChip(
          label: Text(getChapterName(ch)),
          selected: isSelected,
          onSelected: (_) {
            onChapterSelected(id);
          },
          showCheckmark: false,
          selectedColor: p.withValues(alpha: 0.12),
          labelStyle: TextStyle(
            fontSize: 12,
            color: isSelected ? p : ColorUtils.slate600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected ? p.withValues(alpha: 0.3) : ColorUtils.slate200,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        );
      }).toList(),
    );
  }
}

/// Widget for displaying and selecting sub-chapters
class ActivitySubChapterSelector extends StatelessWidget {
  final List<dynamic> subChapters;
  final List<String> selectedSubChapterIds;
  final Function(String, bool) onSubChapterToggled;
  final String Function(dynamic) getSubChapterName;
  final VoidCallback? onViewAll;

  const ActivitySubChapterSelector({
    super.key,
    required this.subChapters,
    required this.selectedSubChapterIds,
    required this.onSubChapterToggled,
    required this.getSubChapterName,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: subChapters.take(7).map((sub) {
        final subId = sub['id'].toString();
        final isSelected = selectedSubChapterIds.contains(subId);
        return FilterChip(
          label: Text(getSubChapterName(sub)),
          selected: isSelected,
          onSelected: (val) {
            onSubChapterToggled(subId, val);
          },
          selectedColor: p.withValues(alpha: 0.08),
          checkmarkColor: p,
          labelStyle: TextStyle(
            fontSize: 11.5,
            color: isSelected ? p : ColorUtils.slate600,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected ? p.withValues(alpha: 0.25) : ColorUtils.slate200,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

/// Dialog for multi-selecting sub chapters
void showMultiSelectSubBabDialog({
  required BuildContext context,
  required LanguageProvider languageProvider,
  required List<dynamic> subChapters,
  required List<String> selectedSubChapterIds,
  required String Function(dynamic) getSubChapterName,
  required Function(String, bool) onSubChapterToggled,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'Select Sub Chapters',
                'id': 'Pilih Sub Bab',
              }),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: subChapters.map((subChapter) {
                  final subId = subChapter['id'].toString();
                  final isSelected = selectedSubChapterIds.contains(subId);
                  return CheckboxListTile(
                    title: Text(getSubChapterName(subChapter)),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        onSubChapterToggled(subId, value == true);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => AppNavigator.pop(context),
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Done',
                    'id': 'Selesai',
                  }),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
