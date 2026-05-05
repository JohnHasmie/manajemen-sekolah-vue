// Admin Raport hub shared components — Mockup #08.
//
// Two new widgets:
//   • StatusPipelineStrip — N circular nodes connected by lines.
//                           Active node enlarges + inverts to white.
//                           Tap a node to filter the list to that
//                           lifecycle stage.
//   • TingkatGroupCard    — Collapsible card with header (tingkat,
//                           class+student count, %-reviewed bar) +
//                           expanded grid of per-kelas mini-chips.
//
// Both are pure presentation widgets keyed off the
// /api/raports/admin-pipeline response shape.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// StatusPipelineStrip
// =====================================================================

class PipelineNode {
  final String key;
  final String label;
  final int count;
  final bool active;

  const PipelineNode({
    required this.key,
    required this.label,
    required this.count,
    required this.active,
  });
}

class StatusPipelineStrip extends StatelessWidget {
  final List<PipelineNode> nodes;
  final ValueChanged<String>? onNodeTap;
  final EdgeInsetsGeometry padding;

  /// Optional widget rendered to the right of the connector row, in
  /// the same crossAxis-center position as the circle nodes. Used by
  /// the Raport hub for the trailing "Cetak" pill so it visually
  /// centers with the pipeline circles instead of the column label.
  final Widget? trailing;

