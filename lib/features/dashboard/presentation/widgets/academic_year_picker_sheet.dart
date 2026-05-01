// Academic year picker bottom sheet.
//
// What this is
// ------------
// Tap-target for `AcademicYearChip` in the dashboard hero. Lets the
// user switch which academic year the rest of the app is scoped to.
// Per Phase-4 mockup #4:
//
//   • Active year is rendered "expanded" — the year string + a row
//     of semester chips (Ganjil / Genap) so the user can drill into
//     a specific semester within the current year.
//   • Older years render as collapsed single-row tiles. Tapping one
//     selects it (and re-runs the dashboard's data loader against
//     the new year context).
//   • A footer note explains that adding new years is admin-only.
//
// State plumbing
// --------------
// Reads the year list + active selection from `academicYearRiverpod`
// (an existing `ChangeNotifier`-backed Riverpod legacy provider).
// On selection it calls `setSelectedYear(id)` then triggers
// `dashboardProvider.notifier.reloadForYearChange()` so all tabs see
// the new context — same flow that the legacy
// `showAcademicYearDialog` used.
//
// Semester switching is local UI state for now (no backend semester
// switcher exists yet); the chips visualise the active semester
// computed from the backend's `Semester.current` flag and will be
// wired to a real provider in a follow-up.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';

/// Show the academic year picker as a brand bottom sheet. Returns
/// the newly-selected year id (string) when the user confirms a
/// switch, or null if they dismissed without changing anything.
Future<String?> showAcademicYearPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  String? currentSemesterLabel,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _AcademicYearPickerSheet(
      currentSemesterLabel: currentSemesterLabel,
    ),
  );
}

class _AcademicYearPickerSheet extends ConsumerWidget {
  final String? currentSemesterLabel;

  const _AcademicYearPickerSheet({
    required this.currentSemesterLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearProvider = ref.watch(academicYearRiverpod);
    // Sort years ascending (e.g. 2023/2024 comes before 2024/2025).
    final years = List<dynamic>.from(yearProvider.academicYears);
    years.sort((a, b) => (a['year'] ?? '').toString().compareTo((b['year'] ?? '').toString()));
    
    final selected = yearProvider.selectedAcademicYear;
    final selectedId = selected?['id']?.toString();
    final selectedIndex = years.indexWhere((y) => y['id']?.toString() == selectedId);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Title block
          Text(
            'Pilih Tahun Ajaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tahun ajaran aktif memengaruhi data semua tab',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: AppSpacing.md),

          // Year list — selected year expanded, others collapsed.
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: years.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final year = years[i] as Map<dynamic, dynamic>;
                final id = year['id']?.toString() ?? '';
                final yearLabel = (year['year'] ?? '').toString();
                final isSelected = selected != null
                    && selected['id']?.toString() == id;
                if (isSelected) {
                  return _ExpandedYearTile(
                    yearLabel: yearLabel,
                    semesterLabel: currentSemesterLabel,
                  );
                }
                final isNext = i > selectedIndex && selectedIndex != -1;
                return _CollapsedYearTile(
                  yearLabel: yearLabel,
                  label: isNext ? 'Selanjutnya' : 'Sebelumnya',
                  onTap: () => _onPickYear(context, ref, id),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.md),

          // Tutup button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Tutup',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle picking a previous (non-active) year. Sets the selection
  /// in the provider, kicks off a dashboard reload, and pops the sheet
  /// so the user is back on the surface that opened it.
  Future<void> _onPickYear(
    BuildContext context,
    WidgetRef ref,
    String yearId,
  ) async {
    if (yearId.isEmpty) return;
    final notifier = ref.read(academicYearRiverpod);
    notifier.setSelectedYear(yearId);
    Navigator.of(context).pop(yearId);
    try {
      await ref.read(dashboardProvider.notifier).reloadForYearChange();
    } catch (e) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      SnackBarUtils.showError(
        context,
        'Gagal memuat data tahun ajaran baru: $e',
      );
    }
  }
}

/// The currently-active year — rendered larger with semester chips.
class _ExpandedYearTile extends StatelessWidget {
  final String yearLabel;
  final String? semesterLabel;

  const _ExpandedYearTile({required this.yearLabel, this.semesterLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AKTIF SEKARANG',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandAzureDeep,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            yearLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Semester chips — for now Ganjil shows as active when the
          // backend label is "Ganjil"/"Semester Ganjil"/etc; everything
          // else falls through to Genap-active. A real semester
          // provider lands in a follow-up.
          Row(
            children: [
              Expanded(
                child: _SemesterChip(
                  label: 'Ganjil',
                  caption: 'Semester 1',
                  active: _isGanjil(semesterLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SemesterChip(
                  label: 'Genap',
                  caption: 'Semester 2',
                  active: !_isGanjil(semesterLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isGanjil(String? raw) {
    if (raw == null) return true; // sensible default early in school year
    final l = raw.toLowerCase();
    return l.contains('ganjil') || l.contains('1');
  }
}

class _SemesterChip extends StatelessWidget {
  final String label;
  final String caption;
  final bool active;

  const _SemesterChip({
    required this.label,
    required this.caption,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? ColorUtils.brandAzure
              : const Color(0xFFE2E8F0),
          width: active ? 1.5 : 0.75,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  style: TextStyle(fontSize: 9, color: ColorUtils.slate500),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? ColorUtils.brandAzureDeep
                        : ColorUtils.slate600,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: ColorUtils.brandAzureDeep,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

/// A previous (non-active) year. Tap to switch to it.
class _CollapsedYearTile extends StatelessWidget {
  final String yearLabel;
  final String label;
  final VoidCallback onTap;

  const _CollapsedYearTile({
    required this.yearLabel,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      yearLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Pilih ▾',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
