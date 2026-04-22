import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/subject_row_widget.dart';

mixin GradeInputContentMixin on ConsumerState<GradePage> {
  bool get isLoading;
  bool get isHomeroomView;
  bool get isTableView;
  String? get gradeErrorMessage => null;

  List<dynamic> getFilteredData();

  Future<void> refresh();

  Map<String, dynamic> safeMap(dynamic raw);

  void openGradeBook(dynamic classData, dynamic subject);

  Color get primaryColor;

  Widget buildContent(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: gradeErrorMessage,
      isEmpty: getFilteredData().isEmpty,
      onRefresh: refresh,
      role: 'guru',
      emptyTitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'No Homeroom Class',
              'id': 'Bukan Wali Kelas',
            })
          : lp.getTranslatedText({
              'en': 'No Classes Found',
              'id': 'Tidak Ada Kelas',
            }),
      emptySubtitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'You are not assigned as homeroom teacher',
              'id': 'Anda tidak ditugaskan sebagai wali kelas',
            })
          : lp.getTranslatedText({
              'en': 'No teaching assignments found',
              'id': 'Tidak ada jadwal mengajar ditemukan',
            }),
      emptyIcon: isHomeroomView ? Icons.class_outlined : Icons.grade_outlined,
      childBuilder: () => isTableView ? buildTableView(getFilteredData()) : _buildListView(getFilteredData()),
    );
  }


  Widget _buildListView(List<dynamic> data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: data.length,
      itemBuilder: (_, i) => buildClassCard(data[i]),
    );
  }

  Widget buildTableView(List<dynamic> data);

  Widget buildClassCard(dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final subjects = (g['subjects'] as List?) ?? [];
    final studentCount = g['student_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        children: [
          _buildCardHeader(cn, studentCount),
          Divider(height: 1, color: ColorUtils.slate200),
          ..._buildSubjectRows(subjects, g),
        ],
      ),
    );
  }

  Widget _buildCardHeader(String className, int count) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Text(
            'Kelas: $className',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count siswa',
              style: TextStyle(
                fontSize: 10,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSubjectRows(List<dynamic> subjects, dynamic classData) {
    return subjects.asMap().entries.map((e) {
      final sub = e.value;
      final isLast = e.key == subjects.length - 1;
      return Column(
        children: [
          SubjectRowWidget(
            classData: classData,
            subject: sub,
            primaryColor: primaryColor,
            onTap: () => openGradeBook(classData, sub),
            isHomeroomView: isHomeroomView,
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Divider(height: 1, color: ColorUtils.slate50),
            ),
        ],
      );
    }).toList();
  }

  Color scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }
}
