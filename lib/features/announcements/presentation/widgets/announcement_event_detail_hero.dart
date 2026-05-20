// Pengumuman + Acara — detail-screen hero card.
//
// Sits below the announcement body and shows:
//   - Top label ("ACARA · DALAM 7 HARI" / "BERLANGSUNG SEKARANG")
//   - Big date line ("Rabu, 27 Mei 2026 — 14:00")
//   - 4-cell countdown (HARI / JAM / MENIT / DETIK), updated every
//     second via a Timer. Stops when state == past.
//   - Status list of admin-scheduled reminders (sent / pending /
//     skipped) when [adminReminders] is supplied.
//   - Personal reminder list when [personalReminders] is supplied,
//     with a CTA chip to open the "Atur Pengingat" picker.
//
// All sections are optional — a parent screen renders only the
// blocks it has data for. Stateless apart from the countdown timer.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';

class AnnouncementEventDetailHero extends StatefulWidget {
  const AnnouncementEventDetailHero({
    super.key,
    required this.event,
    this.adminReminders,
    this.personalReminders,
    this.onAddPersonalReminder,
    this.onRemovePersonalReminder,
  });

  final AnnouncementEvent event;

  /// Admin-side reminder rows from the backend.
  /// Each map mirrors the AnnouncementReminder JSON shape:
  /// `{offset_minutes, status, recipients_total, recipients_delivered}`.
  final List<Map<String, dynamic>>? adminReminders;

  /// Personal reminders the viewer has set. Each map shape:
  /// `{id, offset_minutes, status, fire_at}`.
  final List<Map<String, dynamic>>? personalReminders;

  final VoidCallback? onAddPersonalReminder;
  final void Function(String reminderId)? onRemovePersonalReminder;

  @override
  State<AnnouncementEventDetailHero> createState() =>
      _AnnouncementEventDetailHeroState();
}

class _AnnouncementEventDetailHeroState
    extends State<AnnouncementEventDetailHero> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Re-render every second so the countdown updates live.
    // Stops automatically once the event is past.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.event.isPast) {
        _ticker?.cancel();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final palette = _palette(e);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.isLive
                    ? 'BERLANGSUNG SEKARANG'
                    : 'ACARA · ${e.countdownLabel}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatWhen(e),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  letterSpacing: -0.2,
                ),
              ),
              if (e.eventLocation != null) ...[
                const SizedBox(height: 2),
                Text(
                  e.eventLocation!,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate700,
                  ),
                ),
              ],
              if (!e.isPast) ...[
                const SizedBox(height: 12),
                _CountdownRow(event: e, palette: palette),
              ],
            ],
          ),
        ),
        if (widget.adminReminders != null &&
            widget.adminReminders!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ReminderStatusCard(
            title: 'STATUS PERINGATAN',
            rows: widget.adminReminders!,
            isAdmin: true,
          ),
        ],
        if (widget.personalReminders != null) ...[
          const SizedBox(height: 12),
          _PersonalReminderCard(
            rows: widget.personalReminders!,
            onAdd: widget.onAddPersonalReminder,
            onRemove: widget.onRemovePersonalReminder,
          ),
        ],
      ],
    );
  }

  static _HeroPalette _palette(AnnouncementEvent e) {
    switch (e.state) {
      case AnnouncementEventState.upcoming:
        return const _HeroPalette(
          gradient: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          border: Color(0xFFBFDBFE),
          accent: Color(0xFF1D4ED8),
        );
      case AnnouncementEventState.live:
        return const _HeroPalette(
          gradient: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
          border: Color(0xFFFCA5A5),
          accent: Color(0xFFB91C1C),
        );
      case AnnouncementEventState.past:
        return _HeroPalette(
          gradient: [ColorUtils.slate100, ColorUtils.slate100],
          border: ColorUtils.slate200,
          accent: ColorUtils.slate600,
        );
    }
  }

  static String _formatWhen(AnnouncementEvent e) {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final d = e.eventAt;
    final dow = days[(d.weekday - 1).clamp(0, 6)];
    final m = months[(d.month - 1).clamp(0, 11)];
    final time = e.eventHasTime
        ? ' — ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
        : ' — Sepanjang hari';
    return '$dow, ${d.day} $m ${d.year}$time';
  }
}

