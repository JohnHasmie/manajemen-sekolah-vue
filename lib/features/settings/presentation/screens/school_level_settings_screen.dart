import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_data_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_dialog_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/school_level_ui_builders_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/kelola_tahun_ajaran_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';

/// Pengaturan Umum hub — admin Sistem entry point that surfaces the
/// two configuration blocks the school admin cares about side-by-side:
///
///   1. **Informasi Sekolah** — name, address, jenjang. Each row taps
///      open the [SchoolLevelDialogMixin] edit sheet.
///   2. **Tahun Ajaran** — active-year gradient hero card with semester
///      + period + meta-stats (siswa / kelas / guru), plus an Arsip
///      drill-down tile pointing at [KelolaTahunAjaranScreen].
///
/// Both blocks follow the audited brand spec (`DashboardListTile`
/// tile-card pattern; mockup `_design/admin_tahun_ajaran_redesign.html`
/// Frame A).
class SchoolLevelSettingsScreen extends ConsumerStatefulWidget {
  const SchoolLevelSettingsScreen({super.key});

  @override
  ConsumerState<SchoolLevelSettingsScreen> createState() =>
      _SchoolLevelSettingsScreenState();
}

class _SchoolLevelSettingsScreenState
    extends ConsumerState<SchoolLevelSettingsScreen>
    with
        SchoolLevelDataMixin,
        SchoolLevelDialogMixin,
        SchoolLevelUIBuildersMixin {
  String _schoolName = '';
  String _schoolAddress = '';
  String _selectedJenjang = 'SMA';
  final List<String> _jenjangOptions = ['SD', 'SMP', 'SMA', 'SMK'];
  bool _isLoading = true;
  Map<String, dynamic>? _activeSemester;

  // The address tile carries a violet accent in the mockup so the
  // three rows aren't visually identical. Pinned as a constant so the
  // tile-card pattern doesn't sprout magic hex strings.
  static const Color _violetAccent = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(academicYearRiverpod).fetchAcademicYears();
    });
    _loadSettings();
    _loadActiveSemester();
  }

  void _loadSettings() {
    loadSchoolSettings(
      onSchoolNameChanged: (name) => _schoolName = name,
      onAddressChanged: (addr) => _schoolAddress = addr,
      onJenjangChanged: (level) => _selectedJenjang = level,
      onLoadingChanged: (loading) => _isLoading = loading,
    );
  }

  Future<void> _loadActiveSemester() async {
    try {
      final response = await dioClient.get('/semesters');
      final semestersList = response.data;
      if (semestersList is List) {
        final currentSem = semestersList.firstWhere(
          (s) => s['current'] == true || s['current'] == 1,
          orElse: () => null,
        );
        if (mounted) setState(() => _activeSemester = currentSem);
      }
    } catch (_) {
      // Silently ignore — the gradient card falls back to the AY's
      // own embedded semester column.
    }
  }

  Future<void> _handleRefresh() async {
    _loadSettings();
    _loadActiveSemester();
    await ref.read(academicYearRiverpod).fetchAcademicYears();
  }

  void _openKelolaTahunAjaran() {
    AppNavigator.push(context, const KelolaTahunAjaranScreen()).then((_) {
      _handleRefresh();
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final academicProvider = ref.watch(academicYearRiverpod);
    final overallLoading = _isLoading || academicProvider.isLoading;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: overallLoading
                  ? const SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                  : _buildBody(academicProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Cog action replaces the legacy pencil — Edit affordances now
    // live inside each section header ("Edit ›" link). The cog opens
    // the full system settings flow if the admin wants more controls
    // (currently no-op — reserved hook).
    return const BrandPageHeader(
      role: 'admin',
      subtitle: 'SISTEM · KONFIGURASI',
      title: 'Pengaturan Umum',
    );
  }

  Widget _buildBody(AcademicYearProvider academicProvider) {
    final activeYear = academicProvider.activeAcademicYear;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: ColorUtils.brandDarkBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section 1 · Informasi Sekolah ──
            _SectionHeader(
              icon: Icons.school_rounded,
              tint: ColorUtils.brandDarkBlue,
              title: 'Informasi Sekolah',
              subtitle: 'Identitas & profil sekolah Anda',
              actionLabel: 'Edit',
              actionIcon: Icons.edit_outlined,
              onAction: _showEditDialog,
            ),
            const SizedBox(height: 10),
            buildInfoTileGroup([
              InfoTileRow(
                label: 'Nama Sekolah',
                value: _schoolName,
                icon: Icons.school_rounded,
                iconColor: ColorUtils.brandDarkBlue,
                onTap: _showEditDialog,
              ),
              InfoTileRow(
                label: 'Alamat Sekolah',
                value: _schoolAddress,
                icon: Icons.location_on_rounded,
                iconColor: _violetAccent,
                onTap: _showEditDialog,
              ),
              InfoTileRow(
                label: 'Jenjang Pendidikan',
                value: _jenjangFullLabel(_selectedJenjang),
                icon: Icons.stairs_rounded,
                iconColor: ColorUtils.brandDarkBlue,
                onTap: _showEditDialog,
              ),
            ]),

            const SizedBox(height: 22),

            // ── Section 2 · Tahun Ajaran ──
            _SectionHeader(
              icon: Icons.calendar_today_rounded,
              tint: ColorUtils.green600,
              title: 'Tahun Ajaran',
              subtitle: 'Periode aktif & arsip',
              actionLabel: 'Kelola',
              actionIcon: Icons.chevron_right_rounded,
              onAction: _openKelolaTahunAjaran,
            ),
            const SizedBox(height: 10),
            if (activeYear == null)
              _EmptyActiveYearCard(onTap: _openKelolaTahunAjaran)
            else
              _ActiveYearHero(
                activeYear: activeYear,
                fallbackSemesterName: _activeSemester?['name']?.toString(),
                onTap: _openKelolaTahunAjaran,
              ),
            const SizedBox(height: 10),
            _ArsipDrillTile(onTap: _openKelolaTahunAjaran),
          ],
        ),
      ),
    );
  }

  /// Maps the short code stored in [_selectedJenjang] to a full
  /// readable label for the tile-card row. Keeps the tile value
  /// matching the mockup's "SMP · Sekolah Menengah Pertama" line.
  String _jenjangFullLabel(String code) {
    switch (code) {
      case 'SD':
        return 'SD · Sekolah Dasar';
      case 'SMP':
        return 'SMP · Sekolah Menengah Pertama';
      case 'SMA':
        return 'SMA · Sekolah Menengah Atas';
      case 'SMK':
        return 'SMK · Sekolah Menengah Kejuruan';
      default:
        return code;
    }
  }

  Future<void> _showEditDialog() async {
    await showEditDialog(
      schoolName: _schoolName,
      schoolAddress: _schoolAddress,
      selectedJenjang: _selectedJenjang,
      jenjangOptions: _jenjangOptions,
      onLoadSettings: _loadSettings,
      onSaveSettings: (name, addr, level) async {
        await updateSchoolSettings(
          schoolName: name,
          address: addr,
          jenjang: level,
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Section header — mockup .sec-head pattern.
//   • 32×32 tinted icon frame (10% bg, color-600 icon)
//   • title 13/w800 slate900
//   • subtitle 11/w500 slate500
//   • right-aligned action link with icon (Edit ›, Kelola ›)
// ───────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(icon, color: tint, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // "Edit ›" / "Kelola ›" link — uses a Material InkWell so the
          // touch target stays generous without growing the visual
          // pill. Matches the cobalt link styling from the mockup.
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(actionIcon, size: 14, color: ColorUtils.brandDarkBlue),
                  const SizedBox(width: 4),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorUtils.brandDarkBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Active-year gradient hero card — mockup .ay-hero.
//   • background: linear-gradient(135deg, brandDark, brandCobalt)
//   • topline: green "Saat Ini" pill + transparent semester pill
//   • h3: 22px / w800 / -0.3 / white  ("2025/2026")
//   • semester sub: 12.5 / w500 / white@82%
//   • meta-row (siswa/kelas/guru): preceded by 1px white@20% hairline,
//     each cell has 9.5/w700 white@72% caps label + 16/w800 white value
// ───────────────────────────────────────────────────────────────────────

class _ActiveYearHero extends StatelessWidget {
  final Map<String, dynamic> activeYear;
  final String? fallbackSemesterName;
  final VoidCallback onTap;

  const _ActiveYearHero({
    required this.activeYear,
    required this.fallbackSemesterName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ── Resolve semester label (Title-case for display) ──
    //
    // The AY row's `semester` column still uses Indonesian (`ganjil` /
    // `genap`) per backend convention. The fallback comes from the
    // `/semesters` table, whose `name` was normalized to canonical
    // `odd` / `even` in the follow-up rename. Defensively handle both
    // encodings via [semesterDisplayLabel].
    final activeYearSem = semesterDisplayLabel(
      activeYear['semester']?.toString(),
    );
    final fallbackSem = semesterDisplayLabel(fallbackSemesterName);
    final semesterName =
        activeYearSem ??
        fallbackSem ??
        (fallbackSemesterName?.toString().trim().isNotEmpty == true
            ? fallbackSemesterName!
            : null);

    // ── Period (start_date — end_date) with the same "belum diatur"
    //    guard the Kelola screen uses for legacy nulls.
    final hasStart = (activeYear['start_date'] ?? '').toString().isNotEmpty;
    final hasEnd = (activeYear['end_date'] ?? '').toString().isNotEmpty;
    final startDateStr = hasStart
        ? AppDateUtils.formatDateString(
            activeYear['start_date'],
            format: 'dd MMM yyyy',
          )
        : null;
    final endDateStr = hasEnd
        ? AppDateUtils.formatDateString(
            activeYear['end_date'],
            format: 'dd MMM yyyy',
          )
        : null;
    final periodSubtitle = (startDateStr != null && endDateStr != null)
        ? '$startDateStr — $endDateStr'
        : 'Periode belum diatur';

    // Counts surfaced by the AcademicController.appendCounts() helper.
    final studentCount = '${activeYear['student_count'] ?? 0}';
    final classCount = '${activeYear['class_count'] ?? 0}';
    final teacherCount = '${activeYear['teacher_count'] ?? 0}';

    return Material(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            // Brand admin gradient — same as ColorUtils.brandGradient('admin')
            // but specced verbatim so the topLeft→bottomRight direction
            // matches the mockup's `.ay-hero` exactly. Cannot use the
            // helper directly: it returns a slightly different angle.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ColorUtils.brandDarkBlue, ColorUtils.brandCobalt],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.brandDarkBlue.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top pill row — green "Saat Ini" + transparent semester
              Row(
                children: [
                  const _HeroPill.live(label: 'Saat Ini'),
                  if (semesterName != null) ...[
                    const SizedBox(width: 6),
                    _HeroPill(label: semesterName.toUpperCase()),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Year title — h3 22/w800/-0.3 white
              Text(
                (activeYear['year'] ?? '-').toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              // Period sub — 12.5 / w500 / white@82%
              Text(
                periodSubtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 12),
              // Hairline divider — white @20%
              Container(height: 1, color: Colors.white.withValues(alpha: 0.20)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HeroMeta(label: 'Siswa', value: studentCount),
                  ),
                  Expanded(
                    child: _HeroMeta(label: 'Kelas', value: classCount),
                  ),
                  Expanded(
                    child: _HeroMeta(label: 'Guru', value: teacherCount),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final bool live;

  const _HeroPill({required this.label}) : live = false;
  const _HeroPill.live({required this.label}) : live = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: live
            ? ColorUtils.green600
            : Colors.white.withValues(alpha: 0.20),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ColorUtils.green400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Arsip drill-down tile — single tile-card row pointing at
// KelolaTahunAjaranScreen so the admin can browse past years.
// ───────────────────────────────────────────────────────────────────────

class _ArsipDrillTile extends StatelessWidget {
  final VoidCallback onTap;

  const _ArsipDrillTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate200, width: 0.75),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                ),
                child: Icon(
                  Icons.archive_outlined,
                  color: ColorUtils.slate500,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arsip',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lihat tahun ajaran sebelumnya',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Empty-state card — only shows when there's no active year at all
// (cold-start / fresh school setup).
// ───────────────────────────────────────────────────────────────────────

class _EmptyActiveYearCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyActiveYearCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 40,
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
            'Silakan tambahkan tahun ajaran baru di Kelola.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Buka Kelola'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorUtils.brandDarkBlue,
              side: BorderSide(color: ColorUtils.brandDarkBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
