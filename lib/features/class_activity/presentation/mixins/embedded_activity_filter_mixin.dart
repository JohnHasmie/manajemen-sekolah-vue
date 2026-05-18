import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_dialog.dart';

/// Handles filtering and activity detail display.
mixin EmbeddedActivityFilterMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  Color get primaryColor;

  String? get selectedDateFilter;
  set selectedDateFilter(String? value);

  bool get hasActiveFilter;
  set hasActiveFilter(bool value);

  // Abstract methods
  void resetAndLoadActivities();
  void showEditActivityDialog(dynamic activity);

  void showFilterSheet() {
    final lp = ref.read(languageRiverpod);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityDateFilterSheet(
        primaryColor: primaryColor,
        languageProvider: lp,
        initialDateFilter: selectedDateFilter,
        onApply: (dateFilter) {
          setState(() {
            selectedDateFilter = dateFilter;
            hasActiveFilter = selectedDateFilter != null;
          });
          resetAndLoadActivities();
        },
      ),
    );
  }

  void showActivityDetail(dynamic activity) {
    ActivityDetailDialog.show(
      context: context,
      activity: activity,
      primaryColor: primaryColor,
      languageProvider: ref.read(languageRiverpod),
      canEdit: widget.canEdit,
      selectedClassName: widget.className,
      selectedSubjectName: widget.subjectName,
      onEditPressed: () => showEditActivityDialog(activity),
    );
  }
}

/// Inline date-range filter sheet for the embedded activity list.
///
/// Previously lived in its own `filter_bottom_sheet.dart` widget file — now
/// collocated with its only caller (the filter mixin) and composed from the
/// shared `AppFilterBottomSheet` + `FilterChipGrid` primitives.
class _ActivityDateFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String? initialDateFilter;
  final void Function(String? dateFilter) onApply;

  const _ActivityDateFilterSheet({
    required this.primaryColor,
    required this.languageProvider,
    required this.initialDateFilter,
    required this.onApply,
  });

  @override
  State<_ActivityDateFilterSheet> createState() =>
      _ActivityDateFilterSheetState();
}

class _ActivityDateFilterSheetState extends State<_ActivityDateFilterSheet> {
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
      onReset: () =>
          FilterSheetHelpers.reset(context, () => widget.onApply(null)),
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
        ],
      ),
    );
  }
}
