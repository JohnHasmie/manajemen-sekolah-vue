// Extracted teacher-selection bottom sheet for admin attendance report.
//
// Like a Vue modal component that receives a teacher list as a prop and
// emits an onTeacherSelected event when the user picks a teacher.
// Owns no async logic -- the parent passes in the already-loaded list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// A modal bottom sheet that lets an admin pick a teacher from [teacherList].
///
/// Like a Vue `<TeacherPickerModal>` component:
/// - [teacherList]   – props: the already-loaded teacher data (`List<dynamic>`)
/// - [primaryColor]  – props: brand colour passed down from the parent
/// - [onSelected]    – emit: fires with the chosen teacher map so the parent
///                     can navigate to AttendancePage
///
/// Call [TeacherSelectionSheet.show] from the parent instead of constructing
/// the widget directly -- it wraps [AppBottomSheet.show] for you.
class TeacherSelectionSheet extends ConsumerWidget {
  const TeacherSelectionSheet({
    super.key,
    required this.teacherList,
    required this.primaryColor,
    required this.onSelected,
  });

  final List<dynamic> teacherList;
  final Color primaryColor;

  /// Called with the selected teacher map when the user taps a row.
  /// The parent is responsible for navigating away after this fires.
  final void Function(Map<String, dynamic> teacher) onSelected;

  /// Convenience factory: shows this sheet as a modal bottom sheet.
  ///
  /// Like calling `this.$emit('show-modal')` in Vue – the caller doesn't need
  /// to know the internal sheet geometry details.
  static void show({
    required BuildContext context,
    required List<dynamic> teacherList,
    required Color primaryColor,
    required void Function(Map<String, dynamic> teacher) onSelected,
  }) {
    final container = ProviderScope.containerOf(context);
    final languageProvider = container.read(languageRiverpod);

    AppBottomSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Select Teacher',
        'id': 'Pilih Guru',
      }),
      icon: Icons.person,
      primaryColor: primaryColor,
      simpleHeader: true,
      content: _TeacherListContent(
        teacherList: teacherList,
        primaryColor: primaryColor,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TeacherListContent(
      teacherList: teacherList,
      primaryColor: primaryColor,
      onSelected: onSelected,
    );
  }
}

/// Internal content widget for the teacher selection list.
class _TeacherListContent extends StatelessWidget {
  final List<dynamic> teacherList;
  final Color primaryColor;
  final void Function(Map<String, dynamic> teacher) onSelected;

  const _TeacherListContent({
    required this.teacherList,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: teacherList.length,
      itemBuilder: (context, index) {
        final teacher = teacherList[index] as Map<String, dynamic>? ?? {};
        final model = Teacher.fromJson(teacher);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              child: Text(
                model.initials,
                style: TextStyle(color: primaryColor),
              ),
            ),
            title: Text(
              model.name.isNotEmpty ? model.name : 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              model.employeeNumber != null &&
                      model.employeeNumber!.isNotEmpty
                  ? model.employeeNumber!
                  : 'N/A',
            ),
            onTap: () {
              Navigator.pop(context);
              onSelected(teacher);
            },
          ),
        );
      },
    );
  }
}
