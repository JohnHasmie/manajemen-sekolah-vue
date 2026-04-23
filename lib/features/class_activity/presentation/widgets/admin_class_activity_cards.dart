import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_teacher_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_subject_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_card.dart';

/// Builder widgets for class activity cards.
class AdminClassActivityCardBuilders {
  static Widget buildTeacherCard(
    Map<String, dynamic> teacher,
    int index,
    VoidCallback onTap,
  ) {
    return AdminTeacherCard(teacher: teacher, index: index, onTap: onTap);
  }

  static Widget buildSubjectCard(
    Map<String, dynamic> subject,
    int index,
    VoidCallback onTap,
  ) {
    return AdminSubjectCard(subject: subject, index: index, onTap: onTap);
  }

  static Widget buildActivityCard(
    Map<String, dynamic> activity,
    VoidCallback onTap,
  ) {
    return AdminActivityCard(activity: activity, onTap: onTap);
  }
}
