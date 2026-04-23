// UI building and dialog display mixin.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Provides UI building and dialog handling methods.
mixin LessonPlanUiMixin {
  /// Required abstract members from State.
  void setState(VoidCallback fn);
  BuildContext get context;

  /// Required abstract getters from main state.
  String getFieldValue(String key, String altKey);
  Map<String, dynamic>? getFieldRegenInfo(String fieldKey);
  Color get primaryColor;
  String? get teacherId;

  /// State properties (must be defined in main state).
  String? get regeneratingField;
  set regeneratingField(String? v);

  /// Opens the AI lesson plan result as a flat-flow bottom sheet (#145-pattern).
  void openAiLessonPlanScreen(
    Map<String, dynamic> lessonPlanData,
    String teacherId,
  ) {
    LessonPlanAiResultScreen.show(
      context: context,
      lessonPlanData: lessonPlanData,
      teacherId: teacherId,
      onSaved: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.lessonPlanSavedSuccessfully.tr),
            ),
          );
        }
      },
    );
  }

  /// Shows bottom sheet export menu.
  void showExportMenu({
    required VoidCallback onWordExport,
    required VoidCallback onTextExport,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export ke PDF'),
              onTap: () {
                AppNavigator.pop(context);
                onWordExport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export ke Text'),
              onTap: () {
                AppNavigator.pop(context);
                onTextExport();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows regeneration dialog for field.
  Future<void> showRegenFieldDialog(
    String fieldKey,
    String fieldLabel,
    Future<String?> Function(BuildContext, String, int, int, Color) dialogFn,
    Future<void> Function(String, String, String) regenerateFn,
  ) async {
    final regenInfo = getFieldRegenInfo(fieldKey);
    final remaining = regenInfo?['remaining'] ?? 2;
    final maxAttempts = regenInfo?['max'] ?? 2;

    if (remaining <= 0) {
      showLimitReachedDialog(fieldLabel);
      return;
    }

    final additionalText = await dialogFn(
      context,
      fieldLabel,
      remaining,
      maxAttempts,
      primaryColor,
    );

    if (additionalText != null && mounted) {
      await regenerateFn(fieldKey, fieldLabel, additionalText);
    }
  }

  /// Shows regenerate all dialog.
  Future<void> showRegenAllDialog(
    Future<bool?> Function(BuildContext, Color) dialogFn,
    Future<void> Function(String) regenerateFn,
  ) async {
    final confirmed = await dialogFn(context, primaryColor);
    if (confirmed == true && mounted) {
      await regenerateFn('');
    }
  }

  /// Shows limit reached dialog.
  void showLimitReachedDialog(String fieldLabel) {
    AppAlertDialog.show(
      context: context,
      title: 'Batas Tercapai',
      message:
          'Batas regenerasi untuk "$fieldLabel" '
          'telah tercapai '
          '(maksimal 2 kali per field).',
      icon: Icons.timer_off_rounded,
      confirmText: 'Mengerti',
      showCancel: false,
    );
  }

  /// Check if mounted (required from State).
  bool get mounted;
}
