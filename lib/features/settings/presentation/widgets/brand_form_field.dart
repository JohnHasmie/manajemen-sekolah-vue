// Brand-styled form-field row used inside Pengaturan Umum / Tahun
// Ajaran bottom sheets.
//
// Replaces Flutter's default `OutlineInputBorder + labelText` floating
// label pattern with the audited brand field layout:
//
//   ┌────────────────────────────────────────────┐
//   │ NAMA SEKOLAH                               │   ← uppercase label
//   │ ┌──────────────────────────────────────┐   │
//   │ │ [icon]  SMP Kamil Edu A              │   │   ← filled row
//   │ └──────────────────────────────────────┘   │
//   └────────────────────────────────────────────┘
//
//   • label: 11px / w700 / slate600 / letter-spacing 0.4 / UPPERCASE
//   • input row: slate-50 bg, slate-200 1.5px border, 12dp radius
//   • focus state: white bg, brand-cobalt border
//   • prefix icon: brand-cobalt, 18px (slate-400 if no input)
//
// Pattern is used by [BrandTextFormField] (live TextField) and
// [BrandReadOnlyField] (display-only — e.g. date picker triggers).
//
// Spec source: `_design/admin_tahun_ajaran_redesign.html` `.field`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Live text input wrapped in the brand field layout. Behaves like a
/// regular `TextField` underneath — pass [controller], [keyboardType],
/// [maxLines] etc. just like Material's.
class BrandTextFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final Color? accent;

  const BrandTextFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? ColorUtils.brandDarkBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label),
        const SizedBox(height: 6),
        _FilledRow(
          accent: tint,
          padding: maxLines > 1
              ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          crossAxisAlignment: maxLines > 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: maxLines > 1 ? 3 : 0),
                child: Icon(prefixIcon, color: tint, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate900,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ColorUtils.slate400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Read-only field used by date-picker triggers and dropdown-style
/// inputs. Tapping anywhere in the field fires [onTap]. Trailing
/// chevron is shown by default (set [caret] to false to hide).
class BrandReadOnlyField extends StatelessWidget {
  final String label;
  final String? value;
  final String hintText;
  final IconData prefixIcon;
  final VoidCallback onTap;
  final bool caret;
  final Color? accent;

  const BrandReadOnlyField({
    super.key,
    required this.label,
    required this.value,
    required this.hintText,
    required this.prefixIcon,
    required this.onTap,
    this.caret = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? ColorUtils.brandDarkBlue;
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: _FilledRow(
              accent: tint,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              crossAxisAlignment: CrossAxisAlignment.center,
              child: Row(
                children: [
                  Icon(
                    prefixIcon,
                    color: hasValue ? tint : ColorUtils.slate400,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasValue ? value! : hintText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasValue
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: hasValue
                            ? ColorUtils.slate900
                            : ColorUtils.slate400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (caret)
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ColorUtils.slate400,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Uppercase 11px/w700 caps label used above every brand field.
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate600,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Filled-row container shared by the live & read-only variants —
/// keeps the slate-50/200 border/radius spec identical across both
/// without having to duplicate the BoxDecoration in two places.
class _FilledRow extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;

  const _FilledRow({
    required this.child,
    required this.accent,
    required this.padding,
    required this.crossAxisAlignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200, width: 1.5),
      ),
      padding: padding,
      child: child,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// High-stakes amber toggle row — used by the Tambah Tahun Ajaran sheet
// for the "Set sebagai 'Saat Ini'" flag. Surfaces the warning that
// flipping the flag triggers the cascade Frame E confirms.
//
//   ┌──────────────────────────────────────────────┐
//   │ ⚠  Set sebagai 'Saat Ini'                ◯● │
//   │   Mengganti tahun ajaran aktif. Lama …       │
//   └──────────────────────────────────────────────┘
// ───────────────────────────────────────────────────────────────────────

class BrandAmberToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const BrandAmberToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.warning600.withValues(alpha: 0.08),
        border: Border.all(
          color: ColorUtils.warning600.withValues(alpha: 0.20),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: ColorUtils.warning600,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.warning700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: ColorUtils.green600,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: ColorUtils.slate300,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
