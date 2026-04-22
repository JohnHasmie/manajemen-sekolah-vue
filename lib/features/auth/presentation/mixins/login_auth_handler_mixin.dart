import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';

mixin LoginAuthHandlerMixin on ConsumerState<LoginScreen> {
  Future<void> checkServerConnection() async {
    try {
      await ApiService.checkHealth();
      ref.read(authProvider.notifier).setServerConnected(true);
    } catch (e) {
      ref.read(authProvider.notifier).setServerConnected(false);
      if (mounted) {
        SnackBarUtils.showInfo(context, AppLocalizations.serverNotConnected.tr);
      }
    }
  }

  void handleGlobalAuthEvents(AuthResponse? previous, AuthResponse current) {
    if (!mounted) return;

    switch (current.event) {
      case AuthEvent.unregistered:
        _showUnregisteredDialog();
        break;
      case AuthEvent.error:
        SnackBarUtils.showError(
          context,
          current.messageMap?.tr ??
              current.message ??
              AppLocalizations.loginFailed.tr,
        );
        break;
      case AuthEvent.success:
        AppNavigator.pushReplacementNamed(context, '/${current.message}');
        break;
      case AuthEvent.requiresOtp:
        // Handled by inline UI step transition
        break;
      case AuthEvent.none:
        break;
    }
  }

  Future<void> handleLogin() async {
    final authState = ref.read(authProvider);
    if (!authState.isServerConnected) {
      SnackBarUtils.showInfo(context, AppLocalizations.serverNotConnected.tr);
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;

    await ref.read(authProvider.notifier).login(email, password);
  }

  Future<void> handleGoogleSignIn() async {
    final authState = ref.read(authProvider);
    if (!authState.isServerConnected) {
      SnackBarUtils.showInfo(context, AppLocalizations.serverNotConnected.tr);
      return;
    }

    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  Future<void> handleOtpVerification() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      SnackBarUtils.showInfo(context, AppLocalizations.enterOtp.tr);
      return;
    }

    await ref.read(authProvider.notifier).verifyOtp(otp);
  }

  void _showUnregisteredDialog() {
    AppAlertDialog.show(
      context: context,
      title: AppLocalizations.accountNotRegistered.tr,
      message: AppLocalizations.accountNotRegisteredMsg.tr,
      icon: Icons.person_off_outlined,
      confirmText: AppLocalizations.understand.tr,
      showCancel: false,
    );
  }

  // Expose controllers for mixin usage
  TextEditingController get emailController;
  TextEditingController get passwordController;
  TextEditingController get otpController;
}
