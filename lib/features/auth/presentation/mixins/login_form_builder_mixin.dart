// Frame A / B from `_design/auth_login_school_role_redesign.html`.
//
// The mixin is consumed by [LoginScreen] and renders the login form
// content that lives INSIDE the form-card. The outer brand-gradient
// hero band + form-card overlap chrome live on the screen itself
// (login_screen.dart), so this mixin owns just:
//   • the `Selamat Datang Kembali` heading + subtitle
//   • the email field (with leading icon)
//   • the password field (with leading icon + visibility toggle)
//   • a server-not-connected banner when applicable
//   • the right-aligned `Lupa kata sandi?` link → ForgotPasswordSheet
//   • the cobalt-gradient Masuk CTA
//   • the OR divider
//   • the Google CTA wired to `handleGoogleSignIn`
//   • the "Bantuan masuk" help row → LoginHelpSheet
//   • the "Hubungi admin" footer link → WhatsApp deep-link
//
// "Ingat saya" is intentionally removed — Sanctum tokens persist by
// default; the checkbox added confusion without changing behaviour.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';
import 'package:manajemensekolah/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:manajemensekolah/features/auth/presentation/widgets/login_help_sheet.dart';

/// WhatsApp deep-link target for "Hubungi admin". Per CLAUDE.md the
/// number is the school's main support line; we keep it as a const so
/// it's easy to swap if the number ever changes.
const String _kAdminWhatsAppUrl = 'https://wa.me/6285179819002';

