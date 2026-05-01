# Parent Phase-3 — Shared Component Plan

The Phase-3 visual language for parent screens must come from
**shared widgets** in `lib/core/widgets/`, not inline copies per screen.
That way the dashboard's idiom (azure gradient hero + child selector
chip row + KPI ring + day cards + filter bottom sheet) flows through
every parent surface, and a future style change touches one place.

## A. New shared widgets to create

### A1. `BrandPageHeader`
`lib/core/widgets/brand_page_header.dart`

Generalises `GradientPageHeader` (which exists today) with brand-aware
gradient + Phase-3 slots. Drop-in replacement.

```dart
BrandPageHeader({
  required String title,
  String? subtitle,                   // line above title (e.g. "Akademik · Anak")
  required String role,               // 'admin' | 'guru' | 'wali' — drives gradient
  VoidCallback? onBackPressed,        // auto-shows if Navigator.canPop
  List<Widget>? actionIcons,          // top-right 36×36 white-translucent icons
  Widget? realtimeIndicator,          // optional row above the title (green dot + label)
  Widget? childSelector,              // optional row of horizontal chips (parent-only)
  List<Widget>? filterChips,          // optional row of filter pills under title
});
```

**Gradient:** sourced from `ColorUtils.brandGradient(role)`. Already
exists.

**Replaces:** the inline gradient `Container` blocks in
`parent_billing_screen.dart`, `parent_grade_screen.dart`,
`parent_report_card_detail_screen.dart`, and the upcoming Kehadiran
work. Eventually also replaces `TeacherPageHeader` for teacher
surfaces.

### A2. `ChildSelectorChipRow`
`lib/core/widgets/child_selector_chip_row.dart`

Horizontal scrollable chip row of children. Active child has solid
white pill background + brand-coloured initials avatar + black text;
others are translucent (white at 16% opacity) with white text. Fades
to invisible at the right edge to hint at scroll when there are 3+
children.

```dart
ChildSelectorChipRow({
  required List<ChildSummary> children,
  required String selectedChildId,
  required ValueChanged<String> onSelected,
  Color brandColor = ColorUtils.brandAzure, // for active avatar
});

class ChildSummary {
  final String id;
  final String shortName;       // 'Rania'
  final String klass;           // 'Kelas 8B'
  final String? avatarInitials; // 'RA' (auto-generated from name if null)
}
```

If a parent has only 1 child, the row falls back to a single static
pill — no scroll, no "Ganti".

### A3. `AttendanceRingKpi`
`lib/core/widgets/attendance_ring_kpi.dart`

The donut + legend used in the Kehadiran main screen. Reusable for
the admin "kehadiran hari ini" KPI on the dashboard too.

```dart
AttendanceRingKpi({
  required double rate,                  // 0..100
  required int present,
  required int excused,
  required int sick,
  required int alpha,
  required int schoolDays,
  double? deltaPct,                       // null hides the trend chip
  String periodLabel = 'Bulan ini',
  Color brandColor = ColorUtils.brandAzure,
});
```

### A4. `AttendanceDayCard`
`lib/core/widgets/attendance_day_card.dart`

Single-day list row used in the Riwayat harian list.

```dart
AttendanceDayCard({
  required DateTime date,                    // drives day-of-week badge
  required AttendanceStatus status,
  String? checkInTime,
  String? checkOutTime,
  int? lateMinutes,
  String? note,
  String? attachmentUrl,
  VoidCallback? onTap,
});

enum AttendanceStatus { present, late, excused, sick, alpha }
```

Color mapping is built in:
- `present` → green-50 day badge, green-100 status pill
- `late` / `sick` → amber-50 / amber-100
- `excused` → cyan-50 / cyan-100
- `alpha` → red-50 / red-100

### A5. `AttendanceCalendarGrid`
`lib/core/widgets/attendance_calendar_grid.dart`

7-column SEN-MIN month grid with each cell coloured by status. Used
on the "Lihat kalender penuh" screen and (optionally) the parent
dashboard's expanded view later.

```dart
AttendanceCalendarGrid({
  required DateTime month,                              // any date in the target month
  required Map<DateTime, AttendanceStatus> dayStatuses, // sparse — missing keys render slate
  DateTime? selectedDate,
  ValueChanged<DateTime>? onDaySelected,
});
```

Renders the full 6-row × 7-col grid (including last-week-of-prev-month
and first-week-of-next-month grayed out). Selected cell gets the
brand-azure 2px ring.

## B. Existing shared widgets to reuse (no rewrite)

| Widget | Used for | Notes |
|---|---|---|
| `AppFilterBottomSheet` | Filter sheet for Kehadiran period+status | Same as teacher pattern |
| `AppRefreshIndicator` | Pull-to-refresh on every parent screen | Pass `accentColor: ColorUtils.brandAzure` |
| `BottomSheetFooter` | Cancel / Apply row inside the filter sheet | Already supports primaryColor |
| `EmptyState` / `ErrorScreen` | When no children / no data / network fail | Pass brand color |
| `SkeletonListLoading` | Loading state for day list, calendar, billing | Already in use |
| `SectionHeader` | "Riwayat harian" title | Already used by parent_attendance |

## C. Per-screen usage map

| Parent screen | Header | Body components |
|---|---|---|
| Kehadiran (main) | `BrandPageHeader` + `ChildSelectorChipRow` + 2 filter chips | `AttendanceRingKpi` + `SectionHeader` + repeated `AttendanceDayCard` + footer "Lihat kalender penuh" CTA |
| Kehadiran (calendar) | `BrandPageHeader` + 4 mini KPI tiles | `AttendanceCalendarGrid` + day-detail panel underneath |
| Pengumuman | `BrandPageHeader` + filter chips | reuse existing `EnhancedSearchBar` + announcement card list |
| Aktivitas Kelas | `BrandPageHeader` + `ChildSelectorChipRow` | activity card list |
| Ringkasan Rapor | `BrandPageHeader` + `ChildSelectorChipRow` + semester chip | `HeroStatsRow` + subject grade cards |
| Detail Rapor | `BrandPageHeader` (with back) | existing report card detail body |
| Tagihan (billing) | `BrandPageHeader` + filter chip + inline search field | existing `StudentSelector` + `BillingList` |
| Nilai (grade list) | `BrandPageHeader` + `ChildSelectorChipRow` | existing grade list |

## D. Implementation order

1. Build `BrandPageHeader` — covers every screen.
2. Build `ChildSelectorChipRow` — covers Kehadiran, Aktivitas, Rapor, Nilai.
3. Migrate `parent_billing_screen.dart` to `BrandPageHeader` (already
   has the inline equivalent, this just promotes it to shared).
4. Build `AttendanceRingKpi`, `AttendanceDayCard`,
   `AttendanceCalendarGrid` together — they belong to one feature.
5. Rebuild `parent_attendance_screen.dart` on the new widgets +
   `BrandPageHeader` + `ChildSelectorChipRow` + filter sheet.
6. Build the calendar full-month screen `parent_attendance_calendar_screen.dart`.
7. Migrate the remaining parent screens one by one
   (Pengumuman, Aktivitas, Ringkasan Rapor, Nilai) — each becomes a
   small focused commit on `refactor/brand-phase3-sweep`.

## E. Future reuse

Once these widgets exist, the **teacher** and **admin** roles can also
swap onto `BrandPageHeader` (via the `role:` arg, gradient changes
automatically). `AttendanceRingKpi` plugs into the admin dashboard's
"kehadiran hari ini" tile naturally — same data shape.
