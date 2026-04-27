// Shell state + Riverpod controller for the per-role bottom-nav shell.
//
// Holds: which tab is active, plus a per-tab `GlobalKey<NavigatorState>`
// so each tab owns its own back-stack (tap Beranda → Akademik → RPP detail
// → Beranda → Akademik should restore the RPP detail, not reset the tab).
//
// Per `P1_BottomNav_Spec.md` § 3.3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/shell/role_tabs.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';

/// Immutable snapshot of the shell's UI state. Stored in [shellProvider].
@immutable
class ShellState {
  /// The role this shell instance is rendering for: 'admin' / 'guru' /
  /// 'wali' (with the legacy aliases per `kRoleTabs`).
  final String role;

  /// The currently-selected tab.
  final ShellTab activeTab;

  /// Per-tab `GlobalKey<NavigatorState>` so each tab owns an independent
  /// back-stack. Keys are created once when the shell first mounts and
  /// kept stable across rebuilds; stable keys are how `IndexedStack`
  /// preserves widget state across tab switches.
  final Map<ShellTab, GlobalKey<NavigatorState>> navigatorKeys;

  const ShellState({
    required this.role,
    required this.activeTab,
    required this.navigatorKeys,
  });

  /// Bootstrap state for [role], pre-creating one navigator key per tab
  /// in the role's set.
  factory ShellState.initial({required String role, ShellTab? initialTab}) {
    final tabs = tabsForRole(role);
    final keys = <ShellTab, GlobalKey<NavigatorState>>{
      for (final t in tabs) t: GlobalKey<NavigatorState>(),
    };
    final firstTab = initialTab != null && tabs.contains(initialTab)
        ? initialTab
        : tabs.first;
    return ShellState(role: role, activeTab: firstTab, navigatorKeys: keys);
  }

  /// Index of [activeTab] within the role's tab list — used by
  /// `IndexedStack` and `BottomNavigationBar.currentIndex`. Returns 0 if
  /// the active tab isn't in the role's list (defensive; shouldn't
  /// happen in practice).
  int get activeIndex {
    final tabs = tabsForRole(role);
    final idx = tabs.indexOf(activeTab);
    return idx < 0 ? 0 : idx;
  }

  /// The role's tab list (cached lookup so call sites don't keep paying
  /// the map-read cost).
  List<ShellTab> get tabs => tabsForRole(role);

  ShellState copyWith({ShellTab? activeTab}) {
    return ShellState(
      role: role,
      activeTab: activeTab ?? this.activeTab,
      navigatorKeys: navigatorKeys,
    );
  }
}

/// Riverpod controller for [ShellState].
///
/// Family-keyed by role string so multiple roles can theoretically have
/// independent state (relevant for future multi-role users; for now each
/// session has exactly one role).
///
/// Riverpod 3.x removed `FamilyNotifier`; the canonical replacement is a
/// regular [Notifier] that takes the family arg as a constructor
/// parameter. Mirrors the pattern used by `TeacherAttendanceController`
/// in this codebase.
class ShellNotifier extends Notifier<ShellState> {
  /// The family arg passed at construction time — the role string
  /// (`'admin'` / `'guru'` / `'wali'`) this notifier is scoped to.
  final String role;

  ShellNotifier(this.role);

  @override
  ShellState build() {
    return ShellState.initial(role: role);
  }

  /// Switch to [tab]. No-op when the tab isn't in this role's set or is
  /// already active. The latter is important: tapping the active tab is
  /// handled separately as `popToRoot` (see `RoleShell.onTap`).
  void setTab(ShellTab tab) {
    if (!state.tabs.contains(tab)) return;
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab);
  }

  /// Pop the active tab's back-stack down to its root. Used by the
  /// "tap-active-tab" gesture and by FCM deep-links that want a clean
  /// surface before pushing on top.
  void popToRoot(ShellTab tab) {
    final navKey = state.navigatorKeys[tab];
    if (navKey == null) return;
    navKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Wire-up for the system-back gesture / hardware back button.
  ///
  /// Returns `true` when the back press has been consumed (caller
  /// shouldn't pop further), `false` when the host should let the OS
  /// handle it (typical: about to exit the app from Beranda root).
  ///
  /// Behavior:
  ///   1. If the active tab can pop, pop it.
  ///   2. Else if active tab isn't Beranda, switch to Beranda.
  ///   3. Else allow the OS to handle (return false → Android shows the
  ///      "press back again to exit" gesture / iOS does nothing).
  Future<bool> handleSystemBack() async {
    final navKey = state.navigatorKeys[state.activeTab];
    if (navKey?.currentState?.canPop() ?? false) {
      navKey!.currentState!.pop();
      return true;
    }
    if (state.activeTab != ShellTab.beranda &&
        state.tabs.contains(ShellTab.beranda)) {
      setTab(ShellTab.beranda);
      return true;
    }
    return false;
  }
}

/// Family provider keyed by role. Keep call sites consistent:
/// `ref.watch(shellProvider('admin'))` for state,
/// `ref.read(shellProvider('admin').notifier)` for actions.
final shellProvider =
    NotifierProvider.family<ShellNotifier, ShellState, String>(
      ShellNotifier.new,
    );
