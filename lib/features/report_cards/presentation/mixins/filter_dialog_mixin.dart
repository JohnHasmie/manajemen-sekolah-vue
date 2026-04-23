import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';

mixin FilterDialogMixin on ConsumerState<ReportCardOverviewPage> {
  String? get filterStatus;
  set filterStatus(String? value);
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  void showFilterDialog(LanguageProvider lp) {
    String? tempStatus = filterStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportCardFilterSheet(
        initialStatus: tempStatus,
        primaryColor: primaryColor,
        languageProvider: lp,
        onApply: (status) {
          setState(() => filterStatus = status);
        },
      ),
    );
  }
}

/// Stateful filter sheet for report card status filtering.
class _ReportCardFilterSheet extends StatefulWidget {
  final String? initialStatus;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final ValueChanged<String?> onApply;

  const _ReportCardFilterSheet({
    required this.initialStatus,
    required this.primaryColor,
    required this.languageProvider,
    required this.onApply,
  });

  @override
  State<_ReportCardFilterSheet> createState() => _ReportCardFilterSheetState();
}

class _ReportCardFilterSheetState extends State<_ReportCardFilterSheet> {
  late String? _tempStatus;

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.initialStatus;
  }

  LanguageProvider get _lp => widget.languageProvider;

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: _lp.getTranslatedText({
        'en': 'Filter Report Card',
        'id': 'Filter Raport',
      }),
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      onApply: () {
        Navigator.pop(context);
        widget.onApply(_tempStatus);
      },
      onReset: () => setState(() => _tempStatus = null),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterSectionHeader(
            title: _lp.getTranslatedText({
              'en': 'Report Card Status',
              'id': 'Status Raport',
            }),
            icon: Icons.assignment_outlined,
            primaryColor: widget.primaryColor,
          ),
          FilterChipGrid<String>(
            options: [
              FilterOption(
                value: 'incomplete',
                label: _lp.getTranslatedText({
                  'en': 'Incomplete',
                  'id': 'Belum Lengkap',
                }),
              ),
              FilterOption(
                value: 'draft',
                label: _lp.getTranslatedText({
                  'en': 'Has Draft',
                  'id': 'Ada Draft',
                }),
              ),
              FilterOption(
                value: 'complete',
                label: _lp.getTranslatedText({
                  'en': 'Complete',
                  'id': 'Selesai',
                }),
              ),
            ],
            selectedValue: _tempStatus,
            onSelected: (val) => setState(() => _tempStatus = val),
            selectedColor: widget.primaryColor,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
