// Admin Kegiatan Kelas detail screen (Frame B).
//
// Monitor-only view — admin observes, doesn't author. Mirrors the
// teacher detail's BrandPageLayout chrome but trades the edit + add-
// submission CTAs for a clean three-section read:
//
//   1. Informasi  — guru / jadwal / deadline / tipe + description + lampiran
//   2. Daftar Siswa — submission rows with status pill + score
//   3. Statistik — Distribusi nilai + Tuntas + activity log
//
// KPI overlap card: Submit / Belum / Rerata.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/domain/models/admin_activity_summary.dart';

class AdminActivityDetailScreen extends ConsumerStatefulWidget {
  const AdminActivityDetailScreen({
    super.key,
    required this.activityId,
    this.summary,
  });

  final String activityId;

  /// Optional preloaded summary — when present, the screen paints
  /// instantly with the hub's card data while the full detail is
  /// fetched. Falls back to a skeleton when null.
  final AdminActivitySummary? summary;

  @override
  ConsumerState<AdminActivityDetailScreen> createState() =>
      _AdminActivityDetailScreenState();
}

class _AdminActivityDetailScreenState
    extends ConsumerState<AdminActivityDetailScreen> {
  final ApiClassActivityService _service = ApiClassActivityService();

  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>>? _submissions;
  bool _isLoading = true;
  String? _errorMessage;

  AdminActivitySummary get _activity => widget.summary ?? _fromDetail();

  AdminActivitySummary _fromDetail() {
    final d = _detail;
    if (d == null) {
      return AdminActivitySummary(id: widget.activityId);
    }
    return AdminActivitySummary.fromJson(d);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _service.getActivity(widget.activityId);
      final subs = await _service.getSubmissions(widget.activityId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _submissions = subs;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('admin_activity_detail', 'load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the language provider so future bilingual section labels
    // pick up locale changes without an extra rebuild plumbing pass;
    // Indonesian labels are baked in for now.
    ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: _load,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: 'DETAIL KEGIATAN',
          title: _activity.title ?? '—',
          showBackButton: true,
          kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
          actionIcons: const [],
        ),
        kpiCard: _buildKpiCard(),
        bodyChildren: [
          if (_isLoading && _detail == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: ColorUtils.error600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoSection(activity: _activity),
                  const SizedBox(height: AppSpacing.sm),
                  _SubmissionsSection(submissions: _submissions ?? const []),
                  const SizedBox(height: AppSpacing.sm),
                  _StatsSection(
                    activity: _activity,
                    submissions: _submissions ?? const [],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard() {
    final s = _activity.submissions;
    final submittedTotal = s.submitted + s.late;
    final pending = s.pending == 0 && s.totalStudents > 0
        ? (s.totalStudents - submittedTotal - s.excused).clamp(0, 9999)
        : s.pending;
    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: 'Submit',
          value: '$submittedTotal',
          valueColor: const Color(0xFF15803D),
        ),
        BrandKpiColumn(
          label: 'Belum',
          value: '$pending',
          valueColor: pending > 0 ? const Color(0xFFB45309) : null,
        ),
        BrandKpiColumn(
          label: 'Rerata',
          value: s.avgScore?.toStringAsFixed(1) ?? '—',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sections
// ─────────────────────────────────────────────────────────────────────
class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: iconFg),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandDarkBlue,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.activity});
  final AdminActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: Icons.info_outline_rounded,
      iconBg: const Color(0xFFEDE9FE),
      iconFg: const Color(0xFF7C3AED),
      title: 'Informasi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(label: 'Guru', value: activity.teacherName ?? '—'),
          _MetaRow(
            label: 'Kelas',
            value:
                '${activity.className ?? '—'} · ${activity.subjectName ?? '—'}',
          ),
          _MetaRow(label: 'Tanggal', value: _formatDate(activity.date)),
          _MetaRow(label: 'Tipe', value: activity.type.labelId),
          if ((activity.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              activity.description!,
              style: TextStyle(
                fontSize: 12,
                height: 1.55,
                color: ColorUtils.slate700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.brandDarkBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionsSection extends StatelessWidget {
  const _SubmissionsSection({required this.submissions});
  final List<Map<String, dynamic>> submissions;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      icon: Icons.groups_2_outlined,
      iconBg: const Color(0xFFCCFBF1),
      iconFg: const Color(0xFF0D9488),
      title: 'Daftar Siswa · ${submissions.length}',
      child: submissions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Kegiatan ini tidak melacak submit per siswa.',
                style: TextStyle(fontSize: 11.5, color: ColorUtils.slate500),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < submissions.length && i < 8; i++)
                  _SubmissionRow(row: submissions[i]),
                if (submissions.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '… dan ${submissions.length - 8} siswa lain',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = (row['student_name'] ?? row['name'] ?? '—').toString();
    final nis = (row['nis'] ?? row['student_nis'] ?? '').toString();
    final status = (row['status'] ?? 'pending').toString().toLowerCase();
    final score = row['score'];

    final (statusBg, statusFg, statusLabel) = _statusStyle(status);
    final initials = _initials(name);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.brandDarkBlue,
                  ),
                ),
                if (nis.isNotEmpty)
                  Text(
                    nis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: ColorUtils.slate500,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: statusFg,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              score?.toString() ?? '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: score == null
                    ? ColorUtils.slate400
                    : ColorUtils.brandDarkBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _statusStyle(String status) {
    switch (status) {
      case 'submitted':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D), 'SUBMIT');
      case 'late':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309), 'TELAT');
      case 'excused':
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED), 'IZIN');
      default:
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), 'MENUNGGU');
    }
  }

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.activity, required this.submissions});
  final AdminActivitySummary activity;
  final List<Map<String, dynamic>> submissions;

  @override
  Widget build(BuildContext context) {
    // Compute distribution stats from the submission rows
    var max = 0.0;
    var min = double.infinity;
    var sum = 0.0;
    var scoreCount = 0;
    var tuntas = 0;
    const kkm = 75;
    for (final row in submissions) {
      final raw = row['score'];
      double? s;
      if (raw is num) s = raw.toDouble();
      if (raw is String) s = double.tryParse(raw);
      if (s == null) continue;
      if (s > max) max = s;
      if (s < min) min = s;
      sum += s;
      scoreCount++;
      if (s >= kkm) tuntas++;
    }
    final avg = scoreCount > 0 ? sum / scoreCount : null;
    if (scoreCount == 0) min = 0;
    final tuntasPct = submissions.isEmpty
        ? 0
        : ((tuntas / submissions.length) * 100).round();

    return _SectionShell(
      icon: Icons.bar_chart_rounded,
      iconBg: const Color(0xFFFEF3C7),
      iconFg: const Color(0xFFB45309),
      title: 'Statistik',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'DISTRIBUSI NILAI',
                  primary: avg != null ? avg.toStringAsFixed(1) : '—',
                  primaryLabel: 'rerata',
                  detail: scoreCount > 0
                      ? 'Tertinggi ${max.toStringAsFixed(0)} · '
                            'Terendah ${min.toStringAsFixed(0)}'
                      : 'Belum ada nilai',
                  primaryColor: ColorUtils.brandDarkBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  label: 'TUNTAS',
                  primary: '$tuntas',
                  primaryLabel: 'dari ${submissions.length}',
                  detail: 'KKM ≥ $kkm · $tuntasPct%',
                  primaryColor: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.primary,
    required this.primaryLabel,
    required this.detail,
    required this.primaryColor,
  });

  final String label;
  final String primary;
  final String primaryLabel;
  final String detail;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: primary,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                TextSpan(
                  text: ' $primaryLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: TextStyle(fontSize: 10.5, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }
}
