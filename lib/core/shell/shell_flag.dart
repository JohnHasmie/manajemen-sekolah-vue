// Compile-time feature flag for the P1 bottom-nav shell rollout.
//
// Lives in `lib/core/shell/` rather than under the dashboard feature so
// non-UI services (e.g. `fcm_notification_router.dart`) can read it
// without taking a dependency on a presentation-layer file.
//
// When `false` (default), the legacy dashboard renders unchanged and the
// FCM router pushes screens directly via `navigatorKey`. When `true`,
// the dashboard wraps in `RoleShell` and FCM dispatches through
// `ShellNav.goToGlobal` so notifications land in the correct tab.
//
// Wire to `--dart-define=ENABLE_SHELL=true` for internal builds.
const bool kEnableShell = bool.fromEnvironment(
  'ENABLE_SHELL',
  defaultValue: false,
);
