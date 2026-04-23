import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
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

  /// Shows edit profile dialog.
  Future<void> showEditProfileDialog() async {
    final nameController = TextEditingController(text: profileData['name']);
    final phoneController = TextEditingController(
      text: profileData['phone_number'],
    );
    final addressController = TextEditingController(
      text: profileData['address'],
    );

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(),
              _buildDialogFormFields(
                nameController,
                phoneController,
                addressController,
              ),
              _buildDialogFooter(
                nameController,
                phoneController,
                addressController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds dialog header.
  Widget _buildDialogHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
      ),
      child: Row(
        children: [
          _buildHeaderIcon(),
          const SizedBox(width: 14),
          Expanded(child: _buildHeaderText()),
        ],
      ),
    );
  }

  /// Builds header icon container.
  Widget _buildHeaderIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
    );
  }

  /// Builds header text content.
  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.read(languageRiverpod).getTranslatedText({
            'en': 'Edit Profile',
            'id': 'Edit Profil',
          }),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Perbarui informasi profil Anda',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  /// Builds dialog form fields.
  Widget _buildDialogFormFields(
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController addressController,
  ) {
    final lang = ref.read(languageRiverpod);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
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
      ),
    );
  }

  /// Builds dialog footer.
  Widget _buildDialogFooter(
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController addressController,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Expanded(child: _buildCancelButton()),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildSaveButton(
                nameController,
                phoneController,
                addressController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds cancel button.
  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: () => AppNavigator.pop(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: ColorUtils.slate300),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: Text(
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Cancel',
          'id': 'Batal',
        }),
        style: TextStyle(color: ColorUtils.slate600),
      ),
    );
  }

  /// Builds save button.
  Widget _buildSaveButton(
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController addressController,
  ) {
    return ElevatedButton(
      onPressed: () => _handleProfileUpdate(
        nameController,
        phoneController,
        addressController,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        elevation: 0,
      ),
      child: Text(
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Save',
          'id': 'Simpan',
        }),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
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
    final msg = lang.getTranslatedText({
      'en': 'Profile updated successfully',
      'id': 'Profil berhasil diperbarui',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ColorUtils.success600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows error snackbar.
  void _showErrorSnackBar(dynamic error) {
    final lang = ref.read(languageRiverpod);
    final msg = lang.getTranslatedText({
      'en': 'Failed to update profile',
      'id': 'Gagal memperbarui profil',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$msg: ${ErrorUtils.getFriendlyMessage(error)}'),
        backgroundColor: ColorUtils.error600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows change password dialog.
  void showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ChangePasswordDialog(primaryColor: primaryColor),
    );
  }
}
