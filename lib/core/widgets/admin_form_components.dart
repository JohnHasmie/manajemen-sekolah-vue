// Shared form-body building blocks for admin add/edit sheets.
//
// Mirrors the v3 actions mockup (frames B + C):
//   • [AdminFormSection]    — uppercase slate kicker + grouped child stack.
//   • [AdminFormChoiceChips]— segmented 2/3-choice chip selector
//                             (replaces dropdowns for short option sets
//                             like gender, status, role).
//   • [AdminFormFieldLabel] — bold slate-900 label with required-asterisk.
//
// Pair with the existing `AppEditBottomSheet` / `BottomSheetFooter` to
// build the full sheet:
//   ┌────────────────────────────────────┐
//   │ AdminFormSheetHeader (kicker+title)│
//   ├────────────────────────────────────┤
//   │ DATA POKOK                          │
//   │   [TextField nama]                  │
//   │   [TextField NIS]                   │
//   │   [Dropdown kelas]                  │
//   │ DATA PRIBADI                        │
//   │   [Chip Laki-laki | Perempuan]      │
//   │   [Date picker]                     │
//   │ WALI MURID                          │
//   │   [TextField nama wali]             │
//   │   [TextField email wali]            │
//   │   [TextField hp]                    │
//   ├────────────────────────────────────┤
//   │ Batal | Simpan Siswa                │
//   └────────────────────────────────────┘
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One labelled section of an admin form. Renders as:
///   `DATA POKOK`  ← uppercase 11pt w800 slate-500
///   <child stack with 12 px gaps between rows>
class AdminFormSection extends StatelessWidget {
  /// Uppercase heading (e.g. `'DATA POKOK'`).
  final String label;

  /// Children rendered with vertical 12 px gaps. Pass already-styled
  /// fields, choice chips, dropdowns, etc.
  final List<Widget> children;

  /// Bottom margin under the whole section (separates from next section).
  /// Default: 18 px.
  final double bottomGap;

  /// Optional right-aligned trailing widget on the section header (e.g.
  /// a tiny "+" mini-button to add a row).
  final Widget? trailing;

