# P0 Bug Fix PR Plan

> Companion: `UI_Redesign_Audit.md` § "P0 bugs surfaced by the screenshot pass" (19 items).
> Goal: burn down the P0 list in 1 focused sprint, *before* P1 (bottom nav shell) starts. Most are <1 day; cumulative perceived-quality lift is significant.

---

## Effort summary

| PR | Title | Effort | Blocking |
|---|---|---|---|
| **PR-1** | Role-color contract sweep | 0.5d | — |
| **PR-2** | Dashboard hero + label-wrap polish | 0.5d | — |
| **PR-3** | Auth — stale error toast in role picker | 0.5d | — |
| **PR-4** | Audit-trail — drop trash icon on attendance report | 0.25d | — |
| **PR-5** | RPP scoping fix | 0.5d | — |
| **PR-6** | Schedule matrix duplicate-row investigation | 0.5d | — |
| **PR-7** | **Per-row action sweep** (Theme 7, 8+ admin screens) | 1.5d | — |
| **PR-8** | Verifikasi tab redesign — drop mega-button-per-row | 1.0d | scope-decide first |
| **PR-9** | Parent — empty `Kelas:` data path bug | 1.0d | investigate first |
| **PR-10** | Parent Billing — `Bayar Sekarang` CTA + due-date + i18n | 1.5d | flow-decide first |
| **PR-11** | Parent Announcements — date + priority pill + grouping | 0.5d | — |
| **PR-12** | Login polish — Lupa Password + brand label | 0.5d | brand-decide first |
| **PR-13** | Class Activity reflow — time-scoped feed | 2.0d | bigger; can defer to P6 |

**Total:** ~10 dev-days. Target 1 sprint (2 weeks for one engineer with review/QA cycles, or 1 week split across two).

**Decision-required before PR-8 / PR-10 / PR-12 ships:**
1. PR-8: do we keep `verification_dialog.dart` modal, or inline approve/reject on the row?
2. PR-10: payment flow — in-app gateway or transfer + receipt-upload?
3. PR-12: brand string — "KamilEdu" or "Manajemen Sekolah"?

Write decisions inline below before kicking off the relevant PRs.

---

## Sequencing

```
Week 1                         Week 2
─────────────                  ─────────────
PR-1, PR-2, PR-3, PR-4         PR-7 (sweep)
PR-5, PR-6                     PR-8, PR-9
PR-11, PR-12                   PR-10
                               PR-13 (or punt to P6)
```

PR-1 through PR-6 + PR-11 + PR-12 are independent — ship in parallel as engineering capacity allows. PR-7 (per-row sweep) touches 8+ files but is mechanical; do it as a single focused commit on a quiet day. PR-8 and PR-10 need product decisions first.

---

## PR-1 · Role-color contract sweep

**Bugs fixed:** P0 #5 (Notifications green AppBar), #6 (Parent Billing blue AppBar), Theme 8 follow-up.

**Scope:** every AppBar in the app should derive its color from `ColorUtils.getRoleColor(role)`. Find leaks, fix them, add a test/lint that catches regressions.

**Files touched:**
- `lib/features/notifications/presentation/screens/notification_list_screen.dart` — AppBar uses `Colors.green` or similar; route through `ColorUtils.getRoleColor(widget.role)`.
- `lib/features/finance/presentation/screens/parent_billing_screen.dart` — currently blue; switch to parent purple via `ColorUtils.getRoleColor('wali')`.
- *Audit pass:* `grep` for hex literals + `Colors.{blue,green,purple}` in `lib/features/**/screens/*.dart` to surface other leaks.
- `lib/core/utils/color_utils.dart` — confirm `getRoleColor('wali')` returns the same purple as `dashboard_screen.dart` parent fork.

**Implementation notes:**
- `notification_list_screen.dart` already takes a `role` parameter (per `dashboard_screen.dart` `NotificationListScreen(role: widget.role)`). Wire it.
- For `parent_billing_screen.dart` — verify whether the screen takes a role param or computes it from auth state.

