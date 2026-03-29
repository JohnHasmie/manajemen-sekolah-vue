// Extracted from teacher_attendance_screen.dart (_buildInputMode).
// Like a Vue `<AttendanceInputMode>` component -- renders the "Add Attendance"
// tab content: a loading skeleton, the input form (passed as a pre-built widget),
// the per-student status list, empty/no-selection states, and the submit button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_item.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// The "Add Attendance" tab body for the teacher attendance screen.
///
/// Parameters (like Vue props / emits):
/// - [isLoadingInput]       -- when true, shows skeleton loader
/// - [inputFormWidget]      -- pre-built AttendanceInputForm (all callbacks wired
///                            in the parent so this widget stays stateless)
/// - [selectedSubjectId]    -- null means no subject selected yet; shows a prompt
/// - [filteredStudentList]  -- students currently visible after class/search filter
/// - [attendanceStatus]     -- map of studentId -> current status string
/// - [isSubmitting]         -- disables submit button and shows progress indicator
/// - [primaryColor]         -- role-based accent colour
/// - [onStatusChanged]      -- called when a student status button is tapped;
///                            parent calls setState to update [attendanceStatus]
/// - [onSubmit]             -- called when the "Save Attendance" button is tapped
class AttendanceInputMode extends ConsumerWidget {
  final bool isLoadingInput;
  final Widget inputFormWidget;
  final String? selectedSubjectId;
  final List<Student> filteredStudentList;
  final Map<String, String> attendanceStatus;
  final bool isSubmitting;
  final Color primaryColor;
  final void Function(String studentId, String status) onStatusChanged;
  final VoidCallback onSubmit;

  const AttendanceInputMode({
    super.key,
    required this.isLoadingInput,
    required this.inputFormWidget,
    required this.selectedSubjectId,
    required this.filteredStudentList,
    required this.attendanceStatus,
    required this.isSubmitting,
    required this.primaryColor,
    required this.onStatusChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    if (isLoadingInput) {
      return SkeletonListLoading(itemCount: 4, infoTagCount: 1);
    }

    return Column(
      children: [
        // 1. Form Section -- pre-built AttendanceInputForm passed from parent.
        inputFormWidget,

        // 2. Student List Area
        Expanded(
          child: selectedSubjectId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 64,
                          color: ColorUtils.slate300,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Please select Class and Subject first',
                            'id': 'Silakan pilih Kelas dan Mapel terlebih dahulu',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en':
                                'Or ensure you have a schedule for the selected date',
                            'id':
                                'Atau pastikan anda memiliki jadwal pada tanggal yang dipilih',
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorUtils.slate400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : filteredStudentList.isEmpty
              ? EmptyState(
                  title: languageProvider.getTranslatedText({
                    'en': 'No Students',
                    'id': 'Tidak ada siswa',
                  }),
                  subtitle: languageProvider.getTranslatedText({
                    'en': 'No students found for selected class',
                    'id': 'Tidak ada siswa untuk kelas yang dipilih',
                  }),
                  icon: Icons.people_outline,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredStudentList.length,
                  itemBuilder: (context, index) => AttendanceStudentItem(
                    student: filteredStudentList[index],
                    currentStatus:
                        attendanceStatus[filteredStudentList[index].id] ??
                        'hadir',
                    languageProvider: languageProvider,
                    onStatusChanged: onStatusChanged,
                  ),
                ),
        ),

        // 3. Submit Button -- shown only when a subject is chosen and list is non-empty
        if (selectedSubjectId != null && filteredStudentList.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting ? null : onSubmit,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 20),
                    label: Text(
                      isSubmitting
                          ? languageProvider.getTranslatedText({
                              'en': 'Saving...',
                              'id': 'Menyimpan...',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Save Attendance',
                              'id': 'Simpan Absensi',
                            }),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
