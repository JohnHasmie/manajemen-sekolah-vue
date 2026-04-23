import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_info_row.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_section_header.dart';

/// Mixin for card/widget builders in TeacherDetailScreen.
mixin TeacherDetailCardBuildersMixin {
  /// Builds the profile header card with avatar and badges.
  Widget buildProfileCard(
    Map<String, dynamic> teacher,
    Color avatarColor,
    String initial,
    String nip,
    String homeroomStatus,
  ) {
    final model = Teacher.fromJson(teacher);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: ColorUtils.corporateShadow(elevation: 2.0),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            model.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (nip.isNotEmpty) buildNIPBadge(nip),
              if (homeroomStatus != '-') ...[
                const SizedBox(width: AppSpacing.sm),
                buildWaliKelasBadge(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// NIP badge widget.
  Widget buildNIPBadge(String nip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, size: 12, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'NIP: $nip',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Wali Kelas (homeroom) badge widget.
  Widget buildWaliKelasBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 12, color: Colors.white),
          SizedBox(width: AppSpacing.xs),
          Text(
            'Wali Kelas',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Personal information card.
  Widget buildPersonalInfoCard(Map<String, dynamic> teacher) {
    final model = Teacher.fromJson(teacher);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TeacherSectionHeader(
            icon: Icons.person_rounded,
            title: 'Informasi Pribadi',
          ),
          TeacherInfoRow(label: 'Nama', value: model.name),
          TeacherInfoRow(
            label: 'NIP',
            value: (model.employeeNumber ?? '').isNotEmpty
                ? model.employeeNumber!
                : 'Tidak ada',
          ),
          TeacherInfoRow(label: 'Email', value: model.email),
        ],
      ),
    );
  }

  /// Teaching information card.
  Widget buildTeachingInfoCard(
    Map<String, dynamic> teacher,
    List<String> teachingClassNames,
    List<String> displaySubjectNames,
    String homeroomStatus,
  ) {
    final model = Teacher.fromJson(teacher);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TeacherSectionHeader(
            icon: Icons.school_rounded,
            title: 'Informasi Mengajar',
          ),
          TeacherInfoRow(
            label: 'Kelas',
            value: teachingClassNames.isNotEmpty
                ? teachingClassNames
                : 'Belum dijadwalkan',
            isMultiline: true,
          ),
          TeacherInfoRow(
            label: 'Mata Pelajaran',
            value: displaySubjectNames.isNotEmpty
                ? displaySubjectNames
                : 'Belum ditugaskan',
            isMultiline: true,
          ),
          TeacherInfoRow(
            label: 'Role',
            value: model.role.isNotEmpty ? model.role.toUpperCase() : 'GURU',
          ),
          TeacherInfoRow(label: 'Status Wali Kelas', value: homeroomStatus),
        ],
      ),
    );
  }

  /// Back button widget.
  Widget buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => AppNavigator.pop(context),
        icon: Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: ColorUtils.slate700,
        ),
        label: Text(
          'Kembali ke Daftar Guru',
          style: TextStyle(
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: ColorUtils.slate300),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}