mixin LoginFormBuilderMixin on ConsumerState<LoginScreen> {
  /// Public entry point — composes the form card body. The hero band
  /// + form-card overlap is set up by the screen itself; this method
  /// just emits the fields and CTAs.
  Widget buildLoginForm(AuthState authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selamat Datang Kembali',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: ColorUtils.slate900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Masuk untuk melanjutkan ke akun sekolah Anda.',
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        if (!authState.isServerConnected) ...[
          const SizedBox(height: 12),
          _buildServerWarning(),
        ],
        const SizedBox(height: 14),
        _buildEmailField(authState),
        const SizedBox(height: 12),
        _buildPasswordField(authState),
        _buildForgotPasswordRow(),
        const SizedBox(height: 8),
        _buildLoginButton(authState),
        const SizedBox(height: 14),
        _buildOrDivider(),
        const SizedBox(height: 10),
        _buildGoogleSignInButton(authState),
        const SizedBox(height: 12),
        _buildHelpRow(),
        const SizedBox(height: 12),
        _buildContactAdminFooter(),
      ],
    );
  }

  // ─── Email / Password ────────────────────────────────────────────

  Widget _buildEmailField(AuthState authState) {
    return _FieldShell(
      labelText: 'Email',
      required: true,
      child: TextField(
        key: const Key('email_field'),
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
        decoration: _inputDecoration(
          hint: 'anda@sekolah.id',
          prefixIcon: Icons.alternate_email_rounded,
        ),
      ),
    );
  }

  Widget _buildPasswordField(AuthState authState) {
    return _FieldShell(
      labelText: 'Kata Sandi',
      required: true,
      child: _PasswordTextFieldWidget(
        controller: passwordController,
        isLoading: authState.isLoading,
        onSubmitted: () {
          if (emailController.text.trim().isNotEmpty &&
              passwordController.text.isNotEmpty) {
            handleLogin();
          }
        },
      ),
    );
  }

  Widget _buildForgotPasswordRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _openForgotPassword,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              '${AppLocalizations.forgotPassword.tr}?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandCobalt,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    await showForgotPasswordSheet(
      context: context,
      initialEmail: emailController.text.trim(),
    );
  }

  // ─── CTAs ────────────────────────────────────────────────────────

  Widget _buildLoginButton(AuthState authState) {
    final enabled = authState.isServerConnected && !authState.isLoading;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ColorUtils.brandDarkBlue, ColorUtils.brandCobalt],
                )
              : LinearGradient(
                  colors: [ColorUtils.slate300, ColorUtils.slate300],
                ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ColorUtils.brandDarkBlue.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          key: const Key('login_button'),
          onPressed: enabled ? handleLogin : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.transparent,
          ),
          child: authState.isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Memverifikasi...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.login.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: ColorUtils.slate200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'atau lanjutkan dengan',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate400,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: ColorUtils.slate200)),
      ],
    );
  }

  Widget _buildGoogleSignInButton(AuthState authState) {
    final enabled = authState.isServerConnected && !authState.isLoading;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? handleGoogleSignIn : null,
        icon: Image.asset(
          'assets/icon/google_logo.png',
          height: 18,
          width: 18,
          errorBuilder: (c, o, s) =>
              Icon(Icons.g_mobiledata_rounded, color: ColorUtils.slate800),
        ),
        label: Text(
          authState.isLoading
              ? AppLocalizations.pleaseWait.tr
              : 'Masuk dengan Google',
          style: TextStyle(
            color: enabled ? ColorUtils.slate800 : ColorUtils.slate400,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: enabled ? ColorUtils.slate200 : ColorUtils.slate100,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ─── Helpers row + footer ────────────────────────────────────────

  Widget _buildHelpRow() {
    return Center(
      child: GestureDetector(
        onTap: _openLoginHelp,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 13,
                color: ColorUtils.slate500,
              ),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate600,
                  ),
                  children: [
                    const TextSpan(text: 'Butuh bantuan? '),
                    TextSpan(
                      text: 'Bantuan masuk',
                      style: TextStyle(
                        color: ColorUtils.brandCobalt,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLoginHelp() async {
    await showLoginHelpSheet(
      context: context,
      initialEmail: emailController.text.trim(),
    );
  }

  Widget _buildContactAdminFooter() {
    return Center(
      child: GestureDetector(
        onTap: _launchAdminWhatsApp,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
              children: [
                const TextSpan(text: 'Belum punya akun sekolah? '),
                TextSpan(
                  text: 'Hubungi admin',
                  style: TextStyle(
                    color: ColorUtils.brandCobalt,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Launch the school-admin WhatsApp number. We try the platform's
  /// preferred handler first (which on iOS / Android opens the WA
  /// app directly when installed), then fall back to in-app browser.
  /// If neither succeeds we surface a polite snackbar so the user
  /// knows what number to copy manually.
  Future<void> _launchAdminWhatsApp() async {
    final uri = Uri.parse(_kAdminWhatsAppUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        SnackBarUtils.showError(
          context,
          'Tidak dapat membuka WhatsApp. Hubungi admin di +62 851-7981-9002.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Tidak dapat membuka WhatsApp. Hubungi admin di +62 851-7981-9002.',
      );
    }
  }

  // ─── Server-status banner ────────────────────────────────────────

  Widget _buildServerWarning() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorUtils.error600.withValues(alpha: 0.06),
        border: Border.all(color: ColorUtils.error600.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, size: 16, color: ColorUtils.error600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.serverNotConnected.tr,
              style: TextStyle(
                color: ColorUtils.error600,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Decorations ────────────────────────────────────────────────

  static InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: ColorUtils.slate400,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(prefixIcon, size: 16, color: ColorUtils.slate500),
      suffixIcon: suffix,
      filled: true,
      fillColor: ColorUtils.slate50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ColorUtils.slate200, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ColorUtils.slate200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ColorUtils.brandCobalt, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );
  }

  // Mixin contract — implemented by the screen.
  TextEditingController get emailController;
  TextEditingController get passwordController;
  Future<void> handleLogin();
  Future<void> handleGoogleSignIn();
}

// ─── Internal helpers ────────────────────────────────────────────

/// Wraps a labeled field in a column with the same uppercase 11px
/// label + 6px gap pattern the rest of the auth surfaces use. Keeps
/// the form tidy without copy-pasting the label widget every time.
class _FieldShell extends StatelessWidget {
  final String labelText;
  final bool required;
  final Widget child;

  const _FieldShell({
    required this.labelText,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: labelText.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate700,
                  letterSpacing: 0.4,
                ),
              ),
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.error600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Password text field with its own visibility toggle state. Lives in
/// a separate widget so flipping the toggle doesn't rebuild the entire
/// login form (the email field, the gradient header, the server-status
/// banner, etc.).
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
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: widget.isLoading ? null : (_) => widget.onSubmitted?.call(),
      style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
      decoration: LoginFormBuilderMixin._inputDecoration(
        hint: 'Masukkan kata sandi',
        prefixIcon: Icons.lock_outline_rounded,
        suffix: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: ColorUtils.slate500,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
