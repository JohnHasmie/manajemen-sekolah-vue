// teacher_presensi_screen.dart — the teacher-facing "Presensi Guru"
// (daily attendance) screen.
//
// What the teacher sees, top to bottom:
//   1. A status hero — today's date + a big chip telling them whether
//      they've checked in (and if late) / checked out.
//   2. Today's teaching schedule list (from the config endpoint), with
//      the "telat jika setelah" (late-after) line if the school set a
//      grace window.
//   3. A primary action button that adapts to state:
//        - not checked in  → "Presensi Masuk"
//        - checked in, checkout on, not checked out → "Presensi Pulang"
//        - done for the day → a disabled "Selesai" summary.
//
// The check-in/out flow itself:
//   * If the school requires a photo (camera_required), we open the LIVE
//     front camera via image_picker (source: camera — NEVER gallery, so
//     a teacher can't upload an old selfie).
//   * If the school requires location (location_required), we read a GPS
//     fix via geolocator.
//   * We POST multipart to the backend, which stamps the time, runs the
//     geofence haversine, and decides present/late. We just render the
//     server's verdict (success / late / outside-geofence) back to the
//     teacher.
//
// Analogy for the Laravel/Vue reader: this whole screen is one "page
// component" that hydrates from a single `GET .../config` (like a
// page-load API call), then POSTs a multipart form on submit — the
// server is the source of truth for every rule, exactly like a Laravel
// FormRequest + controller deciding the outcome.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/teacher_attendance/data/'
    'teacher_attendance_location_helper.dart';
import 'package:manajemensekolah/features/teacher_attendance/data/'
    'teacher_attendance_service.dart';
import 'package:manajemensekolah/features/teacher_attendance/domain/models/'
    'teacher_attendance_models.dart';

/// Standalone screen for a teacher's own daily check-in / check-out.
class TeacherPresensiScreen extends StatefulWidget {
  const TeacherPresensiScreen({super.key});

  @override
  State<TeacherPresensiScreen> createState() => _TeacherPresensiScreenState();
}

class _TeacherPresensiScreenState extends State<TeacherPresensiScreen> {
  final TeacherAttendanceService _service = TeacherAttendanceService();
  final TeacherAttendanceLocationHelper _locationHelper =
      TeacherAttendanceLocationHelper();
  final ImagePicker _picker = ImagePicker();

