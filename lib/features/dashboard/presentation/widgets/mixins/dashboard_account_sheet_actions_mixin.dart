import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/account/presentation/screens/'
    'profile_screen.dart';

/// Mixin for action rows on the account sheet — currently the
/// "Lihat Profil" tile and the Logout button.
///
/// History
/// -------
/// This mixin used to render three more actions:
///   • `buildSwitchSchoolButton` — the school switcher row
///   • `buildSettingsButton`     — a separate Settings shortcut
///   • `buildSchoolSettingsSection` — the wrapper around them
///
/// All three were superseded in Phase-4 (Surface 3 — account sheet
/// redesign):
///   • Sekolah aktif now shows up as an `_AccessRow` inside the
///     account sheet body, not a separate button
///   • Settings was folded into the new `Lihat Profil` page
///   • The wrapper became dead with the buttons
///
/// What survives is [buildLihatProfilTile] (one tile) and
/// [buildLogoutButton] (Logout). The mixin abstracts were trimmed
/// to just what those two methods read.
mixin DashboardAccountSheetActionsMixin {
  /// True iff the host is still mounted — guards async setState
  /// calls in [buildLogoutButton].
  bool get isMounted;

  /// Notifier flipped while the logout request is in flight. The
  /// button greys itself out and shows a spinner while non-null.
  ValueNotifier<bool> get isLoggingOutNotifier;

  /// Notifier set by the role-switcher sheet while a swap is in
  /// flight. The Logout button watches this so the user can't tear
  /// down the session mid-swap.
  ValueNotifier<String?> get switchingRoleNotifier;

  /// Build the logout button.
  Widget buildLogoutButton(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        isLoggingOutNotifier,
        switchingRoleNotifier,
      ]),
      builder: (context, _) {
        final isLoggingOut = isLoggingOutNotifier.value;
        final isSwitching = switchingRoleNotifier.value != null;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isLoggingOut || isSwitching)
                ? null
                : () async {
                    isLoggingOutNotifier.value = true;
                    try {
                      await TokenService().logout();
                      if (context.mounted) {
                        appRouter.go('/login');
                      }
                    } finally {
                      if (isMounted) {
                        isLoggingOutNotifier.value = false;
                      }
                    }
                  },
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.all(Radius.circular(15)),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoggingOut)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent,
                      ),
                    )
                  else
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  AppSpacing.h8,
                  Text(
                    isLoggingOut
                        ? '${AppLocalizations.logout.tr}...'
                        : AppLocalizations.logout.tr,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tile that opens the full Profile page (Phase-4 Surface 1).
  /// The full account-detail + advanced settings live there now —
  /// the old "Pengaturan" shortcut on this sheet was retired.
  Widget buildLihatProfilTile(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppNavigator.pop(context);
          AppNavigator.push(context, const ProfileScreen());
        },
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: const Color(0xFFBAE6FD), width: 0.75),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorUtils.brandAzure.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
              AppSpacing.h12,
              Expanded(
                child: Text(
                  AppLocalizations.viewFullProfile.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: ColorUtils.brandAzureDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
