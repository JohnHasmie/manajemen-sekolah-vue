// Kelola Tahun Ajaran — Frame B of the Pengaturan Umum redesign.
//
// Built on shared brand components:
//   • BrandPageLayout — sticky header + scrollable body
//   • BrandPageHeader  — admin navy gradient (kpiOverlayHeight 45dp)
//   • BrandKpiStrip    — Total / Saat Ini / Arsip count overlay
//   • ConfirmationDialog — destructive actions
//   • AppBottomSheet (via TahunAjaranEditSheet) — Tambah / Edit form
//
// Layout follows `_design/admin_tahun_ajaran_redesign.html` Frame B
// verbatim: navy header → KPI strip overlap → "Tahun Ajaran Saat Ini"
// section → cobalt-bordered current-year card with 48×48 year badge
// + meta-stat row → "Riwayat (Arsip)" section → list of archived rows
// with slate year badges + Arsip pill → FAB "Tahun Ajaran Baru".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/settings/data/academic_service.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/tahun_ajaran_activate_dialog.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/tahun_ajaran_edit_sheet.dart';

class KelolaTahunAjaranScreen extends ConsumerStatefulWidget {
  const KelolaTahunAjaranScreen({super.key});

  @override
  ConsumerState<KelolaTahunAjaranScreen> createState() =>
      _KelolaTahunAjaranScreenState();
}

