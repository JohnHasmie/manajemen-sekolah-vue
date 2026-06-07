// Grid frame/chrome widgets for the admin week-grid view.
//
// Extracted verbatim from `admin_schedule_week_grid_view.dart` during the
// Phase-2 readability split. The day-header row + cell, the left time-axis
// rail, the now-line, and the focused-day pill strip. Kept as a `part` file
// so the main grid file shrinks to the layout orchestrator + day column.
part of 'admin_schedule_week_grid_view.dart';

// ─────────────────────────────────────────────────────────────────────
// Day header row
// ─────────────────────────────────────────────────────────────────────

class _DayHeaderRow extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final String? todayDayId;
  final double timeColumnWidth;
  final ValueChanged<String?>? onDayTap;

  const _DayHeaderRow({
    required this.days,
    required this.todayDayId,
    required this.timeColumnWidth,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Container(
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                border: Border(right: BorderSide(color: ColorUtils.slate200)),
              ),
              height: 32,
            ),
          ),
          for (final d in days)
            Expanded(
              child: _DayHeaderCell(
                day: d,
                isToday: d['id']?.toString() == todayDayId,
                onTap: onDayTap == null
                    ? null
                    : () => onDayTap!(d['id']?.toString()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeaderCell extends StatelessWidget {
  final Map<String, dynamic> day;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayHeaderCell({required this.day, required this.isToday, this.onTap});

  String _abbreviation(String name) {
    // Indonesian day names — first 3 letters uppercase.
    if (name.length <= 3) return name.toUpperCase();
    return name.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = (day['name'] ?? '').toString();
    final cell = Container(
      height: 32,
      decoration: BoxDecoration(
        color: isToday ? ColorUtils.brandDarkBlue : Colors.transparent,
        border: Border(right: BorderSide(color: ColorUtils.slate100)),
      ),
      alignment: Alignment.center,
      child: Text(
        _abbreviation(name),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isToday ? Colors.white : ColorUtils.slate600,
          letterSpacing: 0.4,
        ),
      ),
    );
    if (onTap == null) return cell;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cell,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Time column (left rail)
// ─────────────────────────────────────────────────────────────────────

class _TimeColumn extends StatelessWidget {
  final int startMinutes;
  final int endMinutes;
  final double pxPerMinute;
  final double width;

  const _TimeColumn({
    required this.startMinutes,
    required this.endMinutes,
    required this.pxPerMinute,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final hourCount = ((endMinutes - startMinutes) ~/ 60).clamp(1, 24);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(right: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < hourCount; i++)
            SizedBox(
              height: 60 * pxPerMinute,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate100),
                  ),
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 3, top: 2),
                child: Text(
                  ((startMinutes ~/ 60) + i).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Now line — red horizontal line + dot
// ─────────────────────────────────────────────────────────────────────

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(height: 1, color: ColorUtils.error600),
            Positioned(
              left: -3,
              top: -3,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: ColorUtils.error600,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Focused-day header strip
// ─────────────────────────────────────────────────────────────────────

/// Header used in the grid's focused-day mode — pill tabs for each
/// weekday (active = filled navy, others = outlined slate) plus a
/// zoom-out chevron on the right that returns to the full week view.
///
/// Today gets a small accent dot next to its label so the admin can
/// always see which day "is today" while browsing other days.
class _FocusedDayHeaderStrip extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final String focusedDayId;
  final String? todayDayId;
  final ValueChanged<String> onPicked;
  final VoidCallback onZoomOut;

  const _FocusedDayHeaderStrip({
    required this.days,
    required this.focusedDayId,
    required this.todayDayId,
    required this.onPicked,
    required this.onZoomOut,
  });

  String _abbr(String name) {
    if (name.isEmpty) return '—';
    return name.substring(0, name.length.clamp(0, 3)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < days.length; i++) ...[
                    _DayPill(
                      label: _abbr((days[i]['name'] ?? '').toString()),
                      active: days[i]['id']?.toString() == focusedDayId,
                      isToday: days[i]['id']?.toString() == todayDayId,
                      onTap: () => onPicked(days[i]['id']?.toString() ?? ''),
                    ),
                    if (i < days.length - 1) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Zoom-out: returns to the full 6-day week view.
          Tooltip(
            message: kSchViewAllDays.tr,
            child: GestureDetector(
              onTap: onZoomOut,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: ColorUtils.slate200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 16,
                  color: ColorUtils.brandDarkBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final bool active;
  final bool isToday;
  final VoidCallback onTap;

  const _DayPill({
    required this.label,
    required this.active,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ColorUtils.brandDarkBlue : Colors.white,
          border: Border.all(
            color: active ? ColorUtils.brandDarkBlue : ColorUtils.slate200,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ColorUtils.slate700,
                letterSpacing: 0.3,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? Colors.white : ColorUtils.error600,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
