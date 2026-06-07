// Dispatches the login screen's auth steps (school / role / otp /
// login) into the form-card. The school and role pickers (Frames D & E
// of `_design/auth_login_school_role_redesign.html`) live in their own
// widget files under `presentation/widgets/`; this mixin wires them to
// the auth provider and supplies the role colour / icon / stats helpers
// the role picker renders with.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';
import 'package:manajemensekolah/features/auth/presentation/widgets/role_picker_step.dart';
import 'package:manajemensekolah/features/auth/presentation/widgets/school_picker_step.dart';

mixin AuthFormBuilderMixin on ConsumerState<LoginScreen> {
  Widget buildCurrentAuthStep(AuthState authState) {
    switch (authState.step) {
      case AuthStep.schoolSelection:
        return SchoolPickerStep(
          authState: authState,
          onConfirm: (schoolId) =>
              ref.read(authProvider.notifier).selectSchool(schoolId),
          onBackToLogin: () => ref.read(authProvider.notifier).resetToLogin(),
        );
      case AuthStep.roleSelection:
        return RolePickerStep(
          authState: authState,
          getRoleDisplayName: getRoleDisplayName,
          getRoleDescription: getRoleDescription,
          getRoleColor: _roleColor,
          getRoleIconData: _roleIconData,
          getRoleStats: _roleStatsFor,
          onConfirm: (role) => ref.read(authProvider.notifier).selectRole(role),
          onBackToLogin: () => ref.read(authProvider.notifier).resetToLogin(),
        );
      case AuthStep.otpVerification:
        return buildOtpForm(authState);
      case AuthStep.login:
        return buildLoginForm(authState);
    }
  }

  // ─── Role color / icon / stats helpers ──────────────────────────
  // The role accent (Frame E) follows the same admin-navy / guru-
  // cobalt / wali-azure palette the rest of the app already uses on
  // its dashboards (see ColorUtils.brandGradient).

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return ColorUtils.brandDarkBlue;
      case 'guru':
      case 'teacher':
        return ColorUtils.brandCobalt;
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return ColorUtils.brandAzure;
      case 'staff':
        return ColorUtils.brandCobalt;
      default:
        return ColorUtils.brandCobalt;
    }
  }

  IconData _roleIconData(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return Icons.shield_outlined;
      case 'guru':
      case 'teacher':
        return Icons.school_outlined;
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return Icons.family_restroom_rounded;
      case 'staff':
        return Icons.work_outline_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  /// Static stat captions per role — keeps the cards visually balanced
  /// even when the backend doesn't ship per-role counters at the role-
  /// selection step. When real metrics become available (post-login
  /// dashboard payload), we can swap these for live numbers without
  /// touching the picker.
  List<String> _roleStatsFor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return [kAutAdminStat1.tr, kAutAdminStat2.tr];
      case 'guru':
      case 'teacher':
        return [kAutTeacherStat1.tr, kAutTeacherStat2.tr];
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return [kAutParentStat1.tr, kAutParentStat2.tr];
      case 'staff':
        return [kAutStaffStat1.tr];
      default:
        return const [];
    }
  }

  // ─── OTP ────────────────────────────────────────────────────────

  Widget buildOtpForm(AuthState authState) {
    if (authState.otpCode != null &&
        otpController.text.isEmpty &&
        authState.otpCode!.isNotEmpty) {
      otpController.text = authState.otpCode!;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.otpVerification.tr,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: ColorUtils.slate900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${AppLocalizations.otpSentToEmail.tr} '
          '${authState.currentEmail ?? ''}',
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.enterOtpDigits.tr,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        _buildOtpTextField(),
        const SizedBox(height: AppSpacing.xl),
        _buildOtpVerifyButton(authState),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
            child: Text(
              AppLocalizations.backToLogin.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandCobalt,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpTextField() {
    return TextField(
      controller: otpController,
      decoration: InputDecoration(
        labelText: AppLocalizations.otpCode.tr,
        border: const OutlineInputBorder(),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 8),
      autofocus: true,
    );
  }

  Widget _buildOtpVerifyButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: authState.isLoading ? null : handleOtpVerification,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: ColorUtils.brandCobalt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                AppLocalizations.verify.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget buildLoginForm(AuthState authState);

  // Expose controllers and methods for mixin usage
  TextEditingController get emailController;
  TextEditingController get passwordController;
  TextEditingController get otpController;
  Future<void> handleOtpVerification();
  Future<void> handleLogin();
  Future<void> handleGoogleSignIn();
  String getRoleDescription(String role);
  String getRoleDisplayName(String role);
  Widget getRoleIcon(String role);
}
