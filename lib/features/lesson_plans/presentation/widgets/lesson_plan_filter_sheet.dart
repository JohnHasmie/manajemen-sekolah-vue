// Filter bottom sheet for lesson plan status selection.
// Uses the shared AppFilterBottomSheet, FilterChipGrid, and FilterSectionHeader
// for consistent styling with schedule and activity filter sheets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';

/// Shows a filter bottom sheet for lesson plan status selection.
void showLessonPlanFilterSheet({
  required BuildContext context,
  required Color primaryColor,
  required LanguageProvider languageProvider,
  required String? currentStatus,
  required ValueChanged<String?> onApply,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LessonPlanFilterSheetContent(
      primaryColor: primaryColor,
      languageProvider: languageProvider,
      currentStatus: currentStatus,
      onApply: onApply,
    ),
  );
}

/// Internal stateful widget for the lesson plan filter sheet.
class _LessonPlanFilterSheetContent extends StatefulWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String? currentStatus;
  final ValueChanged<String?> onApply;

  const _LessonPlanFilterSheetContent({
    required this.primaryColor,
    required this.languageProvider,
    required this.currentStatus,
    required this.onApply,
  });

  @override
  State<_LessonPlanFilterSheetContent> createState() =>
      _LessonPlanFilterSheetContentState();
}

class _LessonPlanFilterSheetContentState
    extends State<_LessonPlanFilterSheetContent> {
  late String? _tempSelectedStatus;

  @override
  void initState() {
    super.initState();
    _tempSelectedStatus = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;

    final statusOptions = [
      FilterOption(
        value: null,
        label: lang.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      ),
      FilterOption(value: 'Draft', label: 'Draft'),
      FilterOption(
        value: 'Pending',
        label: lang.getTranslatedText({'en': 'Pending', 'id': 'Menunggu'}),
      ),
      FilterOption(
        value: 'Approved',
        label: lang.getTranslatedText({'en': 'Approved', 'id': 'Disetujui'}),
      ),
      FilterOption(
        value: 'Rejected',
        label: lang.getTranslatedText({'en': 'Rejected', 'id': 'Ditolak'}),
      ),
    ];

    return AppFilterBottomSheet(
      title: lang.getTranslatedText({
        'en': 'Filter Lesson Plans',
        'id': 'Filter RPP',
      }),
      icon: Icons.tune_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterSectionHeader(
            title: lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
            icon: Icons.check_circle_outline_rounded,
            primaryColor: widget.primaryColor,
          ),
          FilterChipGrid<String?>(
            options: statusOptions,
            selectedValue: _tempSelectedStatus,
            onSelected: (value) => setState(() => _tempSelectedStatus = value),
            selectedColor: widget.primaryColor,
          ),
        ],
      ),
      onApply: () {
        widget.onApply(_tempSelectedStatus);
        Navigator.pop(context);
      },
      onReset: () => setState(() => _tempSelectedStatus = null),
    );
  }
}
