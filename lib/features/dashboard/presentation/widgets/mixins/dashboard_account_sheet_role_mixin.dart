import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';

/// Mixin that exposes the **role-switching transient state** to the
/// account sheet's actions mixin (which disables the logout button
/// while a role swap is in flight).
///
/// History
/// -------
/// This mixin used to render the legacy in-sheet role-switcher (a
/// stacked list of role tiles with a check on the active one). That
/// surface was migrated in Phase-5 to a dedicated bottom sheet
/// (`showDashboardRolePickerDialog` → "Hero Saat ini + Ganti ke"),
/// so the embedded tiles are gone — the account sheet now shows a
/// single "Peran aktif" row whose [Switch] tap opens the new sheet.
///
/// All that survives here is the [switchingRoleNotifier], which the
/// actions mixin reads to grey out the Logout button while a swap
/// is underway. The unused [WidgetRef]/[BuildContext]/[isMounted]
/// abstract members were dropped along with the dead code.
mixin DashboardAccountSheetRoleMixin {
  /// True (non-null) while a role swap is in flight. Set externally
  /// by whichever surface owns the swap (currently the
  /// `_RoleSwitcherSheet` in `dashboard_school_selection_dialog.dart`).
  ///
  /// The actions mixin disables the Logout button while this is
  /// non-null so the user can't tear down the session mid-swap.
  ValueNotifier<String?> get switchingRoleNotifier;

  /// Concrete dashboard state. Kept abstract so the mixin doesn't
  /// pin a specific holder — the account sheet's state class
  /// satisfies it via [DashboardAccountSheet.state].
  DashboardState get sheetState;
}
