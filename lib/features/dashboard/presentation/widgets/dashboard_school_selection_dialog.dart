// School-selection dialog for switching the active school context.
//
// Extracted from DashboardScreen._showSchoolSelectionDialog to reduce file size.
// Like a Vue `<SchoolPickerModal>` used when the logged-in user has access to
// more than one school (multi-tenant). Tapping a school triggers a school-switch
// API call and navigates to the appropriate role dashboard.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Shows a list of [accessibleSchools] the current user can switch to.
///
/// Use [showDashboardSchoolSelectionDialog] to open it, passing the stable
/// widget [context] of the parent screen (not the bottom-sheet context, which
/// may be popped before the async school-switch completes).
void showDashboardSchoolSelectionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required DashboardState state,
  required String currentRole,
  required Color primaryColor,
  required void Function(
    BuildContext ctx,
    String schoolId,
    List<String> roleList,
  )
  onNeedsRoleSelection,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => _SchoolSelectionDialog(
      dialogContext: dialogContext,
      parentContext: context,
      ref: ref,
      state: state,
      currentRole: currentRole,
      primaryColor: primaryColor,
      onNeedsRoleSelection: onNeedsRoleSelection,
    ),
  );
}

class _SchoolSelectionDialog extends StatelessWidget {
  final BuildContext dialogContext;
  final BuildContext parentContext;
  final WidgetRef ref;
  final DashboardState state;
  final String currentRole;
  final Color primaryColor;
  final void Function(BuildContext ctx, String schoolId, List<String> roleList)
  onNeedsRoleSelection;

  const _SchoolSelectionDialog({
    required this.dialogContext,
    required this.parentContext,
    required this.ref,
    required this.state,
    required this.currentRole,
    required this.primaryColor,
    required this.onNeedsRoleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      title: Row(
        children: [
          Icon(Icons.school_rounded, color: primaryColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppLocalizations.selectSchool.tr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...state.accessibleSchools.map(
              (school) => _SchoolTile(
                school: school,
                isCurrent: school['school_id'] == state.userData['school_id'],
                primaryColor: primaryColor,
                onTap: () => _onSchoolTap(school),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => AppNavigator.pop(dialogContext),
          child: Text(
            AppLocalizations.cancel.tr,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Future<void> _onSchoolTap(Map<dynamic, dynamic> school) async {
    AppNavigator.pop(dialogContext);
    // Capture router before any async gap so it's safe to use after await
    final router = GoRouter.of(parentContext);

    try {
      final schoolId = (school['school_id'] ?? school['id'] ?? '').toString();
      if (schoolId.isEmpty) {
        throw Exception('School ID is missing');
      }
      final result = await ref
          .read(dashboardProvider.notifier)
          .switchSchool(schoolId);

      if (!ref.context.mounted) return;

      if (result['needsRoleSelection'] == true) {
        final roleList = List<String>.from(result['role_list'] ?? []);
        if (roleList.isEmpty) return;
        // ignore: use_build_context_synchronously
        onNeedsRoleSelection(parentContext, schoolId, roleList);
        return;
      }

      final newRole = result['user']?['role']?.toString() ?? currentRole;
      await LocalCacheService.clearAll();
      // Reset so the next dashboard page triggers a fresh initialize
      ref.read(dashboardProvider.notifier).resetForSchoolSwitch();
      if (ref.context.mounted) {
        if (newRole == currentRole) {
          ref.invalidate(dashboardProvider);
        } else {
          router.go('/$newRole');
        }
      }
    } catch (e) {
      AppLogger.error('dashboard', 'Switch school error: $e');
      if (ref.context.mounted) {
        // ignore: use_build_context_synchronously
        SnackBarUtils.showError(
          parentContext,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}

class _SchoolTile extends StatelessWidget {
  final Map<dynamic, dynamic> school;
  final bool isCurrent;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SchoolTile({
    required this.school,
    required this.isCurrent,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCurrent ? null : onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
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
              Icon(Icons.school, color: isCurrent ? primaryColor : Colors.grey),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (school['school_name'] ?? school['name'] ?? 'Unknown School').toString(),
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      school['address'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
}

/// Shows a role-picker dialog when a school switch exposes multiple roles.
///
/// Called from the [showDashboardSchoolSelectionDialog] onNeedsRoleSelection
/// callback when the API returns `needsRoleSelection: true`.
void showDashboardRolePickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String schoolId,
  required List<String> roleList,
  required String currentRole,
  required Color primaryColor,
}) {
  IconData roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'guru':
        return Icons.school;
      case 'wali':
        return Icons.family_restroom;
      case 'staff':
        return Icons.work;
      default:
        return Icons.person;
    }
  }

  String roleName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'guru':
        return 'Guru / Teacher';
      case 'wali':
        return 'Wali Murid / Parent';
      case 'staff':
        return 'Staff';
      default:
        return role;
    }
  }

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      title: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: primaryColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Select Role / Pilih Role',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: roleList.map((role) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  AppNavigator.pop(dialogContext);
                  final router = GoRouter.of(context);
                  try {
                    final result = await ref
                        .read(dashboardProvider.notifier)
                        .switchSchool(schoolId, role: role);
                    if (!ref.context.mounted) return;
                    final newRole = result['user']?['role']?.toString() ?? role;
                    await LocalCacheService.clearAll();
                    ref.read(dashboardProvider.notifier).resetForSchoolSwitch();
                    if (ref.context.mounted) {
                      if (newRole == currentRole) {
                        ref.invalidate(dashboardProvider);
                      } else {
                        router.go('/$newRole');
                      }
                    }
                  } catch (e) {
                    if (ref.context.mounted) {
                      // ignore: use_build_context_synchronously
                      SnackBarUtils.showError(
                        context,
                        e.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  }
                },
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(roleIcon(role), color: primaryColor),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        roleName(role),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => AppNavigator.pop(dialogContext),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
    ),
  );
}
