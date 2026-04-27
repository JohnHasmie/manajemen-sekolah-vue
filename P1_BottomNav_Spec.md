# P1 — Bottom Nav Shell — Implementation Spec

> Status: **draft** · awaiting Yahya sign-off on tab assignments + open questions
> Companion: `UI_Redesign_Audit.md` (P1 proposal), `_baseline/CAPTURE_CHECKLIST.md`

This doc turns P1 from a proposal into something an engineer can build from. It
covers: tab taxonomy per role, the `RoleShell` widget contract, migration shim
strategy, FCM/deep-link compatibility, tab persistence rules, safe-area
handling, and a numbered open-questions list for Yahya to answer before
implementation starts.

---

## 1. Goals & non-goals

**Goals**

- Replace "dashboard-as-router" with a persistent per-role bottom nav. Every
  screen reachable from a tab; the dashboard becomes one tab among several
  (Beranda) instead of the de-facto navigation hub.
- Per-tab back stacks, so tapping Beranda → Akademik → RPP detail → Beranda →
  Akademik returns to RPP detail (not the Akademik root).
- Zero-regression for FCM deep-links, school switching, account sheet, and
  language switching.
- Land *under* the existing `Dashboard` widget so feature teams keep working
  while we peel screens out tab-by-tab.

**Non-goals**

