// Admin · Kalender Acara — Frame A4.
//
// Month-grid view of every announcement that carries an Acara.
// Backed by `GET /announcements?has_event=1&event_from=...&event_to=...`
// scoped to the visible month. Each day cell shows up to 3 dots,
// colored by tipe:
//   • blue   — pengumuman
//   • amber  — peringatan
//   • red    — darurat / live
// Tapping a day filters the list section below to that day's events.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_event_block.dart';

class AdminAnnouncementCalendarScreen extends StatefulWidget {
  const AdminAnnouncementCalendarScreen({super.key});

  @override
  State<AdminAnnouncementCalendarScreen> createState() =>
      _AdminAnnouncementCalendarScreenState();
}

class _AdminAnnouncementCalendarScreenState
    extends State<AdminAnnouncementCalendarScreen> {
  DateTime _viewedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _isLoading = true);
    final from = DateTime(_viewedMonth.year, _viewedMonth.month, 1);
    final to = DateTime(_viewedMonth.year, _viewedMonth.month + 1, 0);
    final result = await AnnouncementService.fetchEventsForCalendar(
      from: from,
      to: to,
    );
    if (!mounted) return;
    final rawData = result['data'];
    final rows = (rawData is List ? rawData : const <dynamic>[])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    setState(() {
      _items = rows;
      _isLoading = false;
    });
  }

  void _onMonthShift(int delta) {
    setState(() {
      _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month + delta);
      // Snap selection into the new month so the list isn't empty.
      _selectedDay = DateTime(
        _viewedMonth.year,
        _viewedMonth.month,
        _viewedMonth.month == DateTime.now().month &&
                _viewedMonth.year == DateTime.now().year
            ? DateTime.now().day
            : 1,
      );
    });
    _loadMonth();
  }

  void _onDayPick(DateTime day) {
    setState(() => _selectedDay = day);
  }

  /// Build a (day-of-month → list of items) lookup so the month grid
  /// can show dots and the list section can filter by selected day.
  Map<int, List<Map<String, dynamic>>> _itemsByDay() {
    final out = <int, List<Map<String, dynamic>>>{};
    for (final m in _items) {
      final raw = m['event_at'];
      if (raw == null) continue;
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) continue;
      if (dt.year != _viewedMonth.year || dt.month != _viewedMonth.month) {
        continue;
      }
      out.putIfAbsent(dt.day, () => []).add(m);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageProvider();
    final byDay = _itemsByDay();
    final selectedDayItems = byDay[_selectedDay.day] ?? const [];

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        header: BrandPageHeader(
          role: 'admin',
          subtitle: lang.getTranslatedText(const {
            'en': 'EVENT CALENDAR',
            'id': 'KALENDER ACARA',
          }),
          title: _formatMonthYear(_viewedMonth),
          actionIcons: [
            BrandHeaderIconButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => _onMonthShift(-1),
            ),
            BrandHeaderIconButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => _onMonthShift(1),
            ),
          ],
        ),
        kpiCard: _MonthGrid(
          month: _viewedMonth,
          selected: _selectedDay,
          itemsByDay: byDay,
          onPickDay: _onDayPick,
        ),
        bodyChildren: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: _DayListSection(
              day: _selectedDay,
              items: selectedDayItems,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMonthYear(DateTime d) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[(d.month - 1).clamp(0, 11)]} ${d.year}';
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.itemsByDay,
    required this.onPickDay,
  });

  final DateTime month;
  final DateTime selected;
  final Map<int, List<Map<String, dynamic>>> itemsByDay;
  final void Function(DateTime) onPickDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart weekday: Mon=1..Sun=7. We render starting Monday (index 0).
    final leadingBlanks = firstDay.weekday - 1;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _DowLabel('Sen'),
              _DowLabel('Sel'),
              _DowLabel('Rab'),
              _DowLabel('Kam'),
              _DowLabel('Jum'),
              _DowLabel('Sab'),
              _DowLabel('Min'),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _buildCell(
                      r * 7 + c - leadingBlanks + 1,
                      daysInMonth,
                      today,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(int day, int daysInMonth, DateTime today) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 38);
    }
    final isToday =
        today.year == month.year &&
        today.month == month.month &&
        today.day == day;
    final isSelected =
        selected.year == month.year &&
        selected.month == month.month &&
        selected.day == day;
    final items = itemsByDay[day] ?? const [];

    return InkWell(
      onTap: () => onPickDay(DateTime(month.year, month.month, day)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorUtils.brandCobalt
              : (isToday
                    ? ColorUtils.brandCobalt.withValues(alpha: 0.08)
                    : null),
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: ColorUtils.brandCobalt, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isToday ? ColorUtils.brandCobalt : ColorUtils.slate700),
              ),
            ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.white : _dotColor(item),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _dotColor(Map<String, dynamic> item) {
    final priority = (item['priority'] ?? '').toString().toLowerCase();
    // Backend canonical: `high` / `urgent` (was `penting` / `important`).
    if (priority == 'high' ||
        priority == 'urgent' ||
        priority == 'penting' ||
        priority == 'important') {
      return const Color(0xFFD97706); // amber-600
    }
    return const Color(0xFF1D4ED8); // blue-700
  }
}

class _DowLabel extends StatelessWidget {
  const _DowLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate400,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayListSection extends StatelessWidget {
  const _DayListSection({
    required this.day,
    required this.items,
    required this.isLoading,
  });

  final DateTime day;
  final List<Map<String, dynamic>> items;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _formatLongDay(day),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              items.isEmpty ? '· tidak ada acara' : '· ${items.length} acara',
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ColorUtils.brandCobalt,
                ),
              ),
            ),
          )
        else if (items.isEmpty)
          _EmptyState()
        else
          for (final row in items) _buildItem(context, row),
      ],
    );
  }

  Widget _buildItem(BuildContext context, Map<String, dynamic> row) {
    final ev = AnnouncementEvent.fromJson(row);
    if (ev == null) return const SizedBox.shrink();
    final title = (row['title'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Acara' : title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          AnnouncementEventBlock(
            event: ev,
            dense: true,
            onTap: () {
              // Open detail via the same nav helper the list uses.
              AppNavigator.pop(context, row);
            },
          ),
        ],
      ),
    );
  }

  static String _formatLongDay(DateTime d) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[(d.weekday - 1).clamp(0, 6)].toUpperCase()}, '
            '${d.day} ${months[(d.month - 1).clamp(0, 11)]}'
        .toUpperCase();
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, size: 28, color: ColorUtils.slate400),
          const SizedBox(height: 6),
          Text(
            'Tidak ada acara di tanggal ini',
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
