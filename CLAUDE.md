# KamilEdu Mobile — Claude Working Guide

This file is the contract for how Claude adds, edits, or refactors code in the
Flutter app. It distills the conventions that came out of the admin, teacher,
and parent refactors so new work stays on the same rails. When the app's
README explains *what the app does*, this file explains *how to change it*.

Companion docs:
- `README.md` — architecture + feature-by-role overview.
- `lib/core/widgets/README.md` — the full shared-component catalog (imports,
  prop shapes, consumers).
- `Admin_Refactor_TODOs.md` — the admin migration plan and compliance
  checklist.
- `REFACTORING_AUDIT.md` / `REFACTORING_PLAN.md` — earlier audit notes kept
  for historical context.

---

## The one rule

**Satu implementasi, tiga role** — one implementation, three role consumers.
Every admin / teacher / parent screen reaches for the same scaffolds, sheets,
filters, and dialogs. If a feature folder is about to build a local dialog,
filter, or edit form, stop and pick the shared component from
`lib/core/widgets/` first.

---

## Directory layout

```
lib/
├── main.dart                         # bootstrap + routing
├── core/
│   ├── constants/app_spacing.dart    # AppSpacing.xs/sm/md/lg/xl — no raw EdgeInsets numbers
│   ├── router/app_navigator.dart     # AppNavigator.push/pop — no raw Navigator.pop
│   ├── utils/color_utils.dart        # ColorUtils.getRoleColor('admin'|'teacher'|'parent')
│   ├── utils/snackbar_utils.dart     # SnackBarUtils.showSuccess/showError — one API
│   └── widgets/                      # THE shared component catalog (see README there)
├── features/
│   └── <feature>/
│       ├── data/                     # services, query/CRUD helpers
│       ├── domain/models/            # PODO models
│       └── presentation/
│           ├── screens/              # AdminXScreen / TeacherXScreen / ParentXScreen
│           ├── widgets/              # feature-local widgets (keep thin)
│           └── mixins/               # screen mixins — be wary, they grow
└── l10n/                             # AppLocalizations.<key>.tr
```

When adding a new feature, mirror this layout. Shared components live under
`lib/core/widgets/`; only put a widget in a feature folder if it is genuinely
local (e.g. `activity_detail_row.dart`). If you see a feature-local widget
that looks reusable, promote it rather than copying.

---

## Shared components — reach for these first

Full catalog: `lib/core/widgets/README.md`. Quick map of what to pick when:

| You want to… | Use | Don't |
|---|---|---|
| Host an admin CRUD list + FAB + filter + bulk | `AdminCrudScaffold` | Hand-roll AppBar + FAB + search |
| Open a bottom sheet for add/edit | `AppEditBottomSheet` or `AppBottomSheet` + `BottomSheetFooter` (when primary reads body state) | `showDialog` / `showModalBottomSheet` directly |
| Open a bottom sheet for filtering | `AppFilterBottomSheet` + `TeacherFilterContent` | Custom filter sheet per feature |
| Render an async list (loading/error/empty/content) | `TeacherAsyncView` (legacy name, role-neutral) | Hand-rolled `if (isLoading) … else if (error) …` |
| Confirm a destructive action | `ConfirmationDialog` / `ActionConfirmSheet` | `showDialog(AlertDialog(...))` |
| Show a search bar on a list screen | `EnhancedSearchBar` / `SearchFilterBar` | Bare `TextField` |
| Show a date picker | `ModernDatePicker` | `showDatePicker` directly |
| Show a rich-text editor | `AppQuillEditor` | Raw `QuillController` |
| Switch between list/matrix/grid | `ViewToggleButton` | Icon-button pair |
| Show active filters under the search bar | `ActiveFilterChips` | Ad-hoc `Wrap` of chips |
| Show role switcher (guru ↔ wali-kelas) | `RoleToggle` | Custom `Switch` row |
| Show a KPI card on a dashboard | `HeroStatsCard` / `StatSummaryCard` | Custom Card + Text stack |
| Show the school pill in the AppBar | `SchoolPill` (compact / expanded) | `PopupMenuButton` |
| Show a Samsung-safe sheet footer | `BottomSheetFooter` | Hand-rolled Cancel/Save row |
| Show bulk-select actions | `BulkActionBar` | Custom bottom bar |

### Composition pattern for sheets that read body state

`AppEditBottomSheet` pre-wires a Batal/Simpan footer. But when the primary
button needs to read controllers or local form state, compose manually:

