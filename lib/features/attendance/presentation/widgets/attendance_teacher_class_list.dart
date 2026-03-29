// Extracted from teacher_attendance_screen.dart (_buildInlineClassList).
// Like a Vue `<TeacherClassList>` component -- shows the list of classes a
// teacher can tap to drill into attendance results or the input form.
//
// Stateless: all mutable data and user interactions are passed in as
// constructor parameters (props + emits in Vue terms). The parent
// (AttendancePage) owns the state; this widget only renders.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';

/// Renders either an empty state or a scrollable list of class cards for the
/// teacher-facing attendance screen.
///
/// Parameters (like Vue props / emits):
/// - [classList]        -- raw class objects from the API
/// - [primaryColor]     -- role-based accent color (passed from the parent)
/// - [languageProvider] -- for translating UI strings
/// - [onClassSelected]  -- called with the class map when the user taps a card;
///                         the parent uses this to call setState + load subjects
class AttendanceTeacherClassList extends StatelessWidget {
  final List<dynamic> classList;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  /// Called when the user taps a class card.
  /// The parent should update [_selectedClassId] and call
  /// [_loadSubjectsByClass] / [_loadAttendanceSummary] inside setState.
  final void Function(Map<String, dynamic> classData) onClassSelected;

  const AttendanceTeacherClassList({
    super.key,
    required this.classList,
    required this.primaryColor,
    required this.languageProvider,
    required this.onClassSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (classList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Class Data',
          'id': 'Data Kelas Kosong',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'You do not have any classes for this academic year',
          'id': 'Anda tidak mengampu kelas untuk tahun ajaran ini',
        }),
        icon: Icons.class_outlined,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: classList.length,
      itemBuilder: (context, index) {
        final classData = classList[index] as Map<String, dynamic>;
        final isHomeroom = classData['is_homeroom'] == true;
        final accentColor = isHomeroom
            ? primaryColor
            : ColorUtils.getColorForIndex(index);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onClassSelected(classData),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
              ),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      isHomeroom
                          ? Icons.home_work_rounded
                          : Icons.class_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                classData['nama'] ??
                                    classData['name'] ??
                                    'Unknown Class',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: ColorUtils.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // "Wali Kelas" badge shown only for homeroom class
                            if (isHomeroom) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'Wali Kelas',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if ([
                          classData['tingkat'],
                          classData['jurusan'],
                        ].any(
                          (e) => e != null && e.toString().isNotEmpty,
                        )) ...[
                          const SizedBox(height: 3),
                          Text(
                            [classData['tingkat'], classData['jurusan']]
                                .where(
                                  (e) => e != null && e.toString().isNotEmpty,
                                )
                                .join(' • '),
                            style: TextStyle(
                              color: ColorUtils.slate600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (classData['homeroom_teacher_name'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Wali Kelas: ${classData['homeroom_teacher_name']}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: ColorUtils.slate400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
