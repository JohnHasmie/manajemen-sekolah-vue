// Riwayat Persetujuan — full-screen audit-trail timeline for one RPP.
//
// Mockup Frame F1. Renders every state change captured in
// lesson_plan_reviews (submit / approve / reject / sent_back / regen /
// edit) in newest-first order, with per-row dot colour, actor name,
// human-readable timestamp, and a quoted note when present.
//
// Open this from the admin detail sheet header (history icon). The
// screen calls GET /rpp/{id}/reviews via LessonPlanService and falls
// back to a friendly empty / error state when the endpoint can't
// resolve the row.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

class LessonPlanReviewHistoryScreen extends StatefulWidget {
  /// UUID of the lesson plan we're showing history for.
  final String lessonPlanId;

  /// Optional title shown under the kicker so the admin can confirm
  /// which RPP they're auditing. When null, the kicker stands alone.
  final String? lessonPlanTitle;

  /// Short subject label for the kicker (e.g. "Matematika · XII IPA 1").
  /// When null, the kicker just reads "Riwayat Persetujuan".
  final String? subtitle;

  const LessonPlanReviewHistoryScreen({
    super.key,
    required this.lessonPlanId,
    this.lessonPlanTitle,
    this.subtitle,
  });

  /// Push this screen on top of the current navigator. Mirrors the
  /// pattern other lesson-plan screens use (AppNavigator.push).
  static Future<void> push({
    required BuildContext context,
    required String lessonPlanId,
    String? lessonPlanTitle,
    String? subtitle,
  }) {
    return AppNavigator.push(
      context,
      LessonPlanReviewHistoryScreen(
        lessonPlanId: lessonPlanId,
        lessonPlanTitle: lessonPlanTitle,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<LessonPlanReviewHistoryScreen> createState() =>
      _LessonPlanReviewHistoryScreenState();
}

class _LessonPlanReviewHistoryScreenState
    extends State<LessonPlanReviewHistoryScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final rows =
          await LessonPlanService.getLessonPlanReviews(widget.lessonPlanId);
      if (!mounted) return;
      setState(() {
        _reviews = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.getFriendlyMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: _load,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: widget.subtitle ?? 'Audit Trail',
          title: widget.lessonPlanTitle ?? 'Riwayat Persetujuan',
        ),
        bodyChildren: [
          const SizedBox(height: AppSpacing.md),
          _buildBody(),
          SizedBox(
            height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: ColorUtils.error600,
            ),
            const SizedBox(height: 10),
            Text(
              'Gagal memuat riwayat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const EmptyState(
        title: 'Belum ada riwayat',
        subtitle: 'Riwayat persetujuan akan muncul setelah ada perubahan status.',
        icon: Icons.history_rounded,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: TimelineCard(rows: _reviews),
    );
  }
}

/// Single card containing the full timeline list. Wrapping the
/// timeline in one card (rather than per-row cards) matches the F1
/// mockup and reads as a continuous audit log.
class TimelineCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const TimelineCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: ColorUtils.slate700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Riwayat Persetujuan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.getRoleColor('admin'),
                ),
              ),
              const Spacer(),
              Text(
                '${rows.length} kejadian',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rows.length; i++)
            TimelineRow(
              row: rows[i],
              isLast: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class TimelineRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isLast;
  const TimelineRow({super.key, required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] ?? '').toString();
    final actorName = (row['actor_name'] ?? 'Sistem').toString();
    final actorRole = (row['actor_role'] ?? '').toString();
    final note = (row['note'] ?? '').toString();
    final createdAt = (row['created_at'] ?? '').toString();
    final revisionAreas = row['revision_areas'];
    final (dotIcon, dotColor, dotBg, headline) = _styleFor(action);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            // Mockup `.timeline .dot` is 26×26 with a 2px white inner
            // border + 1px slate-200 outer halo. Tightening from 28
            // matches the spec.
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: dotBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate200,
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(dotIcon, size: 13, color: dotColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                        ),
                      ),
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatActor(actorName, actorRole),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
                if (revisionAreas is List && revisionAreas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AreasRow(areas: revisionAreas.map((e) => e.toString()).toList()),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  NoteBlock(note: note, tint: dotColor, background: dotBg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns (icon, fg, bg, headline) per action verb. New verbs
  /// fall back to a neutral slate dot + the raw action string.
  (IconData, Color, Color, String) _styleFor(String action) {
    switch (action) {
      case 'submitted':
      case 'reopened':
        return (
          Icons.arrow_upward_rounded,
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
          'Dikirim',
        );
      case 'approved':
        return (
          Icons.check_rounded,
          // 700-weight green per mockup `.timeline .dot.approve`
          // fg `#15803D` on `#DCFCE7` bg.
          ColorUtils.success700,
          const Color(0xFFDCFCE7),
          'Disetujui',
        );
      case 'rejected':
        return (
          Icons.close_rounded,
          ColorUtils.error700,
          const Color(0xFFFEE2E2),
          'Ditolak',
        );
      case 'sent_back':
        return (
          Icons.reply_rounded,
          ColorUtils.warning700,
          ColorUtils.warningLight,
          'Dikembalikan ke guru',
        );
      case 'regen':
        return (
          Icons.auto_awesome_rounded,
          const Color(0xFF7C3AED),
          const Color(0xFFEDE9FE),
          'Regen via AI',
        );
      case 'edit':
        return (
          Icons.edit_rounded,
          const Color(0xFF0284C7),
          const Color(0xFFE0F2FE),
          'Diedit',
        );
      case 'reverted_to_draft':
        return (
          Icons.history_toggle_off_rounded,
          ColorUtils.slate600,
          ColorUtils.slate100,
          'Dikembalikan ke Draft',
        );
      default:
        return (
          Icons.circle_outlined,
          ColorUtils.slate600,
          ColorUtils.slate100,
          action.isEmpty ? 'Perubahan status' : action,
        );
    }
  }

  String _formatActor(String name, String role) {
    if (role.isEmpty) return name;
    final roleLabel = switch (role) {
      'admin' => 'Admin',
      'guru' => 'Guru',
      'parent' => 'Wali',
      _ => role,
    };
    return '$name · $roleLabel';
  }

  /// Best-effort ISO → "hh:mm" / "DD MMM" formatter. Bail to the raw
  /// substring when the timestamp isn't parseable so the row still
  /// renders something meaningful instead of "—".
  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final isToday = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
      if (isToday) {
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }
}

class AreasRow extends StatelessWidget {
  final List<String> areas;
  const AreasRow({super.key, required this.areas});

  static const _labels = {
    'identitas': 'Identitas',
    'kd_indikator': 'KD & Indikator',
    'tujuan': 'Tujuan Pembelajaran',
    'langkah_kegiatan': 'Langkah Kegiatan',
    'penilaian': 'Penilaian',
    'kegiatan': 'Kegiatan',
    'asesmen': 'Asesmen',
    'info_umum': 'Informasi Umum',
    'capaian': 'Capaian',
    'pemahaman_pemantik': 'Pemahaman & Pemantik',
    'asesmen_refleksi': 'Asesmen & Refleksi',
    'lampiran': 'Lampiran',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final a in areas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ColorUtils.warningLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              _labels[a] ?? a,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.warningDark,
              ),
            ),
          ),
      ],
    );
  }
}

class NoteBlock extends StatelessWidget {
  final String note;
  final Color tint;
  final Color background;
  const NoteBlock({
    super.key,
    required this.note,
    required this.tint,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: tint, width: 3)),
      ),
      child: Text(
        '"$note"',
        style: TextStyle(
          fontSize: 11,
          color: tint,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }
}
