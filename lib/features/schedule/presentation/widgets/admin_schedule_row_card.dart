// Frame B row card — admin Jadwal list view redesign (TR.B).
//
// Replaces the v3 `AdminScheduleCard` ("BrandListRow"-based avatar + title)
// with a denser, calendar-style row inspired by the redesign mockup:
//
//     ┌──────┬──────────────────────────────────────────────┬───┐
//     │07.00 │ Fisika · Hukum Newton                        │ › │
//     │— 08:30│ XI-IPA-1 · Pak Bambang · Lab 2              │   │
//     │ 90 mnt│                                              │   │
//     └──────┴──────────────────────────────────────────────┴───┘
//
// Conflict rows render a red border, a red-tinted background, a
// "BENTROK" pill in the top-right corner, and a red subtitle pointing
// to the conflicting session count.
//
// Architecture notes:
//   * Reads `conflict_with` via the shared `ScheduleConflictJson`
//     extension on `Map<String, dynamic>` — no Schedule freezed model
//     change required.
//   * Tap → caller's [onTap] (typically opens the Frame C detail sheet).
//   * Long-press → caller's [onLongPress] (enters bulk-select mode in
//     the admin Jadwal screen).
//   * When [selected] is true the right edge swaps from a chevron to a
//     filled cobalt checkbox so the row reads as "checked" inside the
//     bulk-select bar.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule_kpi_summary.dart';

class AdminScheduleRowCard extends StatelessWidget {
  /// Raw schedule map straight from the API list response. Read via
  /// the [ScheduleConflictJson] extension for `conflict_with` and via
  /// direct keys for everything else.
  final Map<String, dynamic> schedule;

  /// Pre-formatted time-of-day label, e.g. "07:00" or "07.00".
  /// Caller is expected to pass the start time component only — the
  /// row card adds the dash + end-time itself.
  final String startTimeLabel;

  /// Pre-formatted end-of-period label, e.g. "08:30".
  final String endTimeLabel;

  /// Optional duration label shown under the time block, e.g. "90 mnt".
  final String? durationLabel;

  /// Subject name shown as the row title.
  final String subjectName;

  /// Class name (e.g. "X-IPA-1").
  final String? className;

  /// Teacher name (e.g. "Pak Yahya"). Rendered in cobalt accent.
  final String? teacherName;

  /// Optional room name (e.g. "R-101"). Rendered after the teacher.
  final String? roomName;

  /// True when the row is part of the current bulk selection.
  final bool selected;

  /// Tap handler — typically opens the Frame C schedule detail sheet,
  /// or toggles selection when bulk-select mode is active.
  final VoidCallback? onTap;

  /// Long-press handler — typically enters bulk-select mode.
  final VoidCallback? onLongPress;

