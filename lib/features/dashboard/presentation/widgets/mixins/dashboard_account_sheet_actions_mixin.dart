import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/account/presentation/screens/'
    'profile_screen.dart';

/// Mixin for action buttons: switch school, settings, logout.
mixin DashboardAccountSheetActionsMixin {
  /// Abstract getters for state and context access
  String get effectiveRole;
  Color get primaryColor;
  BuildContext get context;
  bool get isMounted;

  /// Callback to trigger school selection dialog
  VoidCallback get onShowSchoolSelection;

  /// Get or set the logging out notifier
  ValueNotifier<bool> get isLoggingOutNotifier;

  /// Get or set the switching role notifier (for disable logic)
  ValueNotifier<String?> get switchingRoleNotifier;

  /// Build the switch school button
  Widget buildSwitchSchoolButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppNavigator.pop(context);
          onShowSchoolSelection();
        },
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, color: primaryColor, size: 20),
              AppSpacing.h8,
              Text(
                AppLocalizations.switchSchool.tr,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the settings button
  Widget buildSettingsButton(BuildContext context) {
    final roleColor = ColorUtils.getRoleColor(effectiveRole);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppNavigator.pop(context);
          AppNavigator.push(context, const ProfileScreen());
        },
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, color: roleColor, size: 20),
              AppSpacing.h8,
              Text(
                AppLocalizations.settings.tr,
                style: TextStyle(color: roleColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the logout button
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

  /// Build the school-switch section. Per Phase-4 redesign the
  /// "Pengaturan" button is no longer shown here — settings live on
  /// the new full Profile page (reachable via [buildLihatProfilTile]).
  /// Single-school users skip the school button entirely so the sheet
  /// stays compact.
  Widget buildSchoolSettingsSection(
    DashboardState sheetState,
    BuildContext context,
  ) {
    if (sheetState.accessibleSchools.length <= 1) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [buildSwitchSchoolButton(context), AppSpacing.v16],
    );
  }

  /// Tile that opens the full Profile page (Surface 1 in Phase-4).
  /// Replaces the previous "Pengaturan" button — the user gets full
  /// account detail + advanced settings on that page rather than a
  /// truncated settings shortcut here.
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