  const StatusPipelineStrip({
    super.key,
    required this.nodes,
    this.onNodeTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PIPELINE STATUS',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < nodes.length; i++) ...[
                      _PipelineDot(
                        node: nodes[i],
                        onTap: onNodeTap == null
                            ? null
                            : () => onNodeTap!(nodes[i].key),
                      ),
                      if (i < nodes.length - 1)
                        Expanded(
                          child: _PipelineConnector(
                            active: nodes[i].active ||
                                nodes[i + 1].active,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PipelineDot extends StatelessWidget {
  final PipelineNode node;
  final VoidCallback? onTap;
  const _PipelineDot({required this.node, this.onTap});

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final size = node.active ? 36.0 : 28.0;
    final bg = node.active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.18);
    final fg = node.active ? navy : Colors.white;
    final countSize = node.active ? 13.0 : 11.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: node.active
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
            ),
            child: Text(
              node.count.toString(),
              style: TextStyle(
                fontSize: countSize,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            node.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: node.active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connector between two adjacent pipeline nodes.
///
/// **Visual rule:**
///   • When [active] is `true`  → a single solid line.
///   • When [active] is `false` → an evenly spaced dashed line.
///
/// **When is [active] true?** Owned by [StatusPipelineStrip], which
/// flips a connector to active when *either* of the two nodes it
/// joins is the active filter target. With no filter applied (the
/// default, "Semua"), no node is active and every connector renders
/// dashed.
///
/// **Dash painting** uses a [CustomPainter] with fixed dash width
/// (4 px) and gap (4 px) so the pattern is identical regardless of
/// the connector's available width. The previous implementation laid
/// out N `SizedBox` dashes inside a `Row(spaceBetween)`, which made
/// the gap depend on `(width - N*dashWidth) / (N-1)`. If that worked
/// out to ~0 the dashes touched and the connector read as a solid
/// line — the bug surfaced as one mysterious solid connector among
/// otherwise-dashed neighbours when the `Expanded` flex doled out
/// slightly different widths.
class _PipelineConnector extends StatelessWidget {
  final bool active;
  const _PipelineConnector({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Colors.white.withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.30);
    // The active circle is 36 px → its vertical centre sits at y=18
    // from the top of the dot Column. Inactive circles are 28 px but
    // their Column is cross-axis-centred inside the Row (which sizes
    // to the tallest child Column), so every circle centre lands at
    // the same y. Pin the connector at top:17 so its 2 px line
    // intersects the circle centreline exactly.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 17, 4, 0),
      child: SizedBox(
        height: 2,
        child: CustomPaint(
          painter: _ConnectorPainter(color: color, solid: active),
        ),
      ),
    );
  }
}

/// Paints a 2 px horizontal stroke across the canvas. When [solid] is
/// true the stroke is continuous; otherwise it's dashed with a fixed
/// `4 px on / 4 px off` rhythm — identical regardless of available
/// width, so neighbouring connectors that get slightly different
/// widths from `Expanded`'s flex distribution still read as the same
/// dashed pattern.
class _ConnectorPainter extends CustomPainter {
  final Color color;
  final bool solid;
  static const double _dash = 4;
  static const double _gap = 4;

  const _ConnectorPainter({required this.color, required this.solid});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;

    if (solid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    var x = 0.0;
    while (x < size.width) {
      final end = (x + _dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x = end + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.color != color || old.solid != solid;
}

// =====================================================================
// TingkatGroupCard
// =====================================================================

enum KelasStatusTone { good, warn, bad }

extension KelasStatusToneTokens on KelasStatusTone {
  Color get bg {
    switch (this) {
      case KelasStatusTone.good:
        return const Color(0xFFF1F5F9);
      case KelasStatusTone.warn:
        return const Color(0xFFFFFBEB);
      case KelasStatusTone.bad:
        return const Color(0xFFFEF2F2);
    }
  }

  Color get fg {
    switch (this) {
      case KelasStatusTone.good:
        return const Color(0xFF0F172A);
      case KelasStatusTone.warn:
        return const Color(0xFF92400E);
      case KelasStatusTone.bad:
        return const Color(0xFF991B1B);
    }
  }

  Color get kickerFg {
    switch (this) {
      case KelasStatusTone.good:
        return const Color(0xFF64748B);
      case KelasStatusTone.warn:
        return const Color(0xFF92400E);
      case KelasStatusTone.bad:
        return const Color(0xFF991B1B);
    }
  }
}

class KelasMiniChipData {
  final String id;
  final String label;
  final String statusLabel;
  final KelasStatusTone tone;

  const KelasMiniChipData({
    required this.id,
    required this.label,
    required this.statusLabel,
    required this.tone,
  });
}

class TingkatGroupCard extends StatefulWidget {
  final int tingkat;
  final int classCount;
  final int studentCount;
  final int reviewedPct;
  final bool alert;
  final List<KelasMiniChipData> classes;
  final void Function(String classId)? onChipTap;
  final void Function(String classId)? onChipLongPress;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry margin;

  /// Currently bulk-selected class IDs — chips in this set
  /// get a navy border highlight.
  final Set<String> selectedClassIds;

  const TingkatGroupCard({
    super.key,
    required this.tingkat,
    required this.classCount,
    required this.studentCount,
    required this.reviewedPct,
    this.alert = false,
    required this.classes,
    this.onChipTap,
    this.onChipLongPress,
    this.initiallyExpanded = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.selectedClassIds = const {},
  });

  @override
  State<TingkatGroupCard> createState() => _TingkatGroupCardState();
}

class _TingkatGroupCardState extends State<TingkatGroupCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final progressColor = widget.reviewedPct >= 80
        ? const Color(0xFF10B981)
        : widget.reviewedPct >= 30
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: widget.alert
            ? Border.all(color: const Color(0xFFFEE2E2), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tingkat ${widget.tingkat}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.alert
                              ? '${widget.classCount} kelas '
                                  '· ${widget.reviewedPct}% '
                                  'diperiksa · butuh perhatian'
                              : '${widget.classCount} kelas '
                                  '· ${widget.studentCount} '
                                  'siswa · '
                                  '${widget.reviewedPct}% '
                                  'diperiksa',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: widget.alert
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: widget.alert
                                ? const Color(0xFFDC2626)
                                : ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Alert dot (mockup: red dot top-right)
                  if (widget.alert)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(
                        right: 4,
                        top: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: ColorUtils.slate500,
                  ),
                ],
              ),
              // Hide the progress track entirely when there's nothing
              // to show — an empty 0% bar collapses to a thin slate200
              // line at the bottom of the card and reads as a stray
              // border. The alert copy ("butuh perhatian") already
              // conveys the empty state.
              if (widget.reviewedPct > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (widget.reviewedPct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: ColorUtils.slate200,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in widget.classes)
                      _KelasMiniChip(
                        data: c,
                        selected: widget.selectedClassIds
                            .contains(c.id),
                        onTap: widget.onChipTap == null
                            ? null
                            : () => widget.onChipTap!(c.id),
                        onLongPress:
                            widget.onChipLongPress == null
                                ? null
                                : () => widget
                                    .onChipLongPress!(c.id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KelasMiniChip extends StatelessWidget {
  final KelasMiniChipData data;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _KelasMiniChip({
    required this.data,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Material(
      color: data.tone.bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 78,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: data.tone.bg,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: navy, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: data.tone.kickerFg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: data.tone.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
