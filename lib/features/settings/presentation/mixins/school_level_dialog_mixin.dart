// Edit Informasi Sekolah sheet — Frame C of the Pengaturan Umum
// redesign.
//
// Built on top of [AppBottomSheet] + [BottomSheetFooter] (shared brand
// components, per CLAUDE.md). Form fields use [BrandTextFormField] so
// the uppercase-label-above + filled-input pattern stays consistent
// across the Tahun Ajaran edit sheet (Frame D) and any future settings
// sheets.
//
// Replaces the old [showDialog] AlertDialog implementation.
//
// Spec source: `_design/admin_tahun_ajaran_redesign.html` Frame C.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/brand_form_field.dart';

mixin SchoolLevelDialogMixin {
  BuildContext get context;

  /// Shows the Edit Informasi Sekolah bottom sheet.
  ///
  /// [onLoadSettings] is called after a successful save so the parent
  /// screen can refresh its display values.
  Future<void> showEditDialog({
    required String schoolName,
    required String schoolAddress,
    required String selectedJenjang,
    required List<String> jenjangOptions,
    required Function() onLoadSettings,
    required Function(String, String, String) onSaveSettings,
  }) async {
    final nameController = TextEditingController(text: schoolName);
    final addressController = TextEditingController(text: schoolAddress);
    String tempJenjang = selectedJenjang;
    bool isSaving = false;

    await AppBottomSheet.show(
      context: context,
      title: kSetEditSchoolInfo.tr,
      subtitle: kSetUpdateSchoolProfile.tr,
      icon: Icons.school_rounded,
      primaryColor: ColorUtils.brandDarkBlue,
      // Per-field 14px gaps + 18px footer breathing room. Drops the
      // sheet's default 20px all-around padding to match the mockup's
      // tighter 16h/18v rhythm.
      contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      content: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandTextFormField(
                label: kSetSchoolName.tr,
                controller: nameController,
                prefixIcon: Icons.school_rounded,
                hintText: kSetEnterSchoolName.tr,
              ),
              const SizedBox(height: 14),
              BrandTextFormField(
                label: kSetSchoolAddress.tr,
                controller: addressController,
                prefixIcon: Icons.location_on_outlined,
                hintText: kSetAddressExample.tr,
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              _JenjangChipGrid(
                options: jenjangOptions,
                value: tempJenjang,
                onChanged: (j) => setSheetState(() => tempJenjang = j),
              ),
            ],
          );
        },
      ),
      footer: StatefulBuilder(
        builder: (context, setFooterState) {
          return BottomSheetFooter(
            primaryLabel: isSaving ? kSetSaving.tr : 'Simpan',
            primaryColor: ColorUtils.brandDarkBlue,
            primaryEnabled: !isSaving,
            secondaryLabel: 'Batal',
            onPrimary: () async {
              final name = nameController.text.trim();
              if (name.length < 3) {
                SnackBarUtils.showError(
                  context,
                  kSetSchoolNameMinLength.tr,
                );
                return;
              }
              setFooterState(() => isSaving = true);
              try {
                await onSaveSettings(
                  name,
                  addressController.text.trim(),
                  tempJenjang,
                );
                if (!context.mounted) return;
                AppNavigator.pop(context);
                onLoadSettings();
                SnackBarUtils.showSuccess(
                  context,
                  kSetSchoolInfoSavedSuccess.tr,
                );
              } catch (e) {
                AppLogger.error('school_settings_save', e);
                if (!context.mounted) return;
                SnackBarUtils.showError(
                  context,
                  'Gagal menyimpan: ${ErrorUtils.getFriendlyMessage(e)}',
                );
              } finally {
                setFooterState(() => isSaving = false);
              }
            },
            onSecondary: () => AppNavigator.pop(context),
          );
        },
      ),
    );
  }
}

/// Jenjang Pendidikan chip-grid — uses [Wrap] so labels never
/// truncate (no Row + Expanded forcing each chip to a quarter-width).
/// Per-jenjang Material icon replaces the legacy emoji prefixes.
class _JenjangChipGrid extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _JenjangChipGrid({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kSetEducationLevelUpper.tr,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((j) {
            final selected = value == j;
            final IconData ico = switch (j) {
              'SD' => Icons.backpack_outlined,
              'SMP' => Icons.menu_book_outlined,
              'SMA' => Icons.school_outlined,
              'SMK' => Icons.handyman_outlined,
              _ => Icons.school_outlined,
            };
            return _JenjangChip(
              label: j,
              icon: ico,
              selected: selected,
              onTap: () => onChanged(j),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _JenjangChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _JenjangChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandDarkBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: selected ? cobalt : Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: selected ? cobalt : ColorUtils.slate200,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cobalt.withValues(alpha: 0.20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : ColorUtils.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : ColorUtils.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
