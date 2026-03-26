// Time/lesson hour settings screen - configure lesson sessions per day.
//
// Like `pages/admin/settings/time.vue` - manages lesson hour schedules
// for each school day (e.g., Monday has 8 sessions from 07:00 to 14:00).
// Each day can have different session configurations.
//
// In Laravel terms, this consumes `GET /api/settings/lesson-hours` and
// `PUT /api/settings/lesson-hours` with per-day session definitions.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/features/settings/services/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

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
      for (var session in allSessions) {
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
                SnackBarUtils.showError(context, 'Gagal memuat data: ${ErrorUtils.getFriendlyMessage(e)}');
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day['name_id'] ?? day['name_en'] ?? 'Hari',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: 3),
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
                  borderRadius: BorderRadius.circular(8),
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
          // Custom Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.corporateBlue600,
                  ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan Waktu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Jadwal & waktu pembelajaran',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _isLoadingTime
                  ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: ColorUtils.corporateBlue600
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today_outlined,
                                    color: ColorUtils.corporateBlue600,
                                    size: 17,
                                  ),
                                ),
                                SizedBox(width: 10),
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
                            physics: NeverScrollableScrollPhysics(),
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

// ─── Day Session Management Bottom Sheet ──────────────────────────────────────

class DaySessionManagementSheet extends StatefulWidget {
  final dynamic day;
  final List<dynamic> sessions;
  final Map<String, List<dynamic>> allSessionsByDay;
  final List<dynamic> allDays;
  final VoidCallback onSave;

  const DaySessionManagementSheet({
    super.key,
    required this.day,
    required this.sessions,
    required this.allSessionsByDay,
    required this.allDays,
    required this.onSave,
  });

  @override
  State<DaySessionManagementSheet> createState() =>
      _DaySessionManagementSheetState();
}

