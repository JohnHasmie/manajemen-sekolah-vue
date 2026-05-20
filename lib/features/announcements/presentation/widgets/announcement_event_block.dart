// Pengumuman + Acara — event block rendered inside each announcement card.
//
// Three colour variants drive urgency at a glance:
//   - upcoming   (blue 50→100) — default for future events
//   - live       (rose  50→100) — event happening now (≤ 1 hour or in window)
//   - past       (slate 100)    — event already ended
//
// Stateless / dumb — accepts an AnnouncementEvent and a single
// onTap callback. The countdown label comes from the event model
// itself so list cards don't need to compute deltas.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';

class AnnouncementEventBlock extends StatelessWidget {
  const AnnouncementEventBlock({
    super.key,
    required this.event,
    this.onTap,
    this.trailingLabel,
    this.dense = false,
  });

  final AnnouncementEvent event;

  /// Optional whole-block tap target. Cards typically delegate to the
  /// outer InkWell already, so this is null for list usage and only
  /// set when the block is standalone (e.g. on the detail hero).
  final VoidCallback? onTap;

  /// Override for the trailing pill (defaults to a chevron). Pass a
  /// short string like "Hadir" / "Pengingat" to surface an action.
  final String? trailingLabel;

  /// Tighter padding for list-card use (true) vs the roomier detail
  /// hero (false).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(event);
    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final body = Container(
      padding: pad,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _DateTile(event: event, palette: palette),
          const SizedBox(width: 10),
          Expanded(
            child: _MetaColumn(event: event, palette: palette),
          ),
          const SizedBox(width: 6),
          _TrailingPill(label: trailingLabel, palette: palette),
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: body,
    );
  }

  static _Palette _palette(AnnouncementEvent e) {
    switch (e.state) {
      case AnnouncementEventState.upcoming:
        return const _Palette(
          gradient: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          border: Color(0xFFBFDBFE),
          accent: Color(0xFF1D4ED8), // blue-700
          dateTileBg: Colors.white,
        );
      case AnnouncementEventState.live:
        return const _Palette(
          gradient: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
          border: Color(0xFFFCA5A5),
          accent: Color(0xFFB91C1C), // red-700
          dateTileBg: Colors.white,
        );
      case AnnouncementEventState.past:
        return _Palette(
          gradient: [ColorUtils.slate100, ColorUtils.slate100],
          border: ColorUtils.slate200,
          accent: ColorUtils.slate600,
          dateTileBg: Colors.white,
        );
    }
  }
}

class _Palette {
  const _Palette({
    required this.gradient,
    required this.border,
    required this.accent,
    required this.dateTileBg,
  });
  final List<Color> gradient;
  final Color border;
  final Color accent;
  final Color dateTileBg;
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.event, required this.palette});
  final AnnouncementEvent event;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final d = event.eventAt;
    final monthLabel = _monthAbbrev(d.month);
    final dowLabel = _dowAbbrev(d.weekday);
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: palette.dateTileBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            monthLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: palette.accent,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dowLabel,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _monthAbbrev(int m) {
    const list = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MEI',
      'JUN',
      'JUL',
      'AGU',
      'SEP',
      'OKT',
      'NOV',
      'DES',
    ];
    return list[(m - 1).clamp(0, 11)];
  }

  static String _dowAbbrev(int weekday) {
    const list = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return list[(weekday - 1).clamp(0, 6)];
  }
}

class _MetaColumn extends StatelessWidget {
  const _MetaColumn({required this.event, required this.palette});
  final AnnouncementEvent event;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final timeText = event.eventHasTime
        ? _formatHM(event.eventAt)
        : 'Sepanjang hari';
    final subParts = <String>[
      timeText,
      if (event.eventLocation != null) event.eventLocation!,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              event.isLive
                  ? Icons.error_outline_rounded
                  : Icons.access_time_rounded,
              size: 11,
              color: palette.accent,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                event.isLive
                    ? 'BERLANGSUNG SEKARANG'
                    : 'ACARA · ${event.countdownLabel}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subParts.join(' · '),
          style: TextStyle(
            fontSize: 11.5,
            color: ColorUtils.slate700,
            height: 1.35,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  static String _formatHM(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }
}

class _TrailingPill extends StatelessWidget {
  const _TrailingPill({required this.label, required this.palette});
  final String? label;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.border),
        ),
        child: Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: palette.accent,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label!,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: palette.accent,
        ),
      ),
    );
  }
}
