// Combined "Filter & Urutkan" sheet for the Mata Pelajaran detail
// screen (Frame B in `_design/admin_mapel_detail_redesign.html`).
//
// Two sections, each mutually exclusive:
//   • Urutkan — Terdaftar dulu (default) / Belum dulu / Nama A→Z /
//               Nama Z→A / Tingkat ↑
//   • Status  — Semua / Terdaftar / Belum Terdaftar
//
// Tapping a row applies + closes the sheet. The Reset button restores
// the defaults (assignedFirst · All), and Terapkan just closes the
// sheet (changes are already applied live).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_filter_mixin.dart';

class SubjectClassFilterSheet extends StatefulWidget {
  final String initialFilter;
  final SubjectClassSort initialSort;
  final Color primaryColor;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<SubjectClassSort> onSortChanged;

  const SubjectClassFilterSheet({
    super.key,
    required this.initialFilter,
    required this.initialSort,
    required this.primaryColor,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  /// Opens the sheet wrapped in [AppBottomSheet]. Returns when the
  /// user closes or applies; changes are already pushed via the
  /// onFilterChanged / onSortChanged callbacks.
  static Future<void> show({
    required BuildContext context,
    required String initialFilter,
    required SubjectClassSort initialSort,
    required Color primaryColor,
    required ValueChanged<String> onFilterChanged,
    required ValueChanged<SubjectClassSort> onSortChanged,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      title: 'Filter & Urutkan',
      subtitle: 'Sesuaikan tampilan daftar kelas',
      icon: Icons.tune_rounded,
      primaryColor: primaryColor,
      content: SubjectClassFilterSheet(
        initialFilter: initialFilter,
        initialSort: initialSort,
        primaryColor: primaryColor,
        onFilterChanged: onFilterChanged,
        onSortChanged: onSortChanged,
      ),
    );
  }

  @override
  State<SubjectClassFilterSheet> createState() =>
      _SubjectClassFilterSheetState();
}

class _SubjectClassFilterSheetState extends State<SubjectClassFilterSheet> {
  late String _filter;
  late SubjectClassSort _sort;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _sort = widget.initialSort;
  }

  void _applyFilter(String value) {
    setState(() => _filter = value);
    widget.onFilterChanged(value);
  }

  void _applySort(SubjectClassSort value) {
    setState(() => _sort = value);
    widget.onSortChanged(value);
  }

  void _reset() {
    _applyFilter('All');
    _applySort(SubjectClassSort.assignedFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'Urutkan', accent: widget.primaryColor),
        for (final option in _sortOptions)
          _PickerRow(
            label: option.label,
            icon: option.icon,
            isSelected: _sort == option.value,
            primaryColor: widget.primaryColor,
            onTap: () => _applySort(option.value),
          ),
        const SizedBox(height: AppSpacing.md),
        _SectionTitle(title: 'Status', accent: widget.primaryColor),
        for (final option in _statusOptions)
          _PickerRow(
            label: option.label,
            icon: option.icon,
            isSelected: _filter == option.value,
            primaryColor: widget.primaryColor,
            onTap: () => _applyFilter(option.value),
          ),
        const SizedBox(height: AppSpacing.md),
        BottomSheetFooter(
          primaryLabel: 'Terapkan',
          primaryColor: widget.primaryColor,
          onPrimary: () => AppNavigator.pop(context),
          secondaryLabel: 'Reset',
          onSecondary: _reset,
        ),
      ],
    );
  }
}

class _SortOption {
  final String label;
  final IconData icon;
  final SubjectClassSort value;
  const _SortOption(this.label, this.icon, this.value);
}

class _StatusOption {
  final String label;
  final IconData icon;
  final String value;
  const _StatusOption(this.label, this.icon, this.value);
}

const _sortOptions = <_SortOption>[
  _SortOption(
    'Terdaftar dulu',
    Icons.arrow_downward_rounded,
    SubjectClassSort.assignedFirst,
  ),
  _SortOption(
    'Belum terdaftar dulu',
    Icons.arrow_upward_rounded,
    SubjectClassSort.unassignedFirst,
  ),
  _SortOption(
    'Nama kelas A → Z',
    Icons.sort_by_alpha_rounded,
    SubjectClassSort.nameAsc,
  ),
  _SortOption(
    'Nama kelas Z → A',
    Icons.sort_by_alpha_rounded,
    SubjectClassSort.nameDesc,
  ),
  _SortOption(
    'Tingkat (terendah dulu)',
    Icons.layers_outlined,
    SubjectClassSort.gradeAsc,
  ),
];

const _statusOptions = <_StatusOption>[
  _StatusOption('Semua kelas', Icons.list_alt_rounded, 'All'),
  _StatusOption('Terdaftar', Icons.check_circle_outline, 'Assigned'),
  _StatusOption(
    'Belum terdaftar',
    Icons.radio_button_unchecked,
    'Unassigned',
  ),
];

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color accent;

  const _SectionTitle({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PickerRow({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? primaryColor : ColorUtils.slate200,
              width: isSelected ? 1.2 : 0.75,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : ColorUtils.slate500,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected ? primaryColor : ColorUtils.slate800,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
