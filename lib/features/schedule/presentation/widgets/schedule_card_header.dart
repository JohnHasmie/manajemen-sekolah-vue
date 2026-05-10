// Header section of a schedule card — Frame A (v2 jadwal redesign).
//
// Visual contract — derived from `_design/teacher_jadwal_redesign.html`
// Frame A:
//
//   ┌────────────────────────────────────────────────┐
//   │ ┌──────┐  Subject name              [class]    │
//   │ │  3   │                                       │
//   │ │  JP  │  ⏱ 09.10–09.50  ·  📍 R.Lab IPA       │
//   │ └──────┘                                  [SEDANG]│
//   └────────────────────────────────────────────────┘
//
//   • 44dp rounded square `hour-chip` with day-color gradient,
//     `<n>` and `JP` label stacked. Soft drop-shadow tinted by the
//     day color when not past.
//   • Subject name on top row (slate-900, 14pt/800), with cobalt class
//     pill on the right.
//   • Bottom row: cobalt time pill + optional teacher/room line.
//   • Top-right corner: status pill — `SEDANG` (red), `SELANJUTNYA`
//     (cobalt), `Selesai` (slate). Shown only when one of those
//     states applies; otherwise nothing is rendered there so the
//     subject text can use the full width.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_helpers.dart';

/// Header section of a schedule card — compact day-colored hour chip,
/// subject + class pill, time + teacher/room, status pill.
class ScheduleCardHeader extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Color accentColor;
  final Color subTextColor;
  final String selectedAcademicYear;
  final LanguageProvider languageProvider;

  /// Day-specific color for the hour chip (e.g. indigo for Monday,
  /// teal for Friday).
  final Color? dayColor;

  /// Whether the card is dimmed (past schedule).
  final bool isPast;

  /// Whether this lesson is happening RIGHT NOW (start ≤ now < end).
  final bool isCurrent;

  /// Whether this is the "next upcoming" lesson today.
  final bool isNext;

  /// Whether this is viewed in wali kelas (homeroom) mode.
  final bool isHomeroomView;

  const ScheduleCardHeader({
    super.key,
    required this.schedule,
    required this.accentColor,
    required this.subTextColor,
    required this.selectedAcademicYear,
    required this.languageProvider,
    this.dayColor,
    this.isPast = false,
    this.isCurrent = false,
    this.isNext = false,
    this.isHomeroomView = false,
  });

  Schedule get _model => Schedule.fromJson(schedule);

  /// Cobalt is the canonical class-pill color (teacher role brand).
  Color get _cobalt => ColorUtils.brandCobalt;

  Color get _hourChipColor {
    if (isPast) return ColorUtils.slate400;
    return dayColor ?? _cobalt;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHourChip(),
        const SizedBox(width: 12),
        Expanded(child: _buildInfo()),
        if (_statusLabel() != null) ...[
          const SizedBox(width: 8),
          _StatusPill(label: _statusLabel()!, kind: _statusKind()!),
        ],
      ],
    );
  }

  // ── Hour chip — 44dp gradient square ──────────────────────────────

  Widget _buildHourChip() {
    final color = _hourChipColor;
    final hourNum = _model.lessonHour?.toString() ?? '-';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: isPast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.white, 0.15) ?? color],
              ),
        color: isPast ? color : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isPast
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hourNum,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'JP',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.86),
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Info column — subject/class/teacher/time ──────────────────────

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [_buildTopRow(), const SizedBox(height: 5), _buildBottomRow()],
    );
  }

  /// Subject name + cobalt class pill.
  Widget _buildTopRow() {
    final className = (_model.className ?? '').isNotEmpty
        ? _model.className!
        : '-';
    final subjectColor = isPast ? ColorUtils.slate500 : ColorUtils.slate900;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            (_model.subjectName ?? '').isNotEmpty
                ? _model.subjectName!
                : languageProvider.getTranslatedText({
                    'en': 'Subject',
                    'id': 'Mata Pelajaran',
                  }),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: subjectColor,
              height: 1.2,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        _ClassPill(className: className, isPast: isPast),
      ],
    );
  }

  /// Cobalt time-pill plus optional teacher (in homeroom mode).
  Widget _buildBottomRow() {
    final hasTeacher = isHomeroomView && (_model.teacherName ?? '').isNotEmpty;
    final color = isPast ? ColorUtils.slate500 : _cobalt;

    return Row(
      children: [
        _MetaChip(
          icon: Icons.access_time_rounded,
          text:
              '${formatTimeStr(_model.startTime)} – ${formatTimeStr(_model.endTime)}',
          color: color,
        ),
        if (hasTeacher) ...[
          const SizedBox(width: 6),
          _DotSeparator(color: color.withValues(alpha: 0.45)),
          const SizedBox(width: 6),
          Flexible(
            child: _MetaChip(
              icon: Icons.person_rounded,
              text: _model.teacherName!,
              color: isPast ? ColorUtils.slate500 : ColorUtils.slate600,
              ellipsize: true,
            ),
          ),
        ],
      ],
    );
  }

  // ── Status pill resolution ────────────────────────────────────────

  String? _statusLabel() {
    if (isCurrent) return 'SEDANG';
    if (isNext) return 'SELANJUTNYA';
    if (isPast) return 'SELESAI';
    return null;
  }

  _StatusKind? _statusKind() {
    if (isCurrent) return _StatusKind.now;
    if (isNext) return _StatusKind.next;
    if (isPast) return _StatusKind.done;
    return null;
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

/// Cobalt-tinted class pill (e.g. `7A`, `8B`).
class _ClassPill extends StatelessWidget {
  final String className;
  final bool isPast;

  const _ClassPill({required this.className, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final color = isPast ? ColorUtils.slate500 : ColorUtils.brandCobalt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Text(
        className,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Inline icon + text — used for the time and teacher metadata.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool ellipsize;

  const _MetaChip({
    required this.icon,
    required this.text,
    required this.color,
    this.ellipsize = false,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Text(
      text,
      maxLines: 1,
      overflow: ellipsize ? TextOverflow.ellipsis : TextOverflow.clip,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        ellipsize ? Flexible(child: txt) : txt,
      ],
    );
  }
}

/// 4dp middot separator between the time pill and the teacher meta.
class _DotSeparator extends StatelessWidget {
  final Color color;
  const _DotSeparator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        height: 1.0,
        fontSize: 13,
      ),
    );
  }
}

enum _StatusKind { now, next, done }

class _StatusPill extends StatelessWidget {
  final String label;
  final _StatusKind kind;

  const _StatusPill({required this.label, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      _StatusKind.now => (
        ColorUtils.error600.withValues(alpha: 0.10),
        ColorUtils.error600,
      ),
      _StatusKind.next => (
        ColorUtils.brandCobalt.withValues(alpha: 0.10),
        ColorUtils.brandCobalt,
      ),
      _StatusKind.done => (ColorUtils.slate100, ColorUtils.slate500),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
          height: 1.0,
        ),
      ),
    );
  }
}
