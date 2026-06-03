// Parent-side Rekomendasi screen — Frames A · B · G of
// `_design/parent_rekomendasi_redesign.html`.
//
// Three modes share this single screen:
//
//   • **Frame A · Multi-child hub** — when the parent has more than
//     one child and no child filter is locked in. The header shows the
//     child-selector chip row (`Semua` first), the body shows one
//     `_ChildSummaryCard` per child with a 3-stat grid + gradient
//     progress + dual CTA.
//   • **Frame B · Per-child rec list** — once a child is selected (or
//     the parent only has one child), the body switches to the hero
//     card + status filter chips + rec card list. Tapping a rec card
//     pushes `ParentRecommendationDetailScreen` (Frame C).
//   • **Frame G · Empty state** — `TeacherAsyncView` already owns the
//     loading + error + empty + content state machine; we just feed
//     it the right `emptyTitle` + `emptySubtitle` per mode.
//
// Brand colour stays **azure** for the parent role (per
// `ColorUtils.brandGradient('parent')`); violet is reserved for the
// AI-reasoning tile inside the detail screen and the "Dari Wali Kelas"
// glyph. Filter sheet (Frame F), Reply sheet (Frame D), and Tandai
// Selesai sheet (Frame E) live in sibling files and are opened from
// here / from the detail screen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/parent_recommendation_detail_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_card.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_child_summary_card.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_filter_sheet.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_kpi_overlap.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_status_chips.dart';

/// Sentinel id used by the "Semua" child chip so the multi-child hub
/// can branch off `_selectedChildId == _kAllChildren`.
const String _kAllChildren = '__all__';

class ParentRecommendationScreen extends ConsumerStatefulWidget {
  /// Authenticated parent's user id. Passed from the parent dashboard.
  final String parentUserId;

  /// Optional student filter — when the parent's deep-link or
  /// dashboard pre-selects one child the screen jumps straight into
  /// per-child mode (Frame B).
  final String? studentId;

  /// Optional deep-link target. When set the matching card scrolls
  /// into view after first paint.
  final String? targetRecommendationId;

  const ParentRecommendationScreen({
    super.key,
    required this.parentUserId,
    this.studentId,
    this.targetRecommendationId,
  });

  @override
  ConsumerState<ParentRecommendationScreen> createState() =>
      _ParentRecommendationScreenState();
}

