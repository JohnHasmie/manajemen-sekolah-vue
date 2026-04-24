# Shared Widgets

Canonical components used across admin, teacher, and parent roles. The rule:
**satu implementasi, tiga role** — one implementation, three role consumers.
Before building a new dialog, sheet, filter, or list chrome, reach for one
of these first.

See `Admin_Refactor_TODOs.md` (project root) for the full migration plan and
the per-screen compliance checklist.

---

## Scaffolds

### `AdminCrudScaffold` — `admin_crud_scaffold.dart`
One-screen scaffold for every admin CRUD entity (Siswa, Guru, Kelas, Mapel,
Jadwal). Ties together AppBar + school pill + search bar + active-filter
chips + async body + FAB + optional `BulkActionBar`.
Consumed by: `admin_student_management_screen`, `admin_teacher_management_screen`,
`admin_classroom_management_screen`, `admin_subject_management_screen`,
`admin_schedule_management_screen`.

### `AppBottomSheet` — `app_bottom_sheet.dart`
Drag-handle → gradient-header → scrollable-body → Samsung-safe footer.
Accepts a `Widget footer` (usually `BottomSheetFooter`).

### `AppEditBottomSheet` — `app_edit_bottom_sheet.dart`
Thin wrapper around `AppBottomSheet` that pre-wires a
Batal/Simpan footer. Use when the primary action is a single save callback
owned by the caller. When the primary button needs to read body state
(controllers, form fields), compose `AppBottomSheet` + `BottomSheetFooter`
manually inside a `StatefulWidget`.

### `AppFilterBottomSheet` — `filter_bottom_sheet.dart`
Canonical filter sheet. Pair with `TeacherFilterContent` (or your own
composition of `FilterSectionHeader` + `FilterChipGrid`) for the body.
Never call `showModalBottomSheet` directly for filters.

### `TeacherAsyncView` — `teacher_async_view.dart`
State-chain wrapper: loading → error → empty → content. Every list screen
body should go through this so state rendering stays consistent. (Name is
legacy — also serves admin and parent.)

---

## Sheet building blocks

### `BottomSheetHeader` — `bottom_sheet_header.dart`
Gradient header with icon + title + subtitle + close button. Used by
`AppBottomSheet` internally; rarely called directly.

### `BottomSheetFooter` — `bottom_sheet_footer.dart`
Samsung-safe footer row: secondary (Batal) + optional danger (Hapus) +
primary (Simpan). Use for every sheet footer — no hand-rolled
Cancel/Save rows.

### `FilterSectionHeader` — `filter_section_header.dart`
Leading icon + section title for filter sheets. One per chip group.

### `FilterChipGrid` — `filter_chip_grid.dart`
Multi-select chip grid with shared selected-style. Paired with
`FilterSectionHeader`.

### `TeacherFilterContent` — `teacher_filter_content.dart`
Pre-composed filter content for class/subject/term/day chips. The
default choice for any filter sheet — only drop down to raw
`FilterSectionHeader` + `FilterChipGrid` when you need an atypical
section.

### `ActiveFilterChips` — `active_filter_chips.dart`
Horizontal row of currently-applied filter chips shown under the search
bar on list screens.

---

## Dialogs & confirmations

### `ConfirmationDialog` — `confirmation_dialog.dart`
Gradient header + Cancel/Confirm row; pops `bool`. Use for every
destructive/high-impact confirm (Hapus Siswa, Kirim Rapor, etc.).

### `ActionConfirmSheet` — `action_confirm_sheet.dart`
Sheet variant of the same pattern when the action has more context to
show (e.g. preview of what will be published).

### `AppAlertDialog` — `app_alert_dialog.dart`
Generic information/error dialog. Prefer `ConfirmationDialog` for
anything with a Confirm/Cancel decision.

---

## Inputs & form helpers

### `EnhancedSearchBar` / `SearchFilterBar` — `enhanced_search_bar.dart`, `search_filter_bar.dart`
Search input with optional filter button. Never use bare `TextField`
for list-screen search.

### `ModernDatePicker` — `modern_date_picker.dart`
Consistent date picker styling across all date fields (due date,
schedule period, announcement publish).

### `AppQuillEditor` — `app_quill_editor.dart`
Rich-text editor with a pre-styled toolbar. Used by lesson-plan editor
and announcement compose.

### `ViewToggleButton` — `view_toggle_button.dart`
List/matrix/grid mode switcher. Identical visual across admin + teacher.

### `RoleToggle` — `role_toggle.dart`
Wali-kelas view switch for screens that render both guru-mapel and
wali-kelas modes.

### `TabSwitcher` — `tab_switcher.dart`
Segmented-control-style tab bar for sheet-internal or sub-screen tabs.

---

## Cards & list chrome

### `HeroStatsCard` — `hero_stats_card.dart`
Navy-gradient KPI card used on the dashboard top row.

### `StatSummaryCard` — `stat_summary_card.dart`
Smaller KPI card used inside dashboards and hubs.

### `PendingInboxCard` — `pending_inbox_card.dart`
Dashboard action inbox: rows like "Verifikasi pembayaran · 12",
"RPP menunggu review · 3". Each row opens the target screen
pre-filtered.

### `QuickActionGrid` — `quick_action_grid.dart`
Dashboard 2×2 grid of shortcut tiles to common actions.

### `SchoolPill` — `school_pill.dart`
Multi-sekolah switcher that collapses to a label for single-school
users. Compact variant sits in the AppBar; expanded variant renders
on the Pengaturan hub.

### `BulkActionBar` — `bulk_action_bar.dart`
Navy bar shown when long-press selection is active. Chip-count pill
+ action buttons (Pindah / Ekspor / Hapus).

### `FrozenColumnTable` — `frozen_column_table.dart`
Scrollable table with N frozen left columns (grade recap, finance
report, jadwal matrix).

### `PaginatedListView` — `paginated_list_view.dart`
Infinite-scroll list with built-in loading + end-of-list states.

### `SectionHeader` — `section_header.dart`
Heading row for in-screen sections.

### `StatusBadge` — `status_badge.dart`
Pill with status color + label used on list cards.

---

## State rendering

### `EmptyState` — `empty_state.dart`
Icon + title + optional CTA for empty list/filter results.

### `ErrorScreen` / `AppErrorState` — `error_screen.dart`, `app_error_state.dart`
Full-screen and inline error views with retry.

### `SkeletonLoading` — `skeleton_loading.dart`
Shimmer placeholders for initial-load list screens.

### `AppRefreshIndicator` — `app_refresh_indicator.dart`
Pull-to-refresh wrapper with role-aware tint.

---

## Chrome

### `GradientPageHeader` / `TeacherPageHeader` — `gradient_page_header.dart`, `teacher_page_header.dart`
Navy-gradient page headers for the hub screens.

### `DragHandle` — `drag_handle.dart`
6×48 pill shown at the top of every bottom sheet.

### `AdminDataMenu` — `admin_data_menu.dart`
Menu grid used on the Manajemen Data hub.

---

## Don't-Dos

- Don't call `showDialog(AlertDialog(...))` for add/edit/filter flows.
  Use `AppEditBottomSheet` / `AppFilterBottomSheet` / `ConfirmationDialog`.
- Don't call `showModalBottomSheet` directly; go through the
  `App*BottomSheet.show()` wrappers.
- Don't build hand-rolled Cancel/Save footer rows. Use `BottomSheetFooter`.
- Don't use bare `TextField` for list-screen search. Use
  `EnhancedSearchBar` / `SearchFilterBar`.
- Don't duplicate a widget in a feature folder if a matching one lives
  here. Extend or generalise the shared one instead.
