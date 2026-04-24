# Admin Refactor · Phase 0 Baseline

Captured on **2026-04-23**, the day the Phase 0 foundation widgets landed.
This file is the "before" snapshot — Phases 1–5 measure themselves against
the line counts, analyzer state, and architectural patterns catalogued here.

---

## Analyzer state

`dart analyze lib/` — **0 errors, 0 warnings, 0 infos**.

All six new foundation widgets passed format + analyze clean on first
compilation; post-linter formatting introduced no regressions elsewhere in
`lib/`.

---

## Phase 0 deliverables (T0.1 → T0.5)

| # | Widget | File | Lines | Role |
|---|---|---|---:|---|
| T0.1 | `AdminCrudScaffold` | `lib/core/widgets/admin_crud_scaffold.dart` | 356 | Composition wrapper — header + async body + FAB + bulk bar. Replaces ~150 lines of shell duplicated across 11 admin screens. |
| T0.2 | `BulkActionBar` / `BulkAction` | `lib/core/widgets/bulk_action_bar.dart` | 305 | Floating multi-select bar. `SafeArea`-aware, scroll-overflows on narrow phones, accent-tinted count pill, destructive-action styling. |
| T0.3 | `SchoolPill` / `SchoolPill.expanded` | `lib/core/widgets/school_pill.dart` | 362 | Compact + expanded variants of the school switcher. Handles dark-surface inversion so admins can drop it into any gradient header or Settings hero. |
| T0.4a | `HeroStatsCard` / `HeroStatsRow` / `StatTrend` | `lib/core/widgets/hero_stats_card.dart` | 276 | Dashboard hero tile. Supports up/down/flat trend chips with `inverse` semantics for "bad-when-up" stats (tagihan telat). |
| T0.4b | `PendingInboxCard` / `PendingInboxEntry` | `lib/core/widgets/pending_inbox_card.dart` | 436 | Grouped worklist card used across admin/teacher/orangtua dashboards. Includes an "all clear" empty state. |
| T0.4c | `QuickActionGrid` / `QuickAction` | `lib/core/widgets/quick_action_grid.dart` | 224 | Responsive 3- or 4-up shortcut grid with optional badge dot. Role-agnostic. |
|  | **Total new shared widget code** |  | **1,959** |  |

Companion doc: `Admin_Refactor_TODOs.md` (Phase 0–5 plan + 10 guiding rules).

### Guiding rules enforced during Phase 0

1. Zero custom `showDialog` for add/edit/filter — compose `AppEditBottomSheet`
   / `AppFilterBottomSheet`.
2. Every footer uses `BottomSheetFooter`; no ad-hoc button rows.
3. No bare `TextField` in search — the header widget wraps `SearchFilterBar`.
4. No per-tab duplicated pagination; use one `TeacherAsyncView` per screen
   and filter the data source.
5. No dual-view re-implementation — lean on `ViewToggleButton` +
   `FrozenColumnTable`.
6. No `_mixin.dart` sprawl; composition over mixin state smuggling.
7. Admin navy `0xFF0F172A` is the shared default accent for foundation
   widgets; role colors override via `ColorUtils.getRoleColor('admin')`.
8. `BorderRadius.circular(12–16)`, `AppSpacing.sm/md/lg/xl`, alpha 0.10–0.18
   for tints — no magic numbers.
9. `Colors.withValues(alpha: X)` everywhere; zero `withOpacity` left behind.
10. Every public widget has a file-top "Why this exists" block + dartdoc on
    every prop.

---

## Pre-migration screen inventory

Eleven admin CRUD / dashboard / list screens are in scope for Phases 1–4.
Each will be rewritten on top of `AdminCrudScaffold` (or, for Keuangan /
Dashboard, the stat + inbox + grid trio).