class _ParentRecommendationScreenState
    extends ConsumerState<ParentRecommendationScreen> {
  bool _loading = true;
  String? _error;

  /// Flat inbox rows from `/recommendations/parent-inbox` — each row
  /// is `{ recipient_id, recommendation, sent_at, read_at, ... }`.
  List<Map<String, dynamic>> _items = [];

  /// Per-child summary rows from `/recommendations/parent-summary`.
  /// Used by Frame A when the parent has multiple children.
  List<Map<String, dynamic>> _children = [];

  /// Currently selected child id. Defaults to `_kAllChildren` for
  /// multi-child parents; gets pre-set to [widget.studentId] when the
  /// screen is opened from a deep link.
  late String _selectedChildId;

  ParentRecFilter _filter = const ParentRecFilter();

  /// Per-rec scroll keys so the deep link can `Scrollable.ensureVisible`.
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.studentId ?? _kAllChildren;
    _load();
  }

  Future<void> _load({bool useCache = true}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final svc = getIt<ApiRecommendationService>();

    // Pull-to-refresh / post-mutation reloads invalidate the cache so
    // the next request actually hits the network. Cached reads
    // resolve in < 1 frame because everything's already in
    // SharedPreferences.
    if (!useCache) {
      await svc.invalidateParentInboxCache(parentUserId: widget.parentUserId);
    }

    // Each call is wrapped in its own try/catch so a transient failure
    // on EITHER endpoint never sinks the whole screen — if the inbox
    // 500s but the summary succeeds we still render the multi-child
    // hub from the summary, and vice versa. Only when *both* fail do
    // we surface the error plaque.
    List<Map<String, dynamic>> inbox = [];
    Object? inboxErr;
    try {
      final raw = await svc.getParentInbox(
        parentUserId: widget.parentUserId,
        // We don't pass studentId on the wire when the user is on the
        // hub — we want all rows so the hub can render every child.
        studentId: null,
        useCache: useCache,
      );
      inbox = raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e) {
      inboxErr = e;
    }

    Map<String, dynamic> summary = const {'children': [], 'totals': {}};
    Object? summaryErr;
    try {
      summary = await svc.getParentSummary(
        parentUserId: widget.parentUserId,
        useCache: useCache,
      );
    } catch (e) {
      summaryErr = e;
    }

    if (!mounted) return;

    if (inboxErr != null && summaryErr != null) {
      // Both failed → show the error plaque. Friendly message instead
      // of dumping the Dio stack trace at the parent.
      //
      // The `!` is sound here — we just type-checked both `Object?`s
      // for non-null in the same condition, but Dart's flow analysis
      // doesn't promote independent locals across `&&`, so we have to
      // assert it ourselves.
      setState(() {
        _error = _friendlyErrorMessage(inboxErr!);
        _loading = false;
      });
      return;
    }

    // Precompute everything that goes into the next setState BEFORE
    // we call setState — frame jank otherwise when the inbox has 50+
    // items (filter / group / count would block the rebuild).
    final children = (summary['children'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    // Fallback: derive children from inbox when the summary endpoint
    // isn't available yet OR returned an empty list. Each unique
    // student_id becomes one row.
    final derivedChildren = children.isNotEmpty
        ? children
        : _deriveChildrenFromInbox(inbox);

    // Resolve the candidate selection before setState so the build()
    // phase doesn't have to re-check it.
    String nextSelected = _selectedChildId;
    if (nextSelected != _kAllChildren &&
        !derivedChildren.any((c) => c['student_id'] == nextSelected)) {
      nextSelected = _kAllChildren;
    }
    if (derivedChildren.length == 1) {
      nextSelected =
          derivedChildren.first['student_id']?.toString() ?? _kAllChildren;
    }

    setState(() {
      _items = inbox;
      _children = derivedChildren;
      _selectedChildId = nextSelected;
      _loading = false;
    });
    // Fire-and-forget — never await read-receipts during render flow.
    unawaited(_autoMarkRead());
    _scrollToTarget();
  }

  /// Replace the verbose Dio dump with a short Indonesian message that
  /// fits the AppErrorState plaque without overflowing.
  String _friendlyErrorMessage(Object e) {
    final raw = e.toString();
    if (raw.contains('500')) {
      return 'Server sedang bermasalah. Silakan coba lagi dalam beberapa saat.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection') ||
        raw.contains('timeout')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }
    if (raw.contains('401') || raw.contains('403')) {
      return 'Sesi Anda telah berakhir. Silakan masuk ulang.';
    }
    return 'Gagal memuat rekomendasi. Tarik ke bawah untuk mencoba lagi.';
  }

  Future<void> _autoMarkRead() async {
    for (final row in _items) {
      if (row['read_at'] != null) continue;
      final rec = row['recommendation'];
      if (rec is! Map) continue;
      final recId = rec['id']?.toString();
      if (recId == null || recId.isEmpty) continue;
      try {
        await getIt<ApiRecommendationService>().markRecommendationRead(
          recommendationId: recId,
          parentUserId: widget.parentUserId,
        );
      } catch (_) {
        /* swallowed — read receipts are best-effort */
      }
    }
  }

  void _scrollToTarget() {
    final target = widget.targetRecommendationId;
    if (target == null || target.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[target];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 320),
          alignment: 0.1,
        );
      }
    });
  }

  // ── Derived view-model helpers ──

  bool get _isMultiChildHub =>
      _children.length > 1 && _selectedChildId == _kAllChildren;

  /// Items filtered by selected child + filter sheet selections.
  List<Map<String, dynamic>> get _filteredItems {
    final now = DateTime.now();
    final cutoff = switch (_filter.period) {
      ParentRecPeriod.last7 => now.subtract(const Duration(days: 7)),
      ParentRecPeriod.last30 => now.subtract(const Duration(days: 30)),
      ParentRecPeriod.all => null,
    };
    return _items.where((row) {
      final rec = row['recommendation'];
      if (rec is! Map) return false;
      // child filter
      if (_selectedChildId != _kAllChildren &&
          rec['student_id']?.toString() != _selectedChildId) {
        return false;
      }
      // status filter
      switch (_filter.status) {
        case ParentRecStatus.all:
          break;
        case ParentRecStatus.unread:
          if (row['read_at'] != null) return false;
          break;
        case ParentRecStatus.active:
          final completed =
              row['parent_completed_at'] != null ||
              rec['status']?.toString().toLowerCase() == 'completed';
          if (completed) return false;
          break;
        case ParentRecStatus.completed:
          final completed =
              row['parent_completed_at'] != null ||
              rec['status']?.toString().toLowerCase() == 'completed';
          if (!completed) return false;
          break;
      }
      // priority filter
      if (_filter.priority != ParentRecPriority.all) {
        final p = rec['priority']?.toString().toLowerCase();
        final wanted = switch (_filter.priority) {
          ParentRecPriority.high => 'high',
          ParentRecPriority.medium => 'medium',
          ParentRecPriority.low => 'low',
          _ => null,
        };
        if (p != wanted) return false;
      }
      // subjects filter
      if (_filter.subjects.isNotEmpty) {
        final s =
            rec['subject_school'] ?? rec['subjectSchool'] ?? rec['subject'];
        final name =
            (s is Map ? s['name']?.toString() : null) ??
            rec['subject_name']?.toString();
        if (name == null || !_filter.subjects.contains(name)) return false;
      }
      // period filter
      if (cutoff != null) {
        final sentAt = row['sent_at'];
        if (sentAt == null) return false;
        try {
          final dt = DateTime.parse(sentAt.toString());
          if (dt.isBefore(cutoff)) return false;
        } catch (_) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// KPI counters scoped to the *currently visible* slice (so the
  /// numbers under the gradient match what the user sees in the list
  /// below).
  ({int unread, int active, int completed}) get _kpi {
    var u = 0, a = 0, c = 0;
    for (final row in _filteredItems) {
      final rec = row['recommendation'];
      if (rec is! Map) continue;
      final completed =
          row['parent_completed_at'] != null ||
          rec['status']?.toString().toLowerCase() == 'completed';
      if (completed) {
        c++;
      } else {
        a++;
      }
      if (row['read_at'] == null) u++;
    }
    return (unread: u, active: a, completed: c);
  }

  /// Distinct mata pelajaran names visible to the parent — feeds the
  /// filter sheet so we never offer a chip for a mapel they don't
  /// have.
  List<String> get _availableSubjects {
    final seen = <String, String>{};
    for (final row in _items) {
      final rec = row['recommendation'];
      if (rec is! Map) continue;
      final s = rec['subject_school'] ?? rec['subjectSchool'] ?? rec['subject'];
      final name =
          (s is Map ? s['name']?.toString() : null) ??
          rec['subject_name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        seen[name.toLowerCase()] = name;
      }
    }
    final list = seen.values.toList()..sort();
    return list;
  }

  // ── Action handlers ──

  Future<void> _openFilter() async {
    final updated = await showParentRecommendationFilterSheet(
      context: context,
      current: _filter,
      availableSubjects: _availableSubjects,
    );
    if (updated == null) return;
    setState(() => _filter = updated);
  }

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final changed = await ParentRecommendationDetailScreen.show(
      context: context,
      parentUserId: widget.parentUserId,
      inboxRow: row,
    );
    if (changed == true && mounted) {
      _load(useCache: false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final azure = ColorUtils.brandAzure;
    final kpi = _kpi;

    final selectedChild = _children.firstWhere(
      (c) => c['student_id']?.toString() == _selectedChildId,
      orElse: () => const <String, dynamic>{},
    );
    final selectedName = selectedChild['student_name']?.toString();
    final selectedKlass = selectedChild['class_name']?.toString();

    final headerSubtitle = _isMultiChildHub
        ? 'Wali · Anak Saya'
        : selectedName == null
        ? 'Wali · Anak'
        : '${selectedName.split(' ').first} · ${selectedKlass ?? 'Anak'}';

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'wali',
            subtitle: headerSubtitle,
            title: 'Rekomendasi Belajar',
            kpiOverlayHeight: 72,
            onBackPressed: () => AppNavigator.pop(context),
            actionIcons: [
              BrandHeaderIconButton(
                icon: Icons.tune_rounded,
                onTap: _openFilter,
                badgeCount: _filter.activeCount > 0
                    ? _filter.activeCount
                    : null,
              ),
            ],
            childSelector: _children.length > 1
                ? ChildSelectorChipRow(
                    children: [
                      ChildSummary(
                        id: _kAllChildren,
                        shortName: 'Semua',
                        klass: '${_children.length} anak',
                        avatarInitials: '◎',
                      ),
                      for (final c in _children)
                        ChildSummary(
                          id: c['student_id']?.toString() ?? '',
                          shortName: _firstWord(c['student_name']) ?? '-',
                          klass: c['class_name']?.toString() ?? '-',
                        ),
                    ],
                    selectedChildId: _selectedChildId,
                    onSelected: (id) => setState(() => _selectedChildId = id),
                    accentColor: azure,
                  )
                : null,
          ),
          // KPI overlap strip — same Transform-translate pattern the
          // existing screen used so we don't fight `BrandPageLayout`'s
          // assumptions about its KPI slot.
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ParentRecKpiOverlap(
                unread: kpi.unread,
                active: kpi.active,
                completed: kpi.completed,
                azure: azure,
              ),
            ),
          ),
          Expanded(
            child: TeacherAsyncView(
              isLoading: _loading,
              errorMessage: _error,
              isEmpty: _isMultiChildHub
                  ? _children.isEmpty
                  : _filteredItems.isEmpty,
              onRefresh: () => _load(useCache: false),
              role: 'wali',
              emptyTitle: _isMultiChildHub
                  ? 'Belum ada rekomendasi'
                  : 'Belum ada rekomendasi untuk anak ini',
              emptySubtitle: _isMultiChildHub
                  ? 'Wali kelas akan mengirim rekomendasi belajar di sini.'
                  : 'Coba reset filter atau periksa lagi nanti.',
              emptyIcon: Icons.chat_bubble_outline_rounded,
              childBuilder: () => AppRefreshIndicator(
                onRefresh: () => _load(useCache: false),
                child: _isMultiChildHub
                    ? _buildHubBody(azure)
                    : _buildListBody(azure),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Frame A — multi-child hub. List of `_ChildSummaryCard` rows.
  Widget _buildHubBody(Color azure) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _children.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            child: Row(
              children: [
                Text(
                  'ANAK SAYA · ${_children.length} ANAK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openFilter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: azure,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final child = _children[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ParentRecChildSummaryCard(
            data: child,
            azure: azure,
            onTap: () => setState(
              () => _selectedChildId =
                  child['student_id']?.toString() ?? _kAllChildren,
            ),
          ),
        );
      },
    );
  }

  /// Frame B — per-child list. Hero card + status filter chips + rec
  /// cards.
  Widget _buildListBody(Color azure) {
    final items = _filteredItems;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildPerChildHero(azure);
        }
        if (index == 1) {
          return _buildStatusChipStrip(azure);
        }
        final row = items[index - 2];
        final rec = row['recommendation'];
        if (rec is! Map) return const SizedBox.shrink();
        final recId = rec['id']?.toString() ?? '$index';
        final key = _cardKeys.putIfAbsent(recId, GlobalKey.new);
        return Padding(
          key: key,
          padding: const EdgeInsets.only(top: 10),
          child: ParentRecommendationCard(
            row: row,
            azure: azure,
            onTap: () => _openDetail(row),
          ),
        );
      },
    );
  }

  Widget _buildPerChildHero(Color azure) {
    final selected = _children.firstWhere(
      (c) => c['student_id']?.toString() == _selectedChildId,
      orElse: () => const <String, dynamic>{},
    );
    final name = selected['student_name']?.toString() ?? 'Anak';
    final klass = selected['class_name']?.toString() ?? '-';
    final total = (selected['total_count'] as num?)?.toInt() ?? _items.length;
    final unread = (selected['unread_count'] as num?)?.toInt() ?? _kpi.unread;
    final highPri = (selected['high_priority_count'] as num?)?.toInt() ?? 0;
    final completed =
        (selected['completed_count'] as num?)?.toInt() ?? _kpi.completed;

    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: azure.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    parentRecInitials(name),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: azure,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: '$klass · '),
                            TextSpan(
                              text: '$total rekomendasi',
                              style: TextStyle(
                                color: azure,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: azure.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: azure.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$unread',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: azure,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'BARU',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: azure,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (unread > 0 || highPri > 0 || completed > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (unread > 0)
                    ParentRecStatusPill(
                      label: '$unread BELUM DIBACA',
                      color: azure,
                    ),
                  if (highPri > 0)
                    ParentRecStatusPill(
                      label: '$highPri PRIORITAS TINGGI',
                      color: ColorUtils.warning600,
                    ),
                  if (completed > 0)
                    ParentRecStatusPill(
                      label: '$completed SELESAI',
                      color: ColorUtils.success600,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChipStrip(Color azure) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in _statusChipEntries())
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ParentRecStatusFilterChip(
                  label: entry.label,
                  count: entry.count,
                  active: _filter.status == entry.value,
                  azure: azure,
                  onTap: () => setState(
                    () => _filter = _filter.copyWith(status: entry.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<({ParentRecStatus value, String label, int count})>
  _statusChipEntries() {
    final all = _items.where((row) {
      final rec = row['recommendation'];
      return rec is Map &&
          (_selectedChildId == _kAllChildren ||
              rec['student_id']?.toString() == _selectedChildId);
    }).toList();
    final unread = all.where((r) => r['read_at'] == null).length;
    final active = all.where((row) {
      final rec = row['recommendation'];
      final completed =
          row['parent_completed_at'] != null ||
          (rec is Map &&
              rec['status']?.toString().toLowerCase() == 'completed');
      return !completed;
    }).length;
    final completed = all.length - active;
    return [
      (value: ParentRecStatus.all, label: 'Semua', count: all.length),
      (value: ParentRecStatus.unread, label: 'Belum Dibaca', count: unread),
      (value: ParentRecStatus.active, label: 'Aktif', count: active),
      (value: ParentRecStatus.completed, label: 'Selesai', count: completed),
    ];
  }

  // ── Helpers ──

  static String? _firstWord(dynamic raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s.split(RegExp(r'\s+')).first;
  }

  static List<Map<String, dynamic>> _deriveChildrenFromInbox(
    List<Map<String, dynamic>> inbox,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in inbox) {
      final rec = row['recommendation'];
      if (rec is! Map) continue;
      final sid = rec['student_id']?.toString();
      if (sid == null || sid.isEmpty) continue;
      final student = rec['student'];
      final klass = rec['class_'] ?? rec['class'];
      final entry = byId.putIfAbsent(sid, () {
        return <String, dynamic>{
          'student_id': sid,
          'student_name':
              (student is Map ? student['name']?.toString() : null) ?? 'Siswa',
          'class_name':
              (klass is Map ? klass['name']?.toString() : null) ?? '-',
          'total_count': 0,
          'unread_count': 0,
          'completed_count': 0,
          'high_priority_count': 0,
        };
      });
      entry['total_count'] = (entry['total_count'] as int) + 1;
      if (row['read_at'] == null) {
        entry['unread_count'] = (entry['unread_count'] as int) + 1;
      }
      final completed =
          row['parent_completed_at'] != null ||
          rec['status']?.toString().toLowerCase() == 'completed';
      if (completed) {
        entry['completed_count'] = (entry['completed_count'] as int) + 1;
      }
      if (rec['priority']?.toString().toLowerCase() == 'high') {
        entry['high_priority_count'] =
            (entry['high_priority_count'] as int) + 1;
      }
    }
    return byId.values.toList();
  }
}