**Conventional commit:**
```
fix(theming): apply role color contract to notifications + parent billing

- NotificationListScreen now derives AppBar color from active role
- ParentBillingScreen flips from blue to parent purple
- Adds grep-based check for hardcoded color literals in screens

Closes P0 #5, #6 from UI_Redesign_Audit.md
```

**Verification:**
- Manual: sign in as admin → tap bell → AppBar should be navy. Same as teacher (green) and parent (purple).
- Manual: parent → Tagihan → AppBar should be purple, not blue.
- `grep -r "Colors.green\|Colors.blue\|Colors.purple" lib/features/*/presentation/screens/` — should be empty after sweep.
- `dart analyze` clean.

---

## PR-2 · Dashboard hero + label-wrap polish

**Bugs fixed:** P0 #1 (admin hero text contrast), #2 (Pengatura\nn wrap), #3 (Pengumum… wrap).

**Scope:** three small visual fixes on dashboards.

**Files touched:**
- `lib/features/dashboard/presentation/widgets/dashboard_hero_section.dart` — change text color on the dark-navy admin hero band from current dark-grey to white/off-white.
- `lib/features/dashboard/presentation/widgets/quick_action_button.dart` (or similar) — investigate why "Pengaturan" wraps. Options:
  (a) shorten label to "Setelan" (preferred — Indonesian for "Setting");
  (b) reduce label font size for QuickAction tiles;
  (c) increase tile width via grid `crossAxisCount` change.
- `lib/features/dashboard/presentation/widgets/parent_menu_items_mixin.dart` — "Pengumuman" tile in parent's Akses Cepat truncates to "Pengumum…". Same fix options as above.

**Implementation notes:**
- (a) is preferred for both labels — shorter is safer than restructuring grid.
- Add tooltip on long labels for hover/long-press accessibility.

**Conventional commit:**
```
fix(dashboard): hero text contrast + tile-label truncation

- Admin hero: text → white for WCAG AA on dark gradient
- QuickAction tile labels shortened: Pengaturan → Setelan
- Parent Akses Cepat: Pengumuman shortened to fit

Closes P0 #1, #2, #3
```

**Verification:**
- Screenshot diff against `_baseline/admin/01_dashboard.png` and `_baseline/parent/01_dashboard.png` — labels should fit on single line.
- Color contrast check with WebAIM contrast tool — admin hero text should pass AA at 4.5:1.

---

## PR-3 · Auth — stale "Email atau password salah" toast leaks into role picker

**Bug fixed:** P0 #4.

**Scope:** when login succeeds, dismiss any in-flight error toast before pushing to school/role picker.

**Files touched:**
- `lib/features/auth/presentation/screens/login_screen.dart` — find the success-handler that navigates to the picker; ensure `SnackBarUtils.dismiss()` (or similar) is called first.
- Possibly `lib/core/utils/error_utils.dart` if the error display goes through a global util.

**Implementation notes:**
- The toast is `'Email atau password salah'`. If it's shown via `SnackBarUtils.showError`, check whether `SnackBarUtils` exposes a dismiss/clear method. If not, add one.
- Alternative: ensure error toasts are tied to the login screen's lifecycle (`ScaffoldMessenger.of(context).clearSnackBars()` on transition).
- Confirm by reading `login_screen.dart` whether the school/role picker is a separate screen push or a multi-step state — if multi-step, the toast may be lingering on the same Scaffold's messenger.

**Conventional commit:**
```
fix(auth): clear error snackbars on successful login

Stale "Email atau password salah" toast was leaking into the
role-picker step because the login screen pushed the picker without
clearing pending snackbars from the parent ScaffoldMessenger.

Closes P0 #4
```

**Verification:**
- Reproduce: enter wrong creds → error toast appears → enter correct creds → tap MASUK → toast should be gone before role picker renders.
- Manual: also test the school-picker step (S2) for the same behavior.

---

## PR-4 · Drop trash icon on attendance report rows

**Bug fixed:** P0 #15.

**Scope:** admins should not be able to delete individual attendance audit records. Remove the trash icon affordance.

**Files touched:**
- `lib/features/attendance/presentation/screens/admin_attendance_report_screen.dart` (or the row widget it composes).

