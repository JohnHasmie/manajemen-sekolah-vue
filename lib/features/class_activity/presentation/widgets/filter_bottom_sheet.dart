// Filter bottom sheet widget for the class-activity screen.
// Extracted from teacher_class_activity_screen.dart to reduce file size.
// Like a Vue child component that emits 'apply' with the selected filter values.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';

/// Bottom sheet that lets the user pick a date-range filter
/// ('today', 'week', or 'month').
///
/// Call [FilterBottomSheet.show] to display it.
/// [onApply] is called with the selected filter value (or null to clear).
class FilterBottomSheet extends StatefulWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String? initialDateFilter;
  final void Function(String? dateFilter) onApply;

  const FilterBottomSheet({
    super.key,
    required this.primaryColor,
    required this.languageProvider,
    required this.initialDateFilter,
    required this.onApply,
  });

  /// Helper to open this sheet as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required String? initialDateFilter,
    required void Function(String? dateFilter) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        initialDateFilter: initialDateFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String? _tempDateFilter;

  @override
  void initState() {
    super.initState();
    _tempDateFilter = widget.initialDateFilter;
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;
    return AppFilterBottomSheet(
      title: lp.getTranslatedText({
        'en': 'Filter Activities',
        'id': 'Filter Kegiatan',
      }),
      icon: Icons.tune_rounded,
      primaryColor: widget.primaryColor,
      onApply: () {
        Navigator.pop(context);
        widget.onApply(_tempDateFilter);
      },
      onReset: () => setState(() => _tempDateFilter = null),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterSectionHeader(
            title: lp.getTranslatedText({
              'en': 'Time Range',
              'id': 'Rentang Waktu',
            }),
            icon: Icons.date_range_rounded,
            primaryColor: widget.primaryColor,
          ),
          FilterChipGrid<String>(
            options: [
              FilterOption(
                value: 'today',
                label: lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
              ),
              FilterOption(
                value: 'week',
                label: lp.getTranslatedText({
                  'en': 'This Week',
                  'id': 'Minggu Ini',
                }),
              ),
              FilterOption(
                value: 'month',
                label: lp.getTranslatedText({
                  'en': 'This Month',
                  'id': 'Bulan Ini',
                }),
              ),
            ],
            selectedValue: _tempDateFilter,
            onSelected: (val) => setState(() => _tempDateFilter = val),
            selectedColor: widget.primaryColor,
          ),
          // No trailing SizedBox: [AppFilterBottomSheet]'s `mainAxisSize.min`
          // shrink-wraps the sheet to content height, and the footer supplies
          // its own padding — matches every other single-section filter sheet.
        ],
      ),
    );
  }
}
