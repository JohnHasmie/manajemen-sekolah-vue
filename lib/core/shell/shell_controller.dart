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

  ShellState copyWith({
    ShellTab? activeTab,
    Map<ShellTab, GlobalKey<NavigatorState>>? navigatorKeys,
  }) {
    return ShellState(
      role: role,
      activeTab: activeTab ?? this.activeTab,
      navigatorKeys: navigatorKeys ?? this.navigatorKeys,
    );
  }
}

/// Outcome of a system-back press, returned by
/// [ShellNotifier.handleSystemBack] so the host (`RoleShell`) can react
/// — show a snackbar, exit the app, or do nothing.
enum SystemBackResult {
  /// The back press was absorbed by the shell — either popped a deep
  /// route, switched to the home tab, or armed the exit-confirm
  /// timer. Caller should NOT propagate the back further.
  consumed,

  /// User is on the home tab root and tapped back. The shell has
  /// armed an exit-confirm window; the host should show a snackbar
  /// like "Tekan kembali sekali lagi untuk keluar". The next back
  /// press inside [ShellNotifier.exitConfirmWindow] will return
  /// [allowExit].
  awaitingExitConfirm,

  /// Second back tap inside the exit-confirm window — the host
  /// should call `SystemNavigator.pop()` to actually exit the app.
  allowExit,
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

  /// Time window during which a second back press on the home root
  /// triggers app exit. Held in a static const so the
  /// [SystemBackResult] enum docs can reference it without importing
  /// material/duration.
  static const Duration exitConfirmWindow = Duration(seconds: 2);

  /// Timestamp of the most recent back-press while on the home tab
  /// root; used to detect a "press again to exit" double-tap.
  /// Reset to null after a successful exit OR when the user
  /// navigates away (we don't bother resetting on tab change because
  /// the timer is short and harmless).
  DateTime? _exitTapAt;

  /// Wire-up for the system-back gesture / hardware back button.
  ///
  /// Behavior:
  ///   1. If the active tab can pop a route off its back-stack → pop
  ///      one level. Returns [SystemBackResult.consumed].
  ///   2. Else if active tab isn't Beranda → switch to Beranda.
  ///      Returns [SystemBackResult.consumed].
  ///   3. Else (we're on Beranda root) →
  ///      a. First press inside the window → arm the timer, return
  ///         [SystemBackResult.awaitingExitConfirm]. Host shows a
  ///         "tekan kembali sekali lagi untuk keluar" snackbar.
  ///      b. Second press within [exitConfirmWindow] → return
  ///         [SystemBackResult.allowExit]; host calls
  ///         `SystemNavigator.pop()` to exit cleanly.
  Future<SystemBackResult> handleSystemBack() async {
    final navKey = state.navigatorKeys[state.activeTab];
    if (navKey?.currentState?.canPop() ?? false) {
      navKey!.currentState!.pop();
      return SystemBackResult.consumed;
    }
    if (state.activeTab != ShellTab.home &&
        state.tabs.contains(ShellTab.home)) {
      setTab(ShellTab.home);
      return SystemBackResult.consumed;
    }
    // We're on the home tab root — drive the exit-confirm flow.
    final now = DateTime.now();
    final last = _exitTapAt;
    if (last != null && now.difference(last) < exitConfirmWindow) {
      _exitTapAt = null;
      return SystemBackResult.allowExit;
    }
    _exitTapAt = now;
    return SystemBackResult.awaitingExitConfirm;
  }

  /// Mint a fresh set of `GlobalKey<NavigatorState>` for every tab and
  /// reset to the role's first tab.
  ///
  /// Why this exists: when the user switches school inside the same
  /// role, the `IndexedStack` subtree gets re-keyed by `RoleShell` via
  /// `schoolEpochProvider`, but the per-tab Navigators are bound by
  /// stable [GlobalKey]s. Flutter's GlobalKey reparenting then keeps
  /// the Navigator's State (and every page underneath it) alive, so
  /// the parent tabs still show the previous school's data.
  ///
  /// Generating fresh keys breaks that identity link — the new
  /// `_TabBranch.Navigator` widgets create brand-new States, every
  /// pushed page is dropped, and the screens' `initState` fires
  /// against the new active school context.
  void resetNavigatorStacks() {
    final freshKeys = <ShellTab, GlobalKey<NavigatorState>>{
      for (final t in state.tabs) t: GlobalKey<NavigatorState>(),
    };
    state = state.copyWith(
      activeTab: state.tabs.first,
      navigatorKeys: freshKeys,
    );
  }
}

/// Family provider keyed by role. Keep call sites consistent:
/// `ref.watch(shellProvider('admin'))` for state,
/// `ref.read(shellProvider('admin').notifier)` for actions.
final shellProvider =
    NotifierProvider.family<ShellNotifier, ShellState, String>(
      ShellNotifier.new,
    );
