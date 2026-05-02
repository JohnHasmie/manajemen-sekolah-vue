import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';

/// Mixin providing the localised role-display helper used by the
/// account sheet's "Peran aktif" row and the user-name fallback.
///
/// History
/// -------
/// This mixin used to render the entire account-sheet header
/// (`buildUserInfoRow` + `_buildUserAvatar` + `_buildUserInfoColumn`)
/// and a paired `roleIcon` widget. The header was redesigned in
/// Phase-4 (Surface 3 — account sheet from person icon) and the
/// new layout is composed inline in `dashboard_account_sheet.dart`,
/// so those builders had no callers anymore. Same story for
/// `roleIcon` after the switcher migrated to the shared
/// `SelectionHeroCard` / `SelectionTile`.
///
/// What survives is [roleDisplayName] — still wanted for `_AccessRow`
/// "Peran aktif" because it goes through `AppLocalizations` so the
/// label flips between EN/ID with the language picker. The shared
/// `core/utils/role_labels.dart::roleDisplayName` is Bahasa-only
/// (the brand bottom sheets are Indonesian) so the two coexist
/// intentionally.
mixin DashboardAccountSheetHeaderMixin {
  /// Abstract getters that the host state class must implement.
  DashboardState get sheetState;
  Color get primaryColor;

  /// Localised role label — uses `AppLocalizations` so it follows
  /// the active language. Used by `_AccessRow` in the account sheet
  /// and as the fallback for the user-name when [sheetState.userData]
  /// has no `nama` field.
  String roleDisplayName(String role) {
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
