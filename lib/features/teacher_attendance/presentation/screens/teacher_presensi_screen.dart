// teacher_presensi_screen.dart — the teacher-facing "Presensi Guru"
// (daily attendance) screen.
//
// What the teacher sees, top to bottom:
//   1. The shared brand header ([BrandPageHeader], role: 'guru') so this
//      screen wears the SAME Dark-Blue → Azure gradient + back button as
//      every other teacher deep-tab screen (no more bespoke violet bar).
//   2. A status hero card that overlaps the header — today's date + a big
//      pill telling them whether they've checked in (and if late) /
//      checked out, plus the masuk/pulang timestamps.
//   3. Requirement chips (selfie / lokasi) so the teacher knows up-front
//      what the school config will ask for.
//   4. Today's teaching schedule list (from the config endpoint), with
//      the "telat jika setelah" (late-after) line if the school set a
//      grace window.
//   5. A primary action button that adapts to state:
//        - not checked in  → "Presensi Masuk"
//        - checked in, checkout on, not checked out → "Presensi Pulang"
//        - done for the day → a "Selesai" summary card.
//
// THEME — this screen now uses the app's design tokens exclusively
// (`ColorUtils`): the brand gradient/role colour for the teacher
// (`getRoleColor('guru')` == brand cobalt), the slate neutral scale for
// surfaces/text, and the semantic 600 weights (success/warning/error/
// info) for state. No off-palette hex literals live in this file — a
// future brand refresh in `color_utils.dart` repaints the whole screen.
// Analogy for the Vue reader: instead of inline Tailwind hex, every
// colour resolves through the shared "tailwind.config" (`ColorUtils`).
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

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/teacher_attendance/data/'
    'teacher_attendance_location_helper.dart';
import 'package:manajemensekolah/features/teacher_attendance/data/'
    'teacher_attendance_service.dart';
import 'package:manajemensekolah/features/teacher_attendance/domain/models/'
    'teacher_attendance_models.dart';

/// Role key for every theme lookup on this screen. Resolving through the
/// shared helper means the teacher accent (brand cobalt) and the hero
/// gradient (Dark Blue → Azure) come from ONE source of truth, exactly
/// like the rest of the teacher experience.
const String _kRole = 'guru';

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

  /// The teacher accent — brand cobalt (#1B6FB8) — pulled from the shared
  /// palette so it always matches the rest of the app.
  Color get _accent => ColorUtils.getRoleColor(_kRole);

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
    // The brand header paints its own gradient + rounded bottom + back
    // button, so we drop the bespoke AppBar entirely and let the screen
    // be one vertical stack: header on top, content below. Scaffold uses
    // the app's neutral surface (slate-50) instead of an off-palette grey.
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandPageHeader(
            role: _kRole,
            subtitle: 'KEHADIRAN',
            title: 'Presensi Guru',
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _LoadingState(accent: _accent);
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          _StatusHero(config: config, accent: _accent),
          const SizedBox(height: AppSpacing.lg),
          _RequirementChips(settings: config.settings, accent: _accent),
          _ScheduleSection(config: config, accent: _accent),
          const SizedBox(height: AppSpacing.xxl),
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
      return _DoneCard(state: state, checkoutEnabled: settings.checkoutEnabled);
    }

    // Checked in, checkout enabled, not yet out → offer check-out. Uses
    // the semantic error/600 weight so "pulang" reads distinct from the
    // brand-coloured "masuk" CTA.
    if (state.canCheckOut) {
      return _ActionButton(
        label: 'Presensi Pulang',
        icon: Icons.logout_rounded,
        color: ColorUtils.error600,
        busy: _submitting,
        onPressed: _onCheckOut,
      );
    }

    // Default: not checked in yet → offer check-in (brand accent).
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

/// The primary state card. Sits at the top of the body and reads at a
/// glance: today's date, a status pill (Belum presensi / Hadir / Hadir —
/// Terlambat), and the masuk/pulang timestamps once they exist.
///
/// Themed entirely from the brand teacher gradient + slate scale: the pill
/// switches between success / warning / slate semantics rather than
/// hand-mixed colours.
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        // Canonical teacher hero gradient (Dark Blue → Azure) — the same
        // pairing every teacher header uses, via the shared helper.
        gradient: ColorUtils.brandGradient(_kRole),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StatusPill(state: state, record: record),
          if (record?.checkInAt != null || record?.checkOutAt != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _TimeStrip(record: record!),
          ],
        ],
      ),
    );
  }
}

/// The big status pill inside the hero. Colour-codes the verdict using a
/// translucent white scrim (so it always reads on the brand gradient)
/// while the icon hints at the semantic (pending / present / late).
class _StatusPill extends StatelessWidget {
  final TeacherAttendanceState state;
  final TeacherAttendanceRecord? record;

  const _StatusPill({required this.state, required this.record});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: AppSpacing.xs + 2),
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
}