  TeacherAttendanceConfig? _config;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  static const Color _accent = Color(0xFF7C3AED); // violet — Kehadiran

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final config = await _service.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = _messageFromError(e);
        _loading = false;
      });
    }
  }

  // ── Submit flows ────────────────────────────────────────────────────

  Future<void> _onCheckIn() => _submit(isCheckOut: false);

  Future<void> _onCheckOut() => _submit(isCheckOut: true);

  /// Shared check-in / check-out pipeline. Gathers the photo + GPS the
  /// school requires, POSTs, then refreshes the screen from the returned
  /// record. Every server rule (time stamping, geofence, late, double
  /// check-in) is enforced backend-side — we only collect inputs and
  /// render the verdict.
  Future<void> _submit({required bool isCheckOut}) async {
    final config = _config;
    if (config == null || _submitting) return;
    final settings = config.settings;

    File? photo;
    double? lat;
    double? lng;

    // 1. Camera — only when the school requires it. LIVE capture only.
    if (settings.cameraRequired) {
      photo = await _captureSelfie();
      if (photo == null) return; // user cancelled the camera
    }

    // 2. Location — only when the school requires it.
    if (settings.locationRequired) {
      final loc = await _resolveLocation();
      if (loc == null) return; // helper already surfaced the reason
      lat = loc.latitude;
      lng = loc.longitude;
    }

    setState(() => _submitting = true);
    try {
      final record = isCheckOut
          ? await _service.checkOut(
              photoFile: photo,
              latitude: lat,
              longitude: lng,
            )
          : await _service.checkIn(
              photoFile: photo,
              latitude: lat,
              longitude: lng,
            );
      if (!mounted) return;
      _announceResult(record, isCheckOut: isCheckOut);
      await _loadConfig();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, _messageFromError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Opens the LIVE front camera (no gallery option is ever offered, so
  /// the teacher must take a fresh selfie). Returns null if cancelled.
  Future<File?> _captureSelfie() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (shot == null) return null;
      return File(shot.path);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal membuka kamera. Pastikan izin kamera diaktifkan.',
        );
      }
      return null;
    }
  }

  /// Reads a GPS fix, surfacing a tailored message + recovery action for
  /// each failure mode (service off, denied, denied-forever).
  Future<LocationResult?> _resolveLocation() async {
    final result = await _locationHelper.getCurrentPosition();
    if (result.isSuccess) return result;
    if (!mounted) return null;

    switch (result.status) {
      case LocationResultStatus.serviceDisabled:
        SnackBarUtils.showWarning(
          context,
          'Lokasi (GPS) belum aktif. Aktifkan lokasi lalu coba lagi.',
        );
        await _locationHelper.openLocationSettings();
        break;
      case LocationResultStatus.permissionDenied:
        SnackBarUtils.showWarning(
          context,
          'Izin lokasi ditolak. Presensi memerlukan lokasi.',
        );
        break;
      case LocationResultStatus.permissionDeniedForever:
        SnackBarUtils.showWarning(
          context,
          'Izin lokasi diblokir. Buka pengaturan untuk mengaktifkannya.',
        );
        await _locationHelper.openAppSettings();
        break;
      case LocationResultStatus.error:
      case LocationResultStatus.success:
        SnackBarUtils.showError(
          context,
          'Gagal membaca lokasi. Coba lagi di area terbuka.',
        );
        break;
    }
    return null;
  }

  /// Renders the server's verdict as a clear success / warning toast.
  void _announceResult(
    TeacherAttendanceRecord record, {
    required bool isCheckOut,
  }) {
    final outside = isCheckOut
        ? record.checkOutOutsideGeofence
        : record.checkInOutsideGeofence;

    if (outside) {
      SnackBarUtils.showWarning(
        context,
        isCheckOut
            ? 'Presensi pulang tercatat, namun di luar area sekolah.'
            : 'Presensi masuk tercatat, namun di luar area sekolah.',
      );
      return;
    }

    if (!isCheckOut && record.isLate) {
      SnackBarUtils.showWarning(
        context,
        'Presensi masuk tercatat — status TERLAMBAT.',
      );
      return;
    }

    SnackBarUtils.showSuccess(
      context,
      isCheckOut
          ? 'Presensi pulang berhasil dicatat.'
          : 'Presensi masuk berhasil dicatat.',
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Presensi Guru'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _ErrorState(message: _loadError!, onRetry: _loadConfig);
    }
    final config = _config;
    if (config == null) {
      return _ErrorState(
        message: 'Data presensi tidak tersedia.',
        onRetry: _loadConfig,
      );
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadConfig,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _StatusHero(config: config, accent: _accent),
          const SizedBox(height: 16),
          _RequirementChips(settings: config.settings, accent: _accent),
          const SizedBox(height: 16),
          _ScheduleSection(config: config, accent: _accent),
          const SizedBox(height: 24),
          _buildPrimaryAction(config),
        ],
      ),
    );
  }

  /// State-aware primary action area.
  Widget _buildPrimaryAction(TeacherAttendanceConfig config) {
    final state = config.state;
    final settings = config.settings;

    // Already fully done for the day.
    if (state.hasCheckedIn &&
        (state.hasCheckedOut || !settings.checkoutEnabled)) {
      return _DoneCard(
        state: state,
        checkoutEnabled: settings.checkoutEnabled,
        accent: _accent,
      );
    }

    // Checked in, checkout enabled, not yet out → offer check-out.
    if (state.canCheckOut) {
      return _ActionButton(
        label: 'Presensi Pulang',
        icon: Icons.logout_rounded,
        color: ColorUtils.error600,
        busy: _submitting,
        onPressed: _onCheckOut,
      );
    }

    // Default: not checked in yet → offer check-in.
    return _ActionButton(
      label: 'Presensi Masuk',
      icon: Icons.login_rounded,
      color: _accent,
      busy: _submitting,
      onPressed: _onCheckIn,
    );
  }

  /// Turns any thrown error into a clean, teacher-readable message.
  /// dioClient wraps server errors into typed [ApiException]s whose
  /// `toString()` is the Indonesian backend message — so a 422
  /// "sudah melakukan presensi masuk" lands here verbatim.
  String _messageFromError(Object e) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).toString();
    }
    if (e is ApiException) return e.toString();
    if (e is DioException) {
      return e.message ?? 'Terjadi kesalahan jaringan. Coba lagi.';
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }
}

// ── Status hero ────────────────────────────────────────────────────────

