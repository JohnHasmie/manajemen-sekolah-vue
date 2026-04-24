# Admin Refactor — Detailed TODOs

Target: `kamiledu-mobile-flutter` · admin-role screens
Principle: **satu implementasi, tiga role**. Mirror the teacher-role refactor that's already shipped.

---

## 0. Guiding rules (apply to every task below)

1. **No custom `showDialog(...)` for add/edit or filter.** Every filter sheet uses `AppFilterBottomSheet`; every add/edit uses `AppEditBottomSheet`; every destructive confirmation uses `ConfirmationDialog` or `ActionConfirmSheet`.
2. **No custom footer widgets.** `BottomSheetFooter` only. Hapus (danger) + Batal + Simpan pattern — matches teacher.
3. **No custom filter section renderer.** `FilterSectionHeader` + `FilterChipGrid` + (where applicable) `TeacherFilterContent` — already does class/subject/term/day chips.
4. **No custom async-state branching.** `TeacherAsyncView` wraps every screen body that loads data. Rename to `AppAsyncView` if touched — but for now, reuse as-is.
5. **No bare `TextField` for search.** `EnhancedSearchBar` or `SearchFilterBar` — whichever the teacher reference uses.
6. **No dual-view re-implementation.** `ViewToggleButton` for list/matrix/grid. Identical toggle chrome across admin + teacher.
7. **Every list screen scaffolds:** AppBar → search bar → active filter chips (`ActiveFilterChips`) → list → FAB. No tabs for CRUD entities.
8. **Long-press → bulk mode.** `BulkActionBar` component (to be built in Phase 0, reused everywhere). Selection, count, Pindah/Ekspor/Hapus.
9. **Before merging any screen:** run `flutter analyze` + smoke test on simulator. Screenshot diff vs. teacher equivalent.
10. **Every new abstraction goes into `lib/core/widgets/`.** No per-feature duplicates.

---

## Phase 0 — Foundation (prerequisites, do first)

### T0.1 — Build `AdminCrudScaffold` shared widget
**Path:** create `lib/core/widgets/admin_crud_scaffold.dart`
**Reference:** pattern extracted from `teacher_material_screen.dart` + `teacher_lesson_plan_screen.dart`
**Purpose:** one reusable scaffold for every admin CRUD entity (Siswa/Guru/Kelas/Mapel/Jadwal/Pengumuman).
**Props:**
- `title: String`, `subtitle: String?` (appbar)
- `schoolPill: Widget?` (multi-sekolah switcher)
- `searchController`, `searchHint: String`
- `filterChipsBuilder: Widget Function(BuildContext)` — delegates to `ActiveFilterChips`
- `onFilterTap: VoidCallback` — opens `AppFilterBottomSheet`
- `body: Widget` — wrapped in `TeacherAsyncView`
- `onFabTap: VoidCallback` — opens `AppEditBottomSheet`
- `bulkActionBar: Widget?` — visible when `selection.isNotEmpty`
**Acceptance:** Siswa screen can be rewritten to `<60 lines` using this scaffold.

### T0.2 — Build `BulkActionBar` shared widget
**Path:** `lib/core/widgets/bulk_action_bar.dart`
**Reference:** no teacher equivalent — this is new, but must match the visual spec in `Admin_Refactor_Wireframe_03`.
**Props:** `selectedCount`, `actions: List<BulkAction>` (label, icon, color, onTap), `onCancel`.
**Acceptance:** navy bar, chip-count pill, ≥3 actions, safe-area aware.

### T0.3 — Build `SchoolPill` shared widget
**Path:** `lib/core/widgets/school_pill.dart`
**Reference:** spec in `Admin_Refactor_Wireframe_02_Dashboard_Redesign`.
**Props:** `currentSchool`, `schools: List`, `onSwitch: ValueChanged`.
**Acceptance:** appears in admin AppBar when user is multi-sekolah super-admin; collapses to a non-tappable label when single-school. Expanded variant renders on `SystemSettingsScreen`.

### T0.4 — Build `HeroStatsCard` + `PendingInboxCard` + `QuickActionGrid`
**Paths:**
- `lib/core/widgets/hero_stats_card.dart`
- `lib/core/widgets/pending_inbox_card.dart`
- `lib/core/widgets/quick_action_grid.dart`
**Reference:** dashboard frame in `Admin_Refactor_Wireframe_02`.
**Acceptance:** all three accept `role: UserRole` and render config-driven content — admin shows verifikasi/tagihan alerts; teacher shows RPP review/absensi pending; OT shows tagihan/pengumuman.

