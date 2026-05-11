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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/parent_recommendation_detail_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_filter_sheet.dart';

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
      );
      inbox = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      inboxErr = e;
    }

    Map<String, dynamic> summary = const {'children': [], 'totals': {}};
    Object? summaryErr;
    try {
      summary = await svc.getParentSummary(parentUserId: widget.parentUserId);
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

    final children = (summary['children'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    // Fallback: derive children from inbox when the summary endpoint
    // isn't available yet OR returned an empty list. Each unique
    // student_id becomes one row.
    final derivedChildren = children.isNotEmpty
        ? children
        : _deriveChildrenFromInbox(inbox);

    setState(() {
      _items = inbox;
      _children = derivedChildren;
      _loading = false;
      // If a deep-linked studentId was provided but it's not actually
      // one of the parent's children, fall back to "Semua" so we
      // don't show an empty list.
      if (_selectedChildId != _kAllChildren &&
          !derivedChildren.any((c) => c['student_id'] == _selectedChildId)) {
        _selectedChildId = _kAllChildren;
      }
      // If the parent only has one child, lock onto it so they skip
      // straight to Frame B without a meaningless chip row.
      if (derivedChildren.length == 1) {
        _selectedChildId =
            derivedChildren.first['student_id']?.toString() ?? _kAllChildren;
      }
    });
    _autoMarkRead();
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
            (rec['subject_school'] ?? rec['subjectSchool'] ?? rec['subject']);
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
              child: _KpiOverlap(
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
          child: _ChildSummaryCard(
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
          child: _ParentRecommendationCard(
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
                    _initials(name),
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
                    _StatusPill(label: '$unread BELUM DIBACA', color: azure),
                  if (highPri > 0)
                    _StatusPill(
                      label: '$highPri PRIORITAS TINGGI',
                      color: ColorUtils.warning600,
                    ),
                  if (completed > 0)
                    _StatusPill(
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
                child: _StatusFilterChip(
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

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
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

// ─── KPI overlap strip ─────────────────────────────────────────────

class _KpiOverlap extends StatelessWidget {
  final int unread;
  final int active;
  final int completed;
  final Color azure;

  const _KpiOverlap({
    required this.unread,
    required this.active,
    required this.completed,
    required this.azure,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _KpiCell(
              value: '$unread',
              label: 'BELUM DIBACA',
              color: azure,
            ),
          ),
          Container(width: 1, height: 28, color: ColorUtils.slate100),
          Expanded(
            child: _KpiCell(
              value: '$active',
              label: 'AKTIF',
              color: ColorUtils.warning600,
            ),
          ),
          Container(width: 1, height: 28, color: ColorUtils.slate100),
          Expanded(
            child: _KpiCell(
              value: '$completed',
              label: 'SELESAI',
              color: ColorUtils.success600,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _KpiCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─── Frame A child summary card ────────────────────────────────────

class _ChildSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color azure;
  final VoidCallback onTap;

  const _ChildSummaryCard({
    required this.data,
    required this.azure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['student_name']?.toString() ?? 'Siswa';
    final klass = data['class_name']?.toString() ?? '-';
    final total = (data['total_count'] as num?)?.toInt() ?? 0;
    final unread = (data['unread_count'] as num?)?.toInt() ?? 0;
    final completed = (data['completed_count'] as num?)?.toInt() ?? 0;
    final active = (total - completed).clamp(0, total);
    final pct = total == 0 ? 0.0 : completed / total;
    final isUnread = unread > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Stack(
          children: [
            if (isUnread)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: azure,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
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
                          _ParentRecommendationScreenState._initials(name),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              klass,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: azure,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: azure.withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '$unread BARU',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '$total',
                          label: 'TOTAL',
                          color: azure,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '$active',
                          label: 'AKTIF',
                          color: ColorUtils.warning600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '$completed',
                          label: 'SELESAI',
                          color: ColorUtils.success600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: ColorUtils.slate100,
                            valueColor: AlwaysStoppedAnimation<Color>(azure),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(pct * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: azure,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CardButton(
                          icon: Icons.history_rounded,
                          label: 'Riwayat',
                          color: azure,
                          filled: false,
                          onTap: onTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _CardButton(
                          icon: Icons.chevron_right_rounded,
                          label: 'Lihat Rekomendasi',
                          color: azure,
                          filled: true,
                          onTap: onTap,
                          iconLast: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final bool iconLast;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
    this.iconLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.20)),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconLast) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            if (iconLast) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Frame B status filter chip ────────────────────────────────────

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color azure;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.azure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? azure : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? azure : ColorUtils.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ColorUtils.slate700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : ColorUtils.slate600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Frame B parent rec card ───────────────────────────────────────

class _ParentRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final Color azure;
  final VoidCallback onTap;

  const _ParentRecommendationCard({
    required this.row,
    required this.azure,
    required this.onTap,
  });

  Map<String, dynamic> get _rec {
    final r = row['recommendation'];
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  String? get _teacherName {
    final t = _rec['teacher'];
    if (t is Map) {
      final n = t['name']?.toString();
      if (n != null && n.isNotEmpty) return n;
    }
    return _rec['teacher_name']?.toString();
  }

  String? get _subjectName {
    final s =
        _rec['subject_school'] ?? _rec['subjectSchool'] ?? _rec['subject'];
    if (s is Map) return s['name']?.toString();
    return _rec['subject_name']?.toString();
  }

  String _fmtAgo(dynamic ts) {
    if (ts == null) return 'baru saja';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';
      return '${dt.day}/${dt.month}/${dt.year % 100}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = row['read_at'] == null;
    final isCompleted =
        row['parent_completed_at'] != null ||
        _rec['status']?.toString().toLowerCase() == 'completed';
    final priority = _rec['priority']?.toString().toLowerCase() ?? 'low';
    final priorityColor = priority == 'high'
        ? ColorUtils.error600
        : priority == 'medium'
        ? ColorUtils.warning600
        : ColorUtils.slate500;
    final priorityLabel = priority == 'high'
        ? 'PRIORITAS TINGGI'
        : priority == 'medium'
        ? 'PRIORITAS SEDANG'
        : 'PRIORITAS RENDAH';
    final dueDate = _rec['due_date'];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnread
                    ? azure.withValues(alpha: 0.30)
                    : ColorUtils.slate200,
                width: isUnread ? 1.5 : 1,
              ),
              boxShadow: isUnread
                  ? [
                      BoxShadow(
                        color: azure.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
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
                        color: azure.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _ParentRecommendationScreenState._initials(
                          _teacherName ?? 'WK',
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: azure,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _teacherName ?? 'Wali Kelas',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            [
                              if (_subjectName != null) _subjectName!,
                              'Wali Kelas',
                              _fmtAgo(row['sent_at']),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: azure.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'WALI KELAS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: azure,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _StatusPill(label: priorityLabel, color: priorityColor),
                    if (_subjectName != null)
                      _StatusPill(
                        label: _subjectName!.toUpperCase(),
                        color: ColorUtils.indigo600,
                      ),
                    if (isCompleted)
                      _StatusPill(
                        label: 'SELESAI',
                        color: ColorUtils.success600,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _rec['title']?.toString() ?? 'Rekomendasi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isCompleted
                        ? ColorUtils.slate500
                        : ColorUtils.slate900,
                    letterSpacing: -0.2,
                    height: 1.3,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                HtmlWidget(
                  _rec['description']?.toString() ?? '',
                  textStyle: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate600,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (dueDate != null && !isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtils.warning600.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorUtils.warning600.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: ColorUtils.warning600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tenggat ${_fmtDate(dueDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.warning600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: azure.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Lihat Detail',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: azure,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: azure,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: azure.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Buka',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isUnread)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: azure, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDate(dynamic ts) {
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
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
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return ts.toString();
    }
  }
}
