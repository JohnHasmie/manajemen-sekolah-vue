// Tab 4 (Info & Keputusan) of the report card detail form.
// Contains attendance counts, homeroom teacher notes, and the year-end
// promotion decision. Stateless; all controller bindings are passed as props.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tab widget for attendance, homeroom notes, and promotion decision.
///
/// Like a Vue component that receives controllers and form state as props.
/// Uses the parent's [TextEditingController]s directly (attendance fields and
/// notes), and surfaces the promotion dropdown change through [onPromotionChanged].
/// No setState is called here — the parent owns all state.
class ReportCardInfoTab extends StatelessWidget {
  /// Controller for "Sakit (Hari)" — sick-day count.
  final TextEditingController sickCtrl;

  /// Controller for "Izin (Hari)" — permitted-absence count.
  final TextEditingController permitCtrl;

  /// Controller for "Tanpa Ket. (Hari)" — unexcused-absence count.
  final TextEditingController absentCtrl;

  /// Controller for homeroom teacher's notes.
  final TextEditingController notesCtrl;

  /// Currently selected promotion decision string (e.g. "Naik Kelas").
  final String promotionDecision;

  /// All available promotion-decision options.
  final List<String> decisions;

  /// Called when the user picks a new promotion decision from the dropdown.
  final void Function(String? value) onPromotionChanged;

  const ReportCardInfoTab({
    super.key,
    required this.sickCtrl,
    required this.permitCtrl,
    required this.absentCtrl,
    required this.notesCtrl,
    required this.promotionDecision,
    required this.decisions,
    required this.onPromotionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Attendance section
        const _SectionTitle(
          title: 'Ketidakhadiran',
          icon: Icons.event_busy_rounded,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate100),
          ),
          child: Row(
            children: [
              _AttendanceField(
                label: 'Sakit',
                controller: sickCtrl,
                color: ColorUtils.warning600,
              ),
              const SizedBox(width: 10),
              _AttendanceField(
                label: 'Izin',
                controller: permitCtrl,
                color: ColorUtils.info600,
              ),
              const SizedBox(width: 10),
              _AttendanceField(
                label: 'Tanpa Ket.',
                controller: absentCtrl,
                color: ColorUtils.error600,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: ColorUtils.slate100),
        ),

        // Notes section
        const _SectionTitle(
          title: 'Catatan Wali Kelas',
          icon: Icons.edit_note_rounded,
        ),
        const SizedBox(height: 8),
        _LabeledTextField(
          label: 'Catatan, saran, atau motivasi...',
          controller: notesCtrl,
          maxLines: 4,
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: ColorUtils.slate100),
        ),

        // Promotion decision
        const _SectionTitle(
          title: 'Keputusan Akhir Tahun',
          icon: Icons.gavel_rounded,
        ),
        const SizedBox(height: 8),
        _LabeledDropdown(
          label: 'Keputusan',
          value: promotionDecision,
          items: decisions,
          onChanged: onPromotionChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers — scoped to this file
// ---------------------------------------------------------------------------

/// Section heading, analogous to a styled `<label>` in a Vue form group.
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionTitle({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: p.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: p),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }
}

class _AttendanceField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;

  const _AttendanceField({
    required this.label,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: color.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withValues(alpha: 0.15)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: '0',
              hintStyle: TextStyle(color: color.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Labeled [TextField] backed by a [TextEditingController].
///
/// Used for fields where the parent needs two-way binding via a controller
/// (e.g. attendance counts and notes), unlike [TextFormField] with initialValue.
class _LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: TextInputType.text,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Labeled dropdown, wrapping [DropdownButton] in the app's standard styled
/// container — analogous to a `<select>` in a Vue form.
class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            final selected = item == value;
            return GestureDetector(
              onTap: () => onChanged(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? p.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? p.withValues(alpha: 0.3)
                        : ColorUtils.slate200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? p : ColorUtils.slate500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