### T0.5 — Baseline analyze + screenshot pass
- `docker compose exec app ./vendor/bin/pint` (backend sanity — not applicable to Flutter, skip)
- `flutter analyze` — capture current warning count
- Smoke-screenshot every admin screen (11 screens) → `_baseline/` folder for visual diff later.

---

## Phase 1 — Manajemen Data (highest reuse, biggest impact)

### T1.1 — Migrate `admin_student_management_screen.dart`
**Non-compliance (from audit):**
- Uses `TextEditingController` bare search (not `EnhancedSearchBar`)
- Custom `showDialog(AlertDialog)` for add/edit/delete
- No `BottomSheetFooter`
- `StudentFilterSheet` wraps `AppFilterBottomSheet` but via extra `showModalBottomSheet` — drop the wrapper
**Teacher reference:** `lib/features/materials/presentation/screens/teacher_material_screen.dart` — cleanest CRUD pattern.
**Subtasks:**
- [ ] Replace screen body with `AdminCrudScaffold` (T0.1)
- [ ] Delete `student_filter_sheet.dart` — call `AppFilterBottomSheet` directly with `TeacherFilterContent` (class/status chips)
- [ ] Build `student_edit_sheet.dart` using `AppEditBottomSheet` — fields: name, NISN, kelas, gender, tgl lahir, status. Delete button = `showConfirmationDialog` → soft-delete API
- [ ] Add long-press → `BulkActionBar` with: Pindah kelas · Ekspor CSV · Hapus
- [ ] Remove all custom `AlertDialog` calls in the feature folder
- [ ] Verify pull-to-refresh via `AppRefreshIndicator`
- [ ] `flutter analyze` clean

### T1.2 — Migrate `admin_teacher_management_screen.dart`
**Teacher reference:** same as T1.1.
**Subtasks:**
- [ ] AdminCrudScaffold migration
- [ ] Build `teacher_edit_sheet.dart` (AppEditBottomSheet) — fields: user account, NIP, mapel yang diampu (multi-select chips), wali kelas flag, status
- [ ] Filter: nama mapel yang diampu + status aktif (chips)
- [ ] Bulk actions: Ekspor · Arsipkan
- [ ] Retire `teacher_filter_sheet.dart` wrapper

### T1.3 — Migrate `admin_classroom_management_screen.dart`
**Current gap:** no add/edit dialog exists at all.
**Subtasks:**
- [ ] AdminCrudScaffold migration
- [ ] Build `classroom_edit_sheet.dart` (AppEditBottomSheet) — fields: nama kelas, tingkat (grade), wali kelas (searchable dropdown from teachers), kapasitas, tahun ajaran
- [ ] Filter: tingkat · tahun ajaran · wali kelas
- [ ] Bulk: Arsipkan lulus (end-of-year transition)
- [ ] Retire `classroom_filter_sheet.dart` wrapper

### T1.4 — Migrate `admin_subject_management_screen.dart`
**Non-compliance:** custom `header_mixin`, `footer_mixin`, `sections_mixin` instead of `BottomSheetHeader`/`BottomSheetFooter`/`FilterSectionHeader`.
**Subtasks:**
- [ ] Delete all three filter mixins — drop-in `FilterSectionHeader` + `BottomSheetFooter`
- [ ] Build `subject_edit_sheet.dart` using `AppEditBottomSheet` — fields: nama mapel, kode, KKM, bobot rapor, tingkat yang mengajar
- [ ] Verify `SubjectFilterSheet` collapses to thin wrapper (or delete entirely)
- [ ] Bulk: Ekspor silabus

### T1.5 — Migrate `admin_schedule_management_screen.dart`
**Non-compliance:** uses BOTH `showDialog` AND `showModalBottomSheet` from `admin_schedule_dialogs_mixin.dart`.
**Teacher reference:** `teacher_schedule_screen.dart` (read-only) + `teacher_lesson_plan_screen.dart` (for edit flow).
**Subtasks:**
- [ ] Delete `admin_schedule_dialogs_mixin.dart`
- [ ] Build `schedule_edit_sheet.dart` using `AppEditBottomSheet` — fields: hari, jam mulai, jam selesai, mapel, guru, kelas, ruangan
- [ ] Apply **dual-view** (T4.1) — list (current) + matrix (new, reuse `FrozenColumnTable`)
- [ ] Bulk: Duplicate to semester berikutnya · Ekspor PDF
- [ ] Filter: hari · guru · kelas · mapel (all via `TeacherFilterContent.classesAndSubjects`)

