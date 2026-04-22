// Account bottom-sheet shown when the user taps the account avatar in the
// app bar.
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
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dashboard_account_sheet_header_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dashboard_account_sheet_role_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dashboard_account_sheet_actions_mixin.dart';

/// The content widget shown inside [showModalBottomSheet] on the dashboard.
///
/// Caller is responsible for opening the sheet; this widget owns the inner
/// tree. Pass [state], [primaryColor], [effectiveRole], and
/// [onShowSchoolSelection] (a callback into the parent to open the
/// school-selection dialog, since that dialog itself needs access to the
/// stable widget context of the parent screen).
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

class _DashboardAccountSheetState extends ConsumerState<DashboardAccountSheet>
    with
        DashboardAccountSheetHeaderMixin,
        DashboardAccountSheetRoleMixin,
        DashboardAccountSheetActionsMixin {
  // ValueNotifiers instead of plain booleans so only the affected subtree
  // rebuilds on change — not the entire bottom sheet.
  //
  // Before: setState() on _isLoggingOut rebuilt the whole sheet (user info
  // row, all role tiles, school/settings buttons, and the logout button).
  // After: only the logout button's ListenableBuilder subtree rebuilds.
  //
  // Similarly, _switchingRole now only rebuilds the role-tiles Column.
  final _isLoggingOut = ValueNotifier<bool>(false);
  final _switchingRole = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _isLoggingOut.dispose();
    _switchingRole.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
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
              child: _buildSheetContent(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the main column content of the sheet
  Widget _buildSheetContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        _buildDragHandle(),
        AppSpacing.v20,

        // User info row
        buildUserInfoRow(),
        AppSpacing.v24,

        // Role switcher section
        buildRoleSwitcherSection(),

        // School and settings section
        buildSchoolSettingsSection(widget.state, context),

        // Logout button
        buildLogoutButton(context),
      ],
    );
  }

  /// Build the drag handle indicator at the top of the sheet
  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 60,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
  }

  // ── Mixin implementations (abstract getters) ──────────────────────────────

  @override
  DashboardState get sheetState => widget.state;

  @override
  Color get primaryColor => widget.primaryColor;

  @override
  String get effectiveRole => widget.effectiveRole;

  @override
  WidgetRef get widgetRef => ref;

  @override
  bool get isMounted => mounted;

  @override
  ValueNotifier<bool> get isLoggingOutNotifier => _isLoggingOut;

  @override
  ValueNotifier<String?> get switchingRoleNotifier => _switchingRole;

  @override
  VoidCallback get onShowSchoolSelection => widget.onShowSchoolSelection;
}