class _KelolaTahunAjaranScreenState
    extends ConsumerState<KelolaTahunAjaranScreen> {
  bool _isActionLoading = false;

  // Admin role accent — navy (`#143068`). Pinned once so every
  // surface (border emphasis, FAB, pill ink, etc.) reads the same.
  Color get _accent => ColorUtils.getRoleColor('admin');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicYearRiverpod).fetchAcademicYears();
    });
  }

  Future<void> _handleRefresh() async {
    await ref.read(academicYearRiverpod).fetchAcademicYears();
  }

  // ─── Mutation handlers ──────────────────────────────────────────────

  Future<void> _handleActivate(Map<String, dynamic> year) async {
    final activeYear = ref.read(academicYearRiverpod).activeAcademicYear;
    final activeYearLabel = activeYear?['year']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => TahunAjaranActivateDialog(
        targetYear: year['year']?.toString() ?? '',
        currentActiveYear: activeYearLabel,
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final svc = getIt<ApiAcademicServices>();
      // setCurrent on the backend now handles the cascade (archive
      // previous + status flip). Older surfaces still call
      // updateAcademicYearStatus separately as a safety net.
      await svc.setCurrentAcademicYear(year['id'].toString());
      await ref.read(academicYearRiverpod).fetchAcademicYears();
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        'Tahun ajaran ${year['year']} berhasil diaktifkan',
      );
    } catch (e) {
      AppLogger.error('academic_year_activate', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal mengaktifkan: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleArchive(Map<String, dynamic> year) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Arsipkan Tahun Ajaran',
        content:
            'Arsipkan tahun ajaran ${year['year']}? Tahun arsip menjadi read-only dan tidak bisa diubah.',
        confirmText: 'Ya, Arsipkan',
        confirmColor: ColorUtils.warning600,
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final svc = getIt<ApiAcademicServices>();
      await svc.archiveAcademicYear(year['id'].toString());
      await ref.read(academicYearRiverpod).fetchAcademicYears();
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        'Tahun ajaran ${year['year']} berhasil diarsipkan',
      );
    } catch (e) {
      AppLogger.error('academic_year_archive', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal mengarsipkan: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleUnarchive(Map<String, dynamic> year) async {
    setState(() => _isActionLoading = true);
    try {
      final svc = getIt<ApiAcademicServices>();
      await svc.unarchiveAcademicYear(year['id'].toString());
      await ref.read(academicYearRiverpod).fetchAcademicYears();
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        'Tahun ajaran ${year['year']} berhasil dipulihkan',
      );
    } catch (e) {
      AppLogger.error('academic_year_unarchive', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal memulihkan: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> year) async {
    final isCurrent = year['current'] == true || year['current'] == 1;
    if (isCurrent) {
      SnackBarUtils.showError(
        context,
        'Tahun ajaran aktif tidak dapat dihapus. Aktifkan tahun ajaran lain terlebih dahulu.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Hapus Tahun Ajaran',
        content:
            'Hapus tahun ajaran ${year['year']}? Tindakan ini tidak dapat dibatalkan.',
        confirmText: 'Ya, Hapus',
        confirmColor: ColorUtils.error600,
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final svc = getIt<ApiAcademicServices>();
      await svc.deleteAcademicYear(year['id'].toString());
      await ref.read(academicYearRiverpod).fetchAcademicYears();
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Tahun ajaran berhasil dihapus');
    } catch (e) {
      AppLogger.error('academic_year_delete', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal menghapus: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showEditSheet([Map<String, dynamic>? year]) {
    TahunAjaranEditSheet.show(
      context: context,
      ref: ref,
      academicYear: year,
      onSaved: () => ref.read(academicYearRiverpod).fetchAcademicYears(),
    );
  }

  void _showQuickActionsSheet(Map<String, dynamic> year) {
    final isCurrent = year['current'] == true || year['current'] == 1;
    final status = (year['status'] ?? '').toString();
    final isArchived = status == 'archived';

    AppBottomSheet.show(
      context: context,
      title: year['year']?.toString() ?? 'Tahun Ajaran',
      subtitle: 'Pilih tindakan',
      icon: Icons.tune_rounded,
      primaryColor: _accent,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCurrent && !isArchived)
            _QuickActionRow(
              icon: Icons.check_circle_rounded,
              label: 'Aktifkan',
              subtitle: 'Jadikan tahun ajaran ini sebagai "Saat Ini"',
              tint: ColorUtils.green600,
              onTap: () {
                Navigator.pop(context);
                _handleActivate(year);
              },
            ),
          if (!isArchived)
            _QuickActionRow(
              icon: Icons.edit_rounded,
              label: 'Edit',
              subtitle: 'Ubah periode atau semester',
              tint: _accent,
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(year);
              },
            ),
          if (!isCurrent && !isArchived)
            _QuickActionRow(
              icon: Icons.archive_outlined,
              label: 'Arsipkan',
              subtitle: 'Lock sebagai arsip read-only',
              tint: ColorUtils.warning600,
              onTap: () {
                Navigator.pop(context);
                _handleArchive(year);
              },
            ),
          if (isArchived)
            _QuickActionRow(
              icon: Icons.unarchive_outlined,
              label: 'Pulihkan',
              subtitle: 'Kembalikan ke status nonaktif',
              tint: _accent,
              onTap: () {
                Navigator.pop(context);
                _handleUnarchive(year);
              },
            ),
          if (!isCurrent)
            _QuickActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Hapus',
              subtitle: 'Tindakan tidak dapat dibatalkan',
              tint: ColorUtils.error600,
              onTap: () {
                Navigator.pop(context);
                _handleDelete(year);
              },
              destructive: true,
            ),
        ],
      ),
      // No explicit footer — each [_QuickActionRow] closes the sheet
      // itself via Navigator.pop. Drag-to-dismiss + scrim-tap still
      // work as expected via AppBottomSheet's defaults.
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(academicYearRiverpod);
    final overallLoading = provider.isLoading || _isActionLoading;
    final years = provider.academicYears;

    Map<String, dynamic>? activeYear;
    for (final y in years) {
      if (y['current'] == true || y['current'] == 1) {
        activeYear = Map<String, dynamic>.from(y);
        break;
      }
    }
    final archivedYears = years
        .where((y) => y['id'] != activeYear?['id'])
        .toList();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: _handleRefresh,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: 'SISTEM · KONFIGURASI',
          title: 'Tahun Ajaran',
          kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
        ),
        kpiCard: BrandKpiStrip(
          columns: [
            BrandKpiColumn(
              label: 'Total',
              value: '${years.length}',
              sub: 'Tahun Ajaran',
            ),
            BrandKpiColumn(
              label: 'Saat Ini',
              value: activeYear != null ? '1' : '0',
              sub: 'Aktif berjalan',
              valueColor: ColorUtils.green600,
            ),
            BrandKpiColumn(
              label: 'Arsip',
              value: '${archivedYears.length}',
              sub: 'Tahun Ajaran lalu',
              valueColor: ColorUtils.slate500,
            ),
          ],
        ),
        bodyChildren: [
          const SizedBox(height: 20),
          if (overallLoading && years.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SkeletonListLoading(itemCount: 4, infoTagCount: 1),
            )
          else ...[
            // Tahun Ajaran Saat Ini — pinned section above the
            // archived list. Mockup renders the section title in caps.
            const _SectionTitle(label: 'Tahun Ajaran Saat Ini'),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: activeYear == null
                  ? const _EmptyActiveYearCard()
                  : _YearCard(
                      year: activeYear,
                      isActive: true,
                      accent: _accent,
                      onMore: () => _showQuickActionsSheet(activeYear!),
                    ),
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              label: 'Riwayat (Arsip)',
              trailing: archivedYears.isEmpty
                  ? null
                  : '${archivedYears.length}',
            ),
            const SizedBox(height: 10),
            if (archivedYears.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _EmptyArchiveCard(),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: archivedYears.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final y = Map<String, dynamic>.from(archivedYears[index]);
                  return _YearCard(
                    year: y,
                    isActive: false,
                    accent: _accent,
                    onMore: () => _showQuickActionsSheet(y),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditSheet(),
        backgroundColor: _accent,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Tahun Ajaran Baru',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Section title — UPPERCASE caps text mirroring the mockup's
// `.sec-title-row .ttl` styling. Optional trailing count badge.
// ───────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  final String? trailing;

  const _SectionTitle({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              '· $trailing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate400,
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Year row card — mockup .ay-row. Two variants:
//   • isActive=true → cobalt 1.5px border + cobalt year badge + Saat
//     Ini green pill + per-row meta-stats
//   • isActive=false → slate-200 border + slate year badge + Arsip pill
//     + per-row meta-stats
// ───────────────────────────────────────────────────────────────────────

class _YearCard extends StatelessWidget {
  final Map<String, dynamic> year;
  final bool isActive;
  final Color accent;
  final VoidCallback onMore;

  const _YearCard({
    required this.year,
    required this.isActive,
    required this.accent,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    // ── Period guard — renders "Periode belum diatur" when null ──
    final hasStart = (year['start_date'] ?? '').toString().isNotEmpty;
    final hasEnd = (year['end_date'] ?? '').toString().isNotEmpty;
    final startDateStr = hasStart
        ? AppDateUtils.formatDateString(
            year['start_date'],
            format: 'dd MMM yyyy',
          )
        : null;
    final endDateStr = hasEnd
        ? AppDateUtils.formatDateString(year['end_date'], format: 'dd MMM yyyy')
        : null;
    final periodPart = (startDateStr != null && endDateStr != null)
        ? '$startDateStr — $endDateStr'
        : null;

    // ── Semester label ──
    //
    // `academic_years.semester` still uses Indonesian (`ganjil` /
    // `genap`) per backend convention; defensively also accept the
    // canonical `odd` / `even` encoding used by `semesters.name`
    // post-rename, in case any legacy code path writes those.
    final semesterLabel = semesterDisplayLabel(year['semester']?.toString());
    final semesterPart = semesterLabel != null
        ? 'Semester $semesterLabel'
        : null;

    // ── Compose sub-line ──
    final subLine = (semesterPart != null && periodPart != null)
        ? '$semesterPart · $periodPart'
        : (periodPart ?? semesterPart ?? 'Periode belum diatur');

    // Year badge halves ("25" / "26") split from the "YYYY/YYYY" label.
    final yearString = (year['year'] ?? '').toString();
    final yearParts = yearString.split('/');
    final y1 = yearParts.isNotEmpty && yearParts.first.length >= 2
        ? yearParts.first.substring(yearParts.first.length - 2)
        : '--';
    final y2 = yearParts.length > 1 && yearParts[1].length >= 2
        ? yearParts[1].substring(yearParts[1].length - 2)
        : '--';

    // Counts surfaced by AcademicController.appendCounts().
    final classCount = year['class_count']?.toString() ?? '0';
    final studentCount = year['student_count']?.toString() ?? '0';
    final teacherCount = year['teacher_count']?.toString() ?? '0';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isActive ? accent : ColorUtils.slate200,
          width: isActive ? 1.5 : 0.75,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        gradient: isActive
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.04), Colors.white],
                stops: const [0.0, 0.5],
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onMore,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _YearBadge(
                      y1: y1,
                      y2: y2,
                      isActive: isActive,
                      accent: accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  yearString,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: ColorUtils.slate900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (isActive) _SaatIniPill() else _ArsipPill(),
                              IconButton(
                                onPressed: onMore,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: ColorUtils.slate500,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subLine,
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          _MetaStatRow(
                            classCount: classCount,
                            studentCount: studentCount,
                            teacherCount: teacherCount,
                            accent: accent,
                            isActive: isActive,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YearBadge extends StatelessWidget {
  final String y1;
  final String y2;
  final bool isActive;
  final Color accent;

  const _YearBadge({
    required this.y1,
    required this.y2,
    required this.isActive,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive ? accent : ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            y1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : ColorUtils.slate700,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
          Text(
            '/',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.65)
                  : ColorUtils.slate500,
              height: 1,
            ),
          ),
          Text(
            y2,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : ColorUtils.slate700,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaatIniPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // green600 tinted backgrounds since ColorUtils doesn't expose
    // green50/100 directly — withValues(alpha) gives us the same
    // visual without sprouting raw hex literals.
    final fill = ColorUtils.green600.withValues(alpha: 0.10);
    final border = ColorUtils.green600.withValues(alpha: 0.30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 10,
            color: ColorUtils.green600,
          ),
          const SizedBox(width: 4),
          Text(
            'Saat Ini',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.green600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArsipPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        'Arsip',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: ColorUtils.slate600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MetaStatRow extends StatelessWidget {
  final String classCount;
  final String studentCount;
  final String teacherCount;
  final Color accent;
  final bool isActive;

  const _MetaStatRow({
    required this.classCount,
    required this.studentCount,
    required this.teacherCount,
    required this.accent,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat(icon: Icons.menu_book_rounded, value: classCount, label: 'Kelas'),
        const SizedBox(width: 12),
        _stat(
          icon: Icons.people_alt_rounded,
          value: studentCount,
          label: 'Siswa',
        ),
        const SizedBox(width: 12),
        _stat(icon: Icons.person_rounded, value: teacherCount, label: 'Guru'),
      ],
    );
  }

  Widget _stat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate800,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Empty states — surfaced when there's no current year (cold start)
// or no archived rows yet (fresh school).
// ───────────────────────────────────────────────────────────────────────

class _EmptyActiveYearCard extends StatelessWidget {
  const _EmptyActiveYearCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 36,
            color: ColorUtils.slate300,
          ),
          const SizedBox(height: 10),
          Text(
            'Belum ada tahun ajaran aktif',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap tombol + di kanan-bawah untuk menambahkan baru.',
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyArchiveCard extends StatelessWidget {
  const _EmptyArchiveCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Center(
        child: Text(
          'Belum ada arsip tahun ajaran',
          style: TextStyle(
            fontSize: 12.5,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Quick-action row — used inside the per-year AppBottomSheet so each
// action carries a clear icon + label + supporting subtitle, instead
// of a plain PopupMenu list.
// ───────────────────────────────────────────────────────────────────────

class _QuickActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
  final bool destructive;

  const _QuickActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: destructive
                            ? ColorUtils.error600
                            : ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ColorUtils.slate400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
