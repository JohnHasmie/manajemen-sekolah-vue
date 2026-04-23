import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';

/// Mixin for form field widget building (text, dropdowns, dates).
mixin AnnouncementFormFieldsMixin on State<AnnouncementFormSheet> {
  /// Builds styled text field for title/content.
  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  /// Builds priority dropdown (Normal/Important).
  Widget buildPrioritasDropdown(
    LanguageProvider lang,
    Color primaryColor,
    String? selectedPriority,
    Function(String?) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedPriority,
        decoration: InputDecoration(
          labelText: lang.getTranslatedText({
            'en': 'Priority',
            'id': 'Prioritas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(Icons.priority_high, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'normal',
            child: Row(
              children: [
                Icon(Icons.circle, color: ColorUtils.slate400, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text(lang.getTranslatedText({'en': 'Normal', 'id': 'Biasa'})),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'important',
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  lang.getTranslatedText({'en': 'Important', 'id': 'Penting'}),
                ),
              ],
            ),
          ),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  /// Builds role target dropdown (All/Admin/Teacher/Student/Parent).
  Widget buildRoleTargetDropdown(
    LanguageProvider lang,
    Color primaryColor,
    String? selectedRole,
    Function(String?) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedRole,
        decoration: InputDecoration(
          labelText: lang.getTranslatedText({
            'en': 'Target Role',
            'id': 'Role Target',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(Icons.people, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(
              lang.getTranslatedText({
                'en': 'All Users',
                'id': 'Semua Pengguna',
              }),
            ),
          ),
          const DropdownMenuItem(value: 'admin', child: Text('Admin')),
          const DropdownMenuItem(value: 'teacher', child: Text('Guru')),
          const DropdownMenuItem(value: 'student', child: Text('Siswa')),
          const DropdownMenuItem(value: 'parent', child: Text('Wali')),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  /// Builds date field with calendar picker.
  Widget buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: ColorUtils.slate200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: primaryColor, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value != null
                    ? '${value.day}/${value.month}/${value.year}'
                    : label,
                style: TextStyle(
                  color: value != null
                      ? ColorUtils.slate800
                      : ColorUtils.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
