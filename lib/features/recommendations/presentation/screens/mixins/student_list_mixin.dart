import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for student list UI building.
mixin StudentListMixin {
  bool get isLoading;
  List<dynamic> get students;
  String get errorMessage;
  Map<String, dynamic> get classData;
  Map<String, String> get teacher;
  GlobalKey<dynamic> get studentListKey;
  BuildContext get context;

  Widget buildStudentListBody() {
    if (isLoading) {
      return const SkeletonListLoading();
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
      );
    }

    if (students.isEmpty) {
      return const Center(child: Text('Tidak ada data siswa'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return buildStudentTile(student, index);
      },
    );
  }

  Widget buildStudentTile(dynamic student, int index) {
    return Container(
      key: index == 0 ? studentListKey : null,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: ColorUtils.corporateShadow(),
      ),
      child: ListTile(
        leading: _buildStudentAvatar(student),
        title: _buildStudentName(student),
        subtitle: _buildStudentNis(student),
        trailing: Icon(Icons.chevron_right, color: ColorUtils.slate400),
        onTap: () {
          LearningRecommendationResultScreen.show(
            context: context,
            teacher: teacher,
            student: student,
            classData: classData,
          );
        },
      ),
    );
  }

  Widget _buildStudentAvatar(dynamic student) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    return CircleAvatar(
      backgroundColor: ColorUtils.slate50,
      child: Text(
        model.initials,
        style: TextStyle(
          color: ColorUtils.slate600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStudentName(dynamic student) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    return Text(
      model.name.isNotEmpty ? model.name : 'Siswa Tanpa Nama',
      style: TextStyle(fontWeight: FontWeight.bold, color: ColorUtils.slate800),
    );
  }

  Widget _buildStudentNis(dynamic student) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    return Text(
      'NIS: ${model.studentNumber.isNotEmpty ? model.studentNumber : '-'}',
      style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
    );
  }
}