/// A compact two-up strip showing the masuk + pulang times. Each cell is
/// a translucent panel on the hero so the timestamps read as "stamped"
/// facts rather than loose text.
class _TimeStrip extends StatelessWidget {
  final TeacherAttendanceRecord record;

  const _TimeStrip({required this.record});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeCell(
            icon: Icons.login_rounded,
            label: 'Masuk',
            value: _formatTime(record.checkInAt),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _TimeCell(
            icon: Icons.logout_rounded,
            label: 'Pulang',
            value: record.checkOutAt != null
                ? _formatTime(record.checkOutAt)
                : '--:--',
          ),
        ),
      ],
    );
  }
}

/// One masuk/pulang cell — icon + label on top, big time below.
class _TimeCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimeCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 14),
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requirement chips (camera / location / radius) ─────────────────────

/// Up-front signal of what the school config will ask for on submit
/// (selfie / location). Hidden entirely when neither is required so the
/// layout stays tight. Chips are tinted with the teacher accent.
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
    // Nothing required → render zero height so the SizedBox above us in
    // the list doesn't create a dangling gap.
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: chips,
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: AppSpacing.xs + 1),
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

/// A white card listing today's teaching periods (+ the "terlambat jika"
/// line). Styled with the shared `corporateCard` decoration so its
/// border/shadow match every other card in the app.
class _ScheduleSection extends StatelessWidget {
  final TeacherAttendanceConfig config;
  final Color accent;

  const _ScheduleSection({required this.config, required this.accent});

  @override
  Widget build(BuildContext context) {
    final schedule = config.todaySchedule;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ColorUtils.corporateCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Text(
                  'Jadwal Mengajar Hari Ini',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: ColorUtils.slate800,
                  ),
                ),
              ),
              if (schedule.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${schedule.length} sesi',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (config.lateAfter != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.av_timer_rounded,
                  size: 14,
                  color: ColorUtils.warning600,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    'Terlambat jika presensi setelah '
                    '${_formatTime(config.lateAfter)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorUtils.warning600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (schedule.isEmpty)
            _EmptySchedule(accent: accent)
          else
            ...schedule.map((s) => _ScheduleRow(schedule: s, accent: accent)),
        ],
      ),
    );
  }
}

/// Friendly empty state for a no-class day — themed on the slate scale so
/// it reads as "quiet" rather than "broken".
class _EmptySchedule extends StatelessWidget {
  final Color accent;

  const _EmptySchedule({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, color: ColorUtils.slate400, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tidak ada jadwal mengajar hari ini.',
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// One teaching period row: an accent timeline dot, the subject, then a
/// muted "kelas · waktu · jam" meta line.
class _ScheduleRow extends StatelessWidget {
  final TeacherTodaySchedule schedule;
  final Color accent;

  const _ScheduleRow({required this.schedule, required this.accent});

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    final time = [
      s.startTime,
      s.endTime,
    ].where((t) => (t ?? '').isNotEmpty).map((t) => _shortTime(t!)).join(' - ');
    final meta = [
      if ((s.className ?? '').isNotEmpty) s.className!,
      if (time.isNotEmpty) time,
      if ((s.lessonHourName ?? '').isNotEmpty) s.lessonHourName!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: AppSpacing.md - 2),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.subjectName ?? 'Mata pelajaran',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Done card ──────────────────────────────────────────────────────────

/// Shown once the teacher is finished for the day (checked in, and either
/// checked out or checkout disabled). Uses the semantic success palette.
class _DoneCard extends StatelessWidget {
  final TeacherAttendanceState state;
  final bool checkoutEnabled;

  const _DoneCard({required this.state, required this.checkoutEnabled});

  @override
  Widget build(BuildContext context) {
    final message = checkoutEnabled
        ? 'Presensi masuk & pulang hari ini sudah lengkap.'
        : 'Presensi masuk hari ini sudah tercatat.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        color: ColorUtils.success600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.success600.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: ColorUtils.success600.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.task_alt_rounded, color: ColorUtils.success600),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selesai',
                  style: TextStyle(
                    color: ColorUtils.success700,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: ColorUtils.success700,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary action button ──────────────────────────────────────────────

/// The hero CTA. Adapts its colour/icon to masuk vs pulang and shows an
/// inline spinner + "Memproses…" while the multipart POST is in flight.
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
          disabledForegroundColor: Colors.white,
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.4),
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

// ── Loading state ──────────────────────────────────────────────────────

/// First-load placeholder. A simple centered spinner tinted with the
/// teacher accent + a reassuring caption, so the screen never flashes a
/// bare grey spinner against the brand header.
class _LoadingState extends StatelessWidget {
  final Color accent;

  const _LoadingState({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: accent),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Memuat presensi…',
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────

/// Shown when the config load fails. Slate-themed icon + message and a
/// retry button so the teacher can recover without leaving the screen.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: ColorUtils.slate400),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorUtils.slate600),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.getRoleColor(_kRole),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
