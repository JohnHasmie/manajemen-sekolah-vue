// Admin Raport hub — Mockup #08 (Phase Final).
//
// Hero with StatusPipelineStrip (4 nodes: Draft → Diperiksa → Terbit →
// Dibagikan) + period pill + Cetak pill, status filter chip strip
// embedded in the gradient (replaces the previous floating search
// bar — search is rare on a class-grouped list, status filtering is
// the actual admin workflow). Body shows TingkatGroupCards filtered
// by the active status. Per-kelas chips long-press toggles bulk
// selection; the sticky BulkActionBar slides up with Cetak + Terbit.
//
// "Rilis berikutnya" stubs from the previous revision are now wired:
//   • Pipeline node tap         → set status filter (or clear if same)
//   • Hero filter button        → status filter sheet
//   • Hero meatball             → refresh menu
//   • Hero "Cetak" pill         → drill into per-class PDF flow
//   • Bulk Cetak                → drill into per-class PDF flow
//   • Bulk Terbit               → real `POST /raports/publish` per class
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_raport_components.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/report_cards/data/admin_raport_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';

/// Status filter keys used both by the pipeline strip and the chip
/// strip. `'all'` means "show everything".
const _statusKeys = ['all', 'draft', 'reviewed', 'published', 'distributed'];

const _statusLabels = {
  'all': 'Semua',
  'draft': 'Draft',
  'reviewed': 'Diperiksa',
  'published': 'Terbit',
  'distributed': 'Dibagikan',
};

class AdminRaportHubScreen extends ConsumerStatefulWidget {
  const AdminRaportHubScreen({super.key});

  @override
  ConsumerState<AdminRaportHubScreen> createState() =>
      _AdminRaportHubScreenState();
}

