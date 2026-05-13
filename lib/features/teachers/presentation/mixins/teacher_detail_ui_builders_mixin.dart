import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for high-level UI builder methods in TeacherDetailScreen.
mixin TeacherDetailUIBuildersMixin {
  /// Callback for loading teacher details.
  Future<void> loadTeacherDetail();

  /// Current loading state.
  bool get isLoading;

  /// Current error message.
  String? get errorMessage;

  /// Top page header — uses the shared [BrandPageHeader] so the
  /// teacher-detail surface matches every other teacher hub
  /// (Presensi / Kegiatan / RPP / etc.).
  ///
  /// Layout:
  ///   - kicker subtitle "Detail Guru"
  ///   - title is the teacher's full name
  ///   - back button is auto-wired by BrandPageHeader (via
  ///     AppNavigator)
  ///   - one action icon: refresh (re-fetches the detail payload)
  Widget buildGradientHeader(BuildContext context, String nameStr) {
    return BrandPageHeader(
      role: 'guru',
      title: nameStr.isNotEmpty ? nameStr : 'Detail Guru',
      subtitle: nameStr.isNotEmpty ? 'Detail Guru' : null,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.refresh_rounded,
          onTap: loadTeacherDetail,
        ),
      ],
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