- Redesigning the dashboard itself (that's P2).
- Folding wali-kelas into the IA (that's P3).
- Settings consolidation (that's P4).
- Animations/transitions polish (later).

---

## 2. Tab taxonomy

### 2.1 Admin (5 tabs)

| Tab | Icon | Indonesian label | Tab root |
|---|---|---|---|
| Beranda | `Icons.home_outlined` | Beranda | `AdminBerandaScreen` (today + pending inbox + quick actions, P2 will trim) |
| Orang | `Icons.people_outline` | Orang | `AdminOrangHubScreen` (Siswa / Guru / Kelas tiles) |
| Akademik | `Icons.menu_book_outlined` | Akademik | `AdminAkademikHubScreen` (Mapel / Jadwal / Nilai / RPP / Raport / Pengumuman / Kegiatan / Presensi) |
| Keuangan | `Icons.account_balance_wallet_outlined` | Keuangan | `AdminKeuanganHubScreen` (current `FinanceScreen`, lightly refactored) |
| Sistem | `Icons.settings_outlined` | Sistem | `SystemSettingsScreen` (already exists) |

**Per-screen mapping.** Existing screen → tab → root or push.

| Screen file | Tab | Position | Notes |
|---|---|---|---|
| `dashboard_screen.dart` (admin fork) | Beranda | root | Wrapped by `RoleShell` from outside; internal layout unchanged in P1. |
| `notification_list_screen.dart` | Beranda | push | Triggered by app-bar bell icon; lives at `Beranda` stack so Beranda badge clears. |
| `admin_student_management_screen.dart` | Orang | push from `AdminOrangHubScreen` | Or root if we collapse hub (open question Q1). |
| `admin_teacher_management_screen.dart` | Orang | push | |
| `admin_classroom_management_screen.dart` | Orang | push | Kelas is a people-grouping → Orang. |
| `student_detail_screen.dart` | Orang | push (deep) | Also reachable from Akademik (e.g. grade row tap) — see §6.2. |
| `teacher_detail_screen.dart` | Orang | push (deep) | |
| `admin_subject_management_screen.dart` | Akademik | push | |
| `admin_schedule_management_screen.dart` | Akademik | push | |
| `admin_grade_overview_screen.dart` | Akademik | push | |
| `admin_lesson_plan_screen.dart` | Akademik | push | |
| `admin_report_card_screen.dart` | Akademik | push | |
| `admin_announcement_screen.dart` | Akademik | push | Justification: pengumuman is mostly academic comms. Open Q5. |
| `admin_class_activity_screen.dart` | Akademik | push | |
| `admin_attendance_report_screen.dart` | Akademik | push | |
| `admin_finance_screen.dart` | Keuangan | root | |
| `class_finance_report_screen.dart` | Keuangan | push | Drill-down from finance hub. |
| `system_settings_screen.dart` | Sistem | root | |
| `school_settings_screen.dart` | Sistem | push | |
| `school_level_settings_screen.dart` | Sistem | push | |
| `time_settings_screen.dart` | Sistem | push | |
| `data_management_screen.dart` | Sistem | push | |
| `settings_screen.dart` | Sistem | push (account) | "Akun" tile inside Sistem. Also reachable from app-bar avatar (see §6.3). |

**Total: 22 admin screens, 5 tabs.** Hub roots add 3 new screens
(`AdminOrangHubScreen`, `AdminAkademikHubScreen`, `AdminKeuanganHubScreen`
likely re-uses `FinanceScreen` so net +2). Sistem already has `SystemSettingsScreen`.

### 2.2 Teacher (4 tabs)

| Tab | Icon | Indonesian label | Tab root |
|---|---|---|---|
| Beranda | `Icons.home_outlined` | Beranda | `TeacherBerandaScreen` (today's schedule, KPIs) |
| Mengajar | `Icons.school_outlined` | Mengajar | `TeacherMengajarHubScreen` (Jadwal / RPP / Materi / Kegiatan) |
| Nilai & Absensi | `Icons.fact_check_outlined` | Nilai & Absensi | `TeacherNilaiHubScreen` (Rekap / Input / Buku Nilai / Absensi / Raport) |
| Lainnya | `Icons.more_horiz` | Lainnya | `TeacherLainnyaHubScreen` (Pengumuman / Rekomendasi Belajar / Akun) |

| Screen file | Tab | Position | Notes |
|---|---|---|---|
| `dashboard_screen.dart` (guru fork) | Beranda | root | |
| `notification_list_screen.dart` | Beranda | push | |
| `teacher_schedule_screen.dart` | Mengajar | push | Or root if Q1 = collapse hubs. |
| `teacher_lesson_plan_screen.dart` | Mengajar | push | |
| `lesson_plan_detail_screen.dart` | Mengajar | push (deep) | |
| `lesson_plan_ai_result_screen.dart` | Mengajar | push (deep) | |
| `teacher_material_screen.dart` | Mengajar | push | |
| `sub_chapter_detail_screen.dart` | Mengajar | push (deep) | |
| `teacher_class_activity_screen.dart` | Mengajar | push | Justification: Kegiatan Kelas is a teaching record, not grading. Open Q4. |
| `embedded_activity_list_screen.dart` | Mengajar | push (deep) | |
| `teacher_grade_recap_screen.dart` | Nilai & Absensi | push | |
| `teacher_grade_input_screen.dart` | Nilai & Absensi | push | |
| `grade_book_screen.dart` | Nilai & Absensi | push (deep) | |
| `teacher_attendance_screen.dart` | Nilai & Absensi | push | Also entry point for wali-kelas attendance (toggle inside). |
| `teacher_report_card_screen.dart` | Nilai & Absensi | push | Raport is grade output → grouped with Nilai. |
| `report_card_detail_screen.dart` | Nilai & Absensi | push (deep) | |
| `teacher_announcement_screen.dart` | Lainnya | push | Comms = secondary for guru. |
| `recommendation_class_screen.dart` | Lainnya | push | AI feature. |
| `recommendation_student_screen.dart` | Lainnya | push (deep) | |
| `recommendation_edit_screen.dart` | Lainnya | push (deep) | |
| `recommendation_result_screen.dart` | Lainnya | push (deep) | |
| `settings_screen.dart` | Lainnya | push | "Akun" tile. |

**Wali-kelas note.** Wali-kelas is *not* a separate tab. The role-toggle stays
inside the relevant Nilai & Absensi screens (current `RoleToggle` pattern via
`teacher_grade_recap_screen.dart`, `teacher_attendance_screen.dart`). P3 will
revisit, but P1 keeps the toggle exactly where it is.

**Total: 18 teacher screens, 4 tabs.** Hub roots add 3 new (Mengajar, Nilai,
Lainnya).

### 2.3 Parent (4 tabs)

| Tab | Icon | Indonesian label | Tab root |
|---|---|---|---|
| Beranda | `Icons.home_outlined` | Beranda | `ParentBerandaScreen` (anak status, today) |
| Akademik | `Icons.menu_book_outlined` | Akademik | `ParentAkademikHubScreen` (Nilai / Raport / Kegiatan / Pengumuman) |
| Kehadiran | `Icons.event_available_outlined` | Kehadiran | `ParentAttendanceScreen` (root, no hub) |
| Keuangan | `Icons.account_balance_wallet_outlined` | Keuangan | `ParentBillingScreen` (root, no hub) |

| Screen file | Tab | Position | Notes |
|---|---|---|---|
| `dashboard_screen.dart` (wali fork) | Beranda | root | |
| `notification_list_screen.dart` | Beranda | push | |
| `parent_grade_screen.dart` | Akademik | push | |
| `parent_class_activity_screen.dart` | Akademik | push | |
| `parent_announcement_screen.dart` | Akademik | push | |
| `parent_report_card_screen.dart` | Akademik | push | |
| `parent_report_card_detail_screen.dart` | Akademik | push (deep) | |
| `parent_attendance_screen.dart` | Kehadiran | root | Tab tap goes straight to attendance, no hub. |
| `parent_billing_screen.dart` | Keuangan | root | Tab tap goes straight to billing, no hub. |
| `settings_screen.dart` | Beranda | push | App-bar avatar → account screen. Open Q3 — could move to a 5th tab. |

**Total: 9 parent screens, 4 tabs.** Hub roots add 1 new (Akademik). Kehadiran
and Keuangan re-use existing screens as their roots.

---

## 3. Shell widget contract

### 3.1 Public API

```dart
/// Persistent role-aware shell. Wraps role-specific content with a bottom
/// navigation bar. One instance per session, mounted directly under
/// MaterialApp by the root router.
class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({
    super.key,
    required this.role,                  // 'admin' | 'guru' | 'wali'
    this.initialTab = ShellTab.beranda,  // for deep-link support
  });

  final String role;
  final ShellTab initialTab;
}

enum ShellTab { beranda, orang, akademik, keuangan, sistem, mengajar, nilai, kehadiran, lainnya }
```

Not every role uses every `ShellTab`. The shell consults a per-role tab list:

```dart
// lib/core/shell/role_tabs.dart
const Map<String, List<ShellTab>> kRoleTabs = {
  'admin': [ShellTab.beranda, ShellTab.orang, ShellTab.akademik, ShellTab.keuangan, ShellTab.sistem],
  'guru':  [ShellTab.beranda, ShellTab.mengajar, ShellTab.nilai, ShellTab.lainnya],
  'wali':  [ShellTab.beranda, ShellTab.akademik, ShellTab.kehadiran, ShellTab.keuangan],
};
```

### 3.2 Internal structure

```
RoleShell (Scaffold)
├── body: IndexedStack(children: [TabBranch × N])
│   └── TabBranch (Navigator with own GlobalKey<NavigatorState>)
│       └── tab root screen (e.g. AdminBerandaScreen)
│           └── pushed screens stack on top of this navigator
└── bottomNavigationBar: BottomNavigationBar
    └── onTap: shellNotifier.setTab(...) (no Navigator.push)
```

Why `IndexedStack` (not `PageView`/`AnimatedSwitcher`):

- Preserves widget state across tab switches (Beranda's scroll position
  doesn't reset when you visit Akademik and come back).
- No swipe-between-tabs gesture (we don't want it — accidentally swiping out
  of a 5-tab grid is annoying, and Samsung gesture nav already uses edge
  swipes for back).

Why per-tab `Navigator` (not the root `Navigator`):

- Tap-twice-on-tab → pop-to-root convention works (iOS-style behavior, Android
  users also expect this).
- Tab back stacks survive switching — required by the per-tab persistence rule
  (§5).

### 3.3 Riverpod state

```dart
// lib/core/shell/shell_controller.dart
class ShellState {
  final ShellTab activeTab;
  final Map<ShellTab, GlobalKey<NavigatorState>> navigatorKeys;
  const ShellState({required this.activeTab, required this.navigatorKeys});
}

final shellProvider = NotifierProvider<ShellNotifier, ShellState>(...);

class ShellNotifier extends Notifier<ShellState> {
  void setTab(ShellTab tab) { ... }
  void popToRoot(ShellTab tab) { ... }
  Future<bool> handleSystemBack() async { ... }  // pops within active tab first
}
```

The shell exposes three operations the rest of the app needs:

- `ref.read(shellProvider.notifier).setTab(ShellTab.akademik)` — switch tab
  programmatically (used by FCM deep-links).
- `ref.read(shellProvider.notifier).popToRoot(ShellTab.akademik)` — pop the
  active tab's stack to its root (used by tap-twice-on-tab and by FCM "go to
  root then push" flows).
- `ref.read(shellProvider.notifier).handleSystemBack()` — wired into
  `WillPopScope`/`PopScope` at the shell root. If the active tab can pop, pops
  it; else if active tab isn't Beranda, switch to Beranda; else allow exit.

### 3.4 App bar ownership

Every tab today renders its own AppBar. Two options:

**Option A — Shell owns the app bar.** `RoleShell` provides a single AppBar
for all tabs, with title/leading/actions injected by the active tab via
`ScopedValue<ShellAppBarConfig>`. Pro: zero-duplication of the school pill,
notification bell, avatar across tabs. Con: more coupling, and pushed screens
inside a tab need their own AppBar (back button) which differs from the root.

**Option B — Each tab root owns its app bar.** Shell provides only the
`bottomNavigationBar`. App bar logic stays in `dashboard_app_bar.dart` and
similar. Pro: zero refactor risk on existing screens. Con: school pill /
notifications icon is re-rendered per tab (cheap, but repetitive code).

**Recommendation: Option B.** Smaller blast radius. We can always merge to A
in a follow-up. Open Q2.

---

## 4. Migration shim

Shipping P1 without breaking the world means rolling out under a feature flag
and behind compatibility shims. Three layers:

### 4.1 Entry-point shim (`Dashboard` keeps working)

`Dashboard(role: 'admin')` is currently the entry widget for all three roles
(constructed inside `main.dart`'s router). We don't break that contract.

```dart
// lib/features/dashboard/presentation/screens/dashboard_screen.dart
class Dashboard extends ConsumerStatefulWidget {
  final String role;
  const Dashboard({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    if (kEnableShell) {
      return RoleShell(role: role);   // new path
    }
    return const _LegacyDashboardBody(); // existing implementation
  }
}
```

`kEnableShell` is a const bool wired to a `--dart-define` flag. Initial value
`false` so the shell ships dark. Feature-flagged rollout: enable for internal
build → admin role only → all roles → flag removed.

### 4.2 Tab-root shim (per-role Beranda)

Each role's Beranda tab root is, on day one, the existing dashboard body
verbatim. We literally re-use the current dashboard widget tree, sans bottom
nav (the shell provides that).

```dart
// lib/core/shell/tabs/admin_beranda_tab.dart
class AdminBerandaTab extends ConsumerWidget {
  @override
  Widget build(...) {
    return AdminDashboardBody(...);  // existing widget, untouched
  }
}
```

This means the dashboard's `HelpersMixin / ContentBuildersMixin / CardsMixin /
DialogMixin` stack keeps working as-is. P2 will refactor the dashboard body
itself — P1 just wraps it.

### 4.3 Push-target shim (`AppNavigator.push` keeps working)

The 387 existing `AppNavigator.push(context, ScreenWidget())` call sites
must continue working. They do, automatically: pushes inside a tab go onto
that tab's `Navigator`, not the root.

The only thing that changes is *where* a `push` lands. If a Beranda screen
calls `AppNavigator.push(context, AdminStudentManagementScreen())`, the
student-management screen pushes onto the Beranda stack — not the Orang
stack. That's surprising, because the user expects "Siswa" to live under
Orang.

Fix: convert "navigate to canonical home" calls to use a new helper.

```dart
// lib/core/shell/shell_nav.dart
class ShellNav {
  /// Switch to the canonical tab, optionally pushing a screen on top.
  static void goTo(BuildContext context, WidgetRef ref, ShellTab tab, {Widget? pushOnTop}) {
    ref.read(shellProvider.notifier).setTab(tab);
    if (pushOnTop != null) {
      // push on the tab's own navigator
      final navKey = ref.read(shellProvider).navigatorKeys[tab]!;
      navKey.currentState?.push(MaterialPageRoute(builder: (_) => pushOnTop));
    }
  }
}
```

Migration: dashboard menu tiles (admin/teacher/parent menu mixins) switch
from `AppNavigator.push` to `ShellNav.goTo`. That's ~30 call sites — the
ones in `admin_menu_items_mixin.dart`, `teacher_menu_items_mixin.dart`,
`parent_menu_items_mixin.dart`. All other 357 call sites stay as
`AppNavigator.push` (correct: pushing a detail screen keeps you in the same
tab).

### 4.4 Phased rollout

1. **Week 1:** Land `RoleShell`, `ShellState`, `ShellNotifier`, hub root
   skeletons. Feature flag off. Existing app unchanged.
2. **Week 1.5:** Flip flag for admin role only on dev/internal builds.
   Validate FCM, school switching, account sheet.
3. **Week 2:** Admin role flag-on for prod. Teacher/parent still on legacy
   path.
4. **Week 2.5:** Teacher + parent flag-on.
5. **Week 3:** Remove `kEnableShell` const, delete the legacy `_LegacyDashboardBody`
   branch, drop dead-menu navigation paths.

Each week ends with a clean commit and a screenshot diff against `_baseline/`.

---

## 5. Tab persistence rules

### 5.1 Per-tab back stack

Each tab owns its `Navigator`. Switching tabs preserves the visited tab's
stack. Example:

```
[Beranda root]                   ← user starts here
→ tap "Akademik" tab
[Akademik root]
→ push "RPP list"
[Akademik root] → [RPP list]
→ push "RPP detail"
[Akademik root] → [RPP list] → [RPP detail]
→ tap "Beranda" tab
[Beranda root]                   ← Akademik stack frozen at [root → list → detail]
→ tap "Akademik" tab
[Akademik root] → [RPP list] → [RPP detail]   ← restored
```

### 5.2 Tap-twice-to-pop-to-root

Standard convention. Tapping the *active* tab again pops that tab to its
root. Implementation:

```dart
onTap: (i) {
  final tappedTab = enabledTabs[i];
  if (tappedTab == state.activeTab) {
    notifier.popToRoot(tappedTab);
  } else {
    notifier.setTab(tappedTab);
  }
}
```

### 5.3 System back button

Per-platform expected behavior:

- **Android** (system back gesture or button): pops within active tab if it
  has anything to pop; else if active tab ≠ Beranda, switch to Beranda; else
  show exit-confirm dialog (existing `WillPopScope` pattern in main.dart, if
  any). Wired via `PopScope` at shell root.
- **iOS** (swipe-from-edge): per-tab default — pops within tab. Same as
  Android but no fallback to Beranda.

### 5.4 Cold start with deep-link

If the app cold-starts with an FCM-tap intent (terminated → opened by
notification), the shell mounts with `initialTab` set to whatever the
notification's `data.type` maps to (see §6).

---

## 6. FCM / deep-link compatibility

### 6.1 Current payload types

From `fcm_message_handler.dart` (read 2026-04-22):

| Payload `type` | Current handler navigation | Notes |
|---|---|---|
| `absensi` / `attendance` | `ParentAttendanceScreen` (parent only) | No teacher/admin handler. Refresh-only for them. |
| `class_activity` / `class_activity_detail` | `ParentClassActivityScreen` | No teacher/admin handler. |
| `pengumuman` / `announcement` | role-aware: admin → `AdminAnnouncementScreen`, default → `ParentAnnouncementScreen` | Teacher route falls through to parent screen — bug. |
| `grade` | `ParentGradeScreen` | No teacher handler. |
| `tagihan` | logged only, no nav | TODO. |
| `refresh_*` | cache invalidation, no nav | Unchanged. |

### 6.2 Mapping payloads to shell tabs

Replace `_router.navigate*` calls with `ShellNav.goTo(...)` so the tab
activates first, then the screen pushes onto that tab's stack.

| Payload `type` | Role | Target tab | Pushed screen |
|---|---|---|---|
| `absensi` / `attendance` | wali | Kehadiran | nothing (root *is* attendance) |
| `absensi` / `attendance` | guru | Nilai & Absensi | `TeacherAttendanceScreen` |
| `absensi` / `attendance` | admin | Akademik | `AdminAttendanceReportScreen` |
| `class_activity*` | wali | Akademik | `ParentClassActivityScreen` |
| `class_activity*` | guru | Mengajar | `TeacherClassActivityScreen` |
| `class_activity*` | admin | Akademik | `AdminClassActivityScreen` |
| `pengumuman` / `announcement` | wali | Akademik | `ParentAnnouncementScreen` |
| `pengumuman` / `announcement` | guru | Lainnya | `TeacherAnnouncementScreen` |
| `pengumuman` / `announcement` | admin | Akademik | `AdminAnnouncementScreen` |
| `grade` | wali | Akademik | `ParentGradeScreen` |
| `grade` | guru | Nilai & Absensi | `TeacherGradeRecapScreen` (pick a sensible default; Q6) |
| `grade` | admin | Akademik | `AdminGradeOverviewScreen` |
| `tagihan` | wali | Keuangan | `ParentBillingScreen` (root, no push) |
| `tagihan` | admin | Keuangan | `AdminFinanceScreen` (root) |

Two payload bugs P1 fixes incidentally: (a) teacher pengumuman currently
opens the parent screen, (b) tagihan currently does nothing. Worth flagging
in the changelog.

### 6.3 App-bar deep-links

The dashboard app bar today provides three "deep" entry points: notifications
bell, account avatar, language switcher.

| App-bar action | Pre-shell behavior | In-shell behavior |
|---|---|---|
| Bell | `Navigator.push(NotificationListScreen)` | Pushes on **active tab's** stack, not Beranda's. Open Q7 — should it always land in Beranda? |
| Avatar | shows `DashboardAccountSheet` (modal) | Modal stays modal, no tab change. |
| Lang | shows `LanguageDialog` (modal) | Modal stays modal. |
| School pill | shows `DashboardSchoolSelectionDialog` (modal) | Modal stays modal. **Switching schools triggers `dashboardProvider.initialize`**, which currently rebuilds the whole dashboard. Inside a shell, only the Beranda tab needs to rebuild. Other tabs reload lazily on next visit. See Q8. |

---

## 7. Safe-area & responsive

### 7.1 Bottom nav height + safe-area

Samsung devices (primary target) reserve gesture-bar space at the bottom.
Material's `BottomNavigationBar` handles this when the parent `Scaffold` has
`extendBody: false` (default). Concretely:

```dart
return Scaffold(
  // No extendBody, no extendBodyBehindAppBar
  body: SafeArea(top: false, bottom: false, child: IndexedStack(...)),
  bottomNavigationBar: BottomNavigationBar(...), // SafeArea handled internally
);
```

Existing `AppBottomSheet` already does the right thing per CLAUDE.md ("Don't
double-pad"). The shell follows the same rule: don't wrap the
`BottomNavigationBar` in a second `SafeArea`.

### 7.2 Scrim & keyboard avoidance

When a tab pushes a screen with a focused `TextField`, the keyboard appears.
Default Flutter behavior pushes the bottom nav up with the keyboard, which
*looks broken* in our design (the nav floats over content).

Fix: `Scaffold(resizeToAvoidBottomInset: true)` at the shell level keeps the
nav fixed while the body resizes. Verified pattern from
`update_status_sheet.dart`'s footer composition.

### 7.3 Tablet & landscape

Out of scope for P1. Mobile portrait only. `MediaQuery.of(context).orientation`
isn't checked; we assume portrait. If we add tablet later, the shell becomes
a `NavigationRail` on the left for landscape — but that's a follow-up.

---

## 8. Testing checklist

The implementation isn't done until the following pass:

**Unit / widget**

- [ ] Tab switch preserves stack (push to Akademik → switch → switch back → still on detail)
- [ ] Tap-active-tab pops to root (with at least 2 levels in stack)
- [ ] System back pops within tab before switching tabs
- [ ] System back from Beranda root shows exit dialog (or quits, per existing convention)
- [ ] FCM payload `pengumuman` for guru lands in Lainnya tab + pushes correct screen
- [ ] FCM payload `tagihan` for admin lands in Keuangan tab
- [ ] School-switch from Beranda app bar reloads only Beranda content (other tabs lazy-reload)
- [ ] `kEnableShell=false` renders legacy dashboard exactly as before

**Manual**

- [ ] Cold start → land on Beranda
- [ ] Cold start with notification (terminated) → lands on correct tab
- [ ] Background-tap notification (app open) → switches tab without losing other tab states
- [ ] Samsung gesture-bar safe area: bottom nav doesn't overlap gesture indicator
- [ ] Keyboard up on a TextField inside a pushed screen: nav stays put, body resizes

**Visual diff**

- [ ] Per-role screenshot pass against `_baseline/` — no regressions on
      pushed screens (their look hasn't changed)
- [ ] New screenshot: bottom nav row in `_after/{admin,teacher,parent}/00_shell.png`

---

## 9. File plan

New files:

```
lib/core/shell/
├── role_shell.dart                  # Scaffold + IndexedStack + BottomNav
├── shell_controller.dart            # ShellNotifier, ShellState
├── shell_nav.dart                   # ShellNav.goTo helper
├── shell_tab.dart                   # ShellTab enum
├── role_tabs.dart                   # kRoleTabs map
└── tabs/
    ├── admin_beranda_tab.dart       # wraps existing AdminDashboardBody
    ├── admin_orang_tab.dart         # AdminOrangHubScreen
    ├── admin_akademik_tab.dart      # AdminAkademikHubScreen
    ├── admin_keuangan_tab.dart      # wraps FinanceScreen
    ├── admin_sistem_tab.dart        # wraps SystemSettingsScreen
    ├── teacher_beranda_tab.dart
    ├── teacher_mengajar_tab.dart
    ├── teacher_nilai_tab.dart
    ├── teacher_lainnya_tab.dart
    ├── parent_beranda_tab.dart
    ├── parent_akademik_tab.dart
    ├── parent_kehadiran_tab.dart    # wraps ParentAttendanceScreen
    └── parent_keuangan_tab.dart     # wraps ParentBillingScreen
```

Modified files:

```
lib/features/dashboard/presentation/screens/dashboard_screen.dart   # add kEnableShell branch
lib/features/dashboard/presentation/widgets/admin_menu_items_mixin.dart  # AppNavigator.push → ShellNav.goTo
lib/features/dashboard/presentation/widgets/teacher_menu_items_mixin.dart  # same
lib/features/dashboard/presentation/widgets/parent_menu_items_mixin.dart   # same
lib/core/services/fcm_notification_router.dart                      # _navigate → ShellNav.goTo
lib/main.dart                                                       # Dashboard widget construction unchanged
```

Estimated diff: +900 lines new, ~150 lines touched.

---

## 10. Open questions for Yahya

These need answers before implementation starts. Numbered so we can resolve
in chat by quoting the number.

**Q1 — Hub roots vs. flat tab roots.**
Should Orang tab tap go to `AdminOrangHubScreen` (a 3-tile picker for
Siswa/Guru/Kelas) or skip the hub and go straight to the most-used child
(probably `AdminStudentManagementScreen`)? Hub is more discoverable; flat is
faster. Same question applies to Akademik (8 children!), Mengajar, Nilai,
parent Akademik. *My recommendation:* hub for Akademik (too many children),
flat-with-tab-bar for Mengajar/Nilai/Orang (3-5 children — a row of segment
tabs at the top is faster than a hub).

**Q2 — Shell-owns-app-bar vs. tab-owns-app-bar.**
§3.4 leans tab-owns. Yes/no — or punt to a follow-up?

**Q3 — Where does parent's "Akun"/Settings live?**
No tab for it. Options: (a) avatar in Beranda's app bar opens it as a modal,
(b) "Akun" tile inside Beranda's quick actions, (c) add a 5th Lainnya tab.
*My recommendation:* (a). Lowest noise.

**Q4 — Teacher's Kegiatan Kelas: Mengajar or Nilai?**
It's a record-keeping action. Putting in Mengajar (lesson-related) keeps
Nilai focused on assessment. Yes/no?

**Q5 — Admin's Pengumuman: Akademik or Sistem?**
Pengumuman is school-wide communication. If we read it as "system tool" it
goes in Sistem. If we read it as "academic announcement" (most use cases),
it goes in Akademik. Yes/no?

**Q6 — `grade` FCM payload for guru: Rekap or Input?**
Default landing screen when a teacher taps a grade notification. Rekap is
read-mostly; Input is action. *My recommendation:* Rekap, because the
notification is informational (a parent inquired, a grade was published).

**Q7 — Notification bell deep-link: active tab or always Beranda?**
If a guru is in Mengajar > RPP detail and taps the bell, do notifications
push onto Mengajar's stack or switch to Beranda first? *My recommendation:*
always Beranda. Notifications are global, not tab-scoped — putting them in
Mengajar is confusing because back goes to RPP detail, which has nothing to
do with notifications.

**Q8 — School switch reload behavior.**
When admin switches schools mid-session, all tabs need to reload their data.
Options: (a) blow up shell state, force re-mount everything (clean, slow);
(b) invalidate per-tab providers, let lazy reload happen on next visit
(fast, but stale data on inactive tabs); (c) eager reload all tabs in
parallel (lots of network). *My recommendation:* (b). Tabs reload-on-visit
because each tab root already does its own pull-to-refresh.

**Q9 — Ship as one PR or split.**
The diff is +900 LOC across many files. Single PR makes review hard but
keeps the rollout atomic. Splitting (1: shell skeleton; 2: admin migration;
3: teacher; 4: parent; 5: FCM rewire) makes review easier but extends the
flag-on window. *My recommendation:* one PR, behind a flag, internal review,
flag-on incrementally per role.

**Q10 — Keep FCM `_router` class or fold into `ShellNav`?**
`FCMNotificationRouter` becomes a thin wrapper around `ShellNav.goTo`.
Either delete it (call `ShellNav.goTo` directly from
`FCMNotificationHandler.handleTap`) or keep the wrapper for future
indirection. *My recommendation:* delete. One less class, less surface area.

---

## 11. After P1 lands — what changes for P2/P3/P4

- **P2 (dashboard reduction).** Beranda tab root currently *is* the existing
  dashboard verbatim. P2 removes the categorized-menu section (now lives in
  Akademik/Orang hub roots) and trims overview cards down to "today's
  status". Shell unchanged.
- **P3 (wali-kelas folding).** RoleToggle stays in Nilai & Absensi tab. P3
  decides whether to keep the toggle (current) or split wali-kelas into a
  5th teacher tab. Shell tab list grows or shrinks accordingly.
- **P4 (settings consolidation).** Sistem tab gets all settings under one
  hub. No shell change.

P1 doesn't *block* P5 (grade unification) or P6 (per-screen density) — those
are independent.
