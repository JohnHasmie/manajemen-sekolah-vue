// Parent-side Rekomendasi screen — Frame I of the
// `_design/teacher_rekomendasi_redesign.html` mockup, minus the
// separate "inbox" surface. The user wanted the shared rec to live
// as a card inside the parent Rekomendasi screen rather than a
// separate inbox, so this screen renders all recs the parent's wali
// kelas teachers have shared.
//
// Per share row:
//   • "DARI WALI KELAS" violet badge
//   • teacher avatar + name + subject + relative time + status pill
//   • title + truncated description
//   • amber due-date strip when present
//   • Lihat Detail (violet tonal) + Balas (violet primary)
//   • read receipts auto-mark on view
//
// Deep-linkable via `?rec_id={id}` query — when the parent app pushes
// this screen with a target id we scroll the matching card into view
// after first paint.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';

class ParentRecommendationScreen extends ConsumerStatefulWidget {
  /// Authenticated parent's user id. Passed from the parent dashboard.
  final String parentUserId;

  /// Optional student filter — when the parent has multiple children
  /// the dashboard may select one and pass it through.
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
  List<dynamic> _items = [];

  /// Tracks per-rec async work so we can disable buttons while the
  /// reply / mark-read calls are in flight.
  final Set<String> _busyIds = {};

  /// Per-rec scroll keys so the deep link can `Scrollable.ensureVisible`.
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool useCache = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await getIt<ApiRecommendationService>().getParentInbox(
        parentUserId: widget.parentUserId,
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
      // Auto mark-read for unread rows + scroll to deep-link target.
      _autoMarkRead();
      _scrollToTarget();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _autoMarkRead() async {
    for (final row in _items) {
      if (row is! Map) continue;
      final readAt = row['read_at'];
      if (readAt != null) continue;
      final rec = row['recommendation'];
      if (rec is! Map) continue;
      final recId = rec['id']?.toString();
      if (recId == null || recId.isEmpty) continue;
      // Fire-and-forget; ignore errors.
      try {
        await getIt<ApiRecommendationService>().markRecommendationRead(
          recommendationId: recId,
          parentUserId: widget.parentUserId,
        );
      } catch (_) {
        /* swallowed */
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

  // ── KPI counters ─────────────────────────────────────────────────

  int get _unreadCount =>
      _items.where((r) => r is Map && r['read_at'] == null).length;
  int get _totalCount => _items.length;
  int get _completedCount => _items.where((r) {
    if (r is! Map) return false;
    final rec = r['recommendation'];
    return rec is Map &&
        (rec['status']?.toString().toLowerCase() == 'completed');
  }).length;

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'parent',
            subtitle: 'Wali · Anak Saya',
            title: 'Rekomendasi Belajar',
            kpiOverlayHeight: 72,
            onBackPressed: () => Navigator.of(context).maybePop(),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _KpiOverlap(
                unread: _unreadCount,
                total: _totalCount,
                completed: _completedCount,
                cobalt: cobalt,
              ),
            ),
          ),
          Expanded(
            child: TeacherAsyncView(
              isLoading: _loading,
              errorMessage: _error,
              isEmpty: _items.isEmpty,
              onRefresh: () => _load(useCache: false),
              role: 'parent',
              emptyTitle: 'Belum ada rekomendasi',
              emptySubtitle:
                  'Wali kelas akan mengirim rekomendasi belajar di sini.',
              childBuilder: () => AppRefreshIndicator(
                onRefresh: () => _load(useCache: false),
                child: _buildList(cobalt),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(Color cobalt) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final row = _items[index];
        if (row is! Map) return const SizedBox.shrink();
        final rec = row['recommendation'];
        if (rec is! Map) return const SizedBox.shrink();
        final recId = rec['id']?.toString() ?? '$index';
        final key = _cardKeys.putIfAbsent(recId, GlobalKey.new);
        return Padding(
          key: key,
          padding: const EdgeInsets.only(top: 10),
          child: _ParentRecommendationCard(
            recipient: Map<String, dynamic>.from(row),
            recommendation: Map<String, dynamic>.from(rec),
            isBusy: _busyIds.contains(recId),
            onReply: () => _handleReply(rec, row),
            cobalt: cobalt,
          ),
        );
      },
    );
  }

  Future<void> _handleReply(dynamic rec, dynamic row) async {
    final recId = (rec is Map ? rec['id']?.toString() : null) ?? '';
    if (recId.isEmpty) return;
    final replyCtrl = TextEditingController(
      text: (row is Map ? row['reply_text']?.toString() : null) ?? '',
    );
    final cobalt = ColorUtils.brandCobalt;

    final reply = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Balas ke Wali Kelas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replyCtrl,
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ColorUtils.slate50,
                  hintText: 'Tulis balasan untuk guru…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cobalt, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: ColorUtils.slate100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(replyCtrl.text.trim()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: cobalt,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: cobalt.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Kirim Balasan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (reply == null || reply.isEmpty) return;

    setState(() => _busyIds.add(recId));
    try {
      await getIt<ApiRecommendationService>().replyToRecommendation(
        recommendationId: recId,
        parentUserId: widget.parentUserId,
        replyText: reply,
      );
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Balasan terkirim ke guru.');
        await _load(useCache: false);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal mengirim balasan: $e');
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(recId));
    }
  }
}

// ─── KPI overlap strip ─────────────────────────────────────────────

class _KpiOverlap extends StatelessWidget {
  final int unread;
  final int total;
  final int completed;
  final Color cobalt;

