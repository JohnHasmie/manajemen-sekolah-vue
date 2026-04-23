// Class detail dialog extracted from AdminClassManagementScreen.
//
// Like a Vue `<ClassDetailModal>` component — shows a read-only summary of a
// single classroom (avatar, grade badge, student count, homeroom teacher) with
// a "View Students" button and Edit/Close footer actions.
//
// Navigation callbacks are passed in rather than accessed via ref so that this
// widget remains a pure StatelessWidget (no Riverpod dependency).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/mixins/class_detail_content_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/mixins/class_detail_footer_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/mixins/class_detail_header_mixin.dart';

/// A labelled row item used inside [ClassDetailDialog].
///
/// Like a `<DetailRow>` micro-component: shows an icon in a tinted square,
/// a small label above, and a value text below.
///
/// Props (all required):
/// - [icon] — Material icon
/// - [label] — small caption text (e.g. "Total Students")
/// - [value] — main value text
class ClassDetailItem extends StatelessWidget {
  const ClassDetailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen dialog that displays classroom details.
///
/// Shown by calling [ClassDetailDialog.show] from the parent screen.
/// The parent passes [onEdit] so the screen retains control over opening
/// the add/edit bottom sheet — no business logic lives here.
///
/// Props:
/// - [classData]      — raw Map from the API
/// - [gradeText]      — pre-formatted grade string (e.g. "Grade 7 SMP")
/// - [primaryColor]   — accent colour (admin role colour)
/// - [isReadOnly]     — when true the Edit button is hidden
/// - [onEdit]         — called after the dialog closes to open the edit sheet
/// - [languageProvider] — for translating all visible strings
class ClassDetailDialog extends StatelessWidget {
  const ClassDetailDialog({
    super.key,
    required this.classData,
    required this.gradeText,
    required this.primaryColor,
    required this.isReadOnly,
    required this.onEdit,
    required this.languageProvider,
  });

  final Map<String, dynamic> classData;
  final String gradeText;
  final Color primaryColor;
  final bool isReadOnly;
  final VoidCallback onEdit;
  final LanguageProvider languageProvider;

  /// Convenience static helper — mirrors the original `_showClassDetail` call
  /// pattern so call sites read as `ClassDetailDialog.show(context, ...)`.
  static void show({
    required BuildContext context,
    required Map<String, dynamic> classData,
    required String gradeText,
    required Color primaryColor,
    required bool isReadOnly,
    required VoidCallback onEdit,
    required LanguageProvider languageProvider,
  }) {
    showDialog(
      context: context,
      builder: (_) => ClassDetailDialog(
        classData: classData,
        gradeText: gradeText,
        primaryColor: primaryColor,
        isReadOnly: isReadOnly,
        onEdit: onEdit,
        languageProvider: languageProvider,
      ),
    );
  }

  @override
  Widget build(BuildContext buildContext) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: _DialogBody(
        classData: classData,
        gradeText: gradeText,
        primaryColor: primaryColor,
        isReadOnly: isReadOnly,
        onEdit: onEdit,
        languageProvider: languageProvider,
        buildContext: buildContext,
      ),
    );
  }
}

/// Internal widget that uses mixins to build the dialog
/// body.
///
/// Separated to provide context via a StatelessWidget
/// parameter rather than through BuildContext parameter
/// shadowing.
class _DialogBody extends StatelessWidget
    with
        ClassDetailHeaderMixin,
        ClassDetailContentMixin,
        ClassDetailFooterMixin {
  const _DialogBody({
    required this.classData,
    required this.gradeText,
    required this.primaryColor,
    required this.isReadOnly,
    required this.onEdit,
    required this.languageProvider,
    required this.buildContext,
  });

  @override
  final Map<String, dynamic> classData;
  @override
  final String gradeText;
  @override
  final Color primaryColor;
  @override
  final bool isReadOnly;
  @override
  final VoidCallback onEdit;
  @override
  final LanguageProvider languageProvider;

  @override
  BuildContext get context => buildContext;

  final BuildContext buildContext;

  @override
  Widget build(BuildContext context) {
    final model = Classroom.fromJson(classData);
    final studentCount = model.studentCount;
    final teacherName = _resolveTeacherName(model);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeaderSection(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildContentSection(teacherName, studentCount),
                const SizedBox(height: AppSpacing.xl),
                buildFooterSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the homeroom teacher display name from the
  /// normalized [Classroom] model.
  String _resolveTeacherName(Classroom model) {
    final resolved = model.homeroomTeacherName;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return languageProvider.getTranslatedText({
      'en': 'Not Assigned',
      'id': 'Belum Ditugaskan',
    });
  }
}
