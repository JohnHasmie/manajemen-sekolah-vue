// Admin Sistem → Waktu Pembelajaran (Frame A hub).
//
// Rebuilt from scratch in WP.7 to match
// `_design/admin_waktu_pembelajaran_redesign.html` Frame A:
//
//   * BrandPageLayout (admin) + BrandPageHeader navy gradient
//   * KPI strip overlap (Hari aktif / Total jam / Durasi rata-rata)
//     computed client-side from the grouped `_sessionsByDay` map so
//     no backend changes are needed at this layer.
//   * Section header (32 dp icon tile + dual-line text), matching the
//     pattern used across Sistem screens.
//   * Day rows — single tap opens `DaySessionManagementSheet` (the
//     Frame B sheet rebuilt in WP.8). Each row carries a colored
//     calendar avatar (per-day from a deterministic palette), the
//     day name, a "N jam · 07:00 – 13:45" sub-line, a status pill
//     (AKTIF / KOSONG), and a trailing chevron.
//
// Backend touchpoints are unchanged: the screen still consumes
//   - `ApiScheduleService.getDays()` for the 7 weekdays
//   - `ApiSettingsService.getLessonHourSettings()` for all sessions
// and groups them by `day_id` client-side.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

class TimeSettingsScreen extends StatefulWidget {
  const TimeSettingsScreen({super.key});

  @override
  State<TimeSettingsScreen> createState() => _TimeSettingsScreenState();
}