### T1.6 — Verify with `flutter analyze` + manual smoke test
- [ ] Every CRUD entity: Add → Edit → Delete → Filter → Bulk select → Bulk action
- [ ] Screenshot each flow, compare to teacher equivalent side-by-side
- [ ] Count lines of code removed — target ≥1,500 LOC net reduction across Phase 1

---

## Phase 2 — Keuangan (Finance Hub unification)

### T2.1 — Build unified `FinanceHubScreen` (replace 3-tab pattern)
**Path:** rewrite `admin_finance_screen.dart`
**Reference:** `Admin_Refactor_Wireframe_04_Keuangan_Unified_Hub`.
**Layout:** single vertical scroll with sections:
1. Hero "Perlu Verifikasi" card (red gradient, top)
2. KPI mini-grid (diterima bulan ini, tagihan menunggak)
3. "Tagihan bulan ini" list section
4. "Jenis pembayaran" 2×2 grid
**Subtasks:**
- [ ] Delete `admin_finance_tabs_mixin.dart` (if exists)
- [ ] Replace TabBar with `SectionHeader` per section
- [ ] Hero card widget → `FinancePendingVerificationCard` (new, in `lib/features/finance/widgets/`)
- [ ] KPI cards reuse `StatSummaryCard`
- [ ] "Tagihan list" reuses `list-card` pattern from Phase 1

### T2.2 — Migrate verification flow to `AppEditBottomSheet`
**Non-compliance:** 6 custom verification dialog mixins.
**Subtasks:**
- [ ] Delete all 6 mixins in `admin/finance/mixins/verification_*.dart`
- [ ] Build `payment_verification_sheet.dart` using `AppEditBottomSheet`:
  - Top: student + payment metadata card
  - Field: expected vs received amount (side-by-side, pre-filled)
  - Field: bukti transfer preview (tap to zoom)
  - Field: catatan admin (optional textarea)
  - Footer: **Tolak** (danger) + **Setujui** (green primary) — override standard Batal/Simpan
- [ ] Swipe-right-to-next-pending gesture (optional — add if time permits, else TODO)
- [ ] Record API: existing `POST /api/payments/{id}/verify` — no change

### T2.3 — Migrate billing generation to `AppEditBottomSheet`
**Non-compliance:** 3 custom billing mixins.
**Subtasks:**
- [ ] Delete billing mixins
- [ ] Build `generate_bills_sheet.dart` using `AppEditBottomSheet`:
  - Jenis pembayaran (radio: SPP / Uang Gedung / Seragam / Kegiatan / Kustom)
  - Periode (chips: bulan, dropdown tahun)
  - Target (radio: Semua siswa · Per kelas · Per tingkat)
  - Jumlah (auto-fill from jenis, editable)
  - Jatuh tempo (ModernDatePicker)
- [ ] Footer: Batal · **Generate 524 tagihan** (dynamic recipient count)