**Implementation notes:**
- ~15 minute fix. Identify the trash IconButton in the row build, delete the call site.
- If the trash icon was wired to a delete handler, leave the handler (in case it's used by bulk-mode) but remove the visible affordance.
- Confirm with backend that there *isn't* a use case for admin attendance row deletion. If there is, restrict to a 3-dot overflow rather than a primary affordance.

**Conventional commit:**
```
fix(attendance): remove per-row delete affordance from admin report

Attendance records are an audit trail; admins should not be able
to delete individual entries from the report list. Removes the red
trash icon from each row.

Closes P0 #15
```

**Verification:** screenshot diff vs `_baseline/admin/11_attendance_report.png` — trash icon gone from each row.

---

## PR-5 · RPP scoping — admin "Kelola RPP" should show all teachers

**Bug fixed:** P0 #14.

**Scope:** admin's "Kelola RPP" menu item currently lands on a teacher-scoped screen titled "RPP - Agil". Either expose the teacher-picker step explicitly or default to all-teachers view with teacher chip on each row.

**Files touched:**
- `lib/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart` — title + scope.
- `lib/features/dashboard/presentation/widgets/admin_menu_items_mixin.dart` — "Kelola RPP" tile route.

**Implementation notes:**
- Two options:
  (a) **All-teachers default with teacher filter chip in the filter sheet.** Title becomes "Semua RPP". Add per-row teacher chip (already exists in some screens). Rebuild the screen as a flat list across all teachers.
  (b) **Insert a teacher-picker step.** Admin → Kelola RPP → pick teacher → teacher-scoped view. More taps, but matches the current model.
- (a) is preferred — fewer taps, more useful for admin's job (review pipeline across all teachers).

**Conventional commit:**
```
fix(rpp): admin Kelola RPP defaults to all-teachers view

- Title changes from teacher-scoped "RPP - Agil" to "Semua RPP"
- Each row shows teacher chip + class chip
- Filter sheet adds teacher filter for narrowing

Closes P0 #14
```

**Verification:**
- Manual: dashboard → Kelola RPP → see all RPPs from all teachers, with teacher chip on each row.
- Filter by teacher chip → narrows to one teacher's RPPs.

---

## PR-6 · Schedule matrix duplicate-row investigation

**Bug fixed:** P0 #13.

**Scope:** every "Jam 1" row in the matrix view shows the same two entries ("B. Arab 8B" + "Bahasa Indonesia 7B"). Investigate whether this is bad seed data or a render bug.

**Files touched:**
- `lib/features/schedule/presentation/screens/admin_schedule_management_screen.dart` (matrix mode).
- Possibly `lib/core/widgets/frozen_column_table.dart` if the bug is in row rendering.
- Possibly the schedule controller / API client if the data is being shaped wrong.

**Implementation notes:**
- Step 1: query the API directly for one day's schedule. If the API returns distinct entries per slot, the bug is in the render layer.
- Step 2: if API also has duplicates, confirm seed data quality.
- Step 3 (if render bug): check the matrix builder — is it iterating `slots` but defaulting each row to the same `slots[0]`?

**Conventional commit (depends on outcome):**
```
fix(schedule): correct matrix view duplicate-row rendering

[Description depends on root cause — render fix or seed fix]

Closes P0 #13
```

**Verification:** capture a fresh `06_schedule_matrix.png`; rows should show distinct entries per time slot.

---

## PR-7 · Per-row action sweep (Theme 7, 8+ screens)

**Bug fixed:** Theme 7 (cross-cutting) — drops per-row edit-pen + trash-icon across A2/A3/A4/A5/A6/A10/A11/A12 + A7 sub-tabs. Replace with: tap-row → detail/edit, long-press → bulk-select, FAB → add.

**Scope:** mechanical sweep. Single focused refactor PR. Affects ~8-10 files but each change is a few-line delete.

**Files touched:**
- `lib/features/students/presentation/screens/admin_student_management_screen.dart`
- `lib/features/teachers/presentation/screens/admin_teacher_management_screen.dart`
- `lib/features/classrooms/presentation/screens/admin_classroom_management_screen.dart`
- `lib/features/subjects/presentation/screens/admin_subject_management_screen.dart`
- `lib/features/schedule/presentation/screens/admin_schedule_management_screen.dart`
- `lib/features/announcements/presentation/screens/admin_announcement_screen.dart`
- `lib/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart`
- `lib/features/finance/presentation/widgets/payment_type_card.dart` (Jenis Pembayaran tab rows)
- `lib/features/finance/presentation/widgets/billing_card.dart` (Tagihan Berjalan rows)
- Possibly the row-builders inside `lib/core/widgets/admin_crud_scaffold/`

**Implementation notes:**
- Each row currently has `trailing: Row([editIcon, deleteIcon])`. Drop both, replace with `trailing: chevronIcon` (or remove trailing entirely; the row itself becomes tap-target).
- Wire the row's `onTap` to the existing edit-sheet show-helper.
- Add `onLongPress` to enter `BulkActionBar` mode (already in shared catalog).
- *Don't* delete the underlying delete handlers — they're still reachable via bulk mode and the 3-dot overflow.

**Conventional commit:**
```
refactor(admin): drop per-row edit/delete icons across CRUD screens

Per UI_Redesign_Audit.md Theme 7. Tap row → detail/edit, long-press →
bulk-select mode, FAB → add. Removes ~20% of row width and
eliminates accidental-delete risk.

Affected: Siswa, Guru, Kelas, Mapel, Jadwal, Pengumuman,
Lesson Plans, Finance Jenis Pembayaran + Tagihan Berjalan.
```

**Verification:**
- Manual: each affected screen — tap a row → opens edit. Long-press → enters bulk mode with `BulkActionBar` visible. FAB → add sheet.
- Screenshot diff vs `_baseline/admin/02_student_list.png` etc — rows should be visibly less crowded on the right.
- `dart analyze lib/features/` clean.

---

## PR-8 · Verifikasi tab — drop mega-button-per-row

**Bug fixed:** P0 #12.

**Scope decision required:** keep `verification_dialog.dart` modal pattern, or inline approve/reject icons on the row?

**Recommendation:** inline `[✓][✗]` action icons on the row. Tapping ✓ opens a confirm sheet (with payment proof preview); tapping ✗ opens a reject reason sheet. Mega-button-per-row deletes.

**Files touched:**
- `lib/features/finance/presentation/widgets/finance_verification_tab.dart`
- `lib/features/finance/presentation/widgets/pending_payment_card.dart` (the row card)
- `lib/features/finance/presentation/widgets/verification_dialog.dart` (preserve as confirm-sheet)

**Implementation notes:**
- Row composition becomes: avatar + student name + meta-line (SPP / Rp / date) + spacer + `[✓ green-filled circle]` + `[✗ red-outline circle]`.
- Confirm sheet (existing `verification_dialog`) opens with payment-proof preview, Approve / Cancel.
- Reject sheet: textarea for reason + Tolak / Cancel.

**Conventional commit:**
```
fix(finance): replace mega-button verification rows with inline actions

Verifikasi tab previously rendered a full-width Verifikasi button per
pending row, which doesn't scale beyond 1-2 rows. Each row now has
inline [check][reject] icons; tap opens confirm sheet with proof.

Closes P0 #12
```

**Verification:**
- Manual: seed 5+ pending verifications → Verifikasi tab should show 5+ compact rows, not 5 mega-buttons.
- Tap ✓ → confirm sheet opens. Tap ✗ → reject sheet opens.

---

## PR-9 · Parent — empty `Kelas:` data path bug

**Bug fixed:** P0 #11.

**Scope:** investigation first. P2 (Kehadiran) and P3 (Nilai) show empty `Kelas:` field on the child profile card. P4 (Kegiatan Kelas) shows `Kelas: 7A` correctly. Find the discrepancy.

**Files touched (TBD after investigation):**
- `lib/features/attendance/presentation/screens/parent_attendance_screen.dart` — likely consuming `parent.children[i]` without `.kelas`
- `lib/features/grades/presentation/screens/parent_grade_screen.dart`
- `lib/features/class_activity/presentation/screens/parent_class_activity_screen.dart` (the working example)
- Possibly the parent / student model class
- Possibly the API endpoint feeding parent screens

**Implementation notes:**
- Step 1: open `parent_class_activity_screen.dart`, find where it renders `Kelas: 7A`. Identify the data source.
- Step 2: open `parent_attendance_screen.dart` + `parent_grade_screen.dart`, identify their data source.
- Step 3: diff — does P4 use a different model field, a different API call, or a different fallback?
- Likely culprit: P4 hits a `students-with-class` endpoint while P2/P3 hit `students` and forget the join.

**Conventional commit (depends on outcome):**
```
fix(parent): populate Kelas field on attendance + grades child cards

[Description depends on root cause]

Closes P0 #11
```

**Verification:** all three parent screens (P2/P3/P4) should show the same `Kelas: 7A` value for the same child.

---

## PR-10 · Parent Billing — Bayar Sekarang CTA + due-date + i18n

**Bugs fixed:** P0 #7 (i18n), #8 (Bayar Sekarang), #9 (due-date).

**Scope decision required:** payment flow design. Two options:
- **(a) In-app payment gateway** (Midtrans/Xendit/etc): more work, integrates a payment SDK. Required if the school accepts cards/e-wallet.
- **(b) Bank transfer + receipt upload:** lighter. Add "Bayar via Transfer" CTA → opens a sheet with bank details + "Unggah Bukti" upload. Backend already supports payment proof per `verification_dialog.dart`.

**Recommendation:** **(b) for now** — already aligned with the existing verification flow on the admin side. Migrate to (a) later if needed.

**Files touched (assuming option b):**
- `lib/features/finance/presentation/screens/parent_billing_screen.dart` — add CTA + due-date.
- `lib/features/finance/presentation/widgets/billing_card.dart` (or parent-specific variant) — row layout: title + amount + period + due-date + status pill + Bayar CTA.
- New widget: `lib/features/finance/presentation/widgets/payment_transfer_sheet.dart` — bank details + receipt upload (compose with `AppBottomSheet` + `BottomSheetFooter`).
- i18n: ONCE → Sekali, MONTHLY → Bulanan. Find in `lib/l10n/` or hardcoded strings in `parent_billing_screen.dart`.
- Backend: verify the existing payment-proof endpoint accepts parent-initiated proofs (admin-initiated currently).

**Conventional commit:**
```
feat(parent): Bayar Sekarang flow with transfer + receipt upload

Parent Billing previously had no payment CTA, no due-date, and
ONCE/MONTHLY metode strings in English. This change:

- Adds "Bayar via Transfer" CTA per row → opens payment_transfer_sheet
- Surfaces due-date on each row
- Translates metode to Sekali / Bulanan
- Sheet uses AppBottomSheet + BottomSheetFooter pattern

Closes P0 #7, #8, #9
```

**Verification:**
- Manual: parent → Tagihan → tap Bayar Sekarang → sheet with bank details + upload affordance.
- Upload a test receipt → admin sees it in Verifikasi tab.

---

## PR-11 · Parent Announcements — date + priority pill + grouping

**Bug fixed:** P0 #10.

**Scope:** parent announcement rows are missing date, priority pill, and date-section grouping that teacher version (T11) has.

**Files touched:**
- `lib/features/announcements/presentation/screens/parent_announcement_screen.dart`

**Implementation notes:**
- Row composition becomes: icon + title + body preview + meta-row (date + audience + Penting pill if applicable).
- Date-section grouping: wrap rows in `ListView.builder` with section headers ("April 2026", "Maret 2026"), counts in header.
- Reuse the section pattern from `teacher_announcement_screen.dart` if extractable.

**Conventional commit:**
```
fix(announcements): parent — add date, priority pill, month grouping

Parent announcement rows were missing date/time, didn't show the
Penting priority pill, and weren't date-grouped. Brings parent in
line with teacher_announcement_screen patterns.

Closes P0 #10
```

**Verification:** screenshot diff vs `_baseline/parent/05_announcements.png` — each row shows date + Penting pill, sections grouped by month.

---

## PR-12 · Login polish — Lupa Password + brand label

**Bugs fixed:** P0 #17 (brand mismatch), #18 (no Lupa Password).

**Scope decision required:** brand string — pick one of:
- **(a) "KamilEdu"** — modern, single-word, brand-y. Use everywhere.
- **(b) "Manajemen Sekolah"** — descriptive, current AppBar default. Less branded.
- **(c) "KamilEdu" as brand on login + "Manajemen Sekolah" as feature label in AppBar** — split. Common SaaS pattern.

**Recommendation:** (c).

**Files touched:**
- `lib/features/auth/presentation/screens/login_screen.dart` — add Lupa Password link below password field; set brand to "KamilEdu".
- New screen (or sheet): `lib/features/auth/presentation/sheets/forgot_password_sheet.dart` — email input + "Kirim Tautan Reset" button.
- Backend: confirm a password-reset endpoint exists; if not, scope is bigger.

**Implementation notes:**
- "Lupa Password?" text-link, right-aligned, navy color, below password field.
- Forgot-password sheet: minimal — email + send button + "Tautan akan dikirim ke email Anda" instructional copy.

**Conventional commit:**
```
feat(auth): add Lupa Password flow + standardize brand label

- "Lupa Password?" link below password field on login
- Sheet collects email and triggers backend reset endpoint
- Brand: "KamilEdu" on login screen, "Manajemen Sekolah" stays as
  feature label in in-app AppBars

Closes P0 #17, #18
```

**Verification:** manual — login screen shows Lupa Password link → tap → sheet → submit → success toast. Brand reads "KamilEdu" on login.

---

## PR-13 · Class Activity reflow — time-scoped feed *(stretch — consider deferring to P6)*

**Bug fixed:** P0 #16.

**Scope:** `admin_class_activity_screen.dart` shows a guru-list when the title says "Kegiatan Kelas". Restructure as a time-scoped activity feed (today / week / month) with per-teacher drill as secondary.

**Why this might defer:** this is a 2-day refactor that overlaps significantly with P1 (bottom nav) and the teacher-Class-Activity-merge thinking. Consider letting P1 + P6 (per-screen density pass) handle it together.

**Files touched (if shipped now):**
- `lib/features/class_activity/presentation/screens/admin_class_activity_screen.dart` — rebuild as time-scoped feed.
- New tab/segment control: today / week / month.
- Per-row: time + subject + class + teacher chip + activity title.
- Per-teacher drill: long-press a teacher chip → filter feed by that teacher.

**Conventional commit:**
```
feat(admin): rebuild Kegiatan Kelas as time-scoped activity feed

Previously the screen was a guru-list requiring 3 taps to see one
teacher's activities. New structure: top-level today/week/month
segment with chronological activity cards. Per-teacher drill is a
secondary filter.

Closes P0 #16
```

**Verification:** dashboard → Kegiatan Kelas → see today's sessions across all teachers, in chronological order.

---

## After the P0 sprint

When the table is burned down:

1. Re-capture the affected `_baseline/` screenshots into `_after/` for diff archive.
2. Update `UI_Redesign_Audit.md` § "P0 bugs" table with ship status.
3. Begin P1 (bottom nav shell) implementation per `P1_BottomNav_Spec.md` once Q1-Q10 are answered.
4. Per-row sweep (PR-7) and the dashboard polish (PR-2) directly help P1 land cleaner — fewer concurrent visual changes during the shell rollout.

---

## Open issues to resolve before kicking off

Please answer in this doc (or in chat, quoting the PR number) before starting:

- [ ] **PR-8 scope:** keep `verification_dialog.dart` modal? *Recommend: yes, repurpose as confirm sheet.*
- [ ] **PR-10 payment flow:** transfer + receipt-upload (option b) or in-app gateway (option a)? *Recommend: b for now.*
- [ ] **PR-12 brand string:** (a) "KamilEdu" everywhere / (b) "Manajemen Sekolah" everywhere / (c) split? *Recommend: c.*
- [ ] **PR-13 timing:** ship in P0 sprint or defer to P6? *Recommend: defer.*
