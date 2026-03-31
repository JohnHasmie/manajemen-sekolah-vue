// Tab 4 (Info & Keputusan) of the report card detail form.
// Contains attendance counts, homeroom teacher notes, and the year-end
// promotion decision. Stateless; all controller bindings are passed as props.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SectionTitle(title: 'Ketidakhadiran'),
        Row(
          children: [
            Expanded(
              child: _LabeledTextField(
                label: 'Sakit (Hari)',
                controller: sickCtrl,
                isNumber: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LabeledTextField(
                label: 'Izin (Hari)',
                controller: permitCtrl,
                isNumber: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LabeledTextField(
                label: 'Tanpa Ket. (Hari)',
                controller: absentCtrl,
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(title: 'Catatan Wali Kelas'),
        _LabeledTextField(
          label: 'Masukkan catatan, saran, atau motivasi untuk siswa...',
          controller: notesCtrl,
          maxLines: 4,
        ),

        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),

        _SectionTitle(title: 'Keputusan Akhir Tahun (Opsional)'),
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

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate700,
        ),
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
  final bool isNumber;

  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(
                color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(
                color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: ColorUtils.getRoleColor('guru')),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            color: Colors.grey.shade50,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
