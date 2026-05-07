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
import 'package:manajemensekolah/features/report_cards/presentation/widgets/admin_raport_hub_widgets.dart';

class AdminRaportHubScreen extends ConsumerStatefulWidget {
  const AdminRaportHubScreen({super.key});

  @override
  ConsumerState<AdminRaportHubScreen> createState() =>
      _AdminRaportHubScreenState();
}

class _AdminRaportHubScreenState extends ConsumerState<AdminRaportHubScreen> {
  AdminRaportPipeline? _data;
  Object? _error;
  bool _loading = true;
  bool _publishing = false;

  /// Active status filter key — one of [adminRaportStatusKeys]. Drives both the
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
      AppLogger.debug(
        'raport-hub',
        'pipeline loaded · tingkats=${result.tingkats.length}',
      );
      setState(() {
        _data = result;
        _loading = false;
        _selectedClassIds.clear();
      });
    } on TimeoutException catch (e) {
      AppLogger.error('raport-hub', 'fetch timeout: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Permintaan ke server terlalu lama (>15s). '
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
    AppNavigator.push(context, AdminReportCardScreen(initialClassId: classId));
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
        .map(
          (n) => PipelineNode(
            key: n.key,
            label: n.label,
            count: n.count,
            active: n.key == _statusFilter,
          ),
        )
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
        out.add(
          TingkatGroup(
            tingkat: t.tingkat,
            classCount: keptClasses.length,
            studentCount: t.studentCount,
            reviewedPct: t.reviewedPct,
            alert: t.alert,
            classes: keptClasses,
          ),
        );
      }
    }
    return out;
  }

  String _statusLabelForKey(String key) => adminRaportStatusLabels[key] ?? key;

  // ── Sheet entry points ─────────────────────────────────────────────

  void _openStatusFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminRaportStatusFilterSheet(
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
      builder: (ctx) => AdminRaportMoreMenuSheet(
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
    AppNavigator.push(context, AdminReportCardScreen(initialClassId: id));
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
      builder: (ctx) => AdminRaportBulkPublishSheet(
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
            bottomPadding:
                (hasBulk ? 96 : 0) +
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
              child: AdminRaportBulkActionBar(
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
        child: AdminRaportInfoCard(
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
        child: AdminRaportInfoCard(
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
          if (i < tingkats.length - 1) const SizedBox(height: AppSpacing.sm),
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
  PipelineNode(key: 'reviewed', label: 'Diperiksa', count: 0, active: true),
  PipelineNode(key: 'published', label: 'Terbit', count: 0, active: false),
  PipelineNode(key: 'distributed', label: 'Dibagikan', count: 0, active: false),
];
