import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

mixin BulkSelectionFooterMixin {
  String get type;
  int get tabIndex;
  List<Map<String, dynamic>> get selected;
  Color get primaryColorImpl;
  void Function(List<Map<String, dynamic>>) get onApplyBulkGrades;
  BuildContext get context;

  Widget buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildCancelButton(),
            if ((type != 'bab' || tabIndex == 1) && selected.isNotEmpty) ...[
              const SizedBox(width: 12),
              _buildApplyButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: ColorUtils.slate300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          AppLocalizations.cancel.tr,
          style: TextStyle(
            color: ColorUtils.slate600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Expanded(
      child: ElevatedButton(
        onPressed: _handleApplyBulk,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColorImpl,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Terapkan (${selected.length})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _handleApplyBulk() {
    onApplyBulkGrades(selected);
    Navigator.pop(context);
  }
}
