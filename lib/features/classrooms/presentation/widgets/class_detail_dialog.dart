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
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';

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
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
          ),
          SizedBox(width: AppSpacing.md),
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
                SizedBox(height: 3),
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

  /// Resolves the homeroom teacher display name from the various API shapes.
  String _resolveTeacherName() {
    if (classData['homeroom_teacher'] is List &&
        (classData['homeroom_teacher'] as List).isNotEmpty) {
      return classData['homeroom_teacher'][0]['name'];
    }
    if (classData['homeroom_teacher'] is Map) {
      return classData['homeroom_teacher']['name'];
    }
    return classData['homeroom_teacher_name'] ??
        classData['wali_kelas_nama'] ??
        languageProvider.getTranslatedText({
          'en': 'Not Assigned',
          'id': 'Belum Ditugaskan',
        });
  }

  @override
  Widget build(BuildContext context) {
    final name = classData['name'] ?? 'C';
    final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
    final avatarColor = ColorUtils.getColorForIndex(nameHash);
    final studentCount = classData['student_count'] ?? 0;
    final teacherName = _resolveTeacherName();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header with avatar, name, grade badge, close button ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.corporateBlue600,
                    ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  Column(
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
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  gradeText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content: detail items + action buttons ──
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClassDetailItem(
                    icon: Icons.people,
                    label: languageProvider.getTranslatedText({
                      'en': 'Total Students',
                      'id': 'Jumlah Siswa',
                    }),
                    value:
                        '$studentCount ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                  ),
                  ClassDetailItem(
                    icon: Icons.person,
                    label: languageProvider.getTranslatedText({
                      'en': 'Homeroom Teacher',
                      'id': 'Wali Kelas',
                    }),
                    value: teacherName,
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // ── View Students button (full width) ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppNavigator.pop(context);
                        AppNavigator.push(
                          context,
                          StudentManagementScreen(
                            initialClassId: classData['id'].toString(),
                          ),
                        );
                      },
                      icon: Icon(Icons.list, color: Colors.white),
                      label: Text(
                        languageProvider.getTranslatedText({
                          'en': 'View Students',
                          'id': 'Lihat Daftar Siswa',
                        }),
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // ── Footer: Close / Edit ──
                  Container(
                    padding: EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: ColorUtils.slate100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Close',
                                'id': 'Tutup',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        if (!isReadOnly) ...[
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                AppNavigator.pop(context);
                                onEdit();
                              },
                              icon: Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Edit',
                                  'id': 'Edit',
                                }),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorUtils.corporateBlue600,
                                padding: EdgeInsets.symmetric(vertical: 13),
                                elevation: 2,
                                shadowColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
