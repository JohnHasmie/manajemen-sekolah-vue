# Admin Mockups · Final Phase — Spec sheet

Companion to `Admin_Mockups_Phase_Final.html`. Covers screens 08–16
(Raport · RPP · Pengumuman · Kehadiran report · Kehadiran detail ·
Keuangan hub · Sistem hub · Profil · Shared dialogs gallery).

The visual baseline is the v3 admin language already shipped on Siswa /
Guru / Kelas / Mapel / Jadwal. This phase **pushes the system further**:
five new shared widgets are introduced because the existing vocabulary
doesn't fit the data shape of Raport / RPP / Pengumuman / Kehadiran /
Sistem.

> The "one rule" still holds — every new pattern below lives in
> `lib/core/widgets/` and is consumable by all 3 roles, not just admin.

---

## 0 · New shared widgets introduced

| # | Widget | Lives in | First consumer |
|---|---|---|---|
| 1 | `StatusPipelineStrip` | `lib/core/widgets/status_pipeline_strip.dart` | Raport (#08) |
| 2 | `ReviewQueueColumn` + `SwipeableQueueCard` | `lib/core/widgets/review_queue_column.dart` | RPP (#09) |
| 3 | `AudienceMatrix` | `lib/core/widgets/audience_matrix.dart` | Pengumuman (#10) |
| 4 | `AttendanceRingHero` + `TrendSparkRow` | `lib/core/widgets/attendance_ring_hero.dart`, `…/trend_spark_row.dart` | Kehadiran report (#11) |
| 5 | `CalendarHeatmap` | `lib/core/widgets/calendar_heatmap.dart` | Kehadiran detail (#12) |
| 6 | `MoneyFlowStrip` + `FlowBar` | `lib/core/widgets/money_flow_strip.dart` | Keuangan (#13) |
| 7 | `CategoryGridHero` | `lib/core/widgets/category_grid_hero.dart` | Sistem (#14) |
| 8 | `IdentityHero` + `RoleScopeChips` + `SecurityChecklistCard` | `lib/core/widgets/identity_hero.dart`, `…/role_scope_chips.dart`, `…/security_checklist_card.dart` | Profil (#15) |

All consume existing tokens: `ColorUtils.brandGradient('admin')`,
`ColorUtils.slate*`, `AppSpacing`. Inter font. Card radius 14, sheet
radius 20+24-on-top, hero radius 0 (flush) with bottom 28px curve.

---

## 1 · Mockup 08 — Raport admin

### Layout
- `BrandPageHeader` (admin gradient, 320 height including pipeline strip).
- Hero contents top-to-bottom:
  - Back / filter / overflow row.
  - Subtitle "Akademik · Penilaian", title "Raport".
  - Period pill "Periode 2025/2026 · Ganjil".
  - `StatusPipelineStrip` (NEW) — 4 nodes connected.
  - Overlapping search field on the bottom edge.
- Body: `SectionLabel("PER TINGKAT · 12 KELAS")` then a `Column` of
  `TingkatGroupCard`s, expandable accordion-style.
- Bulk publish bar (`BulkActionBar` variant) anchors to bottom when
  selection count ≥ 1.

### Components & props

```dart
StatusPipelineStrip(
  nodes: const [
    PipelineNode(label: 'Draft',     count: 42, tone: PipelineTone.muted),
    PipelineNode(label: 'Diperiksa', count: 128, tone: PipelineTone.active),
    PipelineNode(label: 'Terbit',    count: 67, tone: PipelineTone.muted),
    PipelineNode(label: 'Dibagikan', count: 11, tone: PipelineTone.muted),
  ],
  activeIndex: 1,
  onNodeTap: (idx) => filter(state: nodes[idx].label),
  trailing: TextButton('Cetak', onPressed: ...),
);

TingkatGroupCard({
  required int tingkat,
  required int classCount,
  required int studentCount,
  required double percentReviewed,    // 0..1
  required List<KelasMiniChip> chips, // [{label:'7A', state:'terbit'}, …]
  bool initiallyExpanded = true,
  bool warning = false,               // red border + "butuh perhatian"
  ValueChanged<String> onChipLongPress, // → bulk select
});
```

### States
- Default: tingkat-7 expanded, others collapsed.
- Selection: long-press on `KelasMiniChip` flips card into select mode,
  bulk bar slides up.
- Confirm: tapping "Terbit" in bulk bar opens the confirm sheet (Frame B).
  Sheet has impact list (notif fanout, parent access opens, irreversible
  warning) + `AdminFormToggle(neutral)` for "Kirim notifikasi".

### Edge cases
- Tingkat with 0 published rapor → red border + "Butuh perhatian".
- Period switch in hero pill → reload pipeline counts + group cards.
- Cetak action runs through existing PDF generator; `isLoading` state on
  the strip's trailing button.

---

## 2 · Mockup 09 — RPP admin overview

### Layout
- `BrandPageHeader` with **3 `QueueCountTile`** in a row (count + delta).
  Replaces the standard chip-strip — RPP doesn't have list filters,
  it has lifecycle counters.
- Body is a single `ReviewQueueColumn` with 3 tier sections in fixed
  order: Perlu review · Ditolak · Disetujui (collapsed teaser).
- No FAB — admins don't create RPP; teachers do.

### Components & props

```dart
QueueCountTile({
  required String label,    // "PERLU REVIEW"
  required int count,       // 14
  required QueueTone tone,  // warn / good / bad
  String? deltaLabel,       // "+3 hari ini"
});

ReviewQueueColumn({
  required List<ReviewTier> tiers,
  ValueChanged<String>? onCardTap,
});

class ReviewTier {
  final String label;       // "Perlu review"
  final QueueTone tone;
  final int totalCount;
  final List<SwipeableQueueCard> cards;
  final bool collapsed;     // shows first 5 + "lihat semua →"
}

SwipeableQueueCard({
  required String subtitle, // "Bahasa Arab · Kelas 8B"
  required String title,    // "Bab 3 · Hiwar tentang sekolah"
  required List<Widget> meta,  // pills + timestamp
  required String footer,   // "Yahya Hasymi · 14 sub-bab · 1,287 kata"
  Color leftEdgeColor,      // tier color
  required SwipeAction approve,
  required SwipeAction reject,
  Widget? rejectionReason,  // shown italic when rejected
  List<Widget>? actions,    // ⟳ Regen, Edit manual
});
```

### Regen sheet (Frame B)
- `AppBottomSheet` with warning-tinted hero band.
- "Fokus regen" chip group (`AdminFormChoiceChips` single-select):
  IPK / Tujuan / Asesmen.
- Note textarea (max 500 char), live counter.
- Cost preview card: token estimate, model name.
- Footer: AdminFormFooter with primary "⟳ Mulai regen".

### Edge cases
- `regenAttempts >= 2` → primary CTA disables, replace with cooldown
  countdown chip "Tunggu 24 jam".
- AI provider errors → inline error state inside the sheet, not a
  toast.

---

## 3 · Mockup 10 — Pengumuman admin

### Layout
- List surface uses `BrandPageHeader` with `LifecycleChipBar` (4 chips
  in hero: Semua · 📌 Disematkan · Terjadwal · Terkirim).
- Body grouped by lifecycle: pinned (yellow-tinted card border),
  scheduled (blue countdown pill), sent (read-receipt stat), draft
  (italic muted).
- FAB → opens compose sheet (Frame B).

### Compose sheet (Frame B)
- `AppEditBottomSheet` rewritten to host `AudienceMatrix`.
- Audience-pick is the *primary* affordance, not buried.

### Components & props

```dart
AudienceMatrix({
  required List<MatrixRow> rows,     // [Guru, Wali Kelas, Wali Murid]
  required List<MatrixCol> cols,     // [Semua, 7, 8, 9, Custom]
  required Set<MatrixCell> selected,
  required ValueChanged<MatrixCell> onToggle,
  VoidCallback? onCustomTap,         // opens AppFilterBottomSheet
});

class AudienceSummaryStrip extends StatelessWidget {
  final int reachCount;              // computed
  final String tintRole;             // 'admin' for navy fill
  // Renders: "Audiens · 48 guru + 8 wali kelas (7,8) = 56 orang"
}

PinScheduleToggleStack({
  required bool sendNow,
  required ValueChanged<bool> onSendNowChanged,
  required bool pin,
  required ValueChanged<bool> onPinChanged,
  // pin uses AdminToggleTone.warning
});
```

### Lifecycle list cards
- Pinned cards: yellow `#FEF3C7` border, "📌 7 hari" pill.
- Scheduled: blue `#EFF6FF` pill "⏰ 6 hari lagi" (auto-computed).
- Sent: green pill + read-receipt stat "42 dari 48 dibaca · 88%".
- Draft: 0.6 opacity, italic title, no actions.

### Edge cases
- Empty audience → primary CTA disables, summary strip turns red, copy
  flips to "Pilih minimal 1 audiens".
- Schedule + pin both off → "Kirim sekarang" toggle is on by default.
- Pin with 7+ days → confirm sheet warns "akan menggeser pengumuman
  pinned saat ini".

---

## 4 · Mockup 11 — Kehadiran report admin

### Layout
- Hero is taller (340px) to host `AttendanceRingHero`.
- `DateRangeChipBar` inside hero: Hari ini · Minggu ini · Bulan ini ·
  Custom (dashed).
- Below hero: 2-card KPI strip (Rata kehadiran with mini sparkline,
  Siswa tidak hadir with delta).
- `TrendSparkRow` panel — one row per tingkat.
- Pinned export bar at bottom.

### Components & props

```dart
AttendanceRingHero({
  required double rate,            // 92.0 (0..100)
  required AttendanceBreakdown breakdown,
  String? subtitle,                // "Hadir hari ini"
});

class AttendanceBreakdown {
  final int present, excused, sick, alpa;
}

TrendSparkRow({
  required String label,           // "Tingkat 7"
  required double currentPct,
  required List<double> sparkPoints, // 7-day series
  required double deltaPct,
  bool alert = false,              // → red sparkline + alert band
  String? alertCopy,
  VoidCallback? onTap,             // drill to Mockup 12
});
```

### Sparkline color rule
- `currentPct >= 90` → green `#10B981`
- `80–89` → amber `#F59E0B`
- `<80` → red `#DC2626` and `alert: true`

### Export sheet
- Reuses existing `ActionConfirmSheet`.
- File-format chip group (PDF · Excel · CSV).
- Date-range echo pill (read-only).
- Email-on-export `AdminFormToggle(neutral)`.

### Edge cases
- Today is non-school → ring 40% opacity, subtitle "Tidak ada sesi · libur Maulid".
- KPI strip pins to last school day.
- 0 absences → "Siswa tidak hadir" tile shows "🎉 100% hadir".

---

## 5 · Mockup 12 — Kehadiran detail admin

### Layout
- Drilled in from `TrendSparkRow.onTap` carrying the tingkat scope.
- Hero shows tingkat + kelas + month %.
- Filter chips: 30 hari · Semester ini · Mata pel.
- Body: list of `StudentRowHeader + CalendarHeatmap`. One card per
  student.
- When a heatmap cell is tapped, the row expands inline with a
  `CellDetailSheet` (status chip group + note + footer).

### Components & props

```dart
CalendarHeatmap({
  required List<CellState> cells,  // length 30 by default
  int columns = 30,
  ValueChanged<int>? onCellTap,
  int? selectedIndex,
});

enum CellState { present, excused, sick, alpha, holiday }

StudentRowHeader({
  required InitialsAvatar avatar,
  required String name,
  required String classRoll,        // "9C · No. absen 03"
  required double monthlyPct,
  required int presentDays,
  required int totalDays,
  bool alert = false,               // ≥3 alpa streak
  String? alertCopy,                // "⚠ 4× alpa berturut"
});

CellDetailSheet({
  required Date date,
  required CellState currentState,
  required CellMeta meta,           // mata pel, sesi
  required ValueChanged<CellState> onStatusChange,
  required ValueChanged<String> onNoteChange,
  required Future<void> Function() onSave,
});
```

### Audit trail
- Saving a correction prepends an `AuditTrailEntry` row visible from
  the row's overflow menu — read-only.
- Format: `Diubah Yahya · 14:03 · Sakit → Hadir`.

### Edge cases
- Cell outside active semester → status chips disabled, helper "Periode
  dikunci · admin SU diperlukan".
- Holiday cell → cell renders `#E2E8F0`, tap opens read-only popover
  (no status change).

---

## 6 · Mockup 13 — Keuangan hub

### Layout
- Hero (340 height) hosts `MoneyFlowStrip` (3 tiles) + `FlowBar`
  (single-row stacked bar).
- `FinanceTabBar` below hero with red badge on Tagihan when ≥1
  overdue.
- Sub-filter chips per tab (Semua · Belum bayar · Jatuh tempo).
- Body: `InvoiceRow`s in lifecycle order — overdue first, then due,
  then paid (collapsed teaser).
- Pinned `ClassReportDrillCard` at bottom of list → existing
  `ClassFinanceTable`.
- FAB to create new bill.

### Components & props

```dart
MoneyFlowStrip({
  required Money incoming,         // formatted "Rp 184jt"
  required String incomingDelta,   // "↑ 12% vs bulan lalu"
  required Money outstanding,
  required Money overdue,
  required int overdueCount,
  required VoidCallback onOverdueTap,
});

FlowBar({
  required double paidPct,
  required double outstandingPct,
  required double overduePct,
  ValueChanged<FlowSegment>? onSegmentTap,
});

InvoiceRow({
  required String title,
  required String studentName,
  required String invoiceNumber,
  required Money amount,
  required InvoiceStatus status,
  String? overdueLabel,            // "⚠ Lewat 14 hari"
  int? reminderCount,              // pill "Reminder ke-3"
  VoidCallback? onTagihTap,
});
```

### Edge cases
- 0 overdue → overdue tile collapses to half width, FlowBar drops red
  segment, tab badge hidden, "Jatuh tempo" sub-filter chip hidden.
- All bills paid → empty state with celebratory illustration + "Buat
  tagihan periode berikutnya" CTA.

---

## 7 · Mockup 14 — Sistem hub

### Layout
- Hero only 200px tall (no list to filter, just identity).
- `HealthPill` ("Sinkron · konfigurasi sehat") inside hero.
- `CategoryGridHero` 2×3 tile grid below hero.
- `AuditLogPin` pinned bottom — preview of latest entry.

### Components & props

```dart
CategoryGridHero({
  required List<CategoryTile> tiles,
  int columns = 2,
});

class CategoryTile {
  final IconData icon;
  final Color iconBg;       // pastel tint
  final Color iconFg;       // tinted accent
  final String title;
  final String subline;
  final String? meta;
  final VoidCallback onTap;
}

HealthPill({
  required HealthState state,  // ok / warn / error
  required String label,
});

AuditLogPin({
  required AuditEntry latest,
  required VoidCallback onSeeAll,
});
```

### Sub-screens
- Tahun Ajaran (Frame B): active card with `TimelineProgressCard`
  (today-marker on bar) + semester ribbon + history list +
  `DangerZoneCard` for "Akhiri sekarang".
- Other sub-screens follow the same template: hero (160 height) +
  primary content card + history list + danger zone if applicable.

### Edge cases
- No archive → history section hides, AddCTA card moves up.
- Backup last >24h ago → Backup tile turns amber with "⚠ tertunda".
- Audit log empty → AuditLogPin renders "Belum ada aktivitas hari ini".

---

## 8 · Mockup 15 — Profil admin

### Two surfaces

#### A. Account sheet (peek from any header avatar)
- `BrandHeroSheet` variant with `IdentityHero` (navy gradient + avatar +
  name + email + role chips).
- `RoleScopeChips` row — schools admin manages.
- Body: "PERAN SAYA" section with role rows (Admin, Guru if applicable).
  "Beralih" mini-CTA on each row that's not currently active.
- Account links list: Profil lengkap · Keamanan · Keluar (red).

#### B. Profil page (full screen)
- `BrandPageHeader` with large centered avatar.
- `SecurityChecklistCard` immediately under hero (navy-bordered, has
  progress bar + checklist items).
- `ProfileFieldList` (read-only data display).
- Footer: "Keluar dari semua perangkat" red-tinted card.

### Components & props

```dart
IdentityHero({
  required String avatarInitials,
  required String name,
  required String email,
  required String roleLabel,        // "Admin"
  String? subRole,                  // "SU · 2FA aktif"
});

RoleScopeChips({
  required List<SchoolScope> schools,
  required String activeSchoolId,
  required ValueChanged<String> onSelect,
  int maxVisible = 3,
});

SecurityChecklistCard({
  required double percentSecure,    // 0..1, drives bar
  required List<SecurityCheck> items,
});

class SecurityCheck {
  final String label;               // "2FA aktif"
  final SecurityState state;        // ok / warn / fail
  final String? actionLabel;        // "Ganti sekarang"
  final VoidCallback? onAction;
}
```

### Edge cases
- Single-school admin → `RoleScopeChips` section hides.
- All checks green → checklist card shrinks to 1-line "Akun Anda 100%
  aman" celebratory variant.
- Password just changed → "Password 60+ hari" item flips to green
  immediately (don't wait for backend confirm).

---

## 9 · Mockup 16 — Shared dialogs gallery

This is a **canonical reference**, not a new screen. Use it when:
- Adding a new admin screen — pick from this gallery first.
- Auditing a screen for design-token drift.
- Onboarding a new contributor.

The gallery covers:
- `AdminFormFooter` — default + saving variants
- `AdminFormToggle` — neutral + warning tones
- `AdminFormChoiceChips` — single-select with clear-on-retap
- `ConfirmationDialog` — destructive variant
- `BulkActionBar` — long-press triggered
- `ActiveFilterChips` — sticky-in-hero with reset chip
- `AdminFormSheetHeader` — with editingContext slot (NEW prop on
  existing widget)

Every element ships in `lib/core/widgets/admin_form_components.dart`
(footer/toggle/choice chips) or `lib/core/widgets/` (the rest). The
gallery exposes the **exact pixel contract** so engineering can verify
implementation parity.

---

## 10 · Migration order (suggested)

1. **#16 Shared dialogs polish (gallery)** — no new widgets, just
   verify everything in the catalog matches the gallery. Catches drift
   before building on top.
2. **#15 Profil admin** — small surface, lets you ship `IdentityHero` +
   `RoleScopeChips` + `SecurityChecklistCard` early.
3. **#14 Sistem hub** — `CategoryGridHero` + `AuditLogPin` + the
   sub-screen template. After this 4 of the 5 settings sub-screens are
   formulaic.
4. **#13 Keuangan hub** — `MoneyFlowStrip` + `FlowBar`. Big visual
   payoff for relatively contained widget surface.
5. **#11 Kehadiran report** — `AttendanceRingHero` + `TrendSparkRow`.
6. **#12 Kehadiran detail** — `CalendarHeatmap` + `CellDetailSheet`.
   Needs #11 to ship first because it's drilled in from there.
7. **#10 Pengumuman** — `AudienceMatrix` is the riskiest new pattern;
   ship it last in this batch so it can borrow learnings from the
   simpler ones.
8. **#08 Raport** — `StatusPipelineStrip` is biggest UX shift for
   admins. Ship after the other patterns are battle-tested.
9. **#09 RPP** — `ReviewQueueColumn` + `SwipeableQueueCard`. The
   gesture-heavy one; deserves the most QA cycles.

Each step ends with `dart format` + `dart analyze` on the touched
folder + a screenshot diff vs the SVG.

---

## 11 · Cross-cutting verifications

Before any of these screens lands:
- Token check: every color comes from `ColorUtils.*`; no hex literals
  in presentation.
- Padding check: every `EdgeInsets` comes from `AppSpacing`.
- Navigation check: every `Navigator.pop` is `AppNavigator.pop`.
- Snackbar check: every success/error message goes through
  `SnackBarUtils.show*`.
- String check: every user-visible string is Bahasa Indonesia (or
  routed through `getTranslatedText` if bilingual).
- Status vocab: backend `Pending/Approved/Rejected` mapped to UI
  `Menunggu/Disetujui/Ditolak` at the boundary.
