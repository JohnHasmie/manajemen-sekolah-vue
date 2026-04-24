import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

/// Mixin for notification tap-to-navigate logic.
mixin NotificationNavigationMixin {
  BuildContext get context;
  String get role;

  void handleTap(Map<String, dynamic> notif) {
    final type = notif['type'];

    if (role == 'wali' || role == 'parent') {
      if (type == 'bill') {
        AppNavigator.push(context, const ParentBillingScreen());
        return;
      } else if (type == 'class_activity') {
        AppNavigator.push(context, const ParentClassActivityScreen());
        return;
      }
    } else if (role == 'guru' || role == 'teacher') {
      if (type == 'class_activity') {
        AppNavigator.push(context, const TeacherClassActivityScreen());
        return;
      }
    }

    if (type == 'announcement' || type == 'pengumuman') {
      AppNavigator.push(context, const ParentAnnouncementScreen());
    }
  }
}
