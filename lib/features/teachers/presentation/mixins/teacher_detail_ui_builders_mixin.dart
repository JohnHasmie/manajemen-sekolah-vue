import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for high-level UI builder methods in TeacherDetailScreen.
mixin TeacherDetailUIBuildersMixin {
  /// Callback for loading teacher details.
  Future<void> loadTeacherDetail();

  /// Current loading state.
  bool get isLoading;

  /// Current error message.
  String? get errorMessage;

  /// Builds the top gradient header with title and action buttons.
  Widget buildGradientHeader(BuildContext context, String nameStr) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Guru',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nameStr.isNotEmpty ? nameStr : 'Informasi lengkap guru',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: loadTeacherDetail,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main body with conditional loading/error/content.
  Widget buildBody(
    BuildContext context,
    Map<String, dynamic> teacher,
    List<String> teachingClassNames,
    List<String> displaySubjectNames,
    String homeroomStatus,
    Color avatarColor,
    String initial,
  ) {
    if (isLoading) {
      return buildLoadingState();
    }
    if (errorMessage != null) {
      return buildErrorState();
    }
    return buildContentState(
      context,
      teacher,
      teachingClassNames,
      displaySubjectNames,
      homeroomStatus,
      avatarColor,
      initial,
    );
  }

  /// Loading state widget.
  Widget buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                ColorUtils.corporateBlue600,
              ),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Memuat detail guru...',
            style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Error state widget.
  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ColorUtils.error600.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Terjadi kesalahan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage!,
              style: TextStyle(color: ColorUtils.slate600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: loadTeacherDetail,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.corporateBlue600,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Content state widget with teacher details.
  Widget buildContentState(
    BuildContext context,
    Map<String, dynamic> teacher,
    List<String> teachingClassNames,
    List<String> displaySubjectNames,
    String homeroomStatus,
    Color avatarColor,
    String initial,
  ) {
    final nip = Teacher.fromJson(teacher).employeeNumber ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildProfileCard(teacher, avatarColor, initial, nip, homeroomStatus),
          const SizedBox(height: AppSpacing.lg),
          buildPersonalInfoCard(teacher),
          const SizedBox(height: AppSpacing.md),
          buildTeachingInfoCard(
            teacher,
            teachingClassNames,
            displaySubjectNames,
            homeroomStatus,
          ),
          const SizedBox(height: AppSpacing.xxl),
          buildBackButton(context),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// Abstract methods - implemented in card builders mixin.
  Widget buildProfileCard(
    Map<String, dynamic> teacher,
    Color avatarColor,
    String initial,
    String nip,
    String homeroomStatus,
  );

  Widget buildPersonalInfoCard(Map<String, dynamic> teacher);

  Widget buildTeachingInfoCard(
    Map<String, dynamic> teacher,
    List<String> teachingClassNames,
    List<String> displaySubjectNames,
    String homeroomStatus,
  );

  Widget buildBackButton(BuildContext context);
}
