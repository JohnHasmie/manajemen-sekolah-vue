import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';

/// Mixin for role-switching UI and logic.
mixin DashboardAccountSheetRoleMixin {
  /// Abstract getters for state and context access
  DashboardState get sheetState;
  Color get primaryColor;
  BuildContext get context;
  WidgetRef get widgetRef;
  bool get isMounted;

  /// Get or set the switching role notifier
  ValueNotifier<String?> get switchingRoleNotifier;

  /// Get role icon (from header mixin)
  Widget roleIcon(String role);

  /// Get role display name (from header mixin)
  String roleDisplayName(String role);

  /// Build the role tile for a single role option
  Widget buildRoleTile(
    BuildContext context,
    dynamic role,
    String? switchingRole,
  ) {
    final isCurrent = role == sheetState.userData['role'];
    final isSwitching = switchingRole == role;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isCurrent || switchingRole != null)
            ? null
            : () async {
                switchingRoleNotifier.value = role;
                try {
                  await widgetRef
                      .read(dashboardProvider.notifier)
                      .switchRole(role);
                  if (context.mounted) {
                    AppNavigator.pop(context);
                    final effectiveRolePath = (role == 'teacher')
                        ? 'guru'
                        : (role == 'parent')
                        ? 'wali'
                        : role;
                    context.go('/$effectiveRolePath');
                  }
                } finally {
                  if (isMounted) {
                    switchingRoleNotifier.value = null;
                  }
                }
              },
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? primaryColor.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: isCurrent
                  ? primaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (isSwitching)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                )
              else
                roleIcon(role.toString()),
              AppSpacing.h12,
              Expanded(
                child: Text(
                  isSwitching
                      ? '${roleDisplayName(role.toString())}...'
                      : roleDisplayName(role.toString()),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              if (isCurrent)
                Icon(Icons.check_circle, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the role switcher section (header + tiles)
  Widget buildRoleSwitcherSection() {
    if (sheetState.availableRoles.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppLocalizations.switchRole.tr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ValueListenableBuilder<String?>(
          valueListenable: switchingRoleNotifier,
          builder: (context, switchingRole, _) => Column(
            children: sheetState.availableRoles
                .map((role) => buildRoleTile(context, role, switchingRole))
                .toList(),
          ),
        ),
        AppSpacing.v16,
        const Divider(),
        AppSpacing.v16,
      ],
    );
  }
}
