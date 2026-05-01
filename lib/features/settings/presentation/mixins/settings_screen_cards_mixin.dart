import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
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
  /// Renamed to "Akun & Akses" per Phase-4 mockup so the section
  /// title matches the role/school switching surface in the
  /// dashboard account sheet. Content is the same Peran + Sekolah
  /// pair — actual switching still happens from the dashboard
  /// person-icon sheet (linked from "Lihat Profil Lengkap").
  Widget buildAccountInfoCard(String role) {
    final lang = ref.read(languageRiverpod);
    return buildSectionCard(
      sectionIcon: Icons.manage_accounts_rounded,
      sectionTitle: lang.getTranslatedText({
        'en': 'Account & Access',
        'id': 'Akun & Akses',
      }),
      children: [
        buildInfoRow(
          lang.getTranslatedText({'en': 'Active role', 'id': 'Peran aktif'}),
          role,
          Icons.badge_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        buildInfoRow(
          lang.getTranslatedText({'en': 'Active school', 'id': 'Sekolah aktif'}),
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

  /// Builds the danger-coloured "Keluar Akun" button shown at the
  /// bottom of the redesigned profile page (Phase-4 surface 1).
  /// Calls `TokenService().logout()` then routes to /login — same
  /// flow used by the dashboard account sheet so behaviour stays
  /// in sync.
  Widget buildLogoutButton(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await TokenService().logout();
          if (context.mounted) appRouter.go('/login');
        },
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 18,
                color: Colors.red.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                lang.getTranslatedText({
                  'en': 'Sign out',
                  'id': 'Keluar Akun',
                }),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
