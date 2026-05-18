// Login screen scaffold — implements Frame A of
// `_design/auth_login_school_role_redesign.html`.
//
// The screen owns the outer chrome (brand-gradient hero band with the
// KamilEdu logo + wordmark + tagline, and the form-card that overlaps
// the gradient at -24px). The body of the form-card is whichever auth
// step is active — login form, OTP, school picker, role picker — and
// is dispatched via `buildCurrentAuthStep()` from AuthFormBuilderMixin.
//
// "Ingat saya" was intentionally removed — Sanctum tokens persist by
// default, so the checkbox added confusion without changing behaviour.
// The "Hubungi admin" link in the footer launches a WhatsApp deep link
// (`https://wa.me/6285179819002`) via url_launcher.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
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

    // The login step gets the full hero band (logo + tagline). Other
    // steps (OTP, school, role) compress the band to a logo lockup so
    // more vertical space is available for the picker list.
    final isLoginStep = authState.step == AuthStep.login;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrandBand(compact: !isLoginStep),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _FormCard(child: buildCurrentAuthStep(authState)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Brand-gradient hero band ──────────────────────────────────────

class _BrandBand extends StatelessWidget {
  final bool compact;

  const _BrandBand({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        compact ? 18 : 28,
        24,
        compact ? 36 : 56,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.brandDarkBlue,
            ColorUtils.brandCobalt,
            ColorUtils.brandAzure,
          ],
          stops: const [0.0, 0.6, 1.1],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          if (!compact) ...[
            // Full logo lockup: 76dp white card holding the
            // KamilEdu mortarboard + tassel mark, then the wordmark
            // and tagline below.
            const _LogoMark(size: 76, lifted: true),
            const SizedBox(height: 14),
            const _Wordmark(fontSize: 24, accentOpacity: .86),
            const SizedBox(height: 8),
            Text(
              'Platform Manajemen Sekolah Terpadu',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.86),
                letterSpacing: 0.2,
              ),
            ),
          ] else ...[
            // Compact lockup for the school/role/otp steps — the
            // mark + wordmark inline, no tagline. Saves ~80dp of
            // vertical space so the picker list has more room.
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoMark(size: 28, lifted: false),
                SizedBox(width: 10),
                _Wordmark(fontSize: 18, accentOpacity: .86),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// White rounded card holding the mortarboard logo. Uses the existing
/// `assets/icon/KamilEdu.png` asset so we don't duplicate the brand
/// across SVG/PNG variants. The "lifted" variant sits in a white
/// rounded square so the navy mark contrasts against the gradient
/// behind it; the inline variant in the compact band is transparent
/// because the wordmark sits beside it on the same gradient.
class _LogoMark extends StatelessWidget {
  final double size;
  final bool lifted;

  const _LogoMark({required this.size, required this.lifted});

  @override
  Widget build(BuildContext context) {
    final inner = Image.asset(
      'assets/icon/KamilEdu.png',
      height: size * 0.62,
      fit: BoxFit.contain,
      errorBuilder: (c, o, s) => Icon(
        Icons.school_rounded,
        size: size * 0.6,
        color: lifted ? ColorUtils.brandDarkBlue : Colors.white,
      ),
    );
    if (!lifted) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: inner),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: inner),
    );
  }
}

class _Wordmark extends StatelessWidget {
  final double fontSize;
  final double accentOpacity;

  const _Wordmark({required this.fontSize, required this.accentOpacity});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Kamil',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          TextSpan(
            text: 'Edu',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: accentOpacity),
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form card (overlaps the brand band by 24dp) ───────────────────

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: child,
    );
  }
}
