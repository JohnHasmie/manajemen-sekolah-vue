// Bottom sheet for changing the user's password. Extracted from
// settings_screen.dart.
// Migrated from hand-rolled Dialog → brand [AppBottomSheet] +
// [BottomSheetFooter]
// so the header gradient, drag handle, and Samsung-safe footer come for free.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  final Color primaryColor;
  const ChangePasswordDialog({super.key, required this.primaryColor});

  @override
  ChangePasswordDialogState createState() => ChangePasswordDialogState();
}

class ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await getIt<ApiSettingsService>().updatePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;
      AppNavigator.pop(context);
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Password changed successfully',
          'id': 'Kata sandi berhasil diubah',
        }),
      );
    } catch (e) {
      AppLogger.error('settings', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Failed to change password', 'id': 'Gagal mengubah kata sandi'})}: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator:
          validator ??
          (val) => val == null || val.isEmpty
              ? ref.read(languageRiverpod).getTranslatedText({
                  'en': 'This field is required',
                  'id': 'Field ini harus diisi',
                })
              : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: widget.primaryColor,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.error600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.error600, width: 1.5),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: ColorUtils.slate500,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.read(languageRiverpod);
    return AppBottomSheet(
      title: lang.getTranslatedText({
        'en': 'Change Password',
        'id': 'Ubah Kata Sandi',
      }),
      subtitle: 'Masukkan kata sandi baru Anda',
      icon: Icons.lock_rounded,
      primaryColor: widget.primaryColor,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField(
              controller: _oldPasswordController,
              label: lang.getTranslatedText({
                'en': 'Old Password',
                'id': 'Kata Sandi Lama',
              }),
              obscure: _obscureOld,
              onToggle: () => setState(() => _obscureOld = !_obscureOld),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildPasswordField(
              controller: _newPasswordController,
              label: lang.getTranslatedText({
                'en': 'New Password',
                'id': 'Kata Sandi Baru',
              }),
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: _newPasswordValidator,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: lang.getTranslatedText({
                'en': 'Confirm Password',
                'id': 'Konfirmasi Kata Sandi',
              }),
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (val) {
                if (val != _newPasswordController.text) {
                  return lang.getTranslatedText({
                    'en': 'Passwords do not match',
                    'id': 'Kata sandi tidak cocok',
                  });
                }
                return null;
              },
            ),
          ],
        ),
      ),
      footer: BottomSheetFooter(
        primaryLabel: _isLoading
            ? lang.getTranslatedText({'en': 'Saving...', 'id': 'Menyimpan...'})
            : lang.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
        secondaryLabel: lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
        primaryColor: widget.primaryColor,
        primaryEnabled: !_isLoading,
        onPrimary: _updatePassword,
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }

  /// Validates a new password against the password policy rules.
  String? _newPasswordValidator(String? val) {
    final lang = ref.read(languageRiverpod);
    if (val == null || val.isEmpty) {
      return lang.getTranslatedText({
        'en': 'This field is required',
        'id': 'Field ini harus diisi',
      });
    }
    if (val.length < 8) {
      return lang.getTranslatedText({
        'en': 'Password must be at least 8 characters',
        'id': 'Kata sandi harus minimal 8 karakter',
      });
    }
    if (!val.contains(RegExp(r'[a-z]')) || !val.contains(RegExp(r'[A-Z]'))) {
      return lang.getTranslatedText({
        'en': 'Password must contain uppercase and lowercase letters',
        'id': 'Kata sandi harus mengandung huruf besar dan kecil',
      });
    }
    if (!val.contains(RegExp(r'[0-9]'))) {
      return lang.getTranslatedText({
        'en': 'Password must contain at least one number',
        'id': 'Kata sandi harus mengandung minimal satu angka',
      });
    }
    if (!val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return lang.getTranslatedText({
        'en': 'Password must contain at least one special character',
        'id': 'Kata sandi harus mengandung minimal satu karakter khusus',
      });
    }
    return null;
  }
}
