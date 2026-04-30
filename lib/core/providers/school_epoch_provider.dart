// School-switch epoch counter.
//
// Why this exists
// ---------------
// When a parent / teacher / admin switches school within the same role
// (the "Pilih Sekolah" sheet on the dashboard), the dashboard
// reinitialises but the rest of the role's tab tree stays mounted
// inside the `RoleShell.IndexedStack`. Because each tab's
// `ConsumerState` keeps its existing data (announcements, billing,
// activity, attendance, grades, raport) the screens still show the
// previous school's payload until a hot-restart wipes the widget tree.
//
// Bumping `schoolEpochProvider` after every successful school switch
// is what every dependent surface watches: `RoleShell` keys its tab
// subtree on it so a bump forces the whole IndexedStack to unmount +
// remount, which kicks each tab's `initState` and triggers a fresh
// `loadData` against the new active school.
//
// We use a plain `StateProvider<int>` instead of stamping the school
// id directly because the shell only needs to know "did it change?",
// not what the new value is — and an int that monotonically increases
// is a stable cache-buster across multi-tap switches even when the
// user toggles back to a previously-active school.
//
// Note: this project is on Riverpod 3.x where `StateProvider` and the
// other "legacy" providers were moved to `flutter_riverpod/legacy.dart`.
// The `WidgetRef` / `Ref` types still come from the main package.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;

/// Monotonically-increasing counter that bumps on every school switch.
/// Use as the key for any subtree whose state must be wiped when the
/// active school context changes.
final schoolEpochProvider = legacy.StateProvider<int>((_) => 0);

/// Convenience helper — call from any controller / handler that
/// performs a school switch. Equivalent to:
/// `ref.read(schoolEpochProvider.notifier).state += 1`.
void bumpSchoolEpoch(WidgetRef ref) {
  ref.read(schoolEpochProvider.notifier).state += 1;
}

/// Same helper for non-widget Ref (e.g. from inside a Notifier).
void bumpSchoolEpochFromRef(Ref ref) {
  ref.read(schoolEpochProvider.notifier).state += 1;
}
