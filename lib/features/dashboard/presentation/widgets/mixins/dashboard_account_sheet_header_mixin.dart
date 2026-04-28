import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';

/// Mixin providing user info header and role display helpers.
mixin DashboardAccountSheetHeaderMixin {
  /// Abstract getters that state class must implement
  DashboardState get sheetState;
  Color get primaryColor;

  /// Build the user info header row with avatar, name, email, school.
  Widget buildUserInfoRow(BuildContext context) {
    return Row(
      children: [
        _buildUserAvatar(),
        AppSpacing.h16,
        Expanded(child: _buildUserInfoColumn()),
      ],
    );
  }

  /// Build the user avatar circle
  Widget _buildUserAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.account_circle, color: Colors.white, size: 32),
    );
  }

  /// Build the user info column (name, email, school)
  Widget _buildUserInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sheetState.userData['nama'] ??
              sheetState.userData['role'].toString().toUpperCase(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        AppSpacing.v4,
        Text(
          sheetState.userData['email'] ?? '',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          sheetState.userData['nama_sekolah'] ?? '',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Get icon for role display
  Widget roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings, color: primaryColor, size: 20);
      case 'guru':
        return Icon(Icons.school, color: primaryColor, size: 20);
      case 'wali':
        return Icon(Icons.family_restroom, color: primaryColor, size: 20);
      case 'staff':
        return Icon(Icons.work, color: primaryColor, size: 20);
      default:
        return Icon(Icons.person, color: primaryColor, size: 20);
    }
  }

  /// Get display name for role
  String roleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return AppLocalizations.adminRole.tr;
      case 'guru':
      case 'teacher':
        return AppLocalizations.teacherRole.tr;
      case 'wali':
      case 'parent':
      case 'walimurid':
      case 'wali murid':
        return AppLocalizations.parentRole.tr;
      case 'staff':
        return AppLocalizations.staffRole.tr;
      default:
        if (role.isNotEmpty) {
          return role[0].toUpperCase() + role.substring(1);
        }
        return role;
    }
  }
}
