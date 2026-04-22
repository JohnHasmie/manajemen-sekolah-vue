import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin for card builders in SettingsScreen.
mixin SettingsScreenCardsMixin {
  // Abstract properties
  Map<String, dynamic> get profileData;
  Color get primaryColor;
  WidgetRef get ref;
  Widget buildInfoRow(String label, String value, IconData icon);
  Widget buildSectionCard({
    required IconData sectionIcon,
    required String sectionTitle,
    required List<Widget> children,
  });

  /// Builds personal information section card.
  Widget buildPersonalInfoCard() {
    final lang = ref.read(languageRiverpod);
    return buildSectionCard(
      sectionIcon: Icons.person_outline_rounded,
      sectionTitle: lang.getTranslatedText({
        'en': 'Personal Information',
        'id': 'Informasi Pribadi',
      }),
      children: [
        buildInfoRow(
          lang.getTranslatedText({'en': 'Full Name', 'id': 'Nama Lengkap'}),
          profileData['name'] ?? '',
          Icons.person_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        buildInfoRow('Email', profileData['email'] ?? '', Icons.email_rounded),
        const SizedBox(height: AppSpacing.md),
        buildInfoRow(
          'No. Telepon',
          profileData['phone_number'] ?? '',
          Icons.phone_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        buildInfoRow(
          'Alamat',
          profileData['address'] ?? '',
          Icons.location_on_rounded,
        ),
      ],
    );
  }

  /// Builds account information section card.
  Widget buildAccountInfoCard(String role) {
    final lang = ref.read(languageRiverpod);
    return buildSectionCard(
      sectionIcon: Icons.manage_accounts_rounded,
      sectionTitle: lang.getTranslatedText({
        'en': 'Account Information',
        'id': 'Informasi Akun',
      }),
      children: [
        buildInfoRow(
          lang.getTranslatedText({'en': 'Role', 'id': 'Peran'}),
          role,
          Icons.badge_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        buildInfoRow(
          lang.getTranslatedText({'en': 'School', 'id': 'Sekolah'}),
          profileData['school_name'] ?? '',
          Icons.school_rounded,
        ),
      ],
    );
  }

  /// Builds change password button.
  Widget buildChangePasswordButton(VoidCallback onPressed) {
    final lang = ref.watch(languageRiverpod);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.lock_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          lang.getTranslatedText({
            'en': 'Change Password',
            'id': 'Ubah Kata Sandi',
          }),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
