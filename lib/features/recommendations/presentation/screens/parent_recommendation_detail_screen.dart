// Frame C from the parent Rekomendasi mockup — full-page detail view
// for a single shared recommendation.
//
// Pushed as a MaterialPageRoute from `parent_recommendation_screen.dart`
// or directly from a notification deep link. The screen owns:
//   • An azure BrandPageHeader with Anak · Mapel kicker and the rec
//     title in the toolbar.
//   • An azure-tinted hero card (priority + subject + "Dari Wali Kelas"
//     pill row, large title, sent-ago meta line).
//   • Sect-cards for Pesan dari Wali Kelas, Yang Perlu Dilakukan,
//     Materi Terkait (chip strip pulling chapter / sub-chapter from
//     the rec), and an AI Reasoning expandable.
//   • A sticky bottom action bar with Tandai Selesai (outline) +
//     Balas Wali Kelas (primary).
//
// Reads the rec + recipient row from the caller; on Tandai Selesai or
// Balas it makes the corresponding service call and pops `true` so
// the parent list can refresh counters.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_complete_sheet.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_reply_sheet.dart';

class ParentRecommendationDetailScreen extends ConsumerStatefulWidget {
  /// Authenticated parent's user id — needed for read / reply / mark
  /// completed calls.
  final String parentUserId;

  /// The full inbox row — `{ recipient_id, recommendation, sent_at,
  /// read_at, replied_at, parent_completed_at, ... }`. We hold onto
  /// the whole row so the screen can re-render lifecycle pills as the
  /// parent acts on it without a refetch.
  final Map<String, dynamic> inboxRow;

  const ParentRecommendationDetailScreen({
    super.key,
    required this.parentUserId,
    required this.inboxRow,
  });

  /// Pushes the detail screen as a Material page route. Returns `true`
  /// when the parent took an action (replied / tandai selesai) so the
  /// caller can refresh the list.
  static Future<bool?> show({
    required BuildContext context,
    required String parentUserId,
    required Map<String, dynamic> inboxRow,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ParentRecommendationDetailScreen(
          parentUserId: parentUserId,
          inboxRow: inboxRow,
        ),
      ),
    );
  }

  @override
  ConsumerState<ParentRecommendationDetailScreen> createState() =>
      _ParentRecommendationDetailScreenState();
}

