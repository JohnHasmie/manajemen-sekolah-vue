import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/change_password_dialog.dart';

/// Mixin for dialog methods in SettingsScreen.
mixin SettingsScreenDialogsMixin {
  static const String _profileCacheKey = 'settings_profile';

  // Abstract - must be implemented
  Map<String, dynamic> get profileData;
  Color get primaryColor;
  Future<void> loadProfile({bool useCache});
  BuildContext get context;
  WidgetRef get ref;
  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines,
    TextInputType keyboardType,
  });

  /// Shows edit profile bottom sheet — uses brand [AppBottomSheet] chrome
  /// (gradient header + drag handle + Samsung-safe footer) so the profile
  /// edit flow stays consistent with the rest of the settings screen.
  Future<void> showEditProfileDialog() async {
    final nameController = TextEditingController(text: profileData['name']);
    final phoneController = TextEditingController(
      text: profileData['phone_number'],
    );
    final addressController = TextEditingController(
      text: profileData['address'],
    );
    final lang = ref.read(languageRiverpod);

    await AppBottomSheet.show<void>(
      context: context,
      title: lang.getTranslatedText({
        'en': 'Edit Profile',
        'id': 'Edit Profil',
      }),
      subtitle: 'Perbarui informasi profil Anda',
      icon: Icons.person_rounded,
      primaryColor: primaryColor,
      content: _buildProfileFormFields(
        nameController,
        phoneController,
        addressController,
      ),
      footer: BottomSheetFooter(
        primaryLabel: lang.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
        secondaryLabel: lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
        primaryColor: primaryColor,
        onPrimary: () => _handleProfileUpdate(
          nameController,
          phoneController,
          addressController,
        ),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }

  /// Builds profile form fields for the edit-profile sheet.
  Widget _buildProfileFormFields(
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController addressController,
  ) {
    final lang = ref.read(languageRiverpod);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDialogTextField(
          controller: nameController,
          label: lang.getTranslatedText({
            'en': 'Full Name',
            'id': 'Nama Lengkap',
          }),
          icon: Icons.person_outline_rounded,
          maxLines: 1,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: AppSpacing.md),
        buildDialogTextField(
          controller: phoneController,
          label: lang.getTranslatedText({
            'en': 'Phone Number',
            'id': 'Nomor Telepon',
          }),
          icon: Icons.phone_outlined,
          maxLines: 1,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        buildDialogTextField(
          controller: addressController,
          label: lang.getTranslatedText({'en': 'Address', 'id': 'Alamat'}),
          icon: Icons.location_on_outlined,
          maxLines: 2,
          keyboardType: TextInputType.text,
        ),
      ],
    );
  }

  /// Handles profile update.
  Future<void> _handleProfileUpdate(
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController addressController,
  ) async {
    try {
      await getIt<ApiSettingsService>().updateProfile(
        name: nameController.text,
        phoneNumber: phoneController.text,
        address: addressController.text,
      );
      await LocalCacheService.invalidate(_profileCacheKey);
      if (!context.mounted) return;
      AppNavigator.pop(context);
      await loadProfile(useCache: false);
      _showSuccessSnackBar();
    } catch (e) {
      AppLogger.error('settings', e);
      if (context.mounted) {
        _showErrorSnackBar(e);
      }
    }
  }

  /// Shows success snackbar.
  void _showSuccessSnackBar() {
    final lang = ref.read(languageRiverpod);
    SnackBarUtils.showSuccess(
      context,
      lang.getTranslatedText({
        'en': 'Profile updated successfully',
        'id': 'Profil berhasil diperbarui',
      }),
    );
  }

  /// Shows error snackbar.
  void _showErrorSnackBar(dynamic error) {
    final lang = ref.read(languageRiverpod);
    final msg = lang.getTranslatedText({
      'en': 'Failed to update profile',
      'id': 'Gagal memperbarui profil',
    });
    SnackBarUtils.showError(
      context,
      '$msg: ${ErrorUtils.getFriendlyMessage(error)}',
    );
  }

  /// Shows change password bottom sheet — see [ChangePasswordDialog] which
  /// renders an [AppBottomSheet] with the brand gradient header.
  void showChangePasswordDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangePasswordDialog(primaryColor: primaryColor),
    );
  }
}
