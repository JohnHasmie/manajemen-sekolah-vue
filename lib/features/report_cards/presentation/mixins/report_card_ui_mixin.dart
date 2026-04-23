import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

/// Mixin for UI building methods.
mixin ReportCardUIMixin on ConsumerState<ReportCardDetailScreen> {
  Widget buildSikapTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        buildSectionTitle('Sikap Spiritual', Icons.self_improvement_rounded),
        buildDropdown('Predikat', spiritualPredicate, predicates, (v) {
          setState(() => spiritualPredicate = v!);
          markUnsaved();
        }),
        const SizedBox(height: AppSpacing.md),
        buildTextField(
          'Deskripsi',
          spiritualDescCtrl,
          maxLines: 3,
          hint: 'Deskripsi sikap spiritual...',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: ColorUtils.slate100, height: 1),
        ),
        buildSectionTitle('Sikap Sosial', Icons.people_outline_rounded),
        buildDropdown('Predikat', socialPredicate, predicates, (v) {
          setState(() => socialPredicate = v!);
          markUnsaved();
        }),
        const SizedBox(height: AppSpacing.md),
        buildTextField(
          'Deskripsi',
          socialDescCtrl,
          maxLines: 3,
          hint: 'Deskripsi sikap sosial...',
        ),
      ],
    );
  }

  Widget buildSectionTitle(String title, IconData icon) {
    final p = ColorUtils.getRoleColor('guru');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
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
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
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

  Widget buildChipSelector(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
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
