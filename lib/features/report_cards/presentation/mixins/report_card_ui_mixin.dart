// Sikap tab + shared form helpers — Frame A of the
// `_design/teacher_raport_isi_redesign.html` mockup.
//
// The Sikap tab carries two `sect-card` blocks (Spiritual + Sosial),
// each with:
//   • cobalt/violet section icon badge + title + "Wajib" chip
//   • PREDIKAT label + 4-chip selector (Sangat Baik / Baik / Cukup / Kurang)
//   • DESKRIPSI label + textarea-style input
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

/// Mixin for UI building methods shared across tabs.
mixin ReportCardUIMixin on ConsumerState<ReportCardDetailScreen> {
  Widget buildSikapTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        _SectCard(
          icon: Icons.brightness_5_rounded,
          iconBg: ColorUtils.violet700.withValues(alpha: 0.10),
          iconFg: ColorUtils.violet700,
          title: kRepCarSpiritualAttitude.tr,
          chip: 'Wajib',
          children: [
            buildPredikatRow(spiritualPredicate, (v) {
              setState(() => spiritualPredicate = v);
              markUnsaved();
            }),
            const SizedBox(height: 14),
            const _FieldLabel(label: 'Deskripsi'),
            const SizedBox(height: 6),
            buildDescInput(
              spiritualDescCtrl,
              hint: kRepCarSpiritualAttitudeHint.tr,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SectCard(
          icon: Icons.people_alt_rounded,
          iconBg: ColorUtils.brandCobalt.withValues(alpha: 0.10),
          iconFg: ColorUtils.brandCobalt,
          title: kRepCarSocialAttitude.tr,
          chip: 'Wajib',
          children: [
            buildPredikatRow(socialPredicate, (v) {
              setState(() => socialPredicate = v);
              markUnsaved();
            }),
            const SizedBox(height: 14),
            const _FieldLabel(label: 'Deskripsi'),
            const SizedBox(height: 6),
            buildDescInput(
              socialDescCtrl,
              hint: kRepCarSocialAttitudeHint.tr,
            ),
          ],
        ),
      ],
    );
  }

  /// 4-chip predikat selector matching `.predikat-row` in the mockup.
  Widget buildPredikatRow(String value, ValueChanged<String> onChanged) {
    final cobalt = ColorUtils.brandCobalt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Predikat'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: predicates.map((item) {
            final selected = item == value;
            return GestureDetector(
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? cobalt.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? cobalt : ColorUtils.slate200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? cobalt : ColorUtils.slate700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Slate-tinted multi-line text area matching `.desc-input` in the
  /// mockup. Used for spiritual / social descriptions and the Catatan
  /// Wali Kelas field.
  Widget buildDescInput(TextEditingController controller, {String? hint}) {
    final cobalt = ColorUtils.brandCobalt;
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 3,
      keyboardType: TextInputType.multiline,
      style: TextStyle(fontSize: 12.5, color: ColorUtils.slate700, height: 1.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ColorUtils.slate50,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: ColorUtils.slate400,
          height: 1.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cobalt, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  // ── Legacy helpers kept for the older Info/Extras tabs that still
  //    reference these signatures. New mockup-aligned tabs avoid them
  //    in favour of the SectCard + chip pattern. ────────────────────

  Widget buildSectionTitle(String title, IconData icon) {
    final cobalt = ColorUtils.brandCobalt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cobalt.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: cobalt),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumber = false,
    String? hint,
  }) {
    final cobalt = ColorUtils.brandCobalt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: ColorUtils.slate400),
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
              borderSide: BorderSide(color: cobalt, width: 1.5),
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

  Widget buildChipSelector(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return buildPredikatRow(value, (v) => onChanged(v));
  }

  Widget buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return buildChipSelector(label, value, items, onChanged);
  }

  void markUnsaved() {
    if (!hasUnsavedChanges && !isLoading && mounted) {
      setState(() {
        hasUnsavedChanges = true;
      });
    }
  }

  // Abstract declarations
  late String spiritualPredicate;
  late String socialPredicate;
  late TextEditingController spiritualDescCtrl;
  late TextEditingController socialDescCtrl;
  late bool hasUnsavedChanges;
  late bool isLoading;
  late List<String> predicates;
}

// ─── Section card scaffold shared across tabs ────────────────────────

class _SectCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? chip;
  final List<Widget> children;

  const _SectCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.children,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: iconFg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (chip != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate700,
        letterSpacing: 0.4,
      ),
    );
  }
}