### T2.4 — Rebuild `admin_finance_report_screen.dart` using period chips
**Reference:** teacher's attendance screen period chips (reuse pattern).
**Subtasks:**
- [ ] Period selector: Hari ini · Minggu · Bulan · Tahun · Kustom (ModernDatePicker range)
- [ ] Big summary card reuses `HeroStatsCard` (navy gradient, centered Rp figure)
- [ ] Breakdown bars: custom widget OR reuse existing chart lib (check project for `fl_chart` or similar)
- [ ] Ekspor PDF/Excel → reuse shared `ExportActionMenu` (if doesn't exist, build it in `lib/core/widgets/export_action_menu.dart` — also used by grades/attendance teacher exports)

### T2.5 — Jenis Pembayaran management
- [ ] Tap "Kelola ›" in C1 → new mini-screen
- [ ] Reuse `AdminCrudScaffold` (T0.1) — entities: jenis pembayaran
- [ ] `payment_type_edit_sheet.dart` using `AppEditBottomSheet`

---

## Phase 3 — Dashboard & Monitoring

### T3.1 — Rebuild `admin_dashboard_screen.dart`
**Reference:** `Admin_Refactor_Wireframe_02_Dashboard_Redesign`.
**Subtasks:**
- [x] Replace stats grid + menu grid with:
  - `SchoolPill.expanded` (T0.3) in navy gradient header
  - `HeroStatsRow` of 3 `HeroStatsCard` (T0.4) — Siswa · Guru · Verifikasi
  - `PendingInboxCard` (T0.4) — Verifikasi pembayaran · RPP menunggu review · Pengumuman draft · Tagihan menunggak
  - `QuickActionGrid` (T0.4) — 4 tiles: Siswa · Keuangan · Laporan · Pengaturan
- [x] Pull-to-refresh via `AppRefreshIndicator`
- [ ] Remove all inline stat calculations — centralise in `DashboardRepository` (backend) *(deferred to Phase 5 — stats map read with 0-fallback; backend fields land next)*

### T3.2 — Pending inbox filtered view
- [x] Tap a PendingInboxCard item → navigate to relevant screen with pre-applied filter
  - Verifikasi pembayaran → `FinanceScreen(initialTabIndex: 2)`
  - RPP menunggu review → `AdminLessonPlanScreen(initialStatusFilter: 'pending_review')`
  - Pengumuman draft → `AdminAnnouncementScreen(initialStatusFilter: 'draft')`
  - Tagihan menunggak → `FinanceScreen(initialTabIndex: 3)` *(Class Report tab — per-class bill drill-down)*
- [x] Use existing navigation + filter-state pattern *(added `initStatusFilter` to lesson-plan `FilterManagementMixin`; announcement `selectedStatusFilter` seeded directly from initState)*

### T3.3 — Real-time indicator
- [x] PendingInboxCard polls every 60s (Timer.periodic invoking `refreshStats()` — no Pusher/Reverb backend yet)
- [x] Visual: green pulsing dot = connected, grey static = stale
- [x] Fallback to pull-to-refresh — manual refresh also resets the 60s timer

---

## Phase 4 — Sistem (Jadwal dual-view, Pengumuman, Settings)

### T4.1 — Dual-view for Jadwal (list + matrix)
**Already listed partially in T1.5; this task is the view-toggle infrastructure.**
- [ ] Reuse `ViewToggleButton` from teacher refactor
- [ ] Matrix view = `FrozenColumnTable` with rows=time-slots, columns=days-of-week
- [ ] Same filter applies to both views (filter state is single source of truth)
- [ ] Teacher reference: the matrix toggle in `teacher_grade_recap_screen.dart`

### T4.2 — Migrate `admin_announcement_screen.dart` compose flow
**Non-compliance:** `admin_dialog_mixin.dart` uses `showDialog` for compose.
**Reference:** `Admin_Refactor_Wireframe_05_Sistem` frame D2.
**Subtasks:**
- [ ] Delete `admin_dialog_mixin.dart`
- [ ] Build `announcement_compose_sheet.dart` using `AppEditBottomSheet`:
  - Target audiens: `FilterSectionHeader` + radio (Semua · Per Peran · Per Kelas) + `FilterChipGrid` (roles/classes)
  - Judul (required)
  - Isi (AppQuillEditor — reuse teacher's RPP editor component)
  - Prioritas (Normal / Penting — radio)
  - Kirim (Sekarang / Jadwal ModernDatePicker)
- [ ] Primary button dynamically shows recipient count: "Kirim ke 524 OT"
- [ ] Draft save via existing API

### T4.3 — Migrate `admin_class_activity_screen.dart`
**Non-compliance:** custom `filter_bottom_sheet.dart` + `activity_dialog_shell.dart` + `ActivitySearchFilterBar`.
**Subtasks:**
- [ ] Delete all 3 custom files
- [ ] Migrate to `AdminCrudScaffold` + `AppFilterBottomSheet` + `AppEditBottomSheet`
- [ ] Teacher reference: `teacher_class_activity` feature

### T4.4 — `admin_attendance_report_screen.dart` filter migration
- [ ] Remove legacy `AttendanceReportFilterSheet` `showModalBottomSheet` wrapper
- [ ] Call `AppFilterBottomSheet` directly with `TeacherFilterContent.classesAndDateRange`

### T4.5 — Build `SystemSettingsScreen` (pengaturan hub)
**Reference:** `Admin_Refactor_Wireframe_05_Sistem` frame D3.
**Subtasks:**
- [ ] Hero card = expanded `SchoolPill` (T0.3)
- [ ] Sections: Manajemen Sistem · Notifikasi & Akun
- [ ] Menu items reuse `list-card` pattern (same as CRUD)
- [ ] Entries: Profil sekolah · Ekspor laporan · Naik kelas & kelulusan · Data management · Pengaturan notifikasi · Pengguna sistem
- [ ] Each menu item opens its own detail screen or `AppEditBottomSheet`

### T4.6 — Retire legacy report_card dialogs
**Non-compliance:** `admin_report_card_actions_mixin.dart`
- [ ] Replace showDialog-based bulk publish confirm with `ConfirmationDialog`
- [ ] Any edit flows → `AppEditBottomSheet`

### T4.7 — Lesson plan admin regen sheet
**Non-compliance:** `lesson_plan_regen_dialogs.dart` uses showDialog.
- [ ] Build `lesson_plan_regen_sheet.dart` using `AppEditBottomSheet`
- [ ] Fields: mode (regenerate semua / per-bab / per-subbab), prompt tambahan, model AI

---

## Phase 5 — Cleanup, Docs, QA

### T5.1 — Redundancy sweep
- [x] `grep -r "showDialog(" lib/features/**/admin_*.dart` — all remaining are acceptable (read-only detail dialogs, loading spinner, shared `ConfirmationDialog`). `UpdateStatusDialog` (RPP approval) migrated to `update_status_sheet.dart` using `AppBottomSheet` + `BottomSheetFooter` (commit `refactor(lesson-plans): migrate UpdateStatusDialog to AppBottomSheet`).
- [x] `grep -r "showModalBottomSheet(" lib/features/**/admin_*.dart` — no bare calls outside `AppBottomSheet` / `AppEditBottomSheet` / `AppFilterBottomSheet` wrappers
- [x] Three mixin files stubbed as deprecated (sandbox FS blocks physical `unlink`; files have `// Deprecated.` marker and no importers). Follow-up can `git rm` on a dev machine: `announcement_form_header_mixin.dart`, `announcement_form_footer_mixin.dart`, `lesson_plan_regen_dialogs.dart`.
- [x] `dart format` applied to every file touched across Phases 0–4
- [x] `dart analyze lib/` clean — no errors, no new warnings

### T5.2 — Component library docs
- [x] `lib/core/widgets/README.md` created — lists every shared component (scaffolds, sheet blocks, dialogs, inputs, cards, state renderers, chrome), groups by role, and calls out the don't-dos
- [x] Linked to `Admin_Refactor_TODOs.md` for the migration plan
- [ ] Screenshots of each component — deferred; requires a simulator pass. Tracked separately as a QA pass.

### T5.3 — Visual regression test
- [ ] Re-capture screenshots of all 11 admin screens → `_after/` *(requires simulator, out of scope for sandbox)*
- [ ] Diff `_baseline/` vs `_after/` — every screen must look visually consistent with its teacher equivalent
- [ ] Manual QA checklist: filter apply/reset, edit save/cancel, bulk select/action/cancel, search typing, pull-to-refresh

### T5.4 — Update CLAUDE.md
- [x] Shared-component conventions captured in `lib/core/widgets/README.md` (functions as the Flutter-side conventions doc).
- [x] Top-level `CLAUDE.md` created — working contract for adding/editing/refactoring code. Covers directory layout, shared-component pickers, don't-dos, sandboxed-FS workarounds, git hygiene, verification checklist, common edge cases, and the satu-implementasi-tiga-role rule.

### T5.5 — Metrics report
- [ ] LOC delta per feature (target: ~60% net reduction) *(run `git log --shortstat release/teacher-refactor-2026-04-22` for totals)*
- [x] New shared components added: `AdminCrudScaffold`, `BulkActionBar`, `SchoolPill`, `HeroStatsCard`, `PendingInboxCard`, `QuickActionGrid`
- [ ] Non-compliant screens: 11 → 0 *(remaining: class-activity admin migration T4.3, Jadwal matrix T4.1, System settings T4.5 — deferred. RPP approval status dialog ✅ done.)*
- [x] `dart analyze` — clean across lib/
- [ ] Deliver to stakeholders as Markdown report in `/docs/`

---

## Shared component inventory (reuse cheat sheet)

| Component | Path | Admin screens using |
|---|---|---|
| `AppFilterBottomSheet` | `lib/core/widgets/app_filter_bottom_sheet.dart` | All 11 screens |
| `AppEditBottomSheet` | `lib/core/widgets/app_edit_bottom_sheet.dart` | Siswa/Guru/Kelas/Mapel/Jadwal/Pengumuman/Finance edit/Verification/Billing/LessonPlanRegen |
| `BottomSheetFooter` | `lib/core/widgets/bottom_sheet_footer.dart` | Every sheet |
| `FilterSectionHeader` | `lib/core/widgets/filter_section_header.dart` | Every filter sheet |
| `FilterChipGrid` | `lib/core/widgets/filter_chip_grid.dart` | Every filter sheet |
| `TeacherFilterContent` | `lib/core/widgets/teacher_filter_content.dart` | Every filter sheet — rename to `AppFilterContent` during Phase 5 cleanup |
| `TeacherAsyncView` | `lib/core/widgets/teacher_async_view.dart` | Every screen body — rename to `AppAsyncView` during Phase 5 |
| `FrozenColumnTable` | `lib/core/widgets/frozen_column_table.dart` | Jadwal matrix view, Finance report breakdown |
| `EnhancedSearchBar` / `SearchFilterBar` | same folder | Every list screen |
| `ViewToggleButton` | same | Jadwal, (future) Laporan |
| `ActiveFilterChips` | same | Every list screen |
| `ConfirmationDialog` / `ActionConfirmSheet` | same | Every delete/destructive |
| `ModernDatePicker` | same | Finance due date, Jadwal period, Announcement schedule |
| `StatSummaryCard` | same | Dashboard mini-grid, FinanceHub KPIs |
| `SectionHeader` | same | Every section inside a screen |
| `AppRefreshIndicator` | same | Every scrollable screen |
| `EmptyState` | same | Every list |
| `ErrorScreen` | same | Every async failure |
| `AppQuillEditor` | same | Announcement compose, Lesson plan regen |
| **NEW — T0.1** `AdminCrudScaffold` | `lib/core/widgets/admin_crud_scaffold.dart` | All 5 Manajemen Data screens |
| **NEW — T0.2** `BulkActionBar` | `lib/core/widgets/bulk_action_bar.dart` | All 5 Manajemen Data screens + Finance |
| **NEW — T0.3** `SchoolPill` | `lib/core/widgets/school_pill.dart` | Dashboard, Settings |
| **NEW — T0.4** `HeroStatsCard`, `PendingInboxCard`, `QuickActionGrid` | same folder | Dashboard (admin/teacher/OT) |
| **NEW — T2.4** `ExportActionMenu` | `lib/core/widgets/export_action_menu.dart` | Finance reports, Grades export, Attendance export |

---

## Execution order

```
Phase 0 (week 1)          ──┐
  T0.1 AdminCrudScaffold    │
  T0.2 BulkActionBar        │
  T0.3 SchoolPill           │ parallel-safe
  T0.4 Dashboard widgets    │
  T0.5 Baseline             │
                            ─┤
Phase 1 (week 2)            │
  T1.1 Siswa ───────────────┤ (flagship — do first, others copy pattern)
  T1.2 Guru                 │
  T1.3 Kelas                │ parallel after T1.1
  T1.4 Mapel                │
  T1.5 Jadwal               │
  T1.6 Verify               │
                            ─┤
Phase 2 (week 3)            │
  T2.1 Finance Hub          │
  T2.2 Verification         │
  T2.3 Billing              │ sequential (shared state)
  T2.4 Report               │
  T2.5 Jenis Pembayaran     │
                            ─┤
Phase 3 (week 4)            │
  T3.1 Dashboard rebuild    │
  T3.2 Inbox routing        │
  T3.3 Realtime             │
                            ─┤
Phase 4 (week 5)            │
  T4.1 Dual-view            │
  T4.2 Pengumuman           │
  T4.3 Kegiatan Kelas       │ parallel
  T4.4 Attendance report    │
  T4.5 Settings hub         │
  T4.6 Rapor cleanup        │
  T4.7 LP regen sheet       │
                            ─┤
Phase 5 (week 6)            │
  T5.1 Redundancy sweep     │
  T5.2 Docs                 │ sequential
  T5.3 Visual regression    │
  T5.4 CLAUDE.md            │
  T5.5 Metrics              │
```

**Total:** 6 weeks · 5 new shared components · 11 screens migrated · ~1,500 LOC net reduction expected.

---

## Done-Done definition

A task is only "done" when:
1. ✅ Screen uses only shared components (no `showDialog`, no custom filter/edit dialogs, no bare `TextField`)
2. ✅ Filter + edit + delete + bulk flow all work end-to-end on simulator
3. ✅ Visual parity with teacher-role equivalent (side-by-side screenshot)
4. ✅ `flutter analyze` clean (no new warnings)
5. ✅ No dead `_mixin.dart` files left behind
6. ✅ Pull-to-refresh + empty state + error state all render correctly
7. ✅ Bahasa Indonesia error/success messages