  const AdminScheduleRowCard({
    super.key,
    required this.schedule,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.subjectName,
    this.durationLabel,
    this.className,
    this.teacherName,
    this.roomName,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  /// Splits a time string like "07:00" / "07.00" into (hours, minutes)
  /// strings for the stacked-time column. Falls back to the raw input
  /// on either side when the format isn't recognized.
  static (String, String) _splitTime(String raw) {
    if (raw.isEmpty) return ('--', '--');
    final cleaned = raw.replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length < 2) return (cleaned, '');
    return (parts[0].padLeft(2, '0'), parts[1].padLeft(2, '0'));
  }

  @override
  Widget build(BuildContext context) {
    final hasConflict = schedule.hasScheduleConflict;
    final conflictCount = schedule.conflictWithIds.length;
    final (startHours, startMinutes) = _splitTime(startTimeLabel);

    final borderColor = hasConflict
        ? ColorUtils.error600
        : (selected ? ColorUtils.brandCobalt : ColorUtils.slate200);
    final cardBg = hasConflict
        ? ColorUtils.error600.withValues(alpha: 0.04)
        : (selected
              ? ColorUtils.brandCobalt.withValues(alpha: 0.04)
              : Colors.white);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: hasConflict ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            // IntrinsicHeight bounds the Row's cross-axis so children with
            // `CrossAxisAlignment.stretch` (e.g. the left time column's
            // right divider) can size against a definite height. Without
            // this wrapper the Row inherits the parent ListView's infinite
            // vertical constraint and the stretch pass crashes with
            // "BoxConstraints forces an infinite height".
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left time column ──────────────────────────────────
                  _TimeColumn(
                    startHours: startHours,
                    startMinutes: startMinutes,
                    endLabel: endTimeLabel,
                    duration: durationLabel,
                  ),
                  const SizedBox(width: 10),
                  // ── Body ──────────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            subjectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _MetaLine(
                            className: className,
                            teacherName: teacherName,
                            roomName: roomName,
                          ),
                          if (hasConflict) ...[
                            const SizedBox(height: 4),
                            Text(
                              conflictCount == 1
                                  ? '⚠ Bentrok dengan 1 sesi lain'
                                  : '⚠ Bentrok dengan $conflictCount sesi lain',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.error600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── Right rail: chevron OR selection checkbox ─────────
                  _RightRail(selected: selected),
                ],
              ),
            ),
          ),
          if (hasConflict)
            Positioned(top: -8, right: 12, child: _ConflictPill()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Left time column
// ─────────────────────────────────────────────────────────────────────

class _TimeColumn extends StatelessWidget {
  final String startHours;
  final String startMinutes;
  final String endLabel;
  final String? duration;

  const _TimeColumn({
    required this.startHours,
    required this.startMinutes,
    required this.endLabel,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandDarkBlue,
                height: 1.1,
              ),
              children: [
                TextSpan(text: startHours),
                TextSpan(
                  text: '.',
                  style: TextStyle(
                    color: ColorUtils.slate300,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: startMinutes),
              ],
            ),
          ),
          if (endLabel.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              '— $endLabel',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate500,
                height: 1.2,
              ),
            ),
          ],
          if (duration != null && duration!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              duration!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Meta line (class · teacher · room)
// ─────────────────────────────────────────────────────────────────────

class _MetaLine extends StatelessWidget {
  final String? className;
  final String? teacherName;
  final String? roomName;

  const _MetaLine({
    required this.className,
    required this.teacherName,
    required this.roomName,
  });

  @override
  Widget build(BuildContext context) {
    final hasClass = (className ?? '').isNotEmpty;
    final hasTeacher = (teacherName ?? '').isNotEmpty;
    final hasRoom = (roomName ?? '').isNotEmpty;

    if (!hasClass && !hasTeacher && !hasRoom) {
      return Text(
        '—',
        style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
      );
    }

    return DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: ColorUtils.slate600,
        height: 1.2,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasClass)
            Text(
              className!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
          if (hasClass && (hasTeacher || hasRoom)) _MetaDot(),
          if (hasTeacher)
            Text(
              teacherName!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.brandCobalt,
              ),
            ),
          if (hasTeacher && hasRoom) _MetaDot(),
          if (hasRoom)
            Text(
              roomName!,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate600,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: ColorUtils.slate300,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Right rail — chevron OR selection checkbox
// ─────────────────────────────────────────────────────────────────────

class _RightRail extends StatelessWidget {
  final bool selected;

  const _RightRail({required this.selected});

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorUtils.brandCobalt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ColorUtils.brandCobalt, width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: ColorUtils.slate600,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Conflict pill — sits half-overlapping the top-right corner
// ─────────────────────────────────────────────────────────────────────

class _ConflictPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.error600,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.error600.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Text(
        'BENTROK',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Day-tab pills strip — used above the row list to filter by weekday
// ─────────────────────────────────────────────────────────────────────

/// Horizontal pill strip showing one tab per day. The currently
/// selected day is rendered as a filled navy pill; other days render
/// outlined slate.
///
/// Pass `selectedDayId == null` to show an "All days" mode.
/// Tapping the active tab toggles back to all-days.
class AdminScheduleDayTabStrip extends StatelessWidget {
  /// All visible days sorted by order_number (Senin → Sabtu).
  final List<Map<String, dynamic>> days;

  /// Currently selected `day_id`, or null for "all days".
  final String? selectedDayId;

  /// Map of day_id → schedule count, used for the badge on each tab.
  final Map<String, int> countsByDay;

  /// Called with the new selection. Pass null to clear the filter.
  final ValueChanged<String?> onChanged;

  const AdminScheduleDayTabStrip({
    super.key,
    required this.days,
    required this.selectedDayId,
    required this.countsByDay,
    required this.onChanged,
  });

  String _abbreviation(String name) {
    if (name.length <= 3) return name.toUpperCase();
    return name.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _AllTab(active: selectedDayId == null, onTap: () => onChanged(null)),
          for (final d in days) ...[
            const SizedBox(width: 6),
            _DayTab(
              label: _abbreviation((d['name'] ?? '').toString()),
              count: countsByDay[d['id']?.toString()] ?? 0,
              active: selectedDayId == d['id']?.toString(),
              onTap: () {
                final id = d['id']?.toString();
                onChanged(id == selectedDayId ? null : id);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AllTab extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _AllTab({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? ColorUtils.brandDarkBlue : Colors.white,
          border: Border.all(
            color: active ? ColorUtils.brandDarkBlue : ColorUtils.slate200,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Semua',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : ColorUtils.slate700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _DayTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ColorUtils.brandDarkBlue : Colors.white,
          border: Border.all(
            color: active ? ColorUtils.brandDarkBlue : ColorUtils.slate200,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ColorUtils.slate700,
                letterSpacing: 0.3,
                height: 1.1,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white : ColorUtils.brandCobalt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: active ? ColorUtils.brandDarkBlue : Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header (Pagi / Siang)
// ─────────────────────────────────────────────────────────────────────

/// Small "label · count" header that sits above each Pagi / Siang
/// group inside the list view. Matches the mockup's compact slate
/// kicker pattern.
class AdminScheduleSectionHead extends StatelessWidget {
  final String label;
  final int count;

  const AdminScheduleSectionHead({
    super.key,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count == 1 ? '1 sesi' : '$count sesi',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
