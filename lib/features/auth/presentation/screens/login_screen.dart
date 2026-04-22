import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/mixins/login_auth_handler_mixin.dart';
import 'package:manajemensekolah/features/auth/presentation/mixins/auth_form_builder_mixin.dart';
import 'package:manajemensekolah/features/auth/presentation/mixins/login_form_builder_mixin.dart';
import 'package:manajemensekolah/features/auth/presentation/mixins/role_management_mixin.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialError;

  const LoginScreen({super.key, this.initialError});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with
        LoginAuthHandlerMixin,
        AuthFormBuilderMixin,
        LoginFormBuilderMixin,
        RoleManagementMixin {
  @override
  final TextEditingController emailController = TextEditingController();
  @override
  final TextEditingController passwordController = TextEditingController();
  @override
  final TextEditingController otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkServerConnection();

    if (widget.initialError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackBarUtils.showError(context, widget.initialError!);
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for global authentication events
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.lastResponse != null &&
          next.lastResponse != previous?.lastResponse) {
        handleGlobalAuthEvents(previous?.lastResponse, next.lastResponse!);
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ColorUtils.darkBlue, const Color(0xFF002171)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: buildCurrentAuthStep(authState),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extracted widget: password field with its own visibility-toggle state.
//
// Why: the parent screen (_LoginScreenState) used setState() to flip
// _obscurePassword, which rebuilt the entire login form — including the email
// field, the logo, the server-status banner, and the login button — just to
// swap one icon. Keeping the toggle state here means only this widget
// rebuilds on every eye-icon tap.
// ---------------------------------------------------------------------------

class _PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback? onSubmitted;

  const _PasswordTextField({
    required this.controller,
    required this.isLoading,
    this.onSubmitted,
  });

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
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
