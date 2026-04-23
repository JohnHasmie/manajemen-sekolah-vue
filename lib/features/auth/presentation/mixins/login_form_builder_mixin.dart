import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';

mixin LoginFormBuilderMixin on ConsumerState<LoginScreen> {
  // Helper method to build password text field
  Widget _buildPasswordTextField(
    TextEditingController controller,
    bool isLoading,
    VoidCallback? onSubmitted,
  ) {
    return _PasswordTextFieldWidget(
      controller: controller,
      isLoading: isLoading,
      onSubmitted: onSubmitted,
    );
  }

  Widget buildLoginForm(AuthState authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icon/KamilEdu.png', height: 80),
        AppSpacing.v20,
        const Text(
          'Kamil Edu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (!authState.isServerConnected) _buildServerWarning(),
        const SizedBox(height: 30),
        _buildLoginFormFields(authState),
        AppSpacing.v20,
        _buildLoginButtons(authState),
      ],
    );
  }

  Widget _buildServerWarning() {
    return Column(
      children: [
        AppSpacing.v10,
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.red[50],
            border: Border.all(color: Colors.red),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              AppSpacing.h8,
              Expanded(
                child: Text(
                  AppLocalizations.serverNotConnected.tr,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormFields(AuthState authState) {
    return AutofillGroup(
      child: Column(
        children: [
          TextField(
            key: const Key('email_field'),
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 15),
          _buildPasswordTextField(passwordController, authState.isLoading, () {
            if (emailController.text.trim().isNotEmpty &&
                passwordController.text.isNotEmpty) {
              handleLogin();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildLoginButtons(AuthState authState) {
    final enabled = authState.isServerConnected && !authState.isLoading;
    return Column(
      children: [
        _buildLoginButton(authState, enabled),
        const SizedBox(height: 15),
        _buildGoogleSignInButton(authState, enabled),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState, bool enabled) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const Key('login_button'),
        onPressed: enabled ? handleLogin : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: ColorUtils.darkBlue,
          disabledBackgroundColor: ColorUtils.darkBlue.withValues(alpha: 0.6),
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
                AppLocalizations.login.tr.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(AuthState authState, bool enabled) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? handleGoogleSignIn : null,
        icon: Image.asset(
          'assets/icon/google_logo.png',
          height: 24,
          errorBuilder: (c, o, s) => const Icon(Icons.login),
        ),
        label: Text(
          authState.isLoading
              ? AppLocalizations.pleaseWait.tr
              : AppLocalizations.signInWithGoogle.tr,
          style: TextStyle(
            color: authState.isLoading ? Colors.grey : ColorUtils.darkBlue,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: BorderSide(
            color: authState.isLoading ? Colors.grey : ColorUtils.darkBlue,
          ),
        ),
      ),
    );
  }

  // Expose controllers and methods
  TextEditingController get emailController;
  TextEditingController get passwordController;
  Future<void> handleLogin();
  Future<void> handleGoogleSignIn();
}

/// Private password text field widget used by LoginFormBuilderMixin
class _PasswordTextFieldWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback? onSubmitted;

  const _PasswordTextFieldWidget({
    required this.controller,
    required this.isLoading,
    this.onSubmitted,
  });

  @override
  State<_PasswordTextFieldWidget> createState() =>
      _PasswordTextFieldWidgetState();
}

class _PasswordTextFieldWidgetState extends State<_PasswordTextFieldWidget> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('password_field'),
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: widget.isLoading ? null : (_) => widget.onSubmitted?.call(),
    );
  }
}
