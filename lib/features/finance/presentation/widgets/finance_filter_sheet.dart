// Bottom-sheet for filtering payment types by status and period.
//
// Extracted from `_showFilterSheet` in admin_finance_screen.dart.
// Owns its own temporary selection state via StatefulWidget — like a Vue
// component with local `tempSelectedStatus` / `tempSelectedPeriod` data.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';

import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// Bottom-sheet widget for filtering payment types.
class FinanceFilterSheet extends StatefulWidget {
  /// Currently active status filter ('aktif', 'non_aktif', or null).
  final String? currentStatus;

  /// Currently active period filter ('bulanan', 'tahunan', or null).
  final String? currentPeriod;

  /// Resolved language provider from the parent (avoids a second ref.read).
  final LanguageProvider languageProvider;

  /// Primary brand colour already resolved by the parent screen.
  final Color? primaryColor;

  /// Called with the new (status, period) values when the admin taps Apply.
  final void Function(String? status, String? period) onApply;

  const FinanceFilterSheet({
    super.key,
    this.currentStatus,
    this.currentPeriod,
    required this.languageProvider,
    this.primaryColor,
    required this.onApply,
  });

  /// Canonical entry point — wraps [showModalBottomSheet] so callers don't
  /// re-derive `isScrollControlled` / transparent background / barrier
  /// behaviour every time. Mirrors the `App*BottomSheet.show()` pattern.
  static Future<void> show({
    required BuildContext context,
    String? currentStatus,
    String? currentPeriod,
    required LanguageProvider languageProvider,
    Color? primaryColor,
    required void Function(String? status, String? period) onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FinanceFilterSheet(
        currentStatus: currentStatus,
        currentPeriod: currentPeriod,
        languageProvider: languageProvider,
        primaryColor: primaryColor,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FinanceFilterSheet> createState() => _FinanceFilterSheetState();
}

class _FinanceFilterSheetState extends State<FinanceFilterSheet> {
  late String? _tempStatus;
  late String? _tempPeriod;

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.currentStatus;
    _tempPeriod = widget.currentPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;
    final primary = widget.primaryColor ?? ColorUtils.primary;

    return AppFilterBottomSheet(
      title: lang.getTranslatedText({
        'en': 'Filter Finance',
        'id': 'Filter Keuangan',
      }),
      icon: Icons.tune_rounded,
      primaryColor: primary,
      maxHeightFactor: 0.75,
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
                icon: Icons.check_circle_outline_rounded,
                primaryColor: primary,
              ),
              FilterChipGrid<String?>(
                options: [
                  FilterOption(
                    value: 'aktif',
                    label: lang.getTranslatedText({
                      'en': 'Active',
                      'id': 'Aktif',
                    }),
                  ),
                  FilterOption(
                    value: 'non_aktif',
                    label: lang.getTranslatedText({
                      'en': 'Inactive',
                      'id': 'Non-Aktif',
                    }),
                  ),
                ],
                selectedValue: _tempStatus,
                onSelected: (value) => setState(() => _tempStatus = value),
                selectedColor: primary,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Payment Period',
                  'id': 'Periode Pembayaran',
                }),
                icon: Icons.event_repeat_rounded,
                primaryColor: primary,
              ),
              FilterChipGrid<String?>(
                options: [
                  FilterOption(
                    value: 'sekali bayar',
                    label: lang.getTranslatedText({
                      'en': 'One Time',
                      'id': 'Sekali',
                    }),
                  ),
                  FilterOption(
                    value: 'bulanan',
                    label: lang.getTranslatedText({
                      'en': 'Monthly',
                      'id': 'Bulanan',
                    }),
                  ),
                  FilterOption(
                    value: 'semester',
                    label: lang.getTranslatedText({
                      'en': 'Semester',
                      'id': 'Semester',
                    }),
                  ),
                  FilterOption(
                    value: 'tahunan',
                    label: lang.getTranslatedText({
                      'en': 'Yearly',
                      'id': 'Tahunan',
                    }),
                  ),
                ],
                selectedValue: _tempPeriod,
                onSelected: (value) => setState(() => _tempPeriod = value),
                selectedColor: primary,
              ),
            ],
          ),
        ],
      ),
      onApply: () {
        AppNavigator.pop(context);
        widget.onApply(_tempStatus, _tempPeriod);
      },
      onReset: () => setState(() {
        _tempStatus = null;
        _tempPeriod = null;
      }),
    );
  }
}
