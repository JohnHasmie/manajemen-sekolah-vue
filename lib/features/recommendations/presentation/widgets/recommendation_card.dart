// Renders a single AI-generated learning recommendation card.
//
// Mockup: Frame C (base) + Frame G (share affordances) of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Adds three distinct states to the share row:
//   • BELUM DIKIRIM (slate) — rec not yet shared. Card shows a violet
//     dashed "Bagikan ke Wali" CTA *only* when the rec is past
//     pending (in_progress / completed). Pending recs cannot be
//     shared until the wali approves them.
//   • TERKIRIM (cobalt) — at least one parent received it but none
//     have read yet. Footer shows a cobalt-tonal "Riwayat" button
//     plus the existing Tandai Diterapkan CTA.
//   • DIBACA WALI (green) — at least one parent opened the card.
//     A read-receipt strip with stacked avatars + summary appears
//     above the footer.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_material_item.dart';

class RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> rec;
  final Key? listKey;
  final bool isUpdatingStatus;
  final VoidCallback? onToggleStatus;

  /// Open the Bagikan ke Wali sheet. Wired to
  /// `showRecommendationShareSheet` from the calling screen.
  final VoidCallback? onShareToParent;

  /// Open the Riwayat Pengiriman sheet. Wired to
  /// `showRecommendationShareHistorySheet`.
  final VoidCallback? onViewShareHistory;

  /// Open the per-recommendation edit screen. Renders a pencil
  /// affordance next to the title — bulk edit moved off the screen
  /// header so each rec is edited in its own context.
  final VoidCallback? onEdit;

  const RecommendationCard({
    super.key,
    required this.rec,
    this.listKey,
    this.isUpdatingStatus = false,
    this.onToggleStatus,
    this.onShareToParent,
    this.onViewShareHistory,
    this.onEdit,
  });

  String? get _authorName {
    final teacher = rec['teacher'];
    if (teacher is Map) {
      final name = teacher['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    final flat = rec['teacher_name']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  // ── Share state derivation ────────────────────────────────────────

  bool get _hasBeenShared {
    final ts = rec['shared_with_parent_at'];
    if (ts == null) return false;
    if (rec['share_recipient_count'] is num &&
        (rec['share_recipient_count'] as num) == 0) {
      return false;
    }
    return true;
  }

  int get _shareTotal => (rec['share_recipient_count'] as num?)?.toInt() ?? 0;
  int get _shareReadCount => (rec['share_read_count'] as num?)?.toInt() ?? 0;

  /// Whether the wali kelas can fan this rec out. Per the mockup
  /// Frame G, the violet dashed "Bagikan ke Wali" CTA appears on
  /// every active rec — pending and in_progress alike. Only
  /// `dismissed` recs hide the share button (sharing a rejected
  /// rec doesn't make sense). The backend keeps a softer gate that
  /// allows pending too, since the AI generates them already
  /// "approved" at write time.
  bool get _isShareable {
    final s = rec['status']?.toString().toLowerCase() ?? 'pending';
    return s != 'dismissed';
  }

  @override
  Widget build(BuildContext context) {
    final priority = rec['priority']?.toString().toLowerCase() ?? 'low';
    final type = rec['type']?.toString().toLowerCase() ?? 'other';
    final status = rec['status']?.toString().toLowerCase() ?? 'pending';
    final isCompleted = status == 'completed';

    final ({Color color, String label, IconData icon}) priorityInfo;
    if (priority == 'high') {
      priorityInfo = (
        color: ColorUtils.error600,
        label: 'Prioritas Tinggi',
        icon: Icons.priority_high_rounded,
      );
    } else if (priority == 'medium') {
      priorityInfo = (
        color: ColorUtils.warning600,
        label: 'Prioritas Sedang',
        icon: Icons.remove_rounded,
      );
    } else {
      priorityInfo = (
        color: ColorUtils.slate500,
        label: 'Prioritas Rendah',
        icon: Icons.arrow_downward_rounded,
      );
    }

    final accentColor = isCompleted
        ? ColorUtils.success600
        : priorityInfo.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isCompleted
              ? ColorUtils.success600.withValues(alpha: 0.20)
              : ColorUtils.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top accent strip — 4dp coloured by priority / completion.
          Container(height: 4, color: accentColor),

          // Pill row: priority + type + status + share state
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Pill(
                  icon: priorityInfo.icon,
                  label: priorityInfo.label.toUpperCase(),
                  color: priorityInfo.color,
                ),
                _Pill(label: type.toUpperCase(), color: ColorUtils.slate500),
                if (isCompleted)
                  _Pill(
                    icon: Icons.check_circle_rounded,
                    label: 'SUDAH DITERAPKAN',
                    color: ColorUtils.success600,
                  ),
                _SharePill(
                  total: _shareTotal,
                  read: _shareReadCount,
                  hasBeenShared: _hasBeenShared,
                ),
              ],
            ),
          ),

          // Title row — title text on the left, optional pencil button
          // on the right so the wali can jump straight into the per-rec
          // editor without leaving the result screen.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    key: listKey,
                    rec['title'] ?? 'Rekomendasi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isCompleted
                          ? ColorUtils.slate500
                          : ColorUtils.slate900,
                      letterSpacing: -0.3,
                      height: 1.3,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: ColorUtils.slate400,
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    color: ColorUtils.slate500,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),

          // Authoring teacher (wali kelas scope only)
          if (_authorName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: ColorUtils.slate400,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _authorName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: HtmlWidget(
              rec['description'] ?? '',
              textStyle: TextStyle(
                fontSize: 12.5,
                color: isCompleted ? ColorUtils.slate400 : ColorUtils.slate600,
                height: 1.55,
              ),
            ),
          ),

          // AI Reasoning
          if (!isCompleted &&
              rec['ai_reasoning'] != null &&
              (rec['ai_reasoning'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _AiReasoning(text: rec['ai_reasoning'].toString()),
            ),

          // Materials
          if (!isCompleted &&
              rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 12,
                    color: ColorUtils.slate400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Materi & Aktivitas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            ...(rec['materials'] as List).map(
              (mat) => RecommendationMaterialItem(matItem: mat),
            ),
          ],

          // Parent read-receipt strip when shared
          if (_hasBeenShared)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _ParentReceiptStrip(
                total: _shareTotal,
                read: _shareReadCount,
                sharedAt: rec['shared_with_parent_at'],
                onTap: onViewShareHistory,
              ),
            ),

          // Dashed-divider + due-date strip + actions footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rec['due_date'] != null || isCompleted) ...[
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: ColorUtils.slate200,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DueDateStrip(
                      dueDate: rec['due_date'],
                      isCompleted: isCompleted,
                      completedAt: rec['completed_at'],
                    ),
                  ),
                ],
                _FooterActions(
                  isCompleted: isCompleted,
                  isUpdatingStatus: isUpdatingStatus,
                  hasBeenShared: _hasBeenShared,
                  isShareable: _isShareable,
                  onToggleStatus: onToggleStatus,
                  onShare: onShareToParent,
                  onViewHistory: onViewShareHistory,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DueDateStrip extends StatelessWidget {
  final dynamic dueDate;
  final bool isCompleted;
  final dynamic completedAt;

  const _DueDateStrip({
    required this.dueDate,
    required this.isCompleted,
    required this.completedAt,
  });

  String _fmtDate(DateTime dt) {
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
  }

  @override
  Widget build(BuildContext context) {
    final ts = isCompleted ? completedAt : dueDate;
    if (ts == null) return const SizedBox.shrink();
    DateTime? dt;
    try {
      dt = DateTime.parse(ts.toString()).toLocal();
    } catch (_) {
      return const SizedBox.shrink();
    }

    final color = isCompleted ? ColorUtils.success600 : ColorUtils.slate500;
    final icon = isCompleted
        ? Icons.check_circle_rounded
        : Icons.schedule_rounded;

    String label;
    if (isCompleted) {
      label = 'Diterapkan ${_fmtDate(dt)}';
    } else {
      final days = dt.difference(DateTime.now()).inDays;
      if (days < 0) {
        label = 'Tenggat ${_fmtDate(dt)} · lewat ${-days} hari';
      } else if (days == 0) {
        label = 'Tenggat hari ini';
      } else {
        label = 'Tenggat ${_fmtDate(dt)} · $days hari lagi';
      }
    }

    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  const _Pill({this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharePill extends StatelessWidget {
  final int total;
  final int read;
  final bool hasBeenShared;

  const _SharePill({
    required this.total,
    required this.read,
    required this.hasBeenShared,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasBeenShared) {
      return _Pill(
        icon: Icons.send_outlined,
        label: 'BELUM DIKIRIM',
        color: ColorUtils.slate500,
      );
    }
    if (read >= total && total > 0) {
      return _Pill(
        icon: Icons.done_all_rounded,
        label: 'DIBACA WALI',
        color: ColorUtils.success600,
      );
    }
    if (read > 0) {
      return _Pill(
        icon: Icons.done_all_rounded,
        label: '$read/$total DIBACA',
        color: ColorUtils.success600,
      );
    }
    return _Pill(
      icon: Icons.send_rounded,
      label: 'TERKIRIM',
      color: ColorUtils.brandCobalt,
    );
  }
}

class _AiReasoning extends StatelessWidget {
  final String text;

  const _AiReasoning({required this.text});

  @override
  Widget build(BuildContext context) {
    final violet = ColorUtils.violet700;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: violet, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: violet),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ALASAN AI',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: violet,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    color: violet,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
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

class _ParentReceiptStrip extends StatelessWidget {
  final int total;
  final int read;
  final dynamic sharedAt;
  final VoidCallback? onTap;

  const _ParentReceiptStrip({
    required this.total,
    required this.read,
    required this.sharedAt,
    required this.onTap,
  });

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
    final cobalt = ColorUtils.brandCobalt;
    final allRead = read >= total && total > 0;
    final accent = allRead ? ColorUtils.success600 : cobalt;
    final summary = allRead
        ? 'Sudah dibaca semua wali'
        : (read > 0
              ? '$read dari $total wali sudah baca'
              : 'Terkirim · belum dibaca');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        allRead
                            ? Icons.done_all_rounded
                            : Icons.schedule_rounded,
                        size: 11,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Dibagikan ${_fmtAgo(sharedAt)} · $total wali',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  final bool isCompleted;
  final bool isUpdatingStatus;
  final bool hasBeenShared;
  final bool isShareable;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onShare;
  final VoidCallback? onViewHistory;

  const _FooterActions({
    required this.isCompleted,
    required this.isUpdatingStatus,
    required this.hasBeenShared,
    required this.isShareable,
    required this.onToggleStatus,
    required this.onShare,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final violet = ColorUtils.violet700;
    final children = <Widget>[];

    // Share-related action — Riwayat (when shared) or Bagikan ke Wali
    // (when shareable + not yet shared). For pending/dismissed recs we
    // intentionally show nothing — the user must approve the rec first
    // by toggling status to in_progress.
    if (hasBeenShared) {
      children.add(
        _SecondaryButton(
          icon: Icons.history_rounded,
          label: 'Riwayat',
          color: cobalt,
          onTap: onViewHistory,
        ),
      );
    } else if (isShareable && onShare != null) {
      children.add(
        _DashedSecondaryButton(
          icon: Icons.send_rounded,
          label: 'Bagikan ke Wali',
          color: violet,
          onTap: onShare,
        ),
      );
    }

    // Primary status toggle
    if (onToggleStatus != null) {
      children.add(
        Expanded(
          child: _StatusToggleButton(
            isCompleted: isCompleted,
            isUpdatingStatus: isUpdatingStatus,
            onTap: onToggleStatus,
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    // Mix in spacing between elements.
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 8));
      spaced.add(children[i]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: spaced);
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _DashedSecondaryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggleButton extends StatelessWidget {
  final bool isCompleted;
  final bool isUpdatingStatus;
  final VoidCallback? onTap;

  const _StatusToggleButton({
    required this.isCompleted,
    required this.isUpdatingStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final color = isCompleted ? ColorUtils.success600 : cobalt;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isUpdatingStatus ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUpdatingStatus)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isUpdatingStatus
                      ? 'Memperbarui...'
                      : isCompleted
                      ? 'Sudah Diterapkan'
                      : 'Tandai Diterapkan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
