// Dialog for changing the user's password. Extracted from settings_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
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
        ref
            .read(languageRiverpod)
            .getTranslatedText(AppLocalizations.passwordChangedSuccess),
      );
    } catch (e) {
      AppLogger.error('settings', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${ref.read(languageRiverpod).getTranslatedText(AppLocalizations.failedToChangePassword)}: ${ErrorUtils.getFriendlyMessage(e)}',
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
              ? ref
                    .read(languageRiverpod)
                    .getTranslatedText(AppLocalizations.required)
              : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: widget.primaryColor,
          size: 20,
        ),
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
          borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.error600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.error600, width: 1.5),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient Header (Pattern #10)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.primaryColor,
                    widget.primaryColor.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref
                              .read(languageRiverpod)
                              .getTranslatedText(
                                AppLocalizations.changePassword,
                              ),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Masukkan kata sandi baru Anda',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Fields
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildPasswordField(
                      controller: _oldPasswordController,
                      label: ref
                          .read(languageRiverpod)
                          .getTranslatedText(AppLocalizations.oldPassword),
                      obscure: _obscureOld,
                      onToggle: () =>
                          setState(() => _obscureOld = !_obscureOld),
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: ref
                          .read(languageRiverpod)
                          .getTranslatedText(AppLocalizations.newPassword),
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: (val) {
                        final lang = ref.read(languageRiverpod);
                        if (val == null || val.isEmpty) {
                          return lang.getTranslatedText(
                            AppLocalizations.required,
                          );
                        }
                        if (val.length < 8) {
                          return lang.getTranslatedText(
                            AppLocalizations.passwordMinLength,
                          );
                        }
                        if (!val.contains(RegExp(r'[a-z]')) ||
                            !val.contains(RegExp(r'[A-Z]'))) {
                          return lang.getTranslatedText(
                            AppLocalizations.passwordLetters,
                          );
                        }
                        if (!val.contains(RegExp(r'[0-9]'))) {
                          return lang.getTranslatedText(
                            AppLocalizations.passwordNumbers,
                          );
                        }
                        if (!val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                          return lang.getTranslatedText(
                            AppLocalizations.passwordSymbols,
                          );
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: ref
                          .read(languageRiverpod)
                          .getTranslatedText(AppLocalizations.confirmPassword),
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (val) {
                        if (val != _newPasswordController.text) {
                          return ref
                              .read(languageRiverpod)
                              .getTranslatedText(
                                AppLocalizations.passwordMismatch,
                              );
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ColorUtils.slate100)),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          ref
                              .read(languageRiverpod)
                              .getTranslatedText(AppLocalizations.cancel),
                          style: TextStyle(color: ColorUtils.slate600),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                ref
                                    .read(languageRiverpod)
                                    .getTranslatedText(AppLocalizations.save),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