```dart
return AppBottomSheet(
  title: 'Update Status RPP',
  subtitle: 'Ubah status persetujuan RPP',
  icon: Icons.swap_horiz_rounded,
  primaryColor: primary,
  content: _buildBody(),
  footer: BottomSheetFooter(
    primaryLabel: _isUpdating ? 'Menyimpan...' : 'Update Status',
    primaryColor: primary,
    primaryEnabled: !_isUpdating,
    onPrimary: _updateStatus,
    onSecondary: _isUpdating ? () {} : () => AppNavigator.pop(context),
  ),
);
```

The outer widget stays a `StatefulWidget` / `ConsumerStatefulWidget` that owns
`_controller`, `_selected`, `_isUpdating`, etc. Reference:
`lib/features/lesson_plans/presentation/widgets/update_status_sheet.dart`.

---

## Don't-dos (fast checklist)

- Don't `showDialog(AlertDialog(...))` for add/edit/filter flows.
- Don't `showModalBottomSheet` directly — route through the
  `App*BottomSheet.show()` wrappers.
- Don't hand-roll a Cancel/Save footer row. Use `BottomSheetFooter`.
- Don't use bare `TextField` for list-screen search.
- Don't duplicate a widget in a feature folder if a shared equivalent exists.
  Extend the shared one.
- Don't hard-code colors — go through `ColorUtils` (role color, status color,
  slate scale, success/warning/error).
- Don't hard-code paddings — use `AppSpacing.xs/sm/md/lg/xl`.
- Don't call `Navigator.pop(context)` directly — use `AppNavigator.pop` so
  navigation stays observable from the app-level router.
- Don't show snackbars with `ScaffoldMessenger.of(context).showSnackBar(...)` —
  use `SnackBarUtils.showSuccess` / `showError`.
- Don't write literals for BIN strings ("Pending", "Approved") without also
  mapping them to display labels ("Menunggu", "Disetujui", "Ditolak").

---

## Strings, colors, navigation