  const _KpiOverlap({
    required this.unread,
    required this.total,
    required this.completed,
    required this.cobalt,
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
              label: 'PESAN BARU',
              color: ColorUtils.violet700,
            ),
          ),
          Container(width: 1, height: 28, color: ColorUtils.slate100),
          Expanded(
            child: _KpiCell(value: '$total', label: 'TOTAL', color: cobalt),
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

// ─── Card ─────────────────────────────────────────────────────────

class _ParentRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recipient;
  final Map<String, dynamic> recommendation;
  final bool isBusy;
  final VoidCallback onReply;
  final Color cobalt;

  const _ParentRecommendationCard({
    required this.recipient,
    required this.recommendation,
    required this.isBusy,
    required this.onReply,
    required this.cobalt,
  });

  String? get _teacherName {
    final t = recommendation['teacher'];
    if (t is Map) {
      final name = t['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return recommendation['teacher_name']?.toString();
  }

  String? get _subjectName {
    final s =
        recommendation['subject_school'] ??
        recommendation['subjectSchool'] ??
        recommendation['subject'];
    if (s is Map) return s['name']?.toString();
    return recommendation['subject_name']?.toString();
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
    final violet = ColorUtils.violet700;
    final isUnread = recipient['read_at'] == null;
    final isReplied = recipient['replied_at'] != null;

    final priority =
        recommendation['priority']?.toString().toLowerCase() ?? 'low';
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

    final dueDate = recommendation['due_date'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? violet.withValues(alpha: 0.30)
              : ColorUtils.slate200,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: violet.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (isUnread)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: violet,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teacher author strip
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: violet.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: violet,
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
                              'Wali Kelas',
                              if (_subjectName != null) _subjectName!,
                              _fmtAgo(recipient['sent_at']),
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
                        color: violet.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'DARI WALI KELAS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: violet,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Embedded preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    border: Border.all(color: ColorUtils.slate200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Pill(label: priorityLabel, color: priorityColor),
                          if (_subjectName != null)
                            _Pill(
                              label: _subjectName!.toUpperCase(),
                              color: ColorUtils.indigo600,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recommendation['title']?.toString() ?? 'Rekomendasi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.2,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      HtmlWidget(
                        recommendation['description']?.toString() ?? '',
                        textStyle: TextStyle(
                          fontSize: 11.5,
                          color: ColorUtils.slate600,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      if (dueDate != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.warning600.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: ColorUtils.warning600,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Tenggat ${_fmtDate(dueDate)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: ColorUtils.warning600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isReplied) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtils.success600.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: ColorUtils.success600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sudah dibalas',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.success600,
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
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : onReply,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: violet.withValues(alpha: 0.30),
                          ),
                          backgroundColor: violet.withValues(alpha: 0.06),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(Icons.chat_rounded, size: 13, color: violet),
                        label: Text(
                          isReplied ? 'Balas Lagi' : 'Balas',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: violet,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

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
