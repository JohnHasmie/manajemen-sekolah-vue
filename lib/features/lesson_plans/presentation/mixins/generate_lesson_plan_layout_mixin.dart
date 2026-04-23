import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_ui_mixin.dart';

mixin GenerateLessonPlanLayoutMixin
    on ConsumerState<GenerateLessonPlanFormDialog>, GenerateLessonPlanUiMixin {
  Widget buildHeaderSection(
    LanguageProvider languageProvider,
    Color primaryColor,
  ) {
    return BottomSheetHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Generate RPP with AI',
        'id': 'Generate RPP dengan AI',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Create RPP documents automatically',
        'id': 'Buat dokumen RPP secara otomatis',
      }),
      icon: Icons.auto_awesome_rounded,
      primaryColor: primaryColor,
    );
  }

  Widget buildFooterSection(
    LanguageProvider languageProvider,
    Color primaryColor,
  ) {
    if (isAutoGenerating) {
      return _buildGeneratingFooter(primaryColor);
    }

    return BottomSheetFooter(
      primaryLabel: languageProvider.getTranslatedText({
        'en': 'Generate',
        'id': 'Generate',
      }),
      secondaryLabel: languageProvider.getTranslatedText({
        'en': 'Cancel',
        'id': 'Batal',
      }),
      primaryColor: primaryColor,
      onPrimary: submitForm,
      onSecondary: () => Navigator.of(context).pop(),
    );
  }

  /// Custom footer while AI is generating — shows spinner + status.
  Widget _buildGeneratingFooter(Color primaryColor) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg + bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                  if (generationStatus.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      generationStatus,
                      style: TextStyle(
                        fontSize: 10,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Abstract getters
  bool get isAutoGenerating;
  String get generationStatus;
  Future<void> submitForm();
}
