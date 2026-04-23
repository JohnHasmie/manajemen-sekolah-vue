import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';

mixin AuthFormBuilderMixin on ConsumerState<LoginScreen> {
  Widget buildCurrentAuthStep(AuthState authState) {
    switch (authState.step) {
      case AuthStep.schoolSelection:
        return buildSchoolSelection(authState);
      case AuthStep.roleSelection:
        return buildRoleSelection(authState);
      case AuthStep.otpVerification:
        return buildOtpForm(authState);
      case AuthStep.login:
        return buildLoginForm(authState);
    }
  }

  Widget buildOtpForm(AuthState authState) {
    if (authState.otpCode != null &&
        otpController.text.isEmpty &&
        authState.otpCode!.isNotEmpty) {
      otpController.text = authState.otpCode!;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.security, size: 64, color: ColorUtils.darkBlue),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppLocalizations.otpVerification.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.otpSentToEmail.tr,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          authState.currentEmail ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildOtpInputSection(authState),
      ],
    );
  }

  Widget _buildOtpInputSection(AuthState authState) {
    return Column(
      children: [
        Text(AppLocalizations.enterOtpDigits.tr),
        const SizedBox(height: AppSpacing.sm),
        _buildOtpTextField(),
        const SizedBox(height: AppSpacing.xl),
        _buildOtpVerifyButton(authState),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
          child: Text(AppLocalizations.backToLogin.tr),
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
          backgroundColor: ColorUtils.darkBlue,
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
                AppLocalizations.verify.tr.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  Widget buildSchoolSelection(AuthState authState) {
    return Column(
      children: [
        if (authState.isLoading)
          LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.darkBlue),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          AppLocalizations.selectSchool.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        AppSpacing.v10,
        _buildSchoolHeaders(authState),
        AppSpacing.v20,
        _buildSchoolList(authState),
        AppSpacing.v20,
        TextButton(
          onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
          child: Text(AppLocalizations.backToLogin.tr),
        ),
      ],
    );
  }

  Widget _buildSchoolHeaders(AuthState authState) {
    return Column(
      children: [
        Text(
          '${AppLocalizations.hello.tr} '
          '${authState.userData?['name'] ?? authState.userData?['nama'] ?? 'User'},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          AppLocalizations.selectSchoolMsg.tr,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSchoolList(AuthState authState) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: authState.schoolList.length,
      itemBuilder: (context, index) {
        final sekolah = authState.schoolList[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            key: ValueKey('school_${sekolah['school_id'] ?? index}'),
            leading: Icon(Icons.school, color: ColorUtils.darkBlue),
            title: Text(
              sekolah['school_name'] ?? AppLocalizations.schoolNoName.tr,
            ),
            subtitle: Text(sekolah['address'] ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: authState.isLoading
                ? null
                : () async {
                    await ref
                        .read(authProvider.notifier)
                        .selectSchool(sekolah['school_id'].toString());
                  },
          ),
        );
      },
    );
  }

  Widget buildRoleSelection(AuthState authState) {
    final schoolName =
        authState.selectedSchool?['school_name'] ??
        authState.selectedSchool?['name'] ??
        authState.selectedSchool?['nama_sekolah'] ??
        authState.userData?['school_name'] ??
        authState.userData?['nama_sekolah'] ??
        '-';

    return Column(
      children: [
        if (authState.isLoading)
          LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.darkBlue),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          AppLocalizations.selectRole.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        AppSpacing.v10,
        _buildRoleHeaders(authState, schoolName),
        AppSpacing.v20,
        _buildRoleList(authState),
        AppSpacing.v20,
        _buildRoleBackButton(authState),
      ],
    );
  }

  Widget _buildRoleHeaders(AuthState authState, String schoolName) {
    return Column(
      children: [
        Text(
          '${AppLocalizations.hello.tr} '
          '${authState.userData?['name'] ?? authState.userData?['nama'] ?? 'User'},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          '${AppLocalizations.schoolLabel.tr}: $schoolName',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRoleList(AuthState authState) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: authState.roleList.length,
      itemBuilder: (context, index) {
        final role = authState.roleList[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            key: ValueKey('role_$role'),
            leading: getRoleIcon(role),
            title: Text(getRoleDisplayName(role)),
            subtitle: Text(
              '${AppLocalizations.accessAs.tr} '
              '${getRoleDescription(role)}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: authState.isLoading
                ? null
                : () async {
                    await ref
                        .read(authProvider.notifier)
                        .selectRole(role.toString());
                  },
          ),
        );
      },
    );
  }

  Widget _buildRoleBackButton(AuthState authState) {
    return TextButton(
      onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
      child: Text(AppLocalizations.backToLogin.tr),
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
