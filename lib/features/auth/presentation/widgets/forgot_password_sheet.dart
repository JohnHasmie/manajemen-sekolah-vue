// Frame C from `_design/auth_login_school_role_redesign.html` —
// "Lupa Kata Sandi?" sheet shown when the user taps the right-aligned
// link on the login screen.
//
// Built on AppBottomSheet + BottomSheetFooter so the chrome (gradient
// header, drag handle, sticky safe-area footer) matches every other
// sheet in the app. POSTs to `/api/auth/forgot-password` (the new
// endpoint we added on AuthController). Server uses Laravel's
// `Password::sendResetLink` broker, persists a token to the existing
// `password_reset_tokens` table, and dispatches the reset notification
// via the configured mail channel — we just feed it the email and
// surface a neutral success message so the endpoint can't be used to
// enumerate registered users.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';

/// Static helper — opens the forgot-password sheet seeded with the
/// already-typed email (if any) and returns `true` when the parent
/// successfully submitted. The login screen uses the bool only to
/// optionally focus the password field afterwards; nothing else.
Future<bool> showForgotPasswordSheet({
  required BuildContext context,
  String? initialEmail,
}) async {
  final result = await AppBottomSheet.show<bool>(
    context: context,
    title: 'Lupa Kata Sandi',
    subtitle: 'Kami akan mengirim tautan reset ke email Anda.',
    icon: Icons.lock_reset_rounded,
    primaryColor: ColorUtils.brandCobalt,
    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    content: _ForgotPasswordSheetBody(initialEmail: initialEmail ?? ''),
  );
  return result ?? false;
}

class _ForgotPasswordSheetBody extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordSheetBody({required this.initialEmail});

  @override
  State<_ForgotPasswordSheetBody> createState() =>
      _ForgotPasswordSheetBodyState();
}

class _ForgotPasswordSheetBodyState extends State<_ForgotPasswordSheetBody> {
  late final TextEditingController _emailCtrl;
  bool _busy = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _emailCtrl.addListener(() {
      if (_inlineError != null) {
        setState(() => _inlineError = null);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(v);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_canSubmit) {
      setState(() => _inlineError = 'Format email tidak valid.');
      return;
    }
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final result = await AuthService.forgotPassword(email);
      if (!mounted) return;
      AppNavigator.pop(context, true);
      // Show the neutral message AFTER popping so the snackbar lands
      // on the login screen rather than dismissing with the sheet.
      // Defer one frame so the parent has rebuilt.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackBarUtils.showSuccess(
          context,
          (result['message']?.toString().trim().isNotEmpty == true
              ? result['message'].toString()
              : 'Jika email terdaftar, tautan reset akan dikirim. Periksa kotak masuk Anda.'),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Email Terdaftar', required: true),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _canSubmit ? _submit() : null,
            style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
            decoration: InputDecoration(
              hintText: 'anda@sekolah.id',
              hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                size: 18,
                color: _inlineError == null ? cobalt : ColorUtils.error600,
              ),
              filled: true,
              fillColor: _inlineError == null
                  ? ColorUtils.slate50
                  : ColorUtils.error600.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _inlineError == null
                      ? ColorUtils.slate200
                      : ColorUtils.error600,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _inlineError == null
                      ? ColorUtils.slate200
                      : ColorUtils.error600,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cobalt, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 12,
                  color: ColorUtils.error600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _inlineError!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.error600,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Tautan akan kedaluwarsa setelah 30 menit.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Azure info banner — soft reminder that the link goes to email.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorUtils.brandAzure.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColorUtils.brandAzure.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: ColorUtils.brandAzureDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jika Anda tidak menerima email dalam 5 menit, periksa folder spam atau hubungi admin sekolah.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BottomSheetFooter(
            primaryLabel: _busy ? 'Mengirim…' : 'Kirim Tautan',
            secondaryLabel: 'Batal',
            primaryColor: cobalt,
            primaryEnabled: _canSubmit && !_busy,
            onPrimary: () {
              if (_canSubmit && !_busy) _submit();
            },
            onSecondary: () => AppNavigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.toUpperCase(),
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
    );
  }
}