/// Top card: today's date + a status chip reflecting check-in/out state.
class _StatusHero extends StatelessWidget {
  final TeacherAttendanceConfig config;
  final Color accent;

  const _StatusHero({required this.config, required this.accent});

  @override
  Widget build(BuildContext context) {
    final state = config.state;
    final record = state.record;
    final dateLabel = _formatDate(config.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  config.teacherName ?? 'Guru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _statusChip(state, record),
          if (record?.checkInAt != null) ...[
            const SizedBox(height: 12),
            _timeRow('Masuk', record!.checkInAt),
          ],
          if (record?.checkOutAt != null) ...[
            const SizedBox(height: 6),
            _timeRow('Pulang', record!.checkOutAt),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(
    TeacherAttendanceState state,
    TeacherAttendanceRecord? record,
  ) {
    late final String label;
    late final IconData icon;
    if (!state.hasCheckedIn) {
      label = 'Belum presensi';
      icon = Icons.pending_outlined;
    } else if (record?.isLate ?? false) {
      label = 'Hadir — Terlambat';
      icon = Icons.warning_amber_rounded;
    } else {
      label = 'Hadir';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(String label, String? iso) {
    final t = _formatTime(iso);
    return Row(
      children: [
        Icon(
          label == 'Masuk' ? Icons.login_rounded : Icons.logout_rounded,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $t',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Requirement chips (camera / location / radius) ─────────────────────

class _RequirementChips extends StatelessWidget {
  final TeacherAttendanceSettings settings;
  final Color accent;

  const _RequirementChips({required this.settings, required this.accent});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (settings.cameraRequired) {
      chips.add(_chip(Icons.photo_camera_outlined, 'Selfie wajib'));
    }
    if (settings.locationRequired) {
      chips.add(
        _chip(
          Icons.my_location_outlined,
          'Lokasi wajib · radius ${settings.geofenceRadiusM} m',
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today's schedule section ───────────────────────────────────────────

class _ScheduleSection extends StatelessWidget {
  final TeacherAttendanceConfig config;
  final Color accent;

  const _ScheduleSection({required this.config, required this.accent});

  @override
  Widget build(BuildContext context) {
    final schedule = config.todaySchedule;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              const Text(
                'Jadwal Mengajar Hari Ini',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          if (config.lateAfter != null) ...[
            const SizedBox(height: 6),
            Text(
              'Terlambat jika presensi setelah '
              '${_formatTime(config.lateAfter)}',
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.warning600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (schedule.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada jadwal mengajar hari ini.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...schedule.map(_scheduleRow),
        ],
      ),
    );
  }

  Widget _scheduleRow(TeacherTodaySchedule s) {
    final time = [
      s.startTime,
      s.endTime,
    ].where((t) => (t ?? '').isNotEmpty).map((t) => _shortTime(t!)).join(' - ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.subjectName ?? 'Mata pelajaran',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((s.className ?? '').isNotEmpty) s.className!,
                    if (time.isNotEmpty) time,
                    if ((s.lessonHourName ?? '').isNotEmpty) s.lessonHourName!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Done card ──────────────────────────────────────────────────────────

class _DoneCard extends StatelessWidget {
  final TeacherAttendanceState state;
  final bool checkoutEnabled;
  final Color accent;

  const _DoneCard({
    required this.state,
    required this.checkoutEnabled,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final message = checkoutEnabled
        ? 'Presensi masuk & pulang hari ini sudah lengkap.'
        : 'Presensi masuk hari ini sudah tercatat.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColorUtils.success600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.success600.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.task_alt_rounded, color: ColorUtils.success600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ColorUtils.success600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary action button ──────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          busy ? 'Memproses…' : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date / time formatting helpers (shared, top-level) ─────────────────

/// Formats a "YYYY-MM-DD" date into a friendly Indonesian-style label.
/// Falls back to the raw string if parsing fails (defensive — the API
/// is trusted but we never want a crash on the attendance screen).
String _formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final d = DateTime.parse(raw);
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d);
  } catch (_) {
    return raw;
  }
}

/// Formats an ISO8601 timestamp into "HH:mm" local time.
String _formatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '--:--';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('HH:mm').format(dt);
  } catch (_) {
    return iso;
  }
}

/// Trims a "HH:mm:ss" schedule time down to "HH:mm".
String _shortTime(String t) {
  final parts = t.split(':');
  if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
  return t;
}