class _DaySessionManagementSheetState extends State<DaySessionManagementSheet> {
  late List<dynamic> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.sessions);
  }

  Future<void> _refreshSessions() async {
    try {
      final allSettings = await getIt<ApiSettingsService>().getLessonHourSettings();
      final dayId = widget.day['id'].toString();
      final updated = allSettings
          .where((s) => s['day_id'].toString() == dayId)
          .toList();
      updated.sort(
        (a, b) => (a['hour_number'] as int).compareTo(b['hour_number'] as int),
      );

      if (mounted) setState(() => _sessions = updated);
      widget.onSave();
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal memuat ulang sesi: ${ErrorUtils.getFriendlyMessage(e)}');
      }
    }
  }

  void _showAddEditSessionDialog({Map<String, dynamic>? session}) {
    final bool isEdit = session != null;
    final hourController = TextEditingController(
      text: isEdit ? session['hour_number'].toString() : '',
    );

    TimeOfDay startTime = TimeOfDay(hour: 7, minute: 0);
    TimeOfDay endTime = TimeOfDay(hour: 7, minute: 45);

    if (isEdit) {
      try {
        final startParts = session['start_time'].toString().split(':');
        final endParts = session['end_time'].toString().split(':');
        startTime = TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
        );
        endTime = TimeOfDay(
          hour: int.parse(endParts[0]),
          minute: int.parse(endParts[1]),
        );
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: context,
              initialTime: isStart ? startTime : endTime,
            );
            if (picked != null) {
              setModalState(() {
                if (isStart) {
                  startTime = picked;
                } else {
                  endTime = picked;
                }
              });
            }
          }

          Widget buildTimeField(String label, TimeOfDay time, bool isStart) {
            return Expanded(
              child: InkWell(
                onTap: () => pickTime(isStart),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: ColorUtils.corporateBlue600,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: ColorUtils.slate500,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            time.format(context),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header (Pattern #10)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.corporateBlue600,
                        ColorUtils.corporateBlue600.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Sesi' : 'Tambah Sesi',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Atur jam pelajaran untuk hari ini',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          TextField(
                            controller: hourController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Jam Ke-',
                              prefixIcon: Icon(
                                Icons.tag_rounded,
                                color: ColorUtils.corporateBlue600,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: ColorUtils.slate200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: ColorUtils.slate200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: ColorUtils.corporateBlue600,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: ColorUtils.slate50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              buildTimeField('Mulai', startTime, true),
                              SizedBox(width: 10),
                              buildTimeField('Selesai', endTime, false),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Enhanced Footer Actions
                Container(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              AppLocalizations.cancel.tr,
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (hourController.text.isEmpty) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final startStr =
                                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                              final endStr =
                                  '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
                              final hourNum =
                                  int.tryParse(hourController.text) ?? 0;
                              try {
                                if (isEdit) {
                                  await getIt<ApiSettingsService>().updateLessonSession(
                                    id: session['id'].toString(),
                                    startTime: startStr,
                                    endTime: endStr,
                                    hourNumber: hourNum,
                                  );
                                } else {
                                  await getIt<ApiSettingsService>().createLessonSession(
                                    dayId: widget.day['id'].toString(),
                                    hourNumber: hourNum,
                                    startTime: startStr,
                                    endTime: endStr,
                                  );
                                }
                                AppNavigator.pop(context);
                                await _refreshSessions();
                              } catch (e) {
                                AppLogger.error('settings', e);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${AppLocalizations.failedToSave.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
                                    ),
                                    backgroundColor: ColorUtils.error600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              AppLocalizations.save.tr,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _copySchedule(dynamic sourceDay) async {
    final sourceDayId = sourceDay['id'].toString();
    final sourceSessions = widget.allSessionsByDay[sourceDayId] ?? [];
    if (sourceSessions.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: ColorUtils.corporateBlue600),
        ),
      );
      for (var s in sourceSessions) {
        await getIt<ApiSettingsService>().createLessonSession(
          dayId: widget.day['id'].toString(),
          hourNumber: s['hour_number'],
          startTime: s['start_time'],
          endTime: s['end_time'],
        );
      }
      if (mounted) AppNavigator.pop(context);
      await _refreshSessions();
      if (mounted) {
                SnackBarUtils.showSuccess(context, 'Berhasil menyalin jadwal');
      }
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) AppNavigator.pop(context);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal menyalin: ${ErrorUtils.getFriendlyMessage(e)}');
      }
    }
  }

  void _showCopyDialog() {
    final availableDays = widget.allDays.where((d) {
      final dId = d['id'].toString();
      return dId != widget.day['id'].toString() &&
          (widget.allSessionsByDay[dId] ?? []).isNotEmpty;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.corporateBlue600,
                    ColorUtils.corporateBlue600.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    'Salin Jadwal Dari...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 280,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8),
                itemCount: availableDays.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: ColorUtils.slate100,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final d = availableDays[index];
                  final count =
                      widget.allSessionsByDay[d['id'].toString()]?.length ?? 0;
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: ColorUtils.corporateBlue600,
                        size: 17,
                      ),
                    ),
                    title: Text(
                      d['name_id'] ?? d['name_en'] ?? 'Hari',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    subtitle: Text(
                      '$count Sesi',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: ColorUtils.slate400,
                    ),
                    onTap: () {
                      AppNavigator.pop(context);
                      _copySchedule(d);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: ColorUtils.slate300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.cancel.tr,
                    style: TextStyle(color: ColorUtils.slate600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.error600,
                    ColorUtils.error600.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    'Hapus Jam Pelajaran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Apakah Anda yakin ingin menghapus jam pelajaran ini? Data yang dihapus tidak dapat dikembalikan.',
                style: TextStyle(fontSize: 14, color: ColorUtils.slate600),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.cancel.tr,
                        style: TextStyle(color: ColorUtils.slate600),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => AppNavigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.error600,
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.delete.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

    if (confirm != true) return;

    try {
      await getIt<ApiSettingsService>().deleteLessonSession(id);
      await _refreshSessions();
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal menghapus: ${ErrorUtils.getFriendlyMessage(e)}');
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayName = widget.day['name_id'] ?? widget.day['name_en'] ?? 'Hari';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Gradient Header (Pattern #11)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 10, 12, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.corporateBlue600,
                  ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jadwal $dayName',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${_sessions.length} jam pelajaran terdaftar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => AppNavigator.pop(context),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Session list
          Expanded(
            child: _sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ColorUtils.slate100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schedule_outlined,
                            size: 32,
                            color: ColorUtils.slate400,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Belum ada jadwal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate700,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tambah jam pelajaran di bawah',
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                          ),
                        ),
                        if (widget.allDays.any((d) {
                          final dId = d['id'].toString();
                          return dId != widget.day['id'].toString() &&
                              (widget.allSessionsByDay[dId] ?? []).isNotEmpty;
                        })) ...[
                          SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: _showCopyDialog,
                            icon: Icon(Icons.copy_rounded, size: 16),
                            label: Text('Salin dari hari lain'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: ColorUtils.corporateBlue600,
                              ),
                              foregroundColor: ColorUtils.corporateBlue600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ColorUtils.slate200),
                          boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: ColorUtils.corporateBlue600.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ColorUtils.corporateBlue600.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${session['hour_number']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ColorUtils.corporateBlue600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Jam ke-${session['hour_number']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                  Text(
                                    '${session['start_time']} – ${session['end_time']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ColorUtils.slate900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _buildActionButton(
                                  icon: Icons.edit_rounded,
                                  color: ColorUtils.corporateBlue600,
                                  onTap: () => _showAddEditSessionDialog(
                                    session: session,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                _buildActionButton(
                                  icon: Icons.delete_rounded,
                                  color: ColorUtils.error600,
                                  onTap: () =>
                                      _deleteSession(session['id'].toString()),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Enhanced Footer Action
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddEditSessionDialog(),
                  icon: Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    'Tambah Jam Pelajaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.corporateBlue600,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
