import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_info_row.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_section_header.dart';

/// Builds UI components for student detail cards and sections.
mixin StudentDetailUiBuilderMixin {
  /// Gets primary color for UI elements.
  Color getPrimaryColor();

  /// Gets avatar color based on text hash.
  Color getAvatarColor(String text);

  /// Gets avatar initial from text.
  String getAvatarInitial(String text);

  /// Builds personal information card section.
  Widget buildPersonalInfoCard(
    LanguageProvider languageProvider,
    Map<String, dynamic> student,
  ) {
    final model = Student.fromJson(student);
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
          StudentSectionHeader(
            icon: Icons.person_rounded,
            title: languageProvider.getTranslatedText({
              'en': 'Personal Information',
              'id': 'Informasi Pribadi',
            }),
            primaryColor: getPrimaryColor(),
          ),
          StudentInfoRow(
            label: 'NIS',
            value: model.studentNumber.isNotEmpty ? model.studentNumber : '-',
            primaryColor: getPrimaryColor(),
            icon: Icons.badge,
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Class',
              'id': 'Kelas',
            }),
            value: model.className.isNotEmpty ? model.className : 'No Class',
            primaryColor: getPrimaryColor(),
            icon: Icons.school,
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Gender',
              'id': 'Jenis Kelamin',
            }),
            value: getGenderText(model.gender, languageProvider),
            primaryColor: getPrimaryColor(),
            icon: Icons.transgender,
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Birth Date',
              'id': 'Tanggal Lahir',
            }),
            value: formatDate(model.dateOfBirth),
            primaryColor: getPrimaryColor(),
            icon: Icons.cake,
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Address',
              'id': 'Alamat',
            }),
            value: model.address.isNotEmpty ? model.address : 'No Address',
            primaryColor: getPrimaryColor(),
            icon: Icons.location_on,
            isMultiline: true,
          ),
        ],
      ),
    );
  }

  /// Builds class history card section.
  Widget buildClassHistoryCard(
    LanguageProvider languageProvider,
    List<dynamic> classes,
  ) {
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
          StudentSectionHeader(
            icon: Icons.history_rounded,
            title: languageProvider.getTranslatedText({
              'en': 'Class History',
              'id': 'Riwayat Kelas',
            }),
            primaryColor: getPrimaryColor(),
          ),
          ...classes.map<Widget>((classItem) {
            final year = classItem['academic_year']?['year'] ?? 'Unknown Year';
            final classModel = Classroom.fromJson(
              classItem as Map<String, dynamic>,
            );
            return StudentInfoRow(
              label: year,
              value: classModel.name,
              primaryColor: getPrimaryColor(),
              icon: Icons.history,
            );
          }),
        ],
      ),
    );
  }

  /// Builds parent information card section.
  Widget buildParentInfoCard(
    LanguageProvider languageProvider,
    Map<String, dynamic> student,
  ) {
    final model = Student.fromJson(student);
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
          StudentSectionHeader(
            icon: Icons.family_restroom_rounded,
            title: languageProvider.getTranslatedText({
              'en': 'Parent Information',
              'id': 'Informasi Wali',
            }),
            primaryColor: getPrimaryColor(),
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Parent Name',
              'id': 'Nama Wali',
            }),
            value: model.guardianName.isNotEmpty
                ? model.guardianName
                : 'No Parent Name',
            primaryColor: getPrimaryColor(),
            icon: Icons.person,
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Phone Number',
              'id': 'No. Telepon',
            }),
            value: model.phoneNumber.isNotEmpty
                ? model.phoneNumber
                : 'No Phone',
            primaryColor: getPrimaryColor(),
            icon: Icons.phone,
          ),
          StudentInfoRow(
            label: languageProvider.getTranslatedText({
              'en': 'Parent Email',
              'id': 'Email Wali',
            }),
            value: (model.guardianEmail?.isNotEmpty ?? false)
                ? model.guardianEmail!
                : 'No Email',
            primaryColor: getPrimaryColor(),
            icon: Icons.email,
          ),
        ],
      ),
    );
  }

  /// Builds profile header card with avatar.
  Widget buildProfileHeaderCard(Map<String, dynamic> student) {
    final model = Student.fromJson(student);
    final nameStr = model.name;
    final className = model.className;
    final nis = model.studentNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.8)],
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
              color: getAvatarColor(nameStr),
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
                getAvatarInitial(nameStr),
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
            nameStr.isNotEmpty ? nameStr : 'No Name',
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
              if (nis.toString().isNotEmpty)
                buildInfoBadge(Icons.badge_outlined, 'NIS: $nis'),
              if (className.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                buildInfoBadge(Icons.school_outlined, className),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Builds individual info badge.
  Widget buildInfoBadge(IconData icon, String text) {
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
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
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

  /// Builds back button widget.
  Widget buildBackButton(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
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
          languageProvider.getTranslatedText({
            'en': 'Back to Student List',
            'id': 'Kembali ke Daftar Siswa',
          }),
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

  /// Formatting helper methods (required from mixin).
  String getGenderText(String? gender, LanguageProvider languageProvider);
  String formatDate(String? date);

  /// AppNavigator import for back button
  // Using app_navigator import at file level
}
