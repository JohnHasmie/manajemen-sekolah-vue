import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Toggle + chapter dropdown + sub-chapter multi-select tap widget.
///
/// Shown inside [AddActivityDialog] to let the teacher choose whether to
/// derive the activity title from a chapter/sub-chapter or type it manually.
///
/// Callbacks:
/// - [onToggleMaterialTitle] — user flipped the "Choose from material" switch
/// - [onChapterChanged]      — user selected a different chapter
/// - [onSubChapterTap]       — user tapped the sub-chapter field (opens picker)
class AddActivityMaterialSelector extends StatelessWidget {
  final bool useMaterialTitle;
  final bool isLoadingChapters;
  final String? selectedSubjectId;
  final String? selectedChapterId;
  final List<String> selectedSubChapterIds;
  final List<dynamic> chapterMaterialList;
  final List<dynamic> subChapterMaterialList;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  final void Function(bool) onToggleMaterialTitle;
  final void Function(String?) onChapterChanged;
  final VoidCallback onSubChapterTap;
  final String Function(dynamic) getChapterName;
  final String Function(dynamic) getSubChapterName;

  const AddActivityMaterialSelector({
    super.key,
    required this.useMaterialTitle,
    required this.isLoadingChapters,
    required this.selectedSubjectId,
    required this.selectedChapterId,
    required this.selectedSubChapterIds,
    required this.chapterMaterialList,
    required this.subChapterMaterialList,
    required this.primaryColor,
    required this.languageProvider,
    required this.onToggleMaterialTitle,
    required this.onChapterChanged,
    required this.onSubChapterTap,
    required this.getChapterName,
    required this.getSubChapterName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle row
        Row(
          children: [
            Icon(Icons.title, size: 20, color: ColorUtils.slate600),
            SizedBox(width: AppSpacing.sm),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Choose from material',
                'id': 'Pilih dari materi',
              }),
              style: TextStyle(fontSize: 14),
            ),
            Spacer(),
            Switch(
              value: useMaterialTitle,
              onChanged: selectedSubjectId == null ? null : onToggleMaterialTitle,
              activeThumbColor: primaryColor,
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),

        // Chapter dropdown (only when toggle is ON)
        if (useMaterialTitle) ...[
          Builder(
            builder: (context) {
              final Map<String, DropdownMenuItem<String>> uniqueChapterItems = {};
              for (var chapter in chapterMaterialList) {
                final id = chapter['id']?.toString();
                if (id != null && !uniqueChapterItems.containsKey(id)) {
                  uniqueChapterItems[id] = DropdownMenuItem<String>(
                    value: id,
                    child: Text(getChapterName(chapter)),
                  );
                }
              }
              final List<DropdownMenuItem<String>> chapterItems =
                  uniqueChapterItems.values.toList();

              return DropdownButtonFormField<String>(
                key: ValueKey(
                  'bab_${selectedChapterId}_${chapterItems.length}',
                ),
                decoration: InputDecoration(
                  labelText: languageProvider.getTranslatedText({
                    'en': 'Chapter',
                    'id': 'Bab Materi',
                  }),
                  prefixIcon: Icon(Icons.menu_book),
                  border: OutlineInputBorder(),
                ),
                initialValue:
                    (chapterItems.any(
                      (item) => item.value == selectedChapterId,
                    ))
                    ? selectedChapterId
                    : null,
                isExpanded: true,
                items: chapterItems.isEmpty ? null : chapterItems,
                onChanged: chapterItems.isEmpty ? null : onChapterChanged,
                hint: Text(
                  languageProvider.getTranslatedText({
                    'en': isLoadingChapters
                        ? 'Loading chapters...'
                        : (chapterItems.isEmpty
                              ? AppLocalizations.noChapters['en']!
                              : 'Select Chapter'),
                    'id': isLoadingChapters
                        ? 'Memuat bab...'
                        : (chapterItems.isEmpty
                              ? AppLocalizations.noChapters['id']!
                              : 'Pilih Bab'),
                  }),
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.md),
        ],

        // Sub-chapter multi-select tap (only when chapter is selected)
        if (useMaterialTitle && selectedChapterId != null) ...[
          InkWell(
            onTap: onSubChapterTap,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: languageProvider.getTranslatedText({
                  'en': 'Sub Chapters',
                  'id': 'Sub Bab Materi',
                }),
                prefixIcon: Icon(Icons.article),
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                selectedSubChapterIds.isEmpty
                    ? languageProvider.getTranslatedText({
                        'en': 'Select Sub Chapters (optional)',
                        'id': 'Pilih Sub Bab (opsional)',
                      })
                    : selectedSubChapterIds.length == 1
                    ? getSubChapterName(
                        subChapterMaterialList.firstWhere(
                          (s) =>
                              s['id'].toString() == selectedSubChapterIds.first,
                          orElse: () => {},
                        ),
                      )
                    : '${selectedSubChapterIds.length} ${languageProvider.getTranslatedText({'en': 'selected', 'id': 'dipilih'})}',
                style: TextStyle(
                  color: selectedSubChapterIds.isEmpty
                      ? ColorUtils.slate600
                      : ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
