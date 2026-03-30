// Account bottom-sheet shown when the user taps the account avatar in the app bar.
//
// Extracted from DashboardScreen._showAccountBottomSheet to reduce file size.
// Like a Vue modal component (`<AccountModal>`) that handles profile display,
// role switching, school switching, settings navigation, and logout.
//
// Uses ConsumerStatefulWidget because it needs:
// - Local state for loading flags (isLoggingOut, switchingRole)
// - WidgetRef to call dashboardProvider.notifier.switchRole / logout
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';

/// The content widget shown inside [showModalBottomSheet] on the dashboard.
///
/// Caller is responsible for opening the sheet; this widget owns the inner tree.
/// Pass [state], [primaryColor], [effectiveRole], and [onShowSchoolSelection]
/// (a callback into the parent to open the school-selection dialog, since that
/// dialog itself needs access to the stable widget context of the parent screen).
class DashboardAccountSheet extends ConsumerStatefulWidget {
  final DashboardState state;
  final Color primaryColor;
  final String effectiveRole;

  /// Called when the user taps "Switch School" — opens the school-selection
  /// dialog which must be anchored to the parent screen's context.
  final VoidCallback onShowSchoolSelection;

  const DashboardAccountSheet({
    super.key,
    required this.state,
    required this.primaryColor,
    required this.effectiveRole,
    required this.onShowSchoolSelection,
  });

  @override
  ConsumerState<DashboardAccountSheet> createState() =>
      _DashboardAccountSheetState();
}

class _DashboardAccountSheetState
    extends ConsumerState<DashboardAccountSheet> {
  bool _isLoggingOut = false;
  String? _switchingRole; // tracks which role button is in-progress

  Color get _primaryColor => widget.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(AppSpacing.xl),
      child: Wrap(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),

                  // User info row
                  _buildUserInfoRow(),

                  SizedBox(height: AppSpacing.xxl),

                  // Role switcher (only when user has more than one role)
                  if (widget.state.availableRoles.length > 1) ...[
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
                    ...widget.state.availableRoles.map(
                      (role) => _buildRoleTile(context, role),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    SizedBox(height: AppSpacing.lg),
                  ],

                  // Switch school (only when user has access to multiple schools)
                  if (widget.state.accessibleSchools.length > 1) ...[
                    _buildSwitchSchoolButton(context),
                    SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    SizedBox(height: AppSpacing.lg),
                  ],

                  // Settings
                  _buildSettingsButton(context),
                  SizedBox(height: AppSpacing.lg),

                  // Logout
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primaryColor,
                _primaryColor.withValues(alpha: 0.7),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_circle,
            color: Colors.white,
            size: 32,
          ),
        ),
        SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.state.userData['nama'] ??
                    widget.effectiveRole.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                widget.state.userData['email'] ?? '',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                widget.state.userData['nama_sekolah'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTile(BuildContext context, dynamic role) {
    final isCurrent = role == widget.state.userData['role'];
    final isSwitching = _switchingRole == role;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isCurrent || _switchingRole != null)
            ? null
            : () async {
                setState(() => _switchingRole = role);
                try {
                  await ref
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
                  if (mounted) setState(() => _switchingRole = null);
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? _primaryColor.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent
                  ? _primaryColor.withValues(alpha: 0.3)
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
                    color: _primaryColor,
                  ),
                )
              else
                _roleIcon(role.toString()),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isSwitching
                      ? '${_roleDisplayName(role.toString())}...'
                      : _roleDisplayName(role.toString()),
                  style: TextStyle(
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              if (isCurrent)
                Icon(Icons.check_circle, color: _primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSchoolButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppNavigator.pop(context);
          widget.onShowSchoolSelection();
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, color: _primaryColor, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text(
                AppLocalizations.switchSchool.tr,
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    final roleColor = ColorUtils.getRoleColor(widget.effectiveRole);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppNavigator.pop(context);
          AppNavigator.push(context, const SettingsScreen());
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, color: roleColor, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text(
                AppLocalizations.settings.tr,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (_isLoggingOut || _switchingRole != null)
            ? null
            : () async {
                setState(() => _isLoggingOut = true);
                try {
                  await TokenService().logout();
                  if (context.mounted) {
                    appRouter.go('/login');
                  }
                } finally {
                  if (mounted) setState(() => _isLoggingOut = false);
                }
              },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoggingOut)
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
              SizedBox(width: AppSpacing.sm),
              Text(
                _isLoggingOut
                    ? 'Logging out...'
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
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings,
            color: _primaryColor, size: 20);
      case 'guru':
        return Icon(Icons.school, color: _primaryColor, size: 20);
      case 'wali':
        return Icon(Icons.family_restroom, color: _primaryColor, size: 20);
      case 'staff':
        return Icon(Icons.work, color: _primaryColor, size: 20);
      default:
        return Icon(Icons.person, color: _primaryColor, size: 20);
    }
  }

  String _roleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return AppLocalizations.adminRole.tr;
      case 'guru':
      case 'teacher':
        return AppLocalizations.teacherRole.tr;
      case 'wali':
      case 'parent':
      case 'walimurid':
      case 'wali murid':
        return AppLocalizations.parentRole.tr;
      case 'staff':
        return AppLocalizations.staffRole.tr;
      default:
        if (role.isNotEmpty) {
          return role[0].toUpperCase() + role.substring(1);
        }
        return role;
    }
  }
}