  const AdminFormSection({
    super.key,
    required this.label,
    required this.children,
    this.bottomGap = 18,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Bold slate-900 label with optional required-asterisk. Use above any
/// custom field that doesn't carry its own label internally.
class AdminFormFieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const AdminFormFieldLabel({
    super.key,
    required this.text,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One segmented chip option used by [AdminFormChoiceChips].
class AdminFormChoice<T> {
  /// Stable identifier — typed (e.g. `'L'`/`'P'`, an enum, etc.).
  final T value;

  /// Visible label.
  final String label;

  /// Optional small leading icon.
  final IconData? icon;

  const AdminFormChoice({required this.value, required this.label, this.icon});
}

/// Segmented chip-row selector — replaces dropdowns for 2–3 short
/// options (gender, status, role). Designed for small option sets only;
/// reach for a dropdown when you have ≥ 5 entries.
///
/// Renders all chips evenly across the row when [equalWidth] is true
/// (default), or content-sized otherwise. Selected chip = admin navy
/// fill / white text; unselected = white / slate border / slate text.
class AdminFormChoiceChips<T> extends StatelessWidget {
  /// Currently-selected value. May be `null` (no selection).
  final T? value;

  /// Available choices.
  final List<AdminFormChoice<T>> choices;

  /// Selection-changed callback.
  final ValueChanged<T> onChanged;

  /// Spread chips evenly via Flexible(expanded). Default true.
  final bool equalWidth;

  /// Chip height. Default 44 px.
  final double height;

  /// Override the fill color used for the selected chip. Defaults to
  /// admin navy.
  final Color? selectedColor;

  const AdminFormChoiceChips({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.equalWidth = true,
    this.height = 44,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? ColorUtils.getRoleColor('admin');
    final widgets = <Widget>[];
    for (var i = 0; i < choices.length; i++) {
      if (i > 0) widgets.add(const SizedBox(width: 10));
      final c = choices[i];
      final selected = c.value == value;
      final chip = _Chip(
        choice: c,
        selected: selected,
        accent: accent,
        height: height,
        onTap: () => onChanged(c.value),
      );
      widgets.add(equalWidth ? Expanded(child: chip) : chip);
    }
    return Row(children: widgets);
  }
}

/// Cancel + primary footer for admin add/edit sheets. Replaces the 5
/// per-feature implementations with one Samsung-safe row.
///
/// Renders as: outline `Batal` (40 % flex) + filled accent primary
/// (60 % flex). The primary shows a spinner when [isSaving] is true.
class AdminFormFooter extends StatelessWidget {
  /// Primary CTA label — typically `Simpan` / `Simpan Perubahan`.
  final String primaryLabel;

  /// Cancel CTA label. Defaults to `Batal`.
  final String cancelLabel;

  /// Primary tap handler. Pass `null` to disable.
  final VoidCallback? onPrimary;

  /// Cancel tap handler. Defaults to `Navigator.pop(context)`.
  final VoidCallback? onCancel;

  /// When true, primary becomes a spinner and tap is ignored.
  final bool isSaving;

  /// Override accent. Defaults to admin navy.
  final Color? accent;

  /// Hide the cancel button entirely (rare).
  final bool showCancel;

  const AdminFormFooter({
    super.key,
    required this.primaryLabel,
    this.cancelLabel = 'Batal',
    this.onPrimary,
    this.onCancel,
    this.isSaving = false,
    this.accent,
    this.showCancel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? ColorUtils.getRoleColor('admin');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (showCancel) ...[
            Expanded(
              flex: 4,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: ColorUtils.slate200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : (onCancel ?? () => Navigator.of(context).pop()),
                child: Text(
                  cancelLabel,
                  style: TextStyle(
                    color: ColorUtils.slate700,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 6,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSaving ? null : onPrimary,
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline toggle row used for boolean form options (e.g. "Use another
/// user account"). Cleaner than [SwitchListTile] — no oversized vertical
/// padding, status pill on the right shows the current state.
///
/// Default tone is informational (slate). Pass `tone: AdminToggleTone.warning`
/// for amber when the toggle changes destructive behaviour.
enum AdminToggleTone { neutral, warning }

class AdminFormToggle extends StatelessWidget {
  /// Bold title — what the toggle changes (e.g. `'Akun wali'`).
  final String title;

  /// Optional one-line description below the title.
  final String? subtitle;

  /// Current state.
  final bool value;

  /// Change handler.
  final ValueChanged<bool> onChanged;

  /// Tone — neutral (default) or warning (amber, for destructive flips).
  final AdminToggleTone tone;

  /// Optional override for the `value=true` label (default: `Aktif`).
  final String? onLabel;

  /// Optional override for the `value=false` label (default: `Mati`).
  final String? offLabel;

  const AdminFormToggle({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.tone = AdminToggleTone.neutral,
    this.onLabel,
    this.offLabel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tone == AdminToggleTone.warning
        ? const Color(0xFFB45309)
        : ColorUtils.getRoleColor('admin');
    final bg = tone == AdminToggleTone.warning
        ? const Color(0xFFFEF7E0)
        : const Color(0xFFF4F7FB);
    final border = tone == AdminToggleTone.warning
        ? const Color(0xFFFCD34D)
        : ColorUtils.slate200;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: tone == AdminToggleTone.warning
                            ? accent
                            : ColorUtils.slate900,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PillSwitch(value: value, accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact pill-shaped switch used inside [AdminFormToggle].
class _PillSwitch extends StatelessWidget {
  final bool value;
  final Color accent;

  const _PillSwitch({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? accent : ColorUtils.slate300,
        borderRadius: BorderRadius.circular(13),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip<T> extends StatelessWidget {
  final AdminFormChoice<T> choice;
  final bool selected;
  final Color accent;
  final double height;
  final VoidCallback onTap;

  const _Chip({
    required this.choice,
    required this.selected,
    required this.accent,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : ColorUtils.slate600;
    final bg = selected ? accent : Colors.white;
    final border = selected ? accent : ColorUtils.slate200;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (choice.icon != null) ...[
                Icon(choice.icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  choice.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