| # | Feature | Screen | Lines | Target phase |
|---|---|---|---:|---|
| 1 | Siswa | `features/students/presentation/screens/admin_student_management_screen.dart` | 354 | **Phase 1** |
| 2 | Guru | `features/teachers/presentation/screens/admin_teacher_management_screen.dart` | 311 | **Phase 1** |
| 3 | Kelas | `features/classrooms/presentation/screens/admin_classroom_management_screen.dart` | 361 | **Phase 1** |
| 4 | Mapel | `features/subjects/presentation/screens/admin_subject_management_screen.dart` | 175 | **Phase 1** |
| 5 | Jadwal | `features/schedule/presentation/screens/admin_schedule_management_screen.dart` | 338 | **Phase 1 & 4** (dual-view in P4) |
| 6 | Keuangan | `features/finance/presentation/screens/admin_finance_screen.dart` | 391 | **Phase 2** — collapse 3-tab layout |
| 7 | Dashboard | `features/dashboard/presentation/screens/dashboard_screen.dart` | 238 | **Phase 3** — hero + inbox + grid |
| 8 | Pengumuman | `features/announcements/presentation/screens/admin_announcement_screen.dart` | 152 | **Phase 4** |
| 9 | Nilai (Admin) | `features/grades/presentation/screens/admin_grade_overview_screen.dart` | 619 | **Phase 4** — biggest single file |
| 10 | RPP (Admin) | `features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart` | 363 | **Phase 4** |
| 11 | Pengaturan | `features/settings/presentation/screens/settings_screen.dart` | 115 (+16 mixins) | **Phase 4** — SchoolPill.expanded hero |

**Total admin screen code today: 3,417 lines** (the above eleven files).
The 16 `_mixin.dart` files under `features/settings/presentation/mixins/`
are not counted here but represent another 1,500+ lines of indirection that
Phase 4 flattens.

### Adjacent read-side screens (not migrated in P1, referenced later)

| Feature | Screen | Lines |
|---|---|---:|
| Kehadiran (laporan) | `admin_attendance_report_screen.dart` | 406 |
| Kegiatan Kelas | `admin_class_activity_screen.dart` | 273 |
| Raport | `admin_report_card_screen.dart` | 361 |
| Kehadiran (detail) | `admin_attendance_detail.dart` | — |
| RPP (detail) | `lesson_plan_admin_detail_page.dart` | — |
| Finance (laporan) | `class_finance_report_screen.dart` | — |

These receive secondary sweeps once the primary 11 are on the new shell.

---

## Architectural anti-patterns observed (to be removed in P1–P5)

- **Mixin-based state smuggling.** `admin_student_management_screen.dart`
  alone mixes in five mixins (`DataLoadingMixin`, `FilterHelperMixin`,
  `ExcelOperationsMixin`, `StudentActionsMixin`, `TourHelperMixin`) and
  exposes 14 getters/setters just to satisfy the contracts. Phase 1 flattens
  these into explicit controller methods.
- **Per-feature headers.** Every CRUD screen ships its own
  `*_management_header.dart` widget — e.g., `student_management_header.dart`,
  likely duplicated across 11 screens. Target: delete in favor of
  `AdminCrudScaffold`'s built-in header slot.
- **Custom filter dialogs + mixins.** Students alone has
  `student_filter_sheet.dart`, `student_filter_sheet_content.dart`, and
  `student_filter_sheet_filters_mixin.dart`. Target: one `AppFilterBottomSheet`
  per feature, populated via `TeacherFilterContent`.
- **Duplicated dialog widgets for add/edit.** `student_add_edit_dialog.dart`
  + `student_dialog_dropdown.dart` + `student_dialog_text_field.dart`. Target:
  one `AppEditBottomSheet` per feature.
- **Three-tab finance layout** (`admin_finance_screen.dart`, 391 lines).
  Target: single-scroll Finance Hub per the Phase 2 wireframe.
- **Bespoke dashboard cards** hand-painted in `dashboard_screen.dart`. Target:
  `HeroStatsRow` + `PendingInboxCard` + `QuickActionGrid`.

---

## Expected impact (to be verified post-P5)

- ~60 % reduction in admin screen LOC (3,417 → ~1,400 projected).
- 100 % of add / edit / filter flows using shared bottom sheets.
- Zero custom `showDialog` in admin `features/**/presentation/screens/*.dart`.
- Analyzer remains at 0 errors / 0 warnings throughout every phase handoff.
- A swipe between any two admin CRUD screens renders visually identical
  headers, chip rows, FABs, and bulk bars.

---

*Phase 0 complete. Phase 1 (#186) unblocked.*