class _TimeSettingsScreenState extends State<TimeSettingsScreen> {
  List<dynamic> _days = const [];
  Map<String, List<dynamic>> _sessionsByDay = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        getIt<ApiScheduleService>().getDays(),
        getIt<ApiSettingsService>().getLessonHourSettings(),
      ]);

      final allSessions = futures[1];
      final grouped = <String, List<dynamic>>{};
      for (final session in allSessions) {
        final dayId = session['day_id'].toString();
        grouped.putIfAbsent(dayId, () => []).add(session);
      }
      // Keep sessions within each day sorted by hour_number so the
      // hub sub-line range ("07:00 – 13:45") is deterministic.
      for (final entry in grouped.values) {
        entry.sort((a, b) {
          final aHour = (a as Map)['hour_number'];
          final bHour = (b as Map)['hour_number'];
          final aInt = aHour is int ? aHour : int.tryParse('$aHour') ?? 0;
          final bInt = bHour is int ? bHour : int.tryParse('$bHour') ?? 0;
          return aInt.compareTo(bInt);
        });
      }

      if (!mounted) return;
      setState(() {
        _days = futures[0];
        _sessionsByDay = grouped;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('settings', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(
        context,
        '${kSetFailedLoadData.tr}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  // ── KPI helpers ──────────────────────────────────────────────────

  int get _activeDayCount {
    var count = 0;
    for (final list in _sessionsByDay.values) {
      if (list.isNotEmpty) count++;
    }
    return count;
  }

  int get _totalSessionCount {
    var total = 0;
    for (final list in _sessionsByDay.values) {
      total += list.length;
    }
    return total;
  }

  /// Average session duration in minutes across every configured row.
  /// Falls back to 0 when no sessions exist.
  int get _averageDurationMinutes {
    var totalMinutes = 0;
    var count = 0;
    for (final list in _sessionsByDay.values) {
      for (final raw in list) {
        final s = raw as Map;
        final mins = _durationMinutes(
          s['start_time']?.toString() ?? '',
          s['end_time']?.toString() ?? '',
        );
        if (mins > 0) {
          totalMinutes += mins;
          count++;
        }
      }
    }
    if (count == 0) return 0;
    return (totalMinutes / count).round();
  }

  int _durationMinutes(String start, String end) {
    final s = _parseClock(start);
    final e = _parseClock(end);
    if (s == null || e == null) return 0;
    return e - s;
  }

  /// Returns minutes-from-midnight or null when the string isn't a
  /// valid clock value.
  int? _parseClock(String hms) {
    if (hms.isEmpty) return null;
    final parts = hms.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        header: BrandPageHeader(
          role: 'admin',
          kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
          showBackButton: true,
          onBackPressed: () => AppNavigator.pop(context),
          subtitle: kSetLearningTime.tr,
          title: kSetTimeSettings.tr,
        ),
        kpiCard: _isLoading ? null : _kpiCard(),
        onRefresh: _loadInitialData,
        bodyChildren: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              // `shrinkWrap: true` is required because BrandPageLayout
              // already provides the outer scroll; nesting a default
              // (non-shrunk) ListView inside it crashes with
              // "Vertical viewport was given unbounded height".
              child: SkeletonListLoading(
                itemCount: 7,
                infoTagCount: 1,
                shrinkWrap: true,
              ),
            )
          else ...[
            _sectionHeader(),
            const SizedBox(height: 4),
            ...List.generate(_days.length, (index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _DayRow(
                  day: _days[index],
                  index: index,
                  sessions:
                      _sessionsByDay[_days[index]['id'].toString()] ?? const [],
                  onTap: () => _openDaySheet(_days[index]),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: ColorUtils.slate200, width: 0.75),
          boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          children: [
            Expanded(
              child: _kpiCell(
                label: kSetActiveDays.tr,
                value: '$_activeDayCount',
                pillLabel: '${kSetFrom.tr}${_days.length}',
                pillBg: const Color(0xFFDCFCE7),
                pillFg: const Color(0xFF15803D),
              ),
            ),
            Container(width: 1, height: 36, color: ColorUtils.slate100),
            Expanded(
              child: _kpiCell(
                label: kSetTotalHours.tr,
                value: '$_totalSessionCount',
                pillLabel: kSetSessionsPerWeek.tr,
                pillBg: ColorUtils.brandCobalt.withValues(alpha: 0.10),
                pillFg: ColorUtils.brandCobalt,
              ),
            ),
            Container(width: 1, height: 36, color: ColorUtils.slate100),
            Expanded(
              child: _kpiCell(
                label: kSetDuration.tr,
                value: _averageDurationMinutes == 0
                    ? '–'
                    : "$_averageDurationMinutes'",
                pillLabel: kSetAverage.tr,
                pillBg: const Color(0xFFFEF3C7),
                pillFg: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required String pillLabel,
    required Color pillBg,
    required Color pillFg,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
          ),
          child: Text(
            pillLabel,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: pillFg,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ColorUtils.brandDarkBlue.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: ColorUtils.brandDarkBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Jam Aktif Harian',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Pilih hari untuk mengatur jam pelajaran.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDaySheet(dynamic day) async {
    final dayId = day['id'].toString();
    final sessions = _sessionsByDay[dayId] ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DaySessionManagementSheet(
        day: day,
        sessions: List<dynamic>.from(sessions),
        allSessionsByDay: _sessionsByDay,
        allDays: _days,
        onSave: _loadInitialData,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Day row — Frame A row pattern. Inline (not DashboardListTile)
// because the layout needs a trailing status pill which the shared
// tile doesn't expose. Visual identity stays consistent: 42dp
// colored calendar avatar (palette-keyed by day index for variety),
// title row 14pt bold, sub-line with "N jam · range" or muted hint.
// ─────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.index,
    required this.sessions,
    required this.onTap,
  });

  final dynamic day;
  final int index;
  final List<dynamic> sessions;
  final VoidCallback onTap;

  // Per-day palette — deterministic by row index so Senin always reads
  // indigo, Selasa green, Rabu orange, etc.
  static const _palette = <({Color bg, Color fg})>[
    (bg: Color(0xFFEEF2FF), fg: Color(0xFF4F46E5)), // Senin
    (bg: Color(0xFFDCFCE7), fg: Color(0xFF16A34A)), // Selasa
    (bg: Color(0xFFFFF7ED), fg: Color(0xFFEA580C)), // Rabu
    (bg: Color(0xFFFEE2E2), fg: Color(0xFFDC2626)), // Kamis
    (bg: Color(0xFFEDE9FE), fg: Color(0xFF7C3AED)), // Jumat
    (bg: Color(0xFFCCFBF1), fg: Color(0xFF0D9488)), // Sabtu
    (bg: Color(0xFFEEF2FF), fg: Color(0xFF4F46E5)), // Minggu (loops)
  ];

  String _trim(String hms) {
    if (hms.length >= 5) return hms.substring(0, 5);
    return hms;
  }

  String _rangeLabel() {
    if (sessions.isEmpty) return '';
    final first = sessions.first as Map;
    final last = sessions.last as Map;
    final start = _trim(first['start_time']?.toString() ?? '');
    final end = _trim(last['end_time']?.toString() ?? '');
    if (start.isEmpty || end.isEmpty) return '';
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette[index % _palette.length];
    final empty = sessions.isEmpty;
    final dayName = dayNameToIndonesian(day['name']?.toString() ?? 'Hari');
    final range = _rangeLabel();

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate200, width: 0.75),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: empty ? 0.55 : 1.0,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.bg,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: palette.fg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: empty
                            ? ColorUtils.slate500
                            : ColorUtils.slate900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty
                          ? 'Belum diatur · ketuk untuk menambah sesi'
                          : '${sessions.length} jam · $range',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: empty ? FontWeight.w500 : FontWeight.w600,
                        color: empty
                            ? ColorUtils.slate400
                            : ColorUtils.slate600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(active: !empty),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorUtils.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFDCFCE7) : ColorUtils.slate100;
    final fg = active ? const Color(0xFF15803D) : ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        active ? 'AKTIF' : 'KOSONG',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