class _ParentRecommendationDetailScreenState
    extends ConsumerState<ParentRecommendationDetailScreen> {
  late Map<String, dynamic> _row;
  bool _busy = false;
  bool _changed = false;
  bool _showReasoning = false;

  @override
  void initState() {
    super.initState();
    _row = Map<String, dynamic>.from(widget.inboxRow);
    // Fire-and-forget: read-receipts must not block the first frame.
    // We schedule it after the build so the detail screen renders
    // immediately even on slow networks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeMarkRead();
    });
  }

  Map<String, dynamic> get _rec {
    final r = _row['recommendation'];
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  String get _recId => _rec['id']?.toString() ?? '';

  Future<void> _maybeMarkRead() async {
    if (_row['read_at'] != null) return;
    final id = _recId;
    if (id.isEmpty) return;
    try {
      await getIt<ApiRecommendationService>().markRecommendationRead(
        recommendationId: id,
        parentUserId: widget.parentUserId,
      );
      if (!mounted) return;
      setState(() {
        _row['read_at'] = DateTime.now().toIso8601String();
        _changed = true;
      });
    } catch (_) {
      /* swallowed — read receipts are best-effort */
    }
  }

  // ── Action handlers ──

  Future<void> _onReply() async {
    final reply = await showParentRecommendationReplySheet(
      context: context,
      teacherName: _teacherName ?? 'Wali Kelas',
      subjectName: _subjectName,
      initialText: _row['reply_text']?.toString(),
    );
    if (reply == null || reply.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await getIt<ApiRecommendationService>().replyToRecommendation(
        recommendationId: _recId,
        parentUserId: widget.parentUserId,
        replyText: reply,
      );
      if (!mounted) return;
      setState(() {
        _row['replied_at'] = DateTime.now().toIso8601String();
        _row['reply_text'] = reply;
        _changed = true;
      });
      // Invalidate the parent's cached inbox/summary so the list
      // screen shows the freshly-replied row when we pop back.
      await getIt<ApiRecommendationService>().invalidateParentInboxCache(
        parentUserId: widget.parentUserId,
      );
      if (!mounted) return;
      // Refresh parent dashboard so "Rekomendasi belum dibalas"
      // priority-inbox rows drop out of "Perlu perhatian" right away.
      unawaited(ref.read(dashboardProvider.notifier).refreshStats());
      SnackBarUtils.showSuccess(context, 'Balasan terkirim ke wali kelas.');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal mengirim balasan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onMarkCompleted() async {
    if (_row['parent_completed_at'] != null) {
      // Already done — give a friendly nudge instead of opening the
      // sheet again. The wali kelas already saw the confirmation.
      SnackBarUtils.showInfo(
        context,
        'Rekomendasi ini sudah ditandai selesai.',
      );
      return;
    }
    final result = await showParentRecommendationCompleteSheet(
      context: context,
      recommendationTitle: _rec['title']?.toString() ?? 'Rekomendasi',
      dueLabel: _dueLabel,
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await getIt<ApiRecommendationService>()
          .markRecommendationCompletedByParent(
            recommendationId: _recId,
            parentUserId: widget.parentUserId,
            note: result.note,
            notifyTeacher: result.notifyTeacher,
          );
      if (!mounted) return;
      setState(() {
        _row['parent_completed_at'] = DateTime.now().toIso8601String();
        _row['parent_completion_note'] = result.note;
        _changed = true;
      });
      // Invalidate cache so the parent list shows the SELESAI badge
      // when the user pops back.
      await getIt<ApiRecommendationService>().invalidateParentInboxCache(
        parentUserId: widget.parentUserId,
      );
      if (!mounted) return;
      unawaited(ref.read(dashboardProvider.notifier).refreshStats());
      SnackBarUtils.showSuccess(
        context,
        'Rekomendasi ditandai selesai. Terima kasih!',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal menandai selesai: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Derived display fields ──

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

  String? get _dueLabel {
    final d = _rec['due_date'];
    if (d == null) return null;
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
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
      return 'Tenggat ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return null;
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final azure = ColorUtils.brandAzure;
    final violet = ColorUtils.violet700;

    final priority = (_rec['priority'] ?? 'low').toString().toLowerCase();
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

    final isCompleted =
        _row['parent_completed_at'] != null ||
        (_rec['status']?.toString().toLowerCase() == 'completed');

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_busy) {
          AppNavigator.pop(context, _changed);
        }
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            BrandPageHeader(
              role: 'wali',
              subtitle: [
                if (_subjectName != null) _subjectName,
                'Rincian Rekomendasi',
              ].whereType<String>().join(' · '),
              title: _rec['title']?.toString() ?? 'Rekomendasi',
              onBackPressed: _busy
                  ? null
                  : () => AppNavigator.pop(context, _changed),
              kpiOverlayHeight: 36,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // ── Hero detail card (overlaps the header) ──
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: azure.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: azure.withValues(alpha: 0.10),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                              _Pill(label: 'DARI WALI KELAS', color: azure),
                              if (isCompleted)
                                _Pill(
                                  label: 'SELESAI',
                                  color: ColorUtils.success600,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _rec['title']?.toString() ?? 'Rekomendasi',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: ColorUtils.slate900,
                              letterSpacing: -0.3,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _heroMeta(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: -28 + 14), // collapse Transform offset
                  // ── Pesan dari Wali Kelas (if any) ──
                  if (_sharedMessage != null) ...[
                    _SectCard(
                      icon: Icons.chat_bubble_rounded,
                      iconBg: azure.withValues(alpha: 0.10),
                      iconFg: azure,
                      title: 'Pesan dari Wali Kelas',
                      chip: _teacherName,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: azure.withValues(alpha: 0.04),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          border: Border(
                            left: BorderSide(color: azure, width: 3),
                          ),
                        ),
                        child: Text(
                          _sharedMessage!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: ColorUtils.slate700,
                            fontWeight: FontWeight.w600,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── Yang Perlu Dilakukan (description) ──
                  _SectCard(
                    icon: Icons.checklist_rounded,
                    iconBg: ColorUtils.indigo600.withValues(alpha: 0.10),
                    iconFg: ColorUtils.indigo600,
                    title: 'Yang Perlu Dilakukan',
                    child: HtmlWidget(
                      _rec['description']?.toString() ?? '-',
                      textStyle: TextStyle(
                        fontSize: 12.5,
                        color: ColorUtils.slate700,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Materi Terkait (chips) ──
                  if (_materiChips.isNotEmpty) ...[
                    _SectCard(
                      icon: Icons.menu_book_rounded,
                      iconBg: ColorUtils.brandCobalt.withValues(alpha: 0.10),
                      iconFg: ColorUtils.brandCobalt,
                      title: 'Materi Terkait',
                      chip: '${_materiChips.length} dipilih',
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _materiChips,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── AI Reasoning (collapsible) ──
                  if ((_rec['ai_reasoning']?.toString().trim().isNotEmpty ??
                      false))
                    _AiReasoningTile(
                      reasoning: _rec['ai_reasoning'].toString(),
                      expanded: _showReasoning,
                      onTap: () =>
                          setState(() => _showReasoning = !_showReasoning),
                      violet: violet,
                    ),
                  if (_row['replied_at'] != null) ...[
                    const SizedBox(height: 10),
                    _RepliedBanner(replyText: _row['reply_text']?.toString()),
                  ],
                ],
              ),
            ),
            // ── Sticky action bar ──
            _ActionBar(
              azure: azure,
              busy: _busy,
              isCompleted: isCompleted,
              onCompleted: _onMarkCompleted,
              onReply: _onReply,
            ),
          ],
        ),
      ),
    );
  }

  String _heroMeta() {
    final parts = <String>[];
    if (_teacherName != null) parts.add('Dari $_teacherName');
    final sentAt = _row['sent_at'];
    if (sentAt != null) {
      try {
        final dt = DateTime.parse(sentAt.toString()).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          parts.add('${diff.inMinutes}m lalu');
        } else if (diff.inHours < 24) {
          parts.add('${diff.inHours}j lalu');
        } else if (diff.inDays < 7) {
          parts.add('${diff.inDays}h lalu');
        } else {
          parts.add('${dt.day}/${dt.month}/${dt.year % 100}');
        }
      } catch (_) {
        /* ignore */
      }
    }
    if (_dueLabel != null) parts.add(_dueLabel!);
    return parts.join(' · ');
  }

  String? get _sharedMessage {
    final m = _rec['shared_message']?.toString().trim();
    if (m == null || m.isEmpty) return null;
    return m;
  }

  /// Materi chips composed from the rec's `chapter` / `subChapter`
  /// relations + any rows in `materials`. Cobalt for Bab, amber for
  /// Sub-bab — keeps the colour coding aligned with the teacher edit
  /// screen (Frame E of the teacher mockup).
  List<Widget> get _materiChips {
    final out = <Widget>[];

    final ch = _rec['chapter'];
    if (ch is Map) {
      final title = (ch['title'] ?? ch['judul_bab'])?.toString();
      if (title != null && title.isNotEmpty) {
        out.add(
          _MateriChip(label: 'Bab · $title', color: ColorUtils.success600),
        );
      }
    }
    final sc = _rec['sub_chapter'] ?? _rec['subChapter'];
    if (sc is Map) {
      final title = (sc['title'] ?? sc['judul_sub_bab'])?.toString();
      if (title != null && title.isNotEmpty) {
        out.add(
          _MateriChip(label: 'Sub: $title', color: ColorUtils.warning600),
        );
      }
    }

    // Secondary materi rows attached on RecommendationMaterial.
    final mats = _rec['materials'];
    if (mats is List) {
      for (final m in mats) {
        if (m is! Map) continue;
        final title = m['title']?.toString();
        if (title == null || title.isEmpty) continue;
        out.add(_MateriChip(label: title, color: ColorUtils.brandCobalt));
      }
    }
    return out;
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

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

class _SectCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? chip;
  final Widget child;

  const _SectCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.child,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: iconFg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (chip != null && chip!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate600,
                    ),
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

class _MateriChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MateriChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(ctx).size.width - 64;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AiReasoningTile extends StatelessWidget {
  final String reasoning;
  final bool expanded;
  final VoidCallback onTap;
  final Color violet;

  const _AiReasoningTile({
    required this.reasoning,
    required this.expanded,
    required this.onTap,
    required this.violet,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: violet.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: violet.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: violet),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mengapa AI menyarankan ini?',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: violet,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: violet,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              HtmlWidget(
                reasoning,
                textStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate700,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepliedBanner extends StatelessWidget {
  final String? replyText;

  const _RepliedBanner({this.replyText});

  @override
  Widget build(BuildContext context) {
    final green = ColorUtils.success600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: green),
              const SizedBox(width: 8),
              Text(
                'Sudah dibalas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: green,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (replyText != null && replyText!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${replyText!.trim()}"',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final Color azure;
  final bool busy;
  final bool isCompleted;
  final VoidCallback onCompleted;
  final VoidCallback onReply;

  const _ActionBar({
    required this.azure,
    required this.busy,
    required this.isCompleted,
    required this.onCompleted,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final green = ColorUtils.success600;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onCompleted,
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.check_rounded,
                  size: 14,
                  color: isCompleted ? green : ColorUtils.slate700,
                ),
                label: Text(
                  isCompleted ? 'Selesai' : 'Tandai Selesai',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? green : ColorUtils.slate700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isCompleted
                        ? green.withValues(alpha: 0.4)
                        : ColorUtils.slate200,
                  ),
                  backgroundColor: isCompleted
                      ? green.withValues(alpha: 0.06)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onReply,
                icon: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  busy ? 'Memproses…' : 'Balas Wali Kelas',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: azure,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
