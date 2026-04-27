// Per-role bottom-nav tab lists.
//
// The order in each list is the rendering order in the
// `BottomNavigationBar`. Index in this list is what `ShellState.activeIndex`
// references — not the underlying [ShellTab] enum index.
//
// Per `P1_BottomNav_Spec.md` § 2:
//   admin : 5 tabs (Beranda, Orang, Akademik, Keuangan, Sistem)
//   guru  : 4 tabs (Beranda, Mengajar, Nilai, Lainnya)
//   wali  : 4 tabs (Beranda, Akademik, Kehadiran, Keuangan)

import 'package:manajemensekolah/core/shell/shell_tab.dart';

/// Maps a role string ('admin' / 'guru' / 'wali') to the ordered list of
/// tabs that role's bottom nav should render.
///
/// Lookup is done with `kRoleTabs[role]`; missing roles fall back to the
/// admin set (defensive — a future role string we haven't accounted for
/// at least sees a navigable UI rather than crashing).
const Map<String, List<ShellTab>> kRoleTabs = {
  'admin': [
    ShellTab.beranda,
    ShellTab.orang,
    ShellTab.akademik,
    ShellTab.keuangan,
    ShellTab.sistem,
  ],
  'guru': [
    ShellTab.beranda,
    ShellTab.mengajar,
    ShellTab.nilai,
    ShellTab.lainnya,
  ],
  // Some legacy code paths use 'teacher' for guru — accept both so callers
  // don't have to translate first.
  'teacher': [
    ShellTab.beranda,
    ShellTab.mengajar,
    ShellTab.nilai,
    ShellTab.lainnya,
  ],
  'wali': [
    ShellTab.beranda,
    ShellTab.akademik,
    ShellTab.kehadiran,
    ShellTab.keuangan,
  ],
  // Same compatibility shim for parent / orang_tua.
  'parent': [
    ShellTab.beranda,
    ShellTab.akademik,
    ShellTab.kehadiran,
    ShellTab.keuangan,
  ],
  'orang_tua': [
    ShellTab.beranda,
    ShellTab.akademik,
    ShellTab.kehadiran,
    ShellTab.keuangan,
  ],
};

/// Resolves the tab list for [role], with the admin fallback documented
/// above. Centralized so the shell, [ShellNav], and any future tooling
/// (route debug overlay, deep-link parser) all agree on the same lookup.
List<ShellTab> tabsForRole(String role) {
  return kRoleTabs[role.toLowerCase()] ?? kRoleTabs['admin']!;
}