class _AdminRaportHubScreenState
    extends ConsumerState<AdminRaportHubScreen> {
  AdminRaportPipeline? _data;
  Object? _error;
  bool _loading = true;
  bool _publishing = false;

  /// Active status filter key — one of [_statusKeys]. Drives both the
  /// pipeline strip (active node) and the body filter (which classes
  /// the TingkatGroupCard renders).
  String _statusFilter = 'all';

  // Bulk selection
  final Set<String> _selectedClassIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ref
          .read(adminRaportServiceProvider)
          .fetch()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      AppLogger.debug('raport-hub',
          'pipeline loaded · tingkats=${result.tingkats.length}');
      setState(() {
        _data = result;
        _loading = false;
        _selectedClassIds.clear();
      });
    } on TimeoutException catch (e) {
      AppLogger.error('raport-hub', 'fetch timeout: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Permintaan ke server terlalu lama (>15s). '
            'Cek koneksi backend lalu coba lagi.';
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error('raport-hub', e, st);
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toggleClassSelection(String classId) {
    setState(() {
      if (_selectedClassIds.contains(classId)) {
        _selectedClassIds.remove(classId);
      } else {
        _selectedClassIds.add(classId);
      }
    });
  }

  void _onChipTap(String classId) {
    AppNavigator.push(
      context,
      AdminReportCardScreen(initialClassId: classId),
    );
  }

  // ── Pipeline / status filter ───────────────────────────────────────

  /// Pipeline node tap. If the node matches the active filter we clear
  /// it (so a second tap on the highlighted node releases the filter);
  /// otherwise we apply it.
  void _onPipelineNodeTap(String key) {
    setState(() {
      _statusFilter = (_statusFilter == key) ? 'all' : key;
    });
  }

  /// Pipeline shown in the hero — same counts as the API but with
  /// `active` toggled to match the local filter rather than the
  /// backend's "most-pending" hint.
  List<PipelineNode> _pipelineForRender() {
    final base = _data?.pipeline ?? _placeholderPipeline;
    return base
        .map((n) => PipelineNode(
              key: n.key,
              label: n.label,
              count: n.count,
              active: n.key == _statusFilter,
            ))
        .toList();
  }

  /// Filter the API tingkats by status_label so the body matches the
  /// pipeline node selection. `'all'` returns everything.
  List<TingkatGroup> _filteredTingkats() {
    final p = _data;
    if (p == null) return const [];
    if (_statusFilter == 'all') return p.tingkats;

    final wanted = _statusLabelForKey(_statusFilter).toLowerCase();
    final out = <TingkatGroup>[];
    for (final t in p.tingkats) {
      final keptClasses = t.classes
          .where((c) => c.statusLabel.toLowerCase() == wanted)
          .toList();
      if (keptClasses.isNotEmpty) {
        out.add(TingkatGroup(
          tingkat: t.tingkat,
          classCount: keptClasses.length,
          studentCount: t.studentCount,
          reviewedPct: t.reviewedPct,
          alert: t.alert,
          classes: keptClasses,
        ));
      }
    }
    return out;
  }

  String _statusLabelForKey(String key) =>
      _statusLabels[key] ?? key;

  // ── Sheet entry points ─────────────────────────────────────────────

  void _openStatusFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StatusFilterSheet(
        active: _statusFilter,
        onPick: (key) {
          Navigator.pop(ctx);
          setState(() => _statusFilter = key);
        },
      ),
    );
  }

  void _openMoreMenu() {
    final navy = ColorUtils.getRoleColor('admin');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoreMenuSheet(
        navy: navy,
        onCetak: () {
          Navigator.pop(ctx);
          _openCetakFlow();
        },
        onRefresh: () {
          Navigator.pop(ctx);
          _load();
        },
        onClearFilter: _statusFilter == 'all'
            ? null
            : () {
                Navigator.pop(ctx);
                setState(() => _statusFilter = 'all');
              },
      ),
    );
  }

  /// Drill into the per-class PDF flow. Used by both the hero "Cetak"
  /// pill and the BulkActionBar "Cetak" button. If exactly one class
  /// is selected we deep-link into that one; otherwise we drop the
  /// admin onto the picker.
  void _openCetakFlow() {
    String? id;
    if (_selectedClassIds.length == 1) id = _selectedClassIds.first;
    AppNavigator.push(
      context,
      AdminReportCardScreen(initialClassId: id),
    );
  }

  // ── Bulk publish (real backend call) ───────────────────────────────

  Future<void> _confirmAndBulkPublish() async {
    final p = _data;
    if (p == null || _selectedClassIds.isEmpty) return;

    // Collect display info for the confirm sheet.
    final selectedChips = <KelasMiniChipData>[];
    final tingkatLabels = <String>[];
    var studentCount = 0;
    for (final t in p.tingkats) {
      final matched = t.classes
          .where((c) => _selectedClassIds.contains(c.id))
          .toList();
      if (matched.isNotEmpty) {
        tingkatLabels.add('Tingkat ${t.tingkat}');
        selectedChips.addAll(matched);
        final perClass = t.classCount > 0
            ? (t.studentCount / t.classCount).round()
            : 0;
        studentCount += perClass * matched.length;
      }
    }
    final navy = ColorUtils.getRoleColor('admin');
    final classNames = selectedChips.map((c) => c.label).join(', ');
    final tingkatStr = tingkatLabels.join(', ');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BulkPublishSheet(
        navy: navy,
        classCount: _selectedClassIds.length,
        classNames: classNames,
        tingkatLabel: tingkatStr,
        studentCount: studentCount,
      ),
    );

    if (confirmed != true || !mounted) return;
    await _publishSelectedClasses();
  }

  Future<void> _publishSelectedClasses() async {
    final p = _data;
    if (p == null) return;
    final ay = int.tryParse(p.periodAcademicYearId);
    final sem = int.tryParse(p.periodSemesterId);
    if (ay == null || sem == null) {
      SnackBarUtils.showError(
        context,
        'Periode aktif belum tersedia. Coba muat ulang halaman.',
      );
      return;
    }

    setState(() => _publishing = true);
    final svc = ref.read(adminRaportServiceProvider);
    final ids = List<String>.from(_selectedClassIds);
    var totalPublished = 0;
    var failures = 0;
    for (final classId in ids) {
      try {
        final n = await svc.publishClass(
          classId: classId,
          academicYearId: ay,
          semesterId: sem,
        );
        totalPublished += n;
      } catch (e, st) {
        failures++;
        AppLogger.error('raport-hub', 'publish $classId failed: $e', st);
      }
    }
    if (!mounted) return;

    setState(() {
      _publishing = false;
      _selectedClassIds.clear();
    });
    await _load();
    if (!mounted) return;

    if (failures == 0) {
      SnackBarUtils.showSuccess(
        context,
        '$totalPublished raport diterbitkan dari ${ids.length} kelas.',
      );
    } else if (failures < ids.length) {
      SnackBarUtils.showInfo(
        context,
        '$totalPublished raport diterbitkan · '
        '$failures kelas gagal — coba lagi.',
      );
    } else {
      SnackBarUtils.showError(
        context,
        'Gagal menerbitkan ${ids.length} kelas. Cek koneksi & coba lagi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final hasBulk = _selectedClassIds.isNotEmpty;

    final filterApplied = _statusFilter != 'all';
    final periodLabel = _data?.periodLabel ?? 'Periode aktif';
    final statusValue = filterApplied
        ? _statusLabelForKey(_statusFilter)
        : null;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Stack(
        children: [
          // Shared scaffold — Stack pattern with `body Positioned at
          // top: headerH - overlap` so the kpiCard (RaportPipelineCard)
          // visually overlaps the gradient header by 45dp. Same widget
          // that drives parent Tagihan / Nilai overlap.
          BrandPageLayout(
            role: 'admin',
            onRefresh: _load,
            header: BrandPageHeader(
              role: 'admin',
              subtitle: 'Akademik · Penilaian',
              title: 'Raport',
              isRealtimeFresh: !_loading && _error == null,
              // RULE: when paired with a `kpiCard`, the header MUST
              // reserve `BrandPageLayout.kpiOverlapHeight` of gradient
              // below its chip strip so the KPI's overlap zone tucks
              // into empty navy instead of covering the chips.
              kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
              actionIcons: [
                BrandHeaderIconButton(
                  icon: filterApplied
                      ? Icons.filter_alt_rounded
                      : Icons.tune_rounded,
                  onTap: _openStatusFilterSheet,
                  badgeCount: filterApplied ? 1 : null,
                  badgeBorderColor: navy,
                ),
                BrandHeaderIconButton(
                  icon: Icons.more_vert_rounded,
                  onTap: _openMoreMenu,
                ),
              ],
              // Filter chips follow the parent role's pattern
              // (parent_billing_screen): each chip's `value` reflects
              // its current active state. Periode is read-only on
              // admin Raport (the period is fixed by backend), so its
              // chip has `showChevron: false` and no onTap. Status
              // opens the same filter sheet the tune icon does — both
              // entry points hit the same compound sheet.
              bottomSlot: BrandFilterChipStrip(
                chips: [
                  BrandFilterChip(
                    label: 'Periode',
                    value: periodLabel,
                    onTap: null,
                    showChevron: false,
                    width: 172,
                  ),
                  BrandFilterChip(
                    label: 'Status',
                    value: statusValue,
                    onTap: _openStatusFilterSheet,
                  ),
                ],
              ),
            ),
            kpiCard: RaportPipelineCard(
              nodes: _pipelineForRender(),
              onNodeTap: _onPipelineNodeTap,
              caption: _data == null
                  ? null
                  : '${_data!.totalClasses} kelas · $periodLabel',
            ),
            bottomPadding: (hasBulk ? 96 : 0) +
                AppSpacing.xl +
                MediaQuery.of(context).padding.bottom,
            bodyChildren: [
              // Section header — the active filter state lives on
              // the Status chip in the header, not as a separate
              // pill here, so this row is just a kicker label.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'PER TINGKAT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (_data != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${_data!.totalClasses} KELAS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate300,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildBody(navy),
            ],
          ),
          // Bulk action bar — sticks to the bottom of the screen so it
          // stays visible while the admin scrolls through tingkats.
          if (hasBulk)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: _BulkActionBar(
                count: _selectedClassIds.length,
                selectedLabels: _buildSelectedLabels(),
                publishing: _publishing,
                onCetak: _openCetakFlow,
                onTerbit: _confirmAndBulkPublish,
                onClear: () => setState(_selectedClassIds.clear),
              ),
            ),
        ],
      ),
    );
  }

  String _buildSelectedLabels() {
    final p = _data;
    if (p == null) return '';
    final labels = <String>[];
    for (final t in p.tingkats) {
      final matched = t.classes
          .where((c) => _selectedClassIds.contains(c.id))
          .map((c) => c.label);
      if (matched.isNotEmpty) {
        labels.add('Tingkat ${t.tingkat} · ${matched.join(', ')}');
      }
    }
    return labels.join(' | ');
  }

  Widget _buildBody(Color navy) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: _RaportInfoCard(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat pipeline raport',
          message: _error.toString(),
          accentColor: const Color(0xFFDC2626),
          onRetry: _load,
        ),
      );
    }
    final tingkats = _filteredTingkats();
    if (tingkats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: _RaportInfoCard(
          icon: _statusFilter == 'all'
              ? Icons.inbox_rounded
              : Icons.filter_alt_off_rounded,
          title: _statusFilter == 'all'
              ? 'Belum ada data raport'
              : 'Tidak ada kelas pada status "${_statusLabelForKey(_statusFilter)}"',
          message: _statusFilter == 'all'
              ? 'Pipeline ini akan terisi setelah guru '
                  'mengajukan nilai akhir.'
              : 'Coba pilih status lain atau tap "Bersihkan filter".',
          accentColor: navy,
          actionLabel: _statusFilter == 'all'
              ? 'Muat ulang'
              : 'Bersihkan filter',
          onRetry: _statusFilter == 'all'
              ? _load
              : () => setState(() => _statusFilter = 'all'),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tingkats.length; i++) ...[
          TingkatGroupCard(
            tingkat: tingkats[i].tingkat,
            classCount: tingkats[i].classCount,
            studentCount: tingkats[i].studentCount,
            reviewedPct: tingkats[i].reviewedPct,
            alert: tingkats[i].alert,
            classes: tingkats[i].classes,
            initiallyExpanded: i == 0,
            selectedClassIds: _selectedClassIds,
            onChipTap: _onChipTap,
            onChipLongPress: _toggleClassSelection,
          ),
          if (i < tingkats.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Placeholder pipeline for loading state
// ═════════════════════════════════════════════════════════════════════

const _placeholderPipeline = [
  PipelineNode(key: 'draft', label: 'Draft', count: 0, active: false),
  PipelineNode(
      key: 'reviewed', label: 'Diperiksa', count: 0, active: true),
  PipelineNode(
      key: 'published', label: 'Terbit', count: 0, active: false),
  PipelineNode(
      key: 'distributed',
      label: 'Dibagikan',
      count: 0,
      active: false),
];

// ═════════════════════════════════════════════════════════════════════
// Hero retired + body-pill retired — see BrandPageHeader call in
// `build` above. Active filter state is now reflected ON the
// `BrandFilterChip` in the header bottom slot (matches parent role
// pattern), so no separate body-row pill is needed.
// ═════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════
// Bulk action bar (sticky bottom)
// ═════════════════════════════════════════════════════════════════════

class _BulkActionBar extends StatelessWidget {
  final int count;
  final String selectedLabels;
  final bool publishing;
  final VoidCallback onCetak;
  final VoidCallback onTerbit;
  final VoidCallback onClear;

  const _BulkActionBar({
    required this.count,
    required this.selectedLabels,
    required this.publishing,
    required this.onCetak,
    required this.onTerbit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count kelas dipilih',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedLabels,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BarButton(
            label: 'Cetak',
            filled: false,
            onTap: publishing ? null : onCetak,
          ),
          const SizedBox(width: 6),
          _BarButton(
            label: publishing ? 'Menerbitkan…' : 'Terbit',
            filled: true,
            loading: publishing,
            onTap: publishing ? null : onTerbit,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _BarButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: filled
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        filled ? navy : Colors.white,
                      ),
                    ),
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: filled ? navy : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Status filter sheet
// ═════════════════════════════════════════════════════════════════════

class _StatusFilterSheet extends StatelessWidget {
  final String active;
  final ValueChanged<String> onPick;

  const _StatusFilterSheet({
    required this.active,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, color: navy, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter status raport',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Pilih satu status — body daftar tingkat akan disaring otomatis.',
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            for (final key in _statusKeys)
              ListTile(
                onTap: () => onPick(key),
                leading: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconForStatus(key),
                      color: navy, size: 16),
                ),
                title: Text(
                  _statusLabels[key] ?? key,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                trailing: key == active
                    ? Icon(Icons.check_circle_rounded, color: navy)
                    : Icon(Icons.chevron_right_rounded,
                        color: ColorUtils.slate300),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconForStatus(String key) {
    switch (key) {
      case 'draft':
        return Icons.edit_note_rounded;
      case 'reviewed':
        return Icons.task_alt_rounded;
      case 'published':
        return Icons.send_rounded;
      case 'distributed':
        return Icons.share_rounded;
      default:
        return Icons.all_inclusive_rounded;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════
// More-menu sheet
// ═════════════════════════════════════════════════════════════════════

class _MoreMenuSheet extends StatelessWidget {
  final Color navy;
  final VoidCallback onRefresh;
  final VoidCallback onCetak;
  final VoidCallback? onClearFilter;

  const _MoreMenuSheet({
    required this.navy,
    required this.onRefresh,
    required this.onCetak,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.print_rounded, color: navy, size: 16),
              ),
              title: const Text(
                'Cetak raport',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: const Text(
                'Buka alur cetak per kelas',
                style: TextStyle(fontSize: 10.5),
              ),
              onTap: onCetak,
            ),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.refresh_rounded, color: navy, size: 16),
              ),
              title: const Text(
                'Muat ulang data',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: const Text(
                'Ambil pipeline + kelas terbaru dari server',
                style: TextStyle(fontSize: 10.5),
              ),
              onTap: onRefresh,
            ),
            if (onClearFilter != null)
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.filter_alt_off_rounded,
                      color: navy, size: 16),
                ),
                title: const Text(
                  'Bersihkan filter',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: const Text(
                  'Tampilkan semua status',
                  style: TextStyle(fontSize: 10.5),
                ),
                onTap: onClearFilter,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Bulk publish confirm sheet — returns true on confirm, null on cancel
// ═════════════════════════════════════════════════════════════════════

class _BulkPublishSheet extends StatefulWidget {
  final Color navy;
  final int classCount;
  final String classNames;
  final String tingkatLabel;
  final int studentCount;

  const _BulkPublishSheet({
    required this.navy,
    required this.classCount,
    required this.classNames,
    required this.tingkatLabel,
    required this.studentCount,
  });

  @override
  State<_BulkPublishSheet> createState() => _BulkPublishSheetState();
}

class _BulkPublishSheetState extends State<_BulkPublishSheet> {
  bool _sendNotification = true;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorUtils.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                widget.navy,
                widget.navy.withValues(alpha: 0.85),
              ]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TERBITKAN RAPOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.classCount} kelas siap terbit',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.tingkatLabel} · ${widget.classNames} · '
                  '${widget.studentCount} siswa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAMPAK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _ImpactCard(
                  title: 'Notifikasi otomatis',
                  subtitle:
                      '${widget.studentCount} wali murid akan menerima push',
                  color: ColorUtils.slate100,
                  textColor: ColorUtils.slate900,
                ),
                const SizedBox(height: 8),
                _ImpactCard(
                  title: 'Akses parent role',
                  subtitle: 'Rapor lengkap + ringkasan terbuka',
                  color: ColorUtils.slate100,
                  textColor: ColorUtils.slate900,
                ),
                const SizedBox(height: 8),
                _ImpactCard(
                  title: 'Tindakan tidak dapat dibatalkan',
                  subtitle:
                      'Ubah ke Diperiksa harus manual per kelas',
                  color: const Color(0xFFFFFBEB),
                  textColor: const Color(0xFF92400E),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kirim notifikasi push',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Wali murid akan menerima alert',
                              style: TextStyle(
                                fontSize: 10,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _sendNotification,
                        onChanged: (v) =>
                            setState(() => _sendNotification = v),
                        activeTrackColor: widget.navy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottom),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: ColorUtils.slate300),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.navy,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Terbitkan ${widget.classCount} kelas',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
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

class _ImpactCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;

  const _ImpactCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Info card (error / empty)
// ═════════════════════════════════════════════════════════════════════

class _RaportInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;
  final String actionLabel;
  final VoidCallback onRetry;

  const _RaportInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
    required this.onRetry,
    this.actionLabel = 'Muat ulang',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
