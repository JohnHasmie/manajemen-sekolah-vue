import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Dialog utilities for lesson plan regeneration prompts.
class LessonPlanRegenDialogs {
  /// Shows a single field regeneration dialog.
  static Future<bool?> showRegenFieldDialog(
    BuildContext context,
    String fieldLabel,
    int remaining,
    int maxAttempts,
    Color primaryColor,
  ) async {
    final textController = TextEditingController();
    try {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Regenerasi $fieldLabel',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sisa regenerasi: $remaining dari $maxAttempts',
                style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tambahan instruksi (opsional)',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: ColorUtils.slate400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, false),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton(
              onPressed: () => AppNavigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              child: Text(AppLocalizations.regenerate.tr),
            ),
          ],
        ),
      );
    } finally {
      textController.dispose();
    }
  }

  /// Shows a regenerate all fields dialog.
  static Future<bool?> showRegenAllDialog(
    BuildContext context,
    Color primaryColor,
  ) async {
    final textController = TextEditingController();
    try {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Icon(Icons.auto_awesome, color: primaryColor, size: 40),
          title: const Text(
            'Regenerasi Semua Field',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semua field RPP akan di-generate ulang. Setiap field memiliki batas regenerasi masing-masing.',
                style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tambahan instruksi untuk semua field (opsional)',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: ColorUtils.slate400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, false),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => AppNavigator.pop(context, true),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(AppLocalizations.regenerateAll.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    } finally {
      textController.dispose();
    }
  }

  /// Returns additional text from a regeneration dialog.
  static Future<String?> getAdditionalInstructions(
    BuildContext context,
    String fieldLabel,
    int remaining,
    int maxAttempts,
    Color primaryColor,
  ) async {
    final textController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Regenerasi $fieldLabel',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sisa regenerasi: $remaining dari $maxAttempts',
                style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tambahan instruksi (opsional)',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: ColorUtils.slate400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, false),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton(
              onPressed: () => AppNavigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text(AppLocalizations.regenerate.tr),
            ),
          ],
        ),
      );

      return confirmed == true ? textController.text : null;
    } finally {
      textController.dispose();
    }
  }
}
