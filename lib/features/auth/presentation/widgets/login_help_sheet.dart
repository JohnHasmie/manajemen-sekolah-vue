// "Bantuan masuk" sheet — opened from the inline help row at the
// bottom of the login screen. Lets a user who cannot get into the
// app (forgot email, account never provisioned, password reset
// email never arrived) submit a help request to the school admin.
//
// POSTs to `/api/auth/help-request`. Backend persists an audit row in
// `login_help_requests` AND emails the configured support inbox. Each
// IP is throttled to 3 requests per minute on the route.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';

/// Static helper — opens the Bantuan Masuk sheet seeded with whatever
/// the user already typed into the email field on the login screen.
/// Returns true on submit.
Future<bool> showLoginHelpSheet({
  required BuildContext context,
  String? initialEmail,
}) async {
  final result = await AppBottomSheet.show<bool>(
    context: context,
    title: kAutHelpTitle.tr,
    subtitle: kAutHelpSubtitle.tr,
    icon: Icons.help_outline_rounded,
    primaryColor: ColorUtils.brandCobalt,
    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    content: _LoginHelpSheetBody(initialEmail: initialEmail ?? ''),
  );
  return result ?? false;
}

class _LoginHelpSheetBody extends StatefulWidget {
  final String initialEmail;

  const _LoginHelpSheetBody({required this.initialEmail});

  @override
  State<_LoginHelpSheetBody> createState() => _LoginHelpSheetBodyState();
}

class _LoginHelpSheetBodyState extends State<_LoginHelpSheetBody> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _msgCtrl;
  bool _busy = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _phoneCtrl = TextEditingController();
    _schoolCtrl = TextEditingController();
    _msgCtrl = TextEditingController();
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _schoolCtrl,
      _msgCtrl,
    ]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _schoolCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final emailValid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+',
    ).hasMatch(_emailCtrl.text.trim());
    return _nameCtrl.text.trim().length >= 2 &&
        emailValid &&
        _msgCtrl.text.trim().length >= 10;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final result = await AuthService.helpRequest(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        schoolName: _schoolCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
      );
      if (!mounted) return;
      AppNavigator.pop(context, true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SnackBarUtils.showSuccess(
          context,
          (result['message']?.toString().trim().isNotEmpty == true
              ? result['message'].toString()
              : kAutHelpSuccess.tr),
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
          _field(
            label: kAutFullNameLabel.tr,
            required: true,
            controller: _nameCtrl,
            icon: Icons.person_rounded,
            hint: kAutNameHint.tr,
            cobalt: cobalt,
          ),
          const SizedBox(height: 12),
          _field(
            label: kAutActiveEmail.tr,
            required: true,
            controller: _emailCtrl,
            icon: Icons.alternate_email_rounded,
            hint: kAutEmailHint.tr,
            keyboardType: TextInputType.emailAddress,
            cobalt: cobalt,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  label: kAutWhatsAppNumber.tr,
                  required: false,
                  controller: _phoneCtrl,
                  icon: Icons.phone_rounded,
                  hint: kAutPhoneHint.tr,
                  keyboardType: TextInputType.phone,
                  cobalt: cobalt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  label: kAutSchoolLabel.tr,
                  required: false,
                  controller: _schoolCtrl,
                  icon: Icons.school_rounded,
                  hint: kAutSchoolHint.tr,
                  cobalt: cobalt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label(
            kAutMessageLabel.tr,
            required: true,
            helper: kAutMinCharacters.tr,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _msgCtrl,
            maxLines: 4,
            minLines: 3,
            style: TextStyle(fontSize: 12.5, color: ColorUtils.slate900),
            decoration: InputDecoration(
              hintText: kAutMessageHint.tr,
              hintStyle: TextStyle(fontSize: 12.5, color: ColorUtils.slate400),
              filled: true,
              fillColor: ColorUtils.slate50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ColorUtils.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ColorUtils.slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cobalt, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ColorUtils.error600.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: ColorUtils.error600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.error600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          BottomSheetFooter(
            primaryLabel: _busy ? kAutSending.tr : kAutSendRequest.tr,
            secondaryLabel: kCancel.tr,
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

  Widget _field({
    required String label,
    required bool required,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Color cobalt,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
            prefixIcon: Icon(icon, size: 16, color: ColorUtils.slate500),
            filled: true,
            fillColor: ColorUtils.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cobalt, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = false, String? helper}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate700,
              letterSpacing: 0.4,
            ),
          ),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: ColorUtils.error600,
              ),
            ),
          if (helper != null)
            TextSpan(
              text: ' $helper',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate400,
                letterSpacing: 0.2,
              ),
            ),
        ],
      ),
    );
  }
}
