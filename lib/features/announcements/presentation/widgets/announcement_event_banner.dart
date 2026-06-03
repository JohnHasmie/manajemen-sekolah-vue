// Pengumuman + Acara — in-app banner strip.
//
// Surfaces the next N (default 3) announcements with an Acara above
// the user's list / Beranda. Two visual states per banner:
//   • Live (BERLANGSUNG SEKARANG) — red gradient + close action
//   • Upcoming (BESOK 14:00 / X hari lagi) — amber gradient
//
// Stateful so we can drive its own /announcements/upcoming-events
// fetch, auto-refresh every 60s, and let the user dismiss a card
// locally (kept in-memory only — no persistent suppression).
//
// Dropped into:
//   • Beranda RoleDashboardHero footer
//   • Top of Pengumuman list (admin/guru/wali) above first card
//
// Tapping a banner navigates to the announcement detail via the
// caller-supplied [onTap] callback. The widget is intentionally
// minimal-coupling — no Riverpod, no router knowledge.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';

class AnnouncementEventBanner extends StatefulWidget {
  const AnnouncementEventBanner({
    super.key,
    this.limit = 3,
    this.refreshInterval = const Duration(minutes: 1),
    required this.onOpen,
  });

  /// Max banners to keep on screen at once. Anything beyond that is
  /// hidden until the user opens / dismisses the current ones.
  final int limit;

  /// Polling cadence. The card already updates its countdown text
  /// every render (parent rebuilds), so this is just the cadence at
  /// which the backend list is re-fetched.
  final Duration refreshInterval;

  /// Called when the user taps a card. Receives the full announcement
  /// map so the caller can route to detail.
  final void Function(Map<String, dynamic> announcement) onOpen;

  @override
  State<AnnouncementEventBanner> createState() =>
      _AnnouncementEventBannerState();
}

class _AnnouncementEventBannerState extends State<AnnouncementEventBanner> {
  List<Map<String, dynamic>> _items = [];
  final Set<String> _dismissedIds = {};
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final rows = await AnnouncementService.fetchUpcomingEvents(
      limit: widget.limit,
    );
    if (!mounted) return;
    setState(() {
      _items = rows;
      _isLoading = false;
    });
  }

  void _dismiss(String id) {
    setState(() => _dismissedIds.add(id));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    final visible = _items
        .where((m) => !_dismissedIds.contains((m['id'] ?? '').toString()))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final raw in visible)
          if (AnnouncementEvent.fromJson(raw) case final ev?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BannerCard(
                announcement: raw,
                event: ev,
                onTap: () => widget.onOpen(raw),
                onDismiss: () => _dismiss((raw['id'] ?? '').toString()),
              ),
            ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.announcement,
    required this.event,
    required this.onTap,
    required this.onDismiss,
  });

  final Map<String, dynamic> announcement;
  final AnnouncementEvent event;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isLive = event.isLive;
    final gradient = isLive
        ? const [Color(0xFFFEE2E2), Color(0xFFFECACA)]
        : const [Color(0xFFFEF3C7), Color(0xFFFDE68A)];
    final border = isLive ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A);
    final accent = isLive ? const Color(0xFFB91C1C) : const Color(0xFFB45309);
    const iconBg = Colors.white;
    final title = (announcement['title'] ?? '').toString();
    final body = _composeBody(event);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isLive
                      ? Icons.error_outline_rounded
                      : Icons.notifications_active_rounded,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          isLive
                              ? 'BERLANGSUNG SEKARANG'
                              : event.countdownLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: onDismiss,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title.isEmpty ? 'Acara' : title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ColorUtils.slate700,
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compose the body line:
  ///   live  → "Lab Komputer · Mulai 14:00"
  ///   else  → "Hari Rabu · 14:00 · Aula Lt. 2"
  static String _composeBody(AnnouncementEvent event) {
    final parts = <String>[];
    final d = event.eventAt;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final hm = event.eventHasTime ? '$hh:$mm' : 'Sepanjang hari';
    parts.add(hm);
    if (event.eventLocation != null) parts.add(event.eventLocation!);
    return parts.join(' · ');
  }
}
