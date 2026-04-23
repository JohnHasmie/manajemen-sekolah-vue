import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Footer widget with save and
/// finalize buttons for report card.
class ReportCardFooter extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSaveDraft;
  final VoidCallback onFinalize;
  final GlobalKey saveDraftKey;
  final GlobalKey finalizeKey;

  const ReportCardFooter({
    super.key,
    required this.isSaving,
    required this.onSaveDraft,
    required this.onFinalize,
    required this.saveDraftKey,
    required this.finalizeKey,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              key: saveDraftKey,
              child: OutlinedButton(
                onPressed: isSaving ? null : onSaveDraft,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: ColorUtils.slate300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p,
                        ),
                      )
                    : Text(
                        'Simpan Draft',
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              key: finalizeKey,
              child: ElevatedButton(
                onPressed: isSaving ? null : onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: p,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Selesaikan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
