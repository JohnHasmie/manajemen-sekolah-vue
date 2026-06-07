import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_card.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for student list UI in AdminAttendanceDetailPage
mixin AdminDetailUiListMixin on ConsumerState<AdminAttendanceDetailPage> {
  // Abstract properties - must be implemented by consuming class
  List<Student> get studentList;
  bool get isLoading;
  bool get isEditing;
  Map<String, String> get tempAttendanceStatus;

  String getStatusText(String status, LanguageProvider languageProvider);
  Color getStatusColor(String status);
  String getStudentStatusFromData(String studentId);

  Widget buildStudentListHeader(LanguageProvider languageProvider) {
    final studentsWord = languageProvider.getTranslatedText({
      'en': 'students',
      'id': 'siswa',
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            languageProvider.getTranslatedText({
              'en': 'Student List',
              'id': 'Daftar Siswa',
            }),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate600,
            ),
          ),
          const Spacer(),
          Text(
            '${studentList.length} $studentsWord',
            style: TextStyle(fontSize: 12, color: ColorUtils.slate600),
          ),
        ],
      ),
    );
  }

  Widget buildStudentList(LanguageProvider languageProvider) {
    if (isLoading) return _buildLoadingState();
    if (studentList.isEmpty) return _buildEmptyState(languageProvider);
    return _buildStudentListView(languageProvider);
  }

  Widget _buildLoadingState() {
    return const Expanded(
      child: SkeletonListLoading(
        itemCount: 8,
        infoTagCount: 1,
        showActions: false,
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          title: languageProvider.getTranslatedText({
            'en': 'No Students Found',
            'id': 'Siswa Tidak Ditemukan',
          }),
          subtitle: kAttNoStudentsForCriteria.tr,
        ),
      ),
    );
  }

  Widget _buildStudentListView(LanguageProvider languageProvider) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: studentList.length,
        itemBuilder: (context, index) {
          final student = studentList[index];
          final status = getStudentStatusFromData(student.id);
          return AttendanceStudentCard(
            student: student,
            index: index,
            currentStatus: status,
            statusText: getStatusText(status, languageProvider),
            statusColor: getStatusColor(status),
            isEditing: isEditing,
            tempStatus: tempAttendanceStatus[student.id],
            onStatusChanged: (newStatus) {
              setState(() {
                tempAttendanceStatus[student.id] = newStatus;
              });
            },
          );
        },
      ),
    );
  }
}