class _HeroPalette {
  const _HeroPalette({
    required this.gradient,
    required this.border,
    required this.accent,
  });
  final List<Color> gradient;
  final Color border;
  final Color accent;
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({required this.event, required this.palette});
  final AnnouncementEvent event;
  final _HeroPalette palette;

  @override
  Widget build(BuildContext context) {
    final d = event.timeUntilStart;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return Row(
      children: [
        Expanded(child: _Cell(n: days, label: 'HARI', palette: palette)),
        const SizedBox(width: 6),
        Expanded(child: _Cell(n: hours, label: 'JAM', palette: palette)),
        const SizedBox(width: 6),
        Expanded(child: _Cell(n: minutes, label: 'MENIT', palette: palette)),
        const SizedBox(width: 6),
        Expanded(child: _Cell(n: seconds, label: 'DETIK', palette: palette)),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.n, required this.label, required this.palette});
  final int n;
  final String label;
  final _HeroPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            n.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderStatusCard extends StatelessWidget {
  const _ReminderStatusCard({
    required this.title,
    required this.rows,
    required this.isAdmin,
  });
  final String title;
  final List<Map<String, dynamic>> rows;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rows) _buildRow(r),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString();
    final offset = (r['offset_minutes'] as num?)?.toInt() ?? 0;
    final isSent = status == 'sent';
    final isFailed = status == 'failed';
    final bg = isSent
        ? const Color(0xFFDCFCE7)
        : (isFailed ? const Color(0xFFFEE2E2) : ColorUtils.slate50);
    final fg = isSent
        ? const Color(0xFF15803D)
        : (isFailed ? const Color(0xFFB91C1C) : ColorUtils.slate700);
    final icon = isSent
        ? Icons.check_rounded
        : (isFailed
              ? Icons.error_outline_rounded
              : Icons.access_time_rounded);

    String trailing;
    if (isAdmin) {
      final total = (r['recipients_total'] as num?)?.toInt() ?? 0;
      final delivered = (r['recipients_delivered'] as num?)?.toInt() ?? 0;
      trailing = isSent ? '$delivered / $total' : _statusLabel(status);
    } else {
      trailing = _statusLabel(status);
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: fg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _offsetLabel(offset),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Terjadwal';
      case 'sent':
        return 'Terkirim';
      case 'failed':
        return 'Gagal';
      case 'skipped':
        return 'Dilewati';
      default:
        return s;
    }
  }

  static String _offsetLabel(int minutes) {
    if (minutes >= 1440) {
      final d = (minutes / 1440).floor();
      return '$d hari sebelum';
    }
    if (minutes >= 60) {
      final h = (minutes / 60).floor();
      return '$h jam sebelum';
    }
    if (minutes > 0) return '$minutes menit sebelum';
    if (minutes == 0) return 'Saat mulai';
    return '${minutes.abs()} menit setelah';
  }
}

class _PersonalReminderCard extends StatelessWidget {
  const _PersonalReminderCard({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });
  final List<Map<String, dynamic>> rows;
  final VoidCallback? onAdd;
  final void Function(String reminderId)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PENGINGAT KAMU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (onAdd != null)
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_alert_outlined,
                          size: 14,
                          color: ColorUtils.getRoleColor('parent'),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tambah',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.getRoleColor('parent'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Belum ada pengingat pribadi.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: ColorUtils.slate500,
                ),
              ),
            ),
          for (final r in rows) _buildRow(r),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final id = (r['id'] ?? '').toString();
    final status = (r['status'] ?? 'pending').toString();
    final offset = (r['offset_minutes'] as num?)?.toInt() ?? 0;
    final isSent = status == 'sent';
    final icon = isSent
        ? Icons.check_circle_outline_rounded
        : Icons.access_time_rounded;
    final fg = isSent ? const Color(0xFF15803D) : ColorUtils.slate700;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _PersonalReminderCard._offsetLabel(offset),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
          ),
          if (onRemove != null && id.isNotEmpty)
            InkWell(
              onTap: () => onRemove!(id),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: ColorUtils.slate400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _offsetLabel(int minutes) {
    if (minutes >= 1440) {
      final d = (minutes / 1440).floor();
      return '$d hari sebelum';
    }
    if (minutes >= 60) {
      final h = (minutes / 60).floor();
      return '$h jam sebelum';
    }
    if (minutes > 0) return '$minutes menit sebelum';
    if (minutes == 0) return 'Saat mulai';
    return '${minutes.abs()} menit setelah';
  }
}
