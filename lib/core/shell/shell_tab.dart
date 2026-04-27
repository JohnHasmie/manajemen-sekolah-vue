// Bottom-nav tab identifiers shared across roles.
//
// Not every role uses every value — see [kRoleTabs] in `role_tabs.dart` for
// the per-role enabled set. Each role is gated to the tabs that make sense
// for its product surface; this enum is the union.
//
// Per `P1_BottomNav_Spec.md` § 2:
//   admin : beranda · orang · akademik · keuangan · sistem
//   guru  : beranda · mengajar · nilai · lainnya
//   wali  : beranda · akademik · kehadiran · keuangan
//
// Order in the enum is the union order; rendering order is determined by
// each role's `kRoleTabs` list, not by enum index.

import 'package:flutter/material.dart';

/// Identifies a single bottom-nav tab. Distinct tabs across roles
/// (e.g. admin's `orang` vs guru's `mengajar`) live as separate values
/// rather than re-using a generic "tab1/tab2" so call sites stay readable.
enum ShellTab {
  // Common to all 3 roles
  beranda,

  // Admin
  orang,
  akademik,
  keuangan,
  sistem,

  // Teacher
  mengajar,
  nilai,
  lainnya,

  // Parent
  kehadiran,
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
      case ShellTab.beranda:
        return Icons.home_outlined;
      case ShellTab.orang:
        return Icons.people_outline;
      case ShellTab.akademik:
        return Icons.menu_book_outlined;
      case ShellTab.keuangan:
        return Icons.account_balance_wallet_outlined;
      case ShellTab.sistem:
        return Icons.settings_outlined;
      case ShellTab.mengajar:
        return Icons.school_outlined;
      case ShellTab.nilai:
        return Icons.fact_check_outlined;
      case ShellTab.lainnya:
        return Icons.more_horiz;
      case ShellTab.kehadiran:
        return Icons.event_available_outlined;
    }
  }

  /// Indonesian label rendered in the `BottomNavigationBarItem`.
  /// Kept short (single word) so 4-5 tabs fit Samsung portrait without
  /// truncation. The audit's P0 #2/#3 (Pengatura\nn / Pengumum…) was
  /// the cautionary tale here.
  String get label {
    switch (this) {
      case ShellTab.beranda:
        return 'Beranda';
      case ShellTab.orang:
        return 'Orang';
      case ShellTab.akademik:
        return 'Akademik';
      case ShellTab.keuangan:
        return 'Keuangan';
      case ShellTab.sistem:
        return 'Sistem';
      case ShellTab.mengajar:
        return 'Mengajar';
      case ShellTab.nilai:
        return 'Nilai';
      case ShellTab.lainnya:
        return 'Lainnya';
      case ShellTab.kehadiran:
        return 'Kehadiran';
    }
  }
}
