// RoleShell — Scaffold + IndexedStack + BottomNavigationBar.
//
// One instance per session, mounted directly under MaterialApp by the root
// router. Hosts the role-specific tab tree:
//
//   Scaffold
//   ├── body: IndexedStack(
//   │     index: state.activeIndex,
//   │     children: [TabBranch × N],
//   │   )
//   │     TabBranch = Navigator(
//   │       key: GlobalKey<NavigatorState>,
//   │       onGenerateRoute: → tab root screen,
//   │     )
//   └── bottomNavigationBar: BottomNavigationBar
//
// Why IndexedStack (not PageView / AnimatedSwitcher):
//   - Preserves widget state across tab switches (Beranda's scroll
//     position survives a trip to Akademik).
//   - No swipe-between-tabs gesture (we don't want it — Samsung's edge
//     swipe is reserved for back-nav).
//
// Why per-tab Navigator (not the root Navigator):
//   - tap-twice-on-tab pops to root works cleanly.
//   - Tab back stacks survive switching.
//
// Per `P1_BottomNav_Spec.md` § 3.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/school_epoch_provider.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// The persistent shell. Renders one bottom-nav tab strip and an
/// `IndexedStack` of per-tab `Navigator` branches.
///
/// Tab branches are produced by a [WidgetBuilder] passed in via
/// [tabBuilder] so this widget stays role-agnostic — Sub-PR 2/3/4 supply
/// per-role tab roots without RoleShell needing to know about them.
class RoleShell extends ConsumerStatefulWidget {
  /// 'admin' | 'guru' | 'wali' (or the legacy aliases handled in
  /// `kRoleTabs`).
  final String role;

  /// Builds the root widget for [tab]. Called once per tab on shell
  /// mount; the result is wrapped in a `Navigator` so the tab owns its
  /// own back-stack.
  ///
  /// Implementation should return the screen that lives at the tab's
  /// root — typically a hub screen (Akademik) or a single-purpose
  /// screen (Kehadiran for parent).
  final Widget Function(BuildContext context, ShellTab tab) tabBuilder;

  /// Optional initial tab. When null, the role's first tab (always
  /// Beranda in practice) is selected.
  final ShellTab? initialTab;

  const RoleShell({
    super.key,
    required this.role,
    required this.tabBuilder,
    this.initialTab,
  });

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  @override
  void initState() {
    super.initState();
    // If an initialTab was provided, seed it after the provider mounts.
    // Riverpod NotifierProvider.family's initial state is built lazily on
    // first watch, so deferring this avoids touching state mid-build.
    if (widget.initialTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(shellProvider(widget.role).notifier)
              .setTab(widget.initialTab!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shellProvider(widget.role));
    final notifier = ref.read(shellProvider(widget.role).notifier);
    // Re-key the entire tab subtree on every school switch so the
    // `IndexedStack` and its per-tab `Navigator` branches unmount +
    // remount with the new active school context. Without this, screens
    // like Pengumuman / Tagihan / Aktivitas keep their cached state
    // from the previous school until a hot-restart wipes them.
    final schoolEpoch = ref.watch(schoolEpochProvider);

    return PopScope(
      // We handle back ourselves so IndexedStack-state is preserved
      // (popping out of a deep tab back to Beranda instead of exiting).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final result = await notifier.handleSystemBack();
        if (!context.mounted) return;
        switch (result) {
          case SystemBackResult.consumed:
            // The shell already popped a route or switched tab. Nothing
            // more to do.
            break;
          case SystemBackResult.awaitingExitConfirm:
            // First back press on Beranda root — show the
            // "tekan sekali lagi" hint. The shell's notifier has
            // already armed the timer; a second back press inside
            // the window will return [allowExit].
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('Tekan kembali sekali lagi untuk keluar'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ));
            break;
          case SystemBackResult.allowExit:
            // Second back press inside the window — actually exit.
            // SystemNavigator.pop() is the Android-correct way to
            // close the app cleanly; a no-op on iOS per HIG, which
            // is the right behaviour there too.
            await SystemNavigator.pop();
            break;
        }
      },
      child: Scaffold(
        // resizeToAvoidBottomInset keeps the nav bar fixed when a
        // keyboard pops up inside a pushed screen, instead of pushing
        // the nav up off-screen.
        resizeToAvoidBottomInset: true,
        body: KeyedSubtree(
          key: ValueKey('shell-$schoolEpoch'),
          child: IndexedStack(
            index: state.activeIndex,
            children: [
              for (final tab in state.tabs)
                _TabBranch(
                  key: ValueKey(tab),
                  navigatorKey: state.navigatorKeys[tab]!,
                  rootBuilder: (ctx) => widget.tabBuilder(ctx, tab),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _RoleBottomNav(
          role: widget.role,
          tabs: state.tabs,
          activeIndex: state.activeIndex,
          accentColor: ColorUtils.getRoleColor(widget.role),
          onTap: (idx) {
            final tappedTab = state.tabs[idx];
            // Convention: tapping the *active* tab pops that tab's
            // stack to root. Tapping a non-active tab switches.
            if (tappedTab == state.activeTab) {
              notifier.popToRoot(tappedTab);
            } else {
              notifier.setTab(tappedTab);
            }
          },
        ),
      ),
    );
  }
}

/// One tab's root Navigator. Stable [GlobalKey] is what makes the
/// IndexedStack preserve push-stack state across switches.
class _TabBranch extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder rootBuilder;

  const _TabBranch({
    super.key,
    required this.navigatorKey,
    required this.rootBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        // Only the initial route is generated here; subsequent pushes
        // go through `Navigator.of(context).push(MaterialPageRoute(...))`
        // from inside the tab's screens.
        return MaterialPageRoute(
          settings: settings,
          builder: rootBuilder,
        );
      },
    );
  }
}

/// The bottom-nav strip itself — kept as a small private widget so the
/// shell's build method stays scannable. Uses Material's
/// [BottomNavigationBar] directly (vs. a custom widget) so theming and
/// accessibility (focus, ripple, semantics labels) come for free.
class _RoleBottomNav extends StatelessWidget {
  final String role;
  final List<ShellTab> tabs;
  final int activeIndex;
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _RoleBottomNav({
    required this.role,
    required this.tabs,
    required this.activeIndex,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: activeIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: accentColor,
      unselectedItemColor: ColorUtils.slate500,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      items: [
        // Use `labelFor(role)` so role-specific overrides (e.g. parent
        // finance → "Tagihan") render in the bottom nav.
        for (final tab in tabs)
          BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: tab.labelFor(role),
          ),
      ],
    );
  }
}
