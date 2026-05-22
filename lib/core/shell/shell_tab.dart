// Bottom-nav tab identifiers shared across roles.
//
// Code identifiers are English; user-facing labels are Indonesian (per
// CLAUDE.md "Bahasa Indonesia for every user-visible string"). Not every
// role uses every value — see [kRoleTabs] in `role_tabs.dart` for the
// per-role enabled set. Each role is gated to the tabs that make sense
// for its product surface; this enum is the union.
//
// Per `P1_BottomNav_Spec.md` § 2:
//   admin : home · people · academic · finance · system
//   guru  : home · teaching · grades · other
//   wali  : home · academic · attendance · finance
//
// Order in the enum is the union order; rendering order is determined by
// each role's `kRoleTabs` list, not by enum index.

import 'package:flutter/material.dart';

/// Identifies a single bottom-nav tab. Distinct tabs across roles
/// (e.g. admin's `people` vs guru's `teaching`) live as separate values
/// rather than re-using a generic "tab1/tab2" so call sites stay readable.
enum ShellTab {
  // Common to all 3 roles
  home,

  // Admin
  people,
  academic,
  finance,
  system,

  // Teacher
  teaching,
  grades,
  other,

  // Parent
  attendance,
}

/// Static metadata for [ShellTab]: icon + Indonesian label. Lives next to
/// the enum so all UI rendering callers (the bottom nav itself, route
/// debug overlays, accessibility labels) read from one source.
extension ShellTabMeta on ShellTab {
  /// Icon shown in the bottom-nav `BottomNavigationBarItem`. Outlined
  /// variants chosen to match the rest of the app's icon language
  /// (admin dashboard menu uses `Icons.*_outlined`).
  IconData get icon {
    switch (this) {
      case ShellTab.home:
        return Icons.home_outlined;
      case ShellTab.people:
        return Icons.people_outline;
      case ShellTab.academic:
        return Icons.menu_book_outlined;
      case ShellTab.finance:
        return Icons.account_balance_wallet_outlined;
      case ShellTab.system:
        return Icons.settings_outlined;
      case ShellTab.teaching:
        return Icons.school_outlined;
      case ShellTab.grades:
        return Icons.fact_check_outlined;
      case ShellTab.other:
        return Icons.more_horiz;
      case ShellTab.attendance:
        return Icons.event_available_outlined;
    }
  }

  /// Indonesian label rendered in the `BottomNavigationBarItem`.
  /// Kept short (single word) so 4-5 tabs fit Samsung portrait without
  /// truncation. The audit's P0 #2/#3 (Pengatura\nn / Pengumum…) was
  /// the cautionary tale here.
  ///
  /// Default label is the role-neutral one. Use [labelFor] to get a
  /// role-specific override (e.g. parent's `finance` reads "Tagihan"
  /// because the wali surface is bills-only, while admin's stays
  /// "Keuangan" since the admin hub also covers payments + types).
  String get label {
    switch (this) {
      case ShellTab.home:
        return 'Beranda';
      case ShellTab.people:
        return 'Orang';
      case ShellTab.academic:
        return 'Akademik';
      case ShellTab.finance:
        return 'Keuangan';
      case ShellTab.system:
        return 'Profil';
      case ShellTab.teaching:
        return 'Mengajar';
      case ShellTab.grades:
        return 'Nilai';
      case ShellTab.other:
        return 'Lainnya';
      case ShellTab.attendance:
        return 'Kehadiran';
    }
  }

  /// Role-aware label override. Falls through to [label] when no
  /// override exists for the (tab, role) pair. Add new overrides
  /// here rather than in the bottom-nav widget so call sites stay
  /// consistent and the matrix is easy to scan.
  String labelFor(String role) {
    final r = role.toLowerCase();
    // Parent (`wali` / `parent`) — the finance tab only surfaces
    // bills, so the nav reads "Tagihan" to match the screen content
    // and the dashboard's KPI / quick-action labelling.
    if ((r == 'wali' || r == 'parent') && this == ShellTab.finance) {
      return 'Tagihan';
    }
    return label;
  }
}
