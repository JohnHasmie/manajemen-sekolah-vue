// Single source of truth for role-aware display strings, icons, and
// shell-family keys. Pure functions — no BuildContext, no Riverpod —
// so they're safe to call from migrations, models, or pure widgets.
//
// Why this file
// -------------
// The same `switch (role) { case 'admin': … }` pattern was duplicated
// across the codebase:
//   • dashboard_school_selection_dialog.dart  (private _roleDisplayName, etc.)
//   • dashboard_account_sheet_header_mixin.dart (concrete roleIcon, …)
//   • selection_helper.dart                   (auth role labels)
//   • build_mixin.dart  (recommendation tile labels)
//
// Each implementation drifted slightly — different fallback for the
// 'staff' alias, different Bahasa wording, different icons. This file
// pins the canonical answers, all in Bahasa, all aware of the
// English↔Indonesian alias pairs (admin/administrator, guru/teacher,
// wali/parent/orang_tua).
//
// Use this file directly in any role-agnostic widget. The legacy
// header mixin still re-exports its own roleDisplayName/roleIcon to
// preserve back-compat with existing call sites — long term those
// should delegate here too.

import 'package:flutter/material.dart';

/// Bahasa display label for [role]. Accepts English aliases
/// ('teacher', 'parent') and Indonesian forms ('guru', 'wali',
/// 'wali_murid', 'orang_tua') and admin variants
/// ('admin', 'administrator'). Unknown roles fall through to a
/// capitalized echo of the input so the UI never shows an empty
/// label.
String roleDisplayName(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
    case 'administrator':
      return 'Administrator';
    case 'guru':
    case 'teacher':
      return 'Guru';
    case 'wali':
    case 'wali_murid':
    case 'walimurid':
    case 'parent':
    case 'orang_tua':
      return 'Wali Murid';
    case 'staff':
      return 'Staff';
    default:
      if (role.isEmpty) return role;
      return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }
}

/// One-line description of what each role does, used as the
/// secondary line on hero cards and switcher tiles. Bahasa-only.
String roleDescription(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
    case 'administrator':
      return 'Kelola sekolah, guru, dan siswa';
    case 'guru':
    case 'teacher':
      return 'Mengajar dan mengelola kelas';
    case 'wali':
    case 'wali_murid':
    case 'walimurid':
    case 'parent':
    case 'orang_tua':
      return 'Pantau perkembangan anak';
    case 'staff':
      return 'Tugas operasional sekolah';
    default:
      return '';
  }
}

/// Material icon for [role] suitable for both compact tiles
/// (small disc on the left of a row) and hero cards (50px tinted
/// disc).
IconData roleIconData(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
    case 'administrator':
      return Icons.admin_panel_settings_rounded;
    case 'guru':
    case 'teacher':
      return Icons.school_rounded;
    case 'wali':
    case 'wali_murid':
    case 'walimurid':
    case 'parent':
    case 'orang_tua':
      return Icons.family_restroom_rounded;
    case 'staff':
      return Icons.work_rounded;
    default:
      return Icons.person_rounded;
  }
}

/// Map a backend role value (`'parent'` / `'teacher'` / `'admin'`)
/// to the `shellProvider` family key (`'wali'` / `'guru'` /
/// `'admin'`) used for routing and IndexedStack identity.
///
/// The backend uses the English forms; the Flutter shell uses the
/// Indonesian aliases. Keep this mapping in sync with
/// `DashboardController._effectiveRole` — the comparison after a
/// school/role switch reads it from both sides.
String shellRoleKey(String role) {
  switch (role.toLowerCase()) {
    case 'teacher':
      return 'guru';
    case 'parent':
    case 'orang_tua':
    case 'wali_murid':
    case 'walimurid':
      return 'wali';
    case 'administrator':
      return 'admin';
    default:
      return role.toLowerCase();
  }
}
