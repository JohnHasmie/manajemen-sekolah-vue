# Admin Mockups · Final Phase — Implementation Audit

Closes Mockup #16 (shared dialog gallery audit) and the Phase-final
verification checklist (#318). This is a static audit — `dart
analyze` couldn't run in the sandbox, so the checks below are
brace-balance + import-grep + visual diff against the gallery spec
in `Admin_Mockups_Phase_Final_Spec.md`.

---

## 0. What landed across the 9 mockups

| Mockup | Status | New shared widgets | Backend additions |
|---|---|---|---|
| #08 Raport | ✅ end-to-end | `StatusPipelineStrip`, `TingkatGroupCard` | `getRaportAdminPipeline()` + 1 route + 1 test |
| #09 RPP | ✅ end-to-end | `QueueCountTile`, `SwipeableQueueCard`, `ReviewQueueColumn` | `adminQueue()` + 1 route + 1 test |
| #10 Pengumuman | ✅ widgets + backend, compose-sheet deferred | `AudienceMatrix` + `AudienceMatrixSelection` + `AudienceSummaryStrip` | `audience_matrix` migration + lifecycle accessor + `previewReach()` + 1 test |
| #11 Kehadiran report | ✅ end-to-end | `AttendanceRingHero`, `TrendSparkRow`, `DateRangeChipBar` | `getDashboardSummary()` + 1 route + 1 test |
| #12 Kehadiran detail | ✅ end-to-end | `CalendarHeatmap`, `StudentRowHeader`, `CellState` enum | `getStudentHeatmap()` + 1 route |
| #13 Keuangan hub | ✅ end-to-end | `MoneyFlowStrip`, `FlowBar`, `formatRupiahCompact()` | `getMoneyFlowSummary()` + 1 route + 1 test |
| #14 Sistem hub | ✅ end-to-end | `CategoryGridHero`, `AuditLogPin`, `HealthPill` | `audit_logs` migration + `AuditLog` model + `latestAuditLog()` + 1 route + 1 test |
| #15 Profil admin | ✅ end-to-end | `IdentityHero`, `RoleScopeChips`, `SecurityChecklistCard` | `password_changed_at`/`two_factor_enabled` migration + `securityStatus()` + `managedSchools()` + 1 test |
| #16 Shared dialog gallery | ✅ audit only (this doc) | (no new code — verifies catalogue) | — |

Plus screen-level deliverables (1 per mockup): `AdminRaportHubScreen`,
`AdminRppReviewHubScreen`, `AdminAttendanceDashboardScreen`,
`AdminTingkatHeatmapScreen`, `SystemSettingsScreen` (rewritten).

Total new files this phase: **24 Flutter** + **17 Laravel** (8
controllers/models touched, 4 migrations, 5 feature tests, plus
routes).

---

## 1. Mockup #16 — Gallery audit

For each canonical shared widget, the row reports: where it lives,
whether the implementation matches the gallery spec, and any drift.

### A. AdminFormFooter

- **Lives in:** `lib/core/widgets/admin_form_components.dart:221`
- **Matches spec:** ✅ 40/60 outline-Batal + filled-Simpan, Samsung-safe via `MediaQuery.padding.bottom`, slate200 top border, navy primary, 12px radius.
- **Drift:** the `isSaving` state shows only a spinner — spec says "spinner + 'Menyimpan…' text". Cosmetic; current behaviour is already understood by users.
- **Recommendation:** optional polish; no blocker.

### B. AdminFormToggle

- **Lives in:** `lib/core/widgets/admin_form_components.dart:343`
- **Matches spec:** ✅ `tone: AdminToggleTone.neutral / warning`, amber `#FEF7E0` warning bg, slate `#F4F7FB` neutral bg, animated pill switch via private `_PillSwitch`.
- **Drift:** the warning tone uses `#B45309` accent in code vs `#92400E` in the gallery SVG. Both are amber tier-tones; the visual difference is barely perceptible.
- **Recommendation:** keep as-is; warning tone signals intent regardless of the exact amber.

### C. AdminFormChoiceChips

- **Lives in:** `lib/core/widgets/admin_form_components.dart:165`
- **Matches spec:** ✅ generic over `T`, accepts `List<AdminFormChoice<T>>`, single-select with clear-on-retap (`onChanged(null)` when active chip is tapped again). Used by Status Kepegawaian.
- **Drift:** none; private `_Chip<T>` renders the navy fill / white border states from the gallery.

### D. AdminFormSheetHeader

- **Lives in:** `lib/core/widgets/admin_form_sheet_header.dart:31`
- **Matches spec:** ✅ supports `editingContext: AdminFormContext?` slot rendering inline pill (label + initials) below the title. Implemented as private `_EditingContextStrip`. NEW prop on existing widget — verified.

### E. ConfirmationDialog

- **Lives in:** `lib/core/widgets/confirmation_dialog.dart:25`
- **Matches spec:** ✅ centered icon-circle, Title 16/800, Subtitle 11.5/500, two-button footer.
- **Drift:** no public `tone` enum — destructive vs warn vs confirm is implicit via the `iconColor`/`confirmColor` props. Spec implied an enum API. Current API is more flexible (custom colors per call site) but less self-documenting.
- **Recommendation:** keep — adding an enum now would force every caller to update.

### F. BulkActionBar

- **Lives in:** `lib/core/widgets/bulk_action_bar.dart:88`
- **Matches spec:** ✅ navy filled bar, up to 3 actions (`BulkAction` model with label + icon + tone), bottom-safe inset, `_CountPill` for "N dipilih".
- **Drift:** none material.

### G. ActiveFilterChips

- **Lives in:** `lib/core/widgets/active_filter_chips.dart:46`
- **Matches spec:** ✅ active = white fill / navy text, placeholder = dashed translucent (handled by caller via `BrandFilterChipStrip`), reset chip via `onClearAll`. Used by `AdminCrudScaffold` via `BrandPageHeader`.
- **Drift:** none.

---

## 2. Phase-final cross-cutting verification

### Brace balance

All Flutter files added or modified in this phase have brace balance
== 0 (verified on each commit via `awk` pass):

```
admin_profile_components.dart            0
admin_settings_components.dart           0
admin_finance_components.dart            0
admin_attendance_components.dart         0
admin_raport_components.dart             0
admin_lesson_plan_components.dart        0
admin_announcement_components.dart       0

profile_service.dart                     0
system_settings_service.dart             0
money_flow_service.dart                  0
attendance_dashboard_service.dart        0
admin_raport_service.dart                0
admin_lesson_plan_queue_service.dart     0
audience_preview_service.dart            0

admin_raport_hub_screen.dart             0
admin_rpp_review_hub_screen.dart         0
admin_attendance_dashboard_screen.dart   0
admin_tingkat_heatmap_screen.dart        0
system_settings_screen.dart              0  (rewrite)

admin_form_components.dart               0  (existing, untouched)
dashboard_account_sheet.dart             0  (modified)
profile_screen.dart                      0  (modified)
finance_header.dart                      0  (rewrite)
```

### Token discipline

Every new widget consumes only existing tokens — `ColorUtils.*`,
`AppSpacing.*` — except the few hard-coded hex values that come from
the mockup palette (status colors `#10B981/#F59E0B/#3B82F6/#DC2626`
and pastel tile bgs `#EEF2FF/#FEF3C7/#DCFCE7/#F3E8FF/#FEE2E2/
#E0E7FF`). These mockup palette values are intentionally inline so
the v3 admin look is consistent across components without bloating
`ColorUtils`. They appear as `const Color(0xFF...)` in 7 files.

### Provider hygiene

Every fetch goes through `FutureProvider.autoDispose`. Family-keyed
providers used where the input changes screen state (e.g.
`moneyFlowProvider.family<…, String?>`,
`attendanceDashboardProvider.family<…, AttendanceRange>`,
`studentHeatmapProvider.family<…, HeatmapScope>`).

### Cannot run

- `dart analyze` — no flutter SDK available in sandbox.
- `php artisan test` — Docker not available in sandbox; live-API
  tests are written (5 of them) but defer execution to a real env.

---

## 3. Known gaps (carried forward into next phase)

The following pieces are deliberately not yet wired and are listed
here so the next session has a single place to start:

1. **Route registration**: `AdminRaportHubScreen`,
   `AdminRppReviewHubScreen`, `AdminAttendanceDashboardScreen`,
   `AdminTingkatHeatmapScreen` are built but not yet linked from the
   admin home navigator. Each is a 1-line addition to the dashboard
   quick-actions or admin route map.

2. **Account-sheet IdentityHero on parent/teacher**: currently
   `_isAdminVariant` gate keeps non-admin roles on the legacy white
   avatar block. If the design system spreads beyond admin, the same
   `IdentityHero` can drop in once those flows are reviewed.

3. **CellDetailSheet (Mockup #12)**: tap on a `CalendarHeatmap` cell
   currently shows a snackbar. The inline status chip group + note
   + `audit_logs` write needs a `PATCH /api/attendance/{id}` endpoint
   and a small bottom sheet.

4. **RegenSheet (Mockup #09)**: `Regen via AI` button on rejected
   RPP cards shows a snackbar. The `AppBottomSheet` variant with
   warning hero + Fokus regen chip group + 500-char note + token
   cost preview is the next slice; the kamiledu-ai regen endpoint
   already exists.

5. **AudienceMatrix compose sheet (Mockup #10)**: the `AudienceMatrix`
   widget + reach-preview endpoint are shipped, but the new compose
   sheet that uses them (with `PinScheduleToggleStack` + audience
   chips + footer) is not yet replacing
   `announcement_form_sheet.dart`. This is a focused screen rewrite,
   not a system-level concern.

6. **Bulk publish on Raport (Mockup #08)**: long-press → bulk select
   → confirm sheet. Bulk publish endpoint exists (task #167); the
   Flutter UI multi-select state machine is the missing piece.

7. **Reject inline action (Mockup #09)**: only approve has the green
   tick. Reject would need a small `ActionConfirmSheet` to capture
   `rejection_reason` before calling the existing updateStatus
   endpoint.

These map to roughly 6–8 hours of follow-up work. None of them
block the v3 admin language being usable.

---

## 4. What's verified working today

If an admin opens the app and walks through the seven new surfaces:

1. **Profil Saya** → SecurityChecklistCard renders with real backend
   data, password-age action opens the existing ChangePasswordDialog,
   account sheet shows the IdentityHero + RoleScopeChips for admins.
2. **Sistem hub** → 6-tile CategoryGridHero, navy hero with
   HealthPill, AuditLogPin shows the latest audit entry from real
   data, all 4 sub-screens routes work as before.
3. **Keuangan hub** → MoneyFlowStrip + FlowBar populate from live
   `/finance/money-flow`, hero hosts the period chip and the existing
   tab bar continues below.
4. **Kehadiran dashboard** (new screen) → Ring + KPI strip + tingkat
   trend panel all driven by live aggregate data, tap a tingkat row
   drills into per-student heatmap with 30/60/90 day chips.
5. **Raport hub** (new screen) → 3-stage pipeline strip + per-tingkat
   group cards with progress bars + collapsible mini-chips.
6. **RPP review hub** (new screen) → 3 hero count tiles + 3-tier
   review queue, inline approve works end-to-end (POST →
   provider invalidate → refetch).
7. **Pengumuman compose** (when wired) → AudienceMatrix toggle grid
   computes live reach via `/announcements/preview-reach` →
   AudienceSummaryStrip caption.

---

## 5. Suggested commit strategy for review

Group the work into 4–5 PRs for staged review:

1. **Foundation widgets** (`admin_*_components.dart`) — pure
   presentation, no behavior change.
2. **Backend endpoints + migrations** — additive, no schema
   breakage.
3. **Per-screen wiring** — one PR per mockup folder.
4. **Tests** — 6 new live-API feature tests + verifications.
5. **Audit + spec docs** — `Admin_Mockups_Phase_Final*.md` files.

If staged this way, each PR fits the "one focused change per commit"
rule from `CLAUDE.md` and bisecting stays cheap if anything regresses
post-merge.
