import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class StudentSelector extends StatelessWidget {
  final List<Student> students;
  final Student? selectedStudent;
  final Function(Student) onSelected;

  const StudentSelector({
    super.key,
    required this.students,
    this.selectedStudent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final isSelected = selectedStudent?.id == student.id;

          return GestureDetector(
            onTap: () => onSelected(student),
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? ColorUtils.primary
                          : ColorUtils.slate100,
                      border: Border.all(
                        color: isSelected
                            ? ColorUtils.primary
                            : ColorUtils.slate200,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: ColorUtils.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person,
                        color: isSelected ? Colors.white : ColorUtils.slate400,
                        size: 24,
                      ),
                    ),
                  ),
                  AppSpacing.v6,
                  Text(
                    student.name.split(' ')[0],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? ColorUtils.primary
                          : ColorUtils.slate600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
