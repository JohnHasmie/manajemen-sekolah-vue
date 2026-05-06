// Admin Raport hub shared components — Mockup #08.
//
// Three widgets:
//   • PipelineNode model — N-tuple drives the hub's status pipeline.
//   • RaportPipelineCard — body-card variant rendering circles with
//                          uniform sizing + a dashed connector aligned
//                          to the circle centerline. Used after the
//                          gradient-hero refactor.
//   • TingkatGroupCard   — Collapsible card with header (tingkat,
//                          class+student count, %-reviewed bar) +
//                          expanded grid of per-kelas mini-chips.
//
// All three are pure presentation widgets keyed off the
// /api/raports/admin-pipeline response shape.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// PipelineNode
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

// =====================================================================
// RaportPipelineCard
// =====================================================================
//
// Body-card variant of [StatusPipelineStrip] for the admin Raport hub
// after the gradient-hero refactor. Renders the same N nodes, but on a
// white card with slate text and brand-navy active states.
//
// Layout rules
// ------------
//   • Each node: 36×36 circle with the count, then 6dp gap, then
//     a label. All circles are the SAME size — the active state
//     changes fill/text color, never size, so the centerline never
//     drifts (was a long-running bug in the old gradient strip).
//   • Connectors: dashed (or solid if active) horizontal line whose
//     `SizedBox(height: 36)` matches the circle's height. With the
//     row laid out at `CrossAxisAlignment.start`, the connector
//     paints its 2dp line at `size.height/2 = 18`, which is exactly
//     the circle's vertical center. Labels hang below the connector
//     row's top 36dp and never cross the line.
//
// Caption slot
// ------------
// Optional `caption` (e.g. "Periode 2025/2026 · Genap" or just the
// total class count) renders above the node row in a small all-caps
// header. Tap-target on each node still works and `onNodeTap` writes
// back the same `PipelineNode.key` the gradient version does so the
// hub controller's filter logic stays unchanged.
class RaportPipelineCard extends StatelessWidget {
  final List<PipelineNode> nodes;
  final ValueChanged<String>? onNodeTap;
  final String? caption;
  final EdgeInsetsGeometry margin;

  const RaportPipelineCard({
    super.key,
    required this.nodes,
    this.onNodeTap,
    this.caption,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ColorUtils.slate200, width: 0.75),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            // Same lift `BrandKpiStrip` uses so the card reads as a
            // floating overlay when its top tucks into the gradient.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'PIPELINE STATUS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.6,
                  ),
                ),
                if (caption != null && caption!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '· $caption',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate300,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Cross-axis start so the 36dp connector tucks against
            // the top of the row — its painted center line at y=18
            // lands exactly on the circle's vertical center.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < nodes.length; i++) ...[
                  _RaportPipelineNode(
                    node: nodes[i],
                    onTap: onNodeTap == null
                        ? null
                        : () => onNodeTap!(nodes[i].key),
                  ),
                  if (i < nodes.length - 1)
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: CustomPaint(
                          painter: _RaportConnectorPainter(
                            active:
                                nodes[i].active || nodes[i + 1].active,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RaportPipelineNode extends StatelessWidget {
  final PipelineNode node;
  final VoidCallback? onTap;

  const _RaportPipelineNode({required this.node, this.onTap});

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final isActive = node.active;

    final Color circleBg = isActive ? navy : Colors.white;
    final Color circleBorder = isActive ? navy : ColorUtils.slate200;
    final Color circleText = isActive ? Colors.white : navy;
    final Color labelText = isActive ? navy : ColorUtils.slate500;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
              border: Border.all(color: circleBorder, width: 1.5),
            ),
            child: Text(
              node.count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: circleText,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            node.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: labelText,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Body-card connector — renders a 2dp horizontal line at the vertical
/// center of its `size.height = 36` slot, which puts it exactly on the
/// circle's centerline. Solid when either neighbour node is active,
/// dashed otherwise.
class _RaportConnectorPainter extends CustomPainter {
  final bool active;
  static const double _dash = 4;
  static const double _gap = 4;

  const _RaportConnectorPainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final navy = ColorUtils.getRoleColor('admin');
    final paint = Paint()
      ..color = active
          ? navy.withValues(alpha: 0.55)
          : ColorUtils.slate300
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;

    if (active) {
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
  bool shouldRepaint(covariant _RaportConnectorPainter old) =>
      old.active != active;
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
