import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';

mixin RoleManagementMixin on State<LoginScreen> {
  Widget getRoleIcon(String role) {
    // Tint role icons with the canonical role color from
    // ColorUtils.getRoleColor so brand updates flow through here too.
    final color = ColorUtils.getRoleColor(role);
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings, color: color);
      case 'guru':
        return Icon(Icons.school, color: color);
      case 'wali':
        return Icon(Icons.family_restroom, color: color);
      case 'staff':
        return Icon(Icons.work, color: color);
      default:
        return Icon(Icons.person, color: color);
    }
  }

  String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'Administrator';
      case 'guru':
      case 'teacher':
        return 'Teacher';
      case 'wali':
      case 'parent':
      case 'walimurid':
      case 'wali murid':
        return 'Parent';
      case 'staff':
        return 'Staff';
      default:
        if (role.isNotEmpty) {
          return role[0].toUpperCase() + role.substring(1);
        }
        return role;
    }
  }

  String getRoleDescription(String role) {
    switch (role) {
      case 'admin':
        return AppLocalizations.roleDescAdmin.tr;
      case 'guru':
        return AppLocalizations.roleDescTeacher.tr;
      case 'wali':
        return AppLocalizations.roleDescParent.tr;
      case 'staff':
        return AppLocalizations.roleDescStaff.tr;
      default:
        return AppLocalizations.roleDescDefault.tr;
    }
  }
}