- **Bahasa Indonesia** for every user-visible string. Error messages too.
- **Status vocab**: backend uses `Pending / Approved / Rejected`; the UI shows
  `Menunggu / Disetujui / Ditolak`. Always map at the boundary
  (see `update_status_sheet.dart`'s `_mapInitialStatus` helper).
- **Role colors**: `ColorUtils.getRoleColor('admin' | 'teacher' | 'parent')`.
  Admin is navy, teacher is teal, parent is violet. No hex literals in
  presentation code.
- **Navigation**: `AppNavigator.push(context, screen)` /
  `AppNavigator.pop(context, result)`. The latter is what you return from a
  sheet with `true` to tell the caller to refresh.

---

## Async data pattern

Wrap every list-screen body in `TeacherAsyncView`. It owns the loading /
error / empty / content chain so you don't re-implement it per feature.

```dart
TeacherAsyncView(
  state: state,                       // loading | error | empty | content
  onRetry: () => _reload(),
  emptyTitle: 'Belum ada data',
  child: _list,
);
```

Pull-to-refresh goes through `AppRefreshIndicator`. Pagination on long lists
uses `PaginatedListView`.

---

## Adding a new admin CRUD screen (checklist)

Given `AdminXScreen` for some entity X:

1. Build `screens/admin_x_screen.dart` using `AdminCrudScaffold`. Target <100
   lines of screen code.
2. Build `widgets/x_edit_sheet.dart` using `AppEditBottomSheet`
   (or `AppBottomSheet` + `BottomSheetFooter` if the primary needs body
   state). Fields use `ColorUtils` + `AppSpacing`.
3. Build filter content by composing `TeacherFilterContent` where possible;
   fall through to `FilterSectionHeader` + `FilterChipGrid` only for
   atypical sections.
4. Destructive actions (Hapus, Arsipkan) go through `ConfirmationDialog`.
5. Long-press selection → `BulkActionBar` with Pindah / Ekspor / Hapus.
6. Empty / error states → `EmptyState` / `ErrorScreen`. No inline `Text('Error')`.
7. Run `dart format` on every file touched and `dart analyze` on the feature.

Reference screens to copy the pattern from:
`admin_student_management_screen.dart`, `admin_teacher_management_screen.dart`,
`admin_classroom_management_screen.dart`.

---

## Adding a sheet (checklist)

1. Decide: can `AppEditBottomSheet.show(...)` fit? If the primary action can
   be a single onSave callback that captures the form state at call time —
   yes. If the primary's label, enabled state, or handler depend on live body
   state (e.g. _isUpdating, _selectedStatus), compose manually with
   `AppBottomSheet` + `BottomSheetFooter`.
2. Accept a `VoidCallback? onSaved` or return `Future<bool?>` from the
   entry-point helper. Callers use the return value to refresh.
3. The helper function (e.g. `showXSheet`) belongs next to the widget file
   and is the only public API — don't export the private `_XSheet` widget.
4. Inside, own the state in a `State` / `ConsumerState`. Dispose controllers.
5. Submit state via `SnackBarUtils.showSuccess/showError` — never raw
   SnackBar.
6. Error messages are Bahasa Indonesia:
   `'${AppLocalizations.failedToUpdate.tr}: $e'`.

---

## File management inside a sandboxed session

The mount Claude sees for this repo may not allow `unlink` syscalls. That
means `rm` / `git rm` / deleting a file during a session may fail with
`Operation not permitted`. Two workarounds that are known to work:

1. **Rewrite the file in place** — use `Write` to overwrite. The on-disk
   file stays, but its contents become a one-line deprecation shim that
   re-exports the new API. Git still sees a diff.
2. **Rename across directories within the same filesystem** — `mv` is
   implemented as `rename(2)` and does not require unlink. Moving a
   now-dead file into a gitignored directory (e.g. `.dart_tool/_archived_*`)
   takes it out of `lib/` and lets `git rm` / `git status` record the
   deletion correctly.

Only use these workarounds when a real delete would be cleaner outside the
sandbox; flag them in the commit message so a follow-up on a dev machine can
finish the cleanup.

---

## Git hygiene

- **One commit per phase / focused change.** Mixed-concern commits defeat
  bisecting.
- **Conventional commits**:
  `refactor(lesson-plans): migrate UpdateStatusDialog to AppBottomSheet`,
  `feat(admin): Phase 4 — Pengumuman compose + LP regen sheet`,
  `fix(attendance): resolve wali kelas data inconsistency`.
- **Trailer on every Claude commit**:
  `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`.
- **Identity via flags**, not `git config`:
  `git -c user.email=yahyahasymi@gmail.com -c user.name="Yahya Hasymi" commit ...`.

If `.git/index.lock` or `.git/HEAD.lock` is stuck (sandbox bind-mount quirk),
rename it out of the way with `mv .git/index.lock .git/objects/_stale_idx_$(date +%s)`
rather than trying to `rm` it.

---

## Verification before committing

For any non-trivial change:

1. `dart format` on new + modified files.
2. `dart analyze` on the feature directory.
3. Scan for leftover imports of the old widget (`grep` the old symbol).
4. Check the companion mixin or header mixin doesn't still reference the
   old entry point (e.g. `showUpdateStatusDialog` is held as a method
   name on `HeaderBuilderMixin` — if you rename it, update both call sites).
5. Manual UI check if the change is visual. Screenshot diffs go under
   `_baseline/` / `_after/` per the refactor plan.

---

## Common edge cases

- **Mixin method-name back-compat.** Sometimes a screen mixin contract
  (`showUpdateStatusDialog(context, status)`) is held as an abstract method
  by a separate `HeaderBuilderMixin`. Renaming the call site means renaming
  the contract. When in doubt, keep the old method name and delegate
  internally to the new sheet — the contract stays stable, the
  implementation improves.
- **Dual-view toggle state.** The filter state is the single source of truth.
  Both list and matrix (jadwal) views read the same filter chips; switching
  views must not re-query or reset filters.
- **Samsung nav-bar safe area.** `AppBottomSheet` already handles this via
  `SafeArea(top: false)` inside its Container. Don't double-pad. If a sheet
  looks off on Samsung devices, it's almost always because something outside
  `AppBottomSheet` added `SafeArea` a second time.
- **Cross-DB references.** The AI backend (`kamiledu-ai`) stores references
  to core tables (schools, teachers, students) without FK constraints — the
  enforcement is application-level. Don't try to add cross-DB FKs in
  migrations; they'll silently break.

---

## When something seems to want a new abstraction

Before creating a new widget in `lib/core/widgets/`:

1. Is there an existing component that could take one more prop?
2. If you added the prop, would the existing consumers stay unchanged?
3. Does the new component carve a sharp seam, or is it a thin wrapper?

If the answer to (1)/(2) is yes, extend. If you need a new component, add it
to `lib/core/widgets/`, document it in `lib/core/widgets/README.md`, and add
a row to the inventory table in `Admin_Refactor_TODOs.md`.
