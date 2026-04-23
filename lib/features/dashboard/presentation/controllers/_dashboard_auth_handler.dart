import 'dart:convert';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Helper class for authentication and auth data updates.
class DashboardAuthHandler {
  final DashboardState Function() getState;

  DashboardAuthHandler({required this.getState});

  /// Switch to a different role.
  Future<void> switchRole(String role) async {
    final response = await AuthService.switchRole(role);
    await _updateAuthData(response, role);
  }

  /// Switch to a different school.
  /// May return flags like needsRoleSelection or
  /// needsSchoolSelection.
  Future<Map<String, dynamic>> switchSchool(
    String schoolId, {
    String? role,
  }) async {
    final response = await AuthService.switchSchool(schoolId, role: role);

    AppLogger.debug(
      'dashboard_auth_handler',
      'switchSchool response keys: ${response.keys.toList()}',
    );
    AppLogger.debug(
      'dashboard_auth_handler',
      'needsRoleSelection: ${response['needsRoleSelection']}',
    );
    AppLogger.debug(
      'dashboard_auth_handler',
      'user role: ${response['user']?['role']}',
    );

    if (response['needsRoleSelection'] == true) {
      return response;
    }
    if (response['needsSchoolSelection'] == true) {
      return response;
    }

    final newRole =
        response['user']?['role']?.toString() ?? role ?? _effectiveRole();
    await _updateAuthData(response, newRole);
    return response;
  }

  /// Update authentication data (token, user, preferences).
  Future<void> _updateAuthData(
    Map<String, dynamic> response,
    String role,
  ) async {
    // Token may be null when the backend reuses the existing token (e.g. on
    // school switch — identity hasn't changed, only the X-School-ID context).
    // In that case, keep the currently stored token.
    final token = response['token'];
    final prefs = PreferencesService();
    if (token != null) {
      await SecureStorageService().saveToken(token.toString());
      await prefs.setString('token', token.toString());
    }

    final currentUserData = getState().userData;
    final User user = response['user'] != null
        ? User.fromJson(response['user'])
        : User.fromJson(currentUserData).copyWith(role: role);

    final standardizedUser = user.toJson();
    await SecureStorageService().saveUserData(standardizedUser);
    await prefs.setString('user', json.encode(standardizedUser));
  }

  String _effectiveRole() {
    final role = getState().userData['role']?.toString() ?? 'admin';
    if (role == 'teacher') return 'guru';
    if (role == 'parent') return 'wali';
    return role;
  }
}
