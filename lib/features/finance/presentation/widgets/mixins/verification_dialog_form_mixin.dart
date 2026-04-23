import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin providing form field builders for verification dialog.
mixin VerificationDialogFormMixin {
  /// Abstract: State access required.
  void setState(VoidCallback fn);
  BuildContext get context;
  WidgetRef get ref;
  Color get primaryColor;

  /// Builds a styled text field for admin notes input.
  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
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
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  /// Builds a styled dropdown field for selecting verification status.
  Widget buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final String selectedValue = items.contains(value) ? value : items.first;

    final languageProvider = ref.watch(languageRiverpod);

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonFormField<String>(
          initialValue: selectedValue,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            border: InputBorder.none,
          ),
          items: _buildDropdownItems(items, languageProvider),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Helper to build dropdown menu items.
  List<DropdownMenuItem<String>> _buildDropdownItems(
    List<String> items,
    dynamic languageProvider,
  ) {
    return items
        .map(
          (String item) => DropdownMenuItem<String>(
            value: item,
            child: Text(_formatDropdownLabel(item, languageProvider)),
          ),
        )
        .toList();
  }

  /// Helper to format dropdown labels with localization.
  String _formatDropdownLabel(String item, dynamic languageProvider) {
    return item == 'aktif'
        ? 'Aktif'
        : item == 'non-aktif'
        ? 'Non-Aktif'
        : item == 'sekali bayar'
        ? 'Sekali Bayar'
        : item == 'bulanan'
        ? 'Bulanan'
        : item == 'semester'
        ? 'Semester'
        : item == 'tahunan'
        ? 'Tahunan'
        : item == 'verified'
        ? languageProvider.getTranslatedText(AppLocalizations.verified)
        : item == 'rejected'
        ? 'Ditolak'
        : item;
  }
}
