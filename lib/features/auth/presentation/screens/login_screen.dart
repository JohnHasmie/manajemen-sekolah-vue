import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialError;

  const LoginScreen({super.key, this.initialError});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkServerConnection();

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

  Future<void> _checkServerConnection() async {
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

  void _handleGlobalAuthEvents(AuthResponse? previous, AuthResponse current) {
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

  Future<void> _handleLogin() async {
    final authState = ref.read(authProvider);
    if (!authState.isServerConnected) {
      SnackBarUtils.showInfo(context, AppLocalizations.serverNotConnected.tr);
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;

    await ref.read(authProvider.notifier).login(email, password);
  }

  Future<void> _handleGoogleSignIn() async {
    final authState = ref.read(authProvider);
    if (!authState.isServerConnected) {
      SnackBarUtils.showInfo(context, AppLocalizations.serverNotConnected.tr);
      return;
    }

    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  Future<void> _handleOtpVerification() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      SnackBarUtils.showInfo(context, AppLocalizations.enterOtp.tr);
      return;
    }

    await ref.read(authProvider.notifier).verifyOtp(otp);
  }

  void _showUnregisteredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.person_off_outlined,
          color: ColorUtils.darkBlue,
          size: 48,
        ),
        title: Text(
          AppLocalizations.accountNotRegistered.tr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          AppLocalizations.accountNotRegisteredMsg.tr,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context),
            child: Text(AppLocalizations.understand.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for global authentication events
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.lastResponse != null &&
          next.lastResponse != previous?.lastResponse) {
        _handleGlobalAuthEvents(previous?.lastResponse, next.lastResponse!);
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
                physics: BouncingScrollPhysics(),
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
                        child: _buildCurrentAuthStep(authState),
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

  Widget _buildCurrentAuthStep(AuthState authState) {
    switch (authState.step) {
      case AuthStep.schoolSelection:
        return _buildSchoolSelection(authState);
      case AuthStep.roleSelection:
        return _buildRoleSelection(authState);
      case AuthStep.otpVerification:
        return _buildOtpForm(authState);
      case AuthStep.login:
        return _buildLoginForm(authState);
    }
  }

  Widget _buildOtpForm(AuthState authState) {
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
        Text(AppLocalizations.enterOtpDigits.tr),
        const SizedBox(height: AppSpacing.sm),
        TextField(
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
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: authState.isLoading ? null : _handleOtpVerification,
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
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
          child: Text(AppLocalizations.backToLogin.tr),
        ),
      ],
    );
  }

  Widget _buildSchoolSelection(AuthState authState) {
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        AppSpacing.v10,
        Text(
          '${AppLocalizations.hello.tr} ${authState.userData?['name'] ?? authState.userData?['nama'] ?? 'User'},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          AppLocalizations.selectSchoolMsg.tr,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        AppSpacing.v20,
        ListView.builder(
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
        ),
        AppSpacing.v20,
        TextButton(
          onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
          child: Text(AppLocalizations.backToLogin.tr),
        ),
      ],
    );
  }

  Widget _buildRoleSelection(AuthState authState) {
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        AppSpacing.v10,
        Text(
          '${AppLocalizations.hello.tr} ${authState.userData?['name'] ?? authState.userData?['nama'] ?? 'User'},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          '${AppLocalizations.schoolLabel.tr}: $schoolName',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        AppSpacing.v20,
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: authState.roleList.length,
          itemBuilder: (context, index) {
            final role = authState.roleList[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                key: ValueKey('role_$role'),
                leading: _getRoleIcon(role),
                title: Text(_getRoleDisplayName(role)),
                subtitle: Text(
                  '${AppLocalizations.accessAs.tr} ${_getRoleDescription(role)}',
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
        ),
        AppSpacing.v20,
        if (authState.schoolList.length > 1)
          TextButton(
            onPressed: () {
              // A small workaround: change state manually or write a method up
              ref
                  .read(authProvider.notifier)
                  .resetToLogin(); // or provide a backToSchool() method
            },
            child: Text(
              AppLocalizations.backToLogin.tr,
            ), // For now go back to login instead of rewriting full flow backtracking
          )
        else
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).resetToLogin(),
            child: Text(AppLocalizations.backToLogin.tr),
          ),
      ],
    );
  }

  Widget _buildLoginForm(AuthState authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icon/KamilEdu.png', height: 80),
        AppSpacing.v20,
        const Text(
          'Kamil Edu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        if (!authState.isServerConnected) ...[
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
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 30),
        AutofillGroup(
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
              // Extracted into its own StatefulWidget so toggling password
              // visibility only rebuilds this small field, not the entire screen.
              _PasswordTextField(
                controller: passwordController,
                isLoading: authState.isLoading,
                onSubmitted: () {
                  if (emailController.text.trim().isNotEmpty &&
                      passwordController.text.isNotEmpty) {
                    _handleLogin();
                  }
                },
              ),
            ],
          ),
        ),
        AppSpacing.v20,
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('login_button'),
            onPressed: (authState.isServerConnected && !authState.isLoading)
                ? _handleLogin
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: ColorUtils.darkBlue,
              disabledBackgroundColor: ColorUtils.darkBlue.withValues(
                alpha: 0.6,
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
                    AppLocalizations.login.tr.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (authState.isServerConnected && !authState.isLoading)
                ? _handleGoogleSignIn
                : null,
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
        ),
      ],
    );
  }

  Widget _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings, color: ColorUtils.darkBlue);
      case 'guru':
        return Icon(Icons.school, color: Colors.green);
      case 'wali':
        return Icon(Icons.family_restroom, color: Colors.purple);
      case 'staff':
        return Icon(Icons.work, color: Colors.orange);
      default:
        return Icon(Icons.person, color: Colors.grey);
    }
  }

  String _getRoleDisplayName(String role) {
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
        if (role.isNotEmpty) return role[0].toUpperCase() + role.substring(1);
        return role;
    }
  }

  String _getRoleDescription(String role) {
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
