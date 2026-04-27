// Per-role bottom-nav tab lists.
//
// The order in each list is the rendering order in the
// `BottomNavigationBar`. Index in this list is what `ShellState.activeIndex`
// references — not the underlying [ShellTab] enum index.
//
// Per `P1_BottomNav_Spec.md` § 2:
//   admin : 5 tabs (Home, People, Academic, Finance, System)
//   guru  : 4 tabs (Home, Teaching, Grades, Other)
//   wali  : 4 tabs (Home, Academic, Attendance, Finance)

import 'package:manajemensekolah/core/shell/shell_tab.dart';

/// Maps a role string ('admin' / 'guru' / 'wali') to the ordered list of
/// tabs that role's bottom nav should render.
///
/// Lookup is done with `kRoleTabs[role]`; missing roles fall back to the
/// admin set (defensive — a future role string we haven't accounted for
/// at least sees a navigable UI rather than crashing).
const Map<String, List<ShellTab>> kRoleTabs = {
  'admin': [
    ShellTab.home,
    ShellTab.people,
    ShellTab.academic,
    ShellTab.finance,
    ShellTab.system,
  ],
  'guru': [
    ShellTab.home,
    ShellTab.teaching,
    ShellTab.grades,
    ShellTab.other,
  ],
  // Some legacy code paths use 'teacher' for guru — accept both so callers
  // don't have to translate first.
  'teacher': [
    ShellTab.home,
    ShellTab.teaching,
    ShellTab.grades,
    ShellTab.other,
  ],
  'wali': [
    ShellTab.home,
    ShellTab.academic,
    ShellTab.attendance,
    ShellTab.finance,
  ],
  // Same compatibility shim for parent / orang_tua.
  'parent': [
    ShellTab.home,
    ShellTab.academic,
    ShellTab.attendance,
    ShellTab.finance,
  ],
  'orang_tua': [
    ShellTab.home,
    ShellTab.academic,
    ShellTab.attendance,
    ShellTab.finance,
  ],
};

/// Resolves the tab list for [role], with the admin fallback documented
/// above. Centralized so the shell, [ShellNav], and any future tooling
/// (route debug overlay, deep-link parser) all agree on the same lookup.
List<ShellTab> tabsForRole(String role) {
  return kRoleTabs[role.toLowerCase()] ?? kRoleTabs['admin']!;
}
