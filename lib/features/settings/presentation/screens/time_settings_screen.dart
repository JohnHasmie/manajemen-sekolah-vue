// Time/lesson hour settings screen - configure lesson sessions per day.
//
// Like `pages/admin/settings/time.vue` - manages lesson hour schedules
// for each school day (e.g., Monday has 8 sessions from 07:00 to 14:00).
// Each day can have different session configurations.
//
// In Laravel terms, this consumes `GET /api/settings/lesson-hours` and
// `PUT /api/settings/lesson-hours` with per-day session definitions.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

/// Time settings screen - configure lesson hour sessions for each school day.
///
/// This is a [StatefulWidget] with local state for days and their sessions.
/// Shows a list of day cards; tapping a day opens a bottom sheet to manage sessions.
class TimeSettingsScreen extends StatefulWidget {
  const TimeSettingsScreen({super.key});

  @override
  State<TimeSettingsScreen> createState() => _TimeSettingsScreenState();
}

/// Mutable state for [TimeSettingsScreen].
///
/// Key state (like Vue `data()`):
/// - [_days] - list of school days (Monday-Saturday)
/// - [_sessionsByDay] - map of day_id -> list of lesson hour sessions
/// - [_isLoadingTime] - loading state
///
/// setState() triggers re-render like Vue's reactivity system.
class _TimeSettingsScreenState extends State<TimeSettingsScreen> {
  List<dynamic> _days = [];
  Map<String, List<dynamic>> _sessionsByDay = {};
  bool _isLoadingTime = true;

  /// Like Vue's `mounted()` - loads days and their lesson hour sessions.
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Fetches school days and all lesson hour settings in parallel.
  /// Uses `Future.wait` for concurrent API calls - like `Promise.all()` in JavaScript.
  /// Groups sessions by day_id for display.
  Future<void> _loadInitialData() async {
    setState(() => _isLoadingTime = true);
    try {
      final futures = await Future.wait([
        getIt<ApiScheduleService>().getDays(),
        getIt<ApiSettingsService>().getLessonHourSettings(),
      ]);

      final allSessions = futures[1];
      final Map<String, List<dynamic>> grouped = {};
      for (final session in allSessions) {
        final dayId = session['day_id'].toString();
        grouped.putIfAbsent(dayId, () => []).add(session);
      }

      setState(() {
        _days = futures[0];
        _sessionsByDay = grouped;
        _isLoadingTime = false;
      });
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
        setState(() => _isLoadingTime = false);
        SnackBarUtils.showError(
          context,
          'Gagal memuat data: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  /// Opens a bottom sheet to manage lesson sessions for a specific day.
  /// Like clicking a day card to open a Vue modal/drawer with session CRUD.
  void _openDaySettings(dynamic day) {
    final dayId = day['id'].toString();
    final sessions = _sessionsByDay[dayId] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DaySessionManagementSheet(
        day: day,
        sessions: sessions,
        allSessionsByDay: _sessionsByDay,
        allDays: _days,
        onSave: _loadInitialData,
      ),
    );
  }

  Widget _buildDayCard(dynamic day, int index) {
    final dayId = day['id'].toString();
    final sessions = _sessionsByDay[dayId] ?? [];
    final color = ColorUtils.getColorForIndex(index);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDaySettings(day),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayNameToIndonesian(day['name'] ?? 'Hari'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sessions.isEmpty
                          ? 'Belum ada sesi'
                          : '${sessions.length} Jam Pelajaran',
                      style: TextStyle(
                        fontSize: 12,
                        color: sessions.isEmpty
                            ? ColorUtils.slate400
                            : ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.slate500,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'admin',
            subtitle: 'WAKTU PEMBELAJARAN',
            title: 'Pengaturan Waktu',
          ),
          // Body
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _isLoadingTime
                  ? const SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: ColorUtils.corporateBlue600
                                        .withValues(alpha: 0.1),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today_outlined,
                                    color: ColorUtils.corporateBlue600,
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jam Aktif Harian',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: ColorUtils.slate800,
                                      ),
                                    ),
                                    Text(
                                      'Pilih hari untuk mengatur jam pelajaran.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ColorUtils.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _days.length,
                            itemBuilder: (context, index) =>
                                _buildDayCard(_days[index], index),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
