// ShellNav — high-level navigation helper for the bottom-nav shell.
//
// Replaces ad-hoc `AppNavigator.push(context, SomeScreen())` calls when
// the destination needs to land in a *specific tab* (rather than push
// onto the current tab's stack).
//
// Per `P1_BottomNav_Spec.md` § 4.3.
//
// Two distinct use cases:
//
//   1. Cross-tab navigation: dashboard menu tile / FCM deep-link wants
//      to go to a screen that "belongs" to a different tab (e.g. the
//      admin dashboard's Kelola Siswa tile should land in the Orang
//      tab, not push onto Beranda's stack). Use [ShellNav.goTo].
//
//   2. Within-tab navigation: pushing a detail screen from a list inside
//      the same tab. Just use the existing `AppNavigator.push` — it'll
//      naturally land on the active tab's `Navigator` because that's the
//      `Navigator.of(context)` ancestor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';

class ShellNav {
  ShellNav._();

  /// Switch to [tab] for the active session's [role], optionally pushing
  /// [pushOnTop] on that tab's `Navigator`.
  ///
  /// When [pushOnTop] is null this is a pure tab-switch — equivalent to
  /// the user tapping that tab in the bottom nav.
  ///
  /// When [pushOnTop] is provided, the shell first activates the tab
  /// (so `IndexedStack` swaps the visible branch) and then pushes the
  /// screen onto that tab's `Navigator` via its registered
  /// `GlobalKey<NavigatorState>`.
  static void goTo(
    WidgetRef ref, {
    required String role,
    required ShellTab tab,
    Widget? pushOnTop,
  }) {
    final notifier = ref.read(shellProvider(role).notifier);
    notifier.setTab(tab);

    if (pushOnTop != null) {
      // After `setTab` the IndexedStack swaps; the target tab's
      // Navigator may need a frame to mount its initial route before we
      // push on top. Schedule the push for after the current build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = ref.read(shellProvider(role));
        final navKey = state.navigatorKeys[tab];
        navKey?.currentState?.push(
          MaterialPageRoute(builder: (_) => pushOnTop),
        );
      });
    }
  }

  /// Pop the active tab's stack to its root. Mirrors
  /// [ShellNotifier.popToRoot] for callers that don't have a notifier
  /// reference handy.
  static void popActiveTabToRoot(WidgetRef ref, {required String role}) {
    final state = ref.read(shellProvider(role));
    ref.read(shellProvider(role).notifier).popToRoot(state.activeTab);
  }
}
