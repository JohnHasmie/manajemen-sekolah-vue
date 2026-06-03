import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_polling_skeleton_body.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_polling_error_body.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_data_mixin.dart';

mixin LessonPlanAiResultUiMixin
    on State<LessonPlanAiResultScreen>, LessonPlanAiResultDataMixin {
  // Abstract getters from other mixins
  bool get isSaving;
  bool get isPolling;
  bool get isRegenerating;
  String? get pollingError;
  String get pollingStatus;

  Widget buildPollingBody(
    bool isPolling,
    String pollingStatus,
    String? pollingError,
  ) {
    if (isPolling) {
      return LessonPlanPollingSkeletonBody(pollingStatus: pollingStatus);
    } else if (pollingError != null) {
      return LessonPlanPollingErrorBody(
        pollingError: pollingError,
        onBack: () => AppNavigator.pop(context),
      );
    }
    return const SizedBox.shrink();
  }

  /// Success body shown briefly before auto-navigating back.
  Widget buildMainContent() {
    final primaryColor = ColorUtils.getRoleColor('guru');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate300.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: ColorUtils.success600.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ColorUtils.success600.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: ColorUtils.success600,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'RPP Berhasil Dibuat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'RPP AI telah tersimpan otomatis.\n'
                'Anda dapat melihat dan mengedit dari daftar RPP.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
