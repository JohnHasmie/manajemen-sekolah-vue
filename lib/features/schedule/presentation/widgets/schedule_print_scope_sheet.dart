// Bottom sheet that lets admin pick a Print PDF scope before generating
// the schedule PDF.
//
// Added in Fix-1c — sits behind the BrandHeaderIconButton on the admin
// Jadwal screen. The three radio-style tiles mirror the backend's
// `scope` contract (all | per_teacher | per_class). Selecting a tile
// closes the sheet and triggers [onConfirm] with the chosen scope.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/schedule/exports/schedule_print_pdf_service.dart';

/// Picker for [SchedulePrintScope]. Drives the Print PDF flow.
class SchedulePrintScopeSheet extends StatefulWidget {
  const SchedulePrintScopeSheet({
    super.key,
    required this.onConfirm,
    this.initialScope = SchedulePrintScope.all,
    this.filterSummary,
  });

  /// Fired with the chosen scope after admin taps "Cetak PDF". The sheet
  /// pops itself before invoking the callback so the caller can show a
  /// loading indicator without contention.
  final void Function(SchedulePrintScope) onConfirm;

  /// Pre-selected scope. Defaults to [SchedulePrintScope.all].
  final SchedulePrintScope initialScope;

  /// Optional one-line summary of the currently-applied filters, shown
  /// under the subtitle so admin sees the PDF will reflect what's
  /// visible. E.g. "Filter aktif: Guru Pak Adi · Kelas X IPA 1".
  final String? filterSummary;

  static Future<void> show({
    required BuildContext context,
    required void Function(SchedulePrintScope) onConfirm,
    SchedulePrintScope initialScope = SchedulePrintScope.all,
    String? filterSummary,
  }) {
    return AppBottomSheet.show(
      context: context,
      title: 'Cetak PDF Jadwal',
      subtitle: 'Pilih bagaimana jadwal dikelompokkan dalam PDF.',
      icon: Icons.picture_as_pdf_rounded,
      primaryColor: ColorUtils.getRoleColor('admin'),
      content: SchedulePrintScopeSheet(
        onConfirm: onConfirm,
        initialScope: initialScope,
        filterSummary: filterSummary,
      ),
    );
  }

  @override
  State<SchedulePrintScopeSheet> createState() =>
      _SchedulePrintScopeSheetState();
}

class _SchedulePrintScopeSheetState extends State<SchedulePrintScopeSheet> {
  late SchedulePrintScope _selected = widget.initialScope;

  static const _options = <_ScopeOption>[
    _ScopeOption(
      scope: SchedulePrintScope.all,
      icon: Icons.view_list_rounded,
      title: 'Semua Jadwal',
      description:
          'Cetak dalam satu tabel datar, diurutkan berdasarkan hari dan jam.',
    ),
    _ScopeOption(
      scope: SchedulePrintScope.perTeacher,
      icon: Icons.person_outline_rounded,
      title: 'Per Guru',
      description:
          'Kelompokkan tabel per guru — cocok untuk membagikan jadwal masing-masing.',
    ),
    _ScopeOption(
      scope: SchedulePrintScope.perClass,
      icon: Icons.class_outlined,
      title: 'Per Kelas',
      description:
          'Kelompokkan tabel per kelas — cocok untuk ditempel di kelas atau dibagikan ke wali.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.getRoleColor('admin');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.filterSummary != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 16,
                  color: ColorUtils.slate500,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.filterSummary!,
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorUtils.slate700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final opt in _options) ...[
          _ScopeTile(
            option: opt,
            selected: _selected == opt.scope,
            primaryColor: primary,
            onTap: () => setState(() => _selected = opt.scope),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        BottomSheetFooter(
          primaryLabel: 'Cetak PDF',
          primaryColor: primary,
          onPrimary: () {
            AppNavigator.pop(context);
            widget.onConfirm(_selected);
          },
          onSecondary: () => AppNavigator.pop(context),
        ),
      ],
    );
  }
}

class _ScopeOption {
  final SchedulePrintScope scope;
  final IconData icon;
  final String title;
  final String description;

  const _ScopeOption({
    required this.scope,
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.option,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  final _ScopeOption option;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? primaryColor : ColorUtils.slate200;
    final iconBg = selected
        ? primaryColor.withValues(alpha: 0.12)
        : ColorUtils.slate100;
    final iconColor = selected ? primaryColor : ColorUtils.slate600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(option.icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorUtils.slate600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? primaryColor : ColorUtils.slate300,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
