// The per-day column for the admin week-grid view.
//
// Extracted verbatim from `admin_schedule_week_grid_view.dart` during the
// Phase-2 readability split. Owns the drag-target hover state, the per-slot
// density grouping (lanes / cluster), and the lane / stack / cluster block
// renderers. Kept as a `part` file because it depends on the library-private
// `_BlockPalette`, `_SlotEntry`, `_SlotGroup`, and `_RenderMode` types.
part of 'admin_schedule_week_grid_view.dart';

// ─────────────────────────────────────────────────────────────────────
// Day column — schedule blocks positioned absolutely by start_time
// ─────────────────────────────────────────────────────────────────────

class _DayColumn extends StatefulWidget {
  final String dayId;
  final bool isToday;
  final bool isHighlighted;
  final int startMinutes;
  final int endMinutes;
  final double pxPerMinute;

  /// True when this column is rendering inside the single-day "focused"
  /// view (one day fills the full screen width). The extra horizontal
  /// real-estate lets each lane stay readable even when 4-6 sessions
  /// share a slot, so [_DayColumnState._computeSlotGroups] keeps lanes
  /// mode active up to 6 sessions instead of collapsing to a cluster
  /// card at 4 like it does in the cramped week grid.
  final bool isFocused;
  final List<Map<String, dynamic>> schedules;
  final List<_SlotEntry> slotsOnThisDay;
  final _BlockPalette Function(Map<String, dynamic>) paletteFor;
  final void Function(Map<String, dynamic>)? onTap;
  final void Function(Map<String, dynamic>)? onLongPress;
  final Future<void> Function({
    required Map<String, dynamic> schedule,
    required String newLessonHourDaysId,
    required String newDayId,
    required String newStartTime,
  })?
  onReschedule;
  final void Function(List<Map<String, dynamic>> sessions)? onSlotClusterTap;
  final void Function(List<Map<String, dynamic>> sessions)?
  onSlotClusterLongPress;

  /// Bulk-select state forwarded from the grid widget (TR.F).
  final Set<String> selectedIds;
  final bool isBulkMode;

  const _DayColumn({
    required this.dayId,
    required this.isToday,
    required this.isHighlighted,
    required this.startMinutes,
    required this.endMinutes,
    required this.pxPerMinute,
    required this.isFocused,
    required this.schedules,
    required this.slotsOnThisDay,
    required this.paletteFor,
    required this.onTap,
    required this.onLongPress,
    required this.onReschedule,
    required this.onSlotClusterTap,
    required this.onSlotClusterLongPress,
    required this.selectedIds,
    required this.isBulkMode,
  });

  @override
  State<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<_DayColumn> {
  /// The slot the user's finger is currently over (within ±30-min
  /// tolerance) while dragging. Null when nothing is dragged here, or
  /// when the finger is over a stretch of the column with no nearby
  /// lesson_hour — in that case the ghost is hidden as a visual cue
  /// that the drop will no-op.
  _SlotEntry? _hoveredSlot;

  /// Returns the slot on this day whose start_time is closest to
  /// [droppedMinutes], within a generous ±30-minute tolerance so the
  /// admin's drop doesn't need to be pixel-perfect. Returns null when
  /// the day has no slots or no slot is within tolerance.
  _SlotEntry? _nearestSlot(int droppedMinutes) {
    if (widget.slotsOnThisDay.isEmpty) return null;
    _SlotEntry? best;
    int bestDiff = 1 << 30;
    for (final slot in widget.slotsOnThisDay) {
      final diff = (slot.startMinutes - droppedMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = slot;
      }
    }
    if (best == null) return null;
    if (bestDiff > 30) return null;
    return best;
  }

  /// Translates a local y-coordinate inside the column into the nearest
  /// slot entry. Used by both [onMove] (for the ghost preview) and
  /// [onAcceptWithDetails] (for the actual drop resolution) so both
  /// paths agree on what slot the admin meant.
  _SlotEntry? _slotAtLocalY(double localY) {
    final droppedMinutes =
        widget.startMinutes + (localY / widget.pxPerMinute).round();
    return _nearestSlot(droppedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final hourCount = ((widget.endMinutes - widget.startMinutes) ~/ 60).clamp(
      1,
      24,
    );
    final dropEnabled =
        widget.onReschedule != null && widget.slotsOnThisDay.isNotEmpty;
    // Local aliases for fields read directly inside `build()`. Anything
    // referenced from `_buildBlock` reads through `widget.` instead
    // since `_buildBlock` is a separate method on the State.
    final startMinutes = widget.startMinutes;
    final pxPerMinute = widget.pxPerMinute;
    final schedules = widget.schedules;
    final onReschedule = widget.onReschedule;
    final dayId = widget.dayId;
    final isToday = widget.isToday;
    final isHighlighted = widget.isHighlighted;

    // Pre-compute slot groups so each cluster of sessions sharing a
    // start_time picks the right density bucket — `lanes` (≤3),
    // `stack` (4–5), or `cluster` (6+). This keeps the column readable
    // even when 21 classes are scheduled at the same lesson_hour.
    final groups = _computeSlotGroups(schedules);

    // Drag-hover state: figure out if the currently-hovered slot maps
    // to a high-density group, so we can hand the hover treatment to
    // the block itself (and suppress the generic ghost rectangle).
    final hoveredStartMin = _hoveredSlot?.startMinutes;
    _RenderMode? hoveredGroupMode;
    for (final g in groups) {
      if (g.startMinutes == hoveredStartMin) {
        hoveredGroupMode = g.renderMode;
        break;
      }
    }
    final hoveredIsHighDensity =
        hoveredGroupMode == _RenderMode.stack ||
        hoveredGroupMode == _RenderMode.cluster;

    final columnBody = LayoutBuilder(
      builder: (ctx, constraints) {
        final colWidth = constraints.maxWidth;
        return Stack(
          children: [
            // Hour-grid lines.
            Column(
              children: [
                for (var i = 0; i < hourCount; i++)
                  SizedBox(
                    height: 60 * pxPerMinute,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate100),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Session blocks — dispatch per group's render mode. The
            // group whose slot is currently being hovered gets a
            // `isHovered: true` flag so its renderer can light up.
            for (final group in groups)
              ..._renderGroup(
                group,
                hourCount,
                colWidth,
                isHovered: hoveredStartMin == group.startMinutes,
              ),
          ],
        );
      },
    );

    final styled = Container(
      decoration: BoxDecoration(
        color: isToday
            ? ColorUtils.brandDarkBlue.withValues(alpha: 0.03)
            : (isHighlighted
                  ? ColorUtils.brandCobalt.withValues(alpha: 0.04)
                  : Colors.white),
        border: Border(right: BorderSide(color: ColorUtils.slate100)),
      ),
      child: columnBody,
    );

    // Wire the DragTarget only when reschedule is supported. Without
    // [onReschedule] the column stays inert so drag drops on a
    // read-only viewer cleanly bounce back to the source.
    if (!dropEnabled) return styled;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        // Live preview — translate the global drop position to local y
        // inside this column and resolve the slot the admin's finger
        // currently hovers. Clears _hoveredSlot when no slot is within
        // tolerance (so the user sees no ghost in dead zones).
        final ro = context.findRenderObject() as RenderBox?;
        if (ro == null || !ro.hasSize) return;
        final localY = ro.globalToLocal(details.offset).dy;
        final hovered = _slotAtLocalY(localY);
        if (hovered?.lessonHourId != _hoveredSlot?.lessonHourId) {
          setState(() => _hoveredSlot = hovered);
        }
      },
      onLeave: (_) {
        if (_hoveredSlot != null) {
          setState(() => _hoveredSlot = null);
        }
      },
      onAcceptWithDetails: (details) async {
        final ro = context.findRenderObject() as RenderBox?;
        if (ro == null || !ro.hasSize) return;
        final localY = ro.globalToLocal(details.offset).dy;
        final slot = _slotAtLocalY(localY);
        // Clear the ghost immediately so it doesn't linger after drop.
        if (_hoveredSlot != null) {
          setState(() => _hoveredSlot = null);
        }
        if (slot == null) return;
        // No-op when the drop lands on the source slot.
        final currentLessonHourId = (details.data['lesson_hour_days_id'] ?? '')
            .toString();
        if (currentLessonHourId == slot.lessonHourId) return;
        await onReschedule!.call(
          schedule: details.data,
          newLessonHourDaysId: slot.lessonHourId,
          newDayId: dayId,
          newStartTime: slot.startTime,
        );
      },
      builder: (ctx, candidate, rejected) {
        final dragging = candidate.isNotEmpty;
        if (!dragging || _hoveredSlot == null) return styled;
        // High-density slots (stack / cluster) provide their own
        // hover feedback baked into the block — see
        // `_buildStackBlock` / `_buildClusterCard` `isHovered`. Skip
        // the generic ghost so we don't double-up the cobalt overlay
        // on top of an already-highlighted card.
        if (hoveredIsHighDensity) return styled;
        // Per-slot ghost: cobalt outlined rectangle at the resolved
        // target slot's position. Width spans the column minus the
        // standard 2px inset; height is derived from the slot's own
        // duration so the preview matches what will actually land.
        //
        // We deliberately *don't* tint the whole column — that visual
        // implied any drop point would succeed; we want the admin to
        // see where exactly the snap is going.
        final ghostTop =
            (_hoveredSlot!.startMinutes - startMinutes) * pxPerMinute;
        final ghostHeight = (_hoveredSlot!.durationMinutes * pxPerMinute).clamp(
          20.0,
          double.infinity,
        );
        return Stack(
          children: [
            styled,
            Positioned(
              top: ghostTop,
              left: 2,
              right: 2,
              height: ghostHeight,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorUtils.brandCobalt.withValues(alpha: 0.12),
                    border: Border.all(color: ColorUtils.brandCobalt, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _hoveredSlot!.startTime,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.brandCobalt,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Groups a day's schedules into per-slot buckets so each group can
  /// pick the right density mode (lanes / stack / cluster) for the
  /// number of sessions sharing the same start_time.
  ///
  /// School schedules in this app snap to fixed `lesson_hours`, so all
  /// sessions at the same hour share `start_time` exactly — bucketing
  /// by `start_time` cleanly separates each lesson_hour's row into its
  /// own group. The density bucket is then chosen by count:
  ///   * 1–3 sessions → [_RenderMode.lanes] (existing side-by-side path)
  ///   * 4–5 sessions → [_RenderMode.stack] (compact stacked mini-cards)
  ///   * 6+  sessions → [_RenderMode.cluster] (aggregator card)
  ///
  /// Within each group sessions are sorted by class_name for stable
  /// visual ordering. Returned list is sorted by start_time so earlier
  /// slots paint first inside the Stack.
  List<_SlotGroup> _computeSlotGroups(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const [];
    final byStart = <int, List<Map<String, dynamic>>>{};
    for (final s in items) {
      final startMin = AdminScheduleWeekGridView._parseMinutes(s['start_time']);
      if (startMin == null) continue;
      byStart.putIfAbsent(startMin, () => []).add(s);
    }

    final groups = <_SlotGroup>[];
    for (final entry in byStart.entries) {
      final start = entry.key;
      final sessions = entry.value;
      sessions.sort((a, b) {
        final ca = (a['class_name'] ?? a['kelas_nama'] ?? '').toString();
        final cb = (b['class_name'] ?? b['kelas_nama'] ?? '').toString();
        return ca.compareTo(cb);
      });

      // Use the max end_time across the group for the rendered height.
      // In practice every session in the group shares the same end_time
      // (they all reference the same lesson_hour), but the max guards
      // against staggered durations.
      var maxEnd = start;
      var anyConflict = false;
      for (final s in sessions) {
        final endMin = AdminScheduleWeekGridView._parseMinutes(s['end_time']);
        if (endMin != null && endMin > maxEnd) maxEnd = endMin;
        if (s.hasScheduleConflict) anyConflict = true;
      }
      final dur = (maxEnd - start).clamp(20, 240);

      // Two density buckets: lanes vs cluster. The stack bucket
      // previously sat between them (4–5) but rendered text unreadably
      // small on a 50px-wide column, so we collapse it into cluster
      // mode — the cluster card's count badge + tap-to-expand is more
      // useful than half-readable mini-cards.
      //
      // The lane-mode threshold is wider in focused mode (≤6) because
      // the single-day view spans the full screen width — 6 lanes
      // across ~340dp leaves each card ~52dp wide, which is still
      // legible. In the cramped week grid each day column is only
      // ~50dp wide, so we collapse to cluster mode at 4+ sessions.
      final laneThreshold = widget.isFocused ? 6 : 3;
      final mode = sessions.length <= laneThreshold
          ? _RenderMode.lanes
          : _RenderMode.cluster;

      groups.add(
        _SlotGroup(
          startMinutes: start,
          durationMinutes: dur,
          sessions: sessions,
          hasConflict: anyConflict,
          renderMode: mode,
        ),
      );
    }

    groups.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return groups;
  }

  /// Dispatches each group to the renderer that fits its density mode.
  ///
  /// [isHovered] is true when a drag is currently positioned over this
  /// group's slot — used by stack / cluster renderers to light up
  /// their borders + tint as a drop-zone affordance. Lanes mode uses
  /// the generic ghost overlay from the DragTarget builder instead.
  List<Widget> _renderGroup(
    _SlotGroup group,
    int hourCount,
    double colWidth, {
    bool isHovered = false,
  }) {
    switch (group.renderMode) {
      case _RenderMode.lanes:
        final widgets = <Widget>[];
        for (var i = 0; i < group.sessions.length; i++) {
          widgets.addAll(
            _buildBlock(
              group.sessions[i],
              hourCount,
              i,
              group.sessions.length,
              colWidth,
            ),
          );
        }
        return widgets;
      case _RenderMode.stack:
        return [_buildStackBlock(group, hourCount, isHovered: isHovered)];
      case _RenderMode.cluster:
        return [_buildClusterCard(group, hourCount, isHovered: isHovered)];
    }
  }

  List<Widget> _buildBlock(
    Map<String, dynamic> s,
    int hourCount,
    int lane,
    int totalLanes,
    double colWidth,
  ) {
    final startMin = AdminScheduleWeekGridView._parseMinutes(s['start_time']);
    final endMin = AdminScheduleWeekGridView._parseMinutes(s['end_time']);
    if (startMin == null || endMin == null || endMin <= startMin) {
      return const [];
    }
    final top = (startMin - widget.startMinutes) * widget.pxPerMinute;
    final height = (endMin - startMin) * widget.pxPerMinute;
    if (top < 0 || top > hourCount * 60 * widget.pxPerMinute) {
      return const [];
    }

    // Lane geometry: split the column width into [totalLanes] columns
    // when 2-3 sessions share the start_time, full width when there's
    // only one.
    const sideInset = 2.0;
    const laneGap = 1.0;
    final availableWidth = (colWidth - 2 * sideInset).clamp(0.0, 9999.0);
    final laneWidth = totalLanes <= 1
        ? availableWidth
        : (availableWidth - laneGap * (totalLanes - 1)) / totalLanes;
    final leftPos = sideInset + lane * (laneWidth + laneGap);
    final palette = widget.paletteFor(s);
    final subjectName = (s['subject_name'] ?? s['mata_pelajaran_nama'] ?? '—')
        .toString();
    final className = (s['class_name'] ?? s['kelas_nama'] ?? '').toString();
    final teacherName = (s['teacher_name'] ?? s['guru_nama'] ?? '').toString();
    final isConflict = s.hasScheduleConflict;

    // Inner card content — reused for the in-grid block AND the
    // LongPressDraggable feedback overlay so the drag preview matches
    // the original visual exactly (just rotated + shadowed).
    final cardContent = Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border(left: BorderSide(color: palette.border, width: 3)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isConflict) ...[
                Icon(Icons.warning_amber_rounded, size: 9, color: palette.fg),
                const SizedBox(width: 2),
              ],
              Expanded(
                child: Text(
                  subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: palette.fg,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          if (height > 26 && (className.isNotEmpty || teacherName.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                [
                  className,
                  if (teacherName.isNotEmpty) teacherName,
                ].where((e) => e.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: palette.fg.withValues(alpha: 0.85),
                  height: 1.1,
                ),
              ),
            ),
        ],
      ),
    );

    final blockHeight = height.clamp(18.0, double.infinity);
    final sessionId = (s['id'] ?? '').toString();
    final isSelected =
        sessionId.isNotEmpty && widget.selectedIds.contains(sessionId);

    // Gesture-arena policy on grid blocks:
    //   * Tap (any mode):
    //       - bulk-mode  → toggle selection (routes via onLongPress
    //                       so the screen reuses _toggleSelection)
    //       - otherwise → open the detail sheet
    //   * Long-press:
    //       - When drag is enabled (onReschedule != null) the
    //         enclosing LongPressDraggable owns the long-press —
    //         we must NOT register an inner onLongPress, otherwise
    //         the inner GestureDetector wins the arena and the
    //         block becomes a "toggle selection" instead of a
    //         draggable. This was the TR.F regression: drag stopped
    //         working in editable AY because the inner detector
    //         hijacked every long-press. Bulk-mode entry from the
    //         grid view is now via cluster-card long-press / list
    //         view long-press; long-press on a block always means
    //         "pick it up to reschedule".
    //       - When drag is disabled (read-only AY), keep the inner
    //         onLongPress as a no-op — there's no reason to enter
    //         bulk-mode in read-only since the bulk actions can't
    //         mutate anything.
    final dragEnabled = widget.onReschedule != null;
    final blockGesture = GestureDetector(
      onTap: widget.isBulkMode
          ? (widget.onLongPress == null ? null : () => widget.onLongPress!(s))
          : (widget.onTap == null ? null : () => widget.onTap!(s)),
      onLongPress: dragEnabled
          ? null
          : (widget.onLongPress == null ? null : () => widget.onLongPress!(s)),
      child: cardContent,
    );

    // Compose the visual: card + optional selection overlay (cobalt
    // outline + check-corner dot) when this session is in the bulk
    // selection set. The overlay sits inside the same bounding rect
    // so it doesn't disrupt the Stack/Positioned layout above.
    final visual = isSelected
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: blockGesture),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: ColorUtils.brandCobalt,
                        width: 2,
                      ),
                      color: ColorUtils.brandCobalt.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IgnorePointer(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: ColorUtils.brandCobalt,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.brandCobalt.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          )
        : blockGesture;

    // Drag stays enabled whenever the AY is editable — even mid
    // bulk-select. Initial TR.F shipping killed drag in bulk mode
    // to avoid the long-press gesture conflicting with "extend
    // selection", but that left the admin unable to reschedule once
    // they'd selected anything from the cluster card / list view.
    // The new model: long-press always initiates a drag (so reorder
    // is one gesture away even mid-select), and bulk-select is
    // extended via tap-on-block while [isBulkMode] is true (see the
    // tap gesture above, which routes to onLongPress in bulk mode).
    // Tap on a non-selected block in bulk mode adds it to the
    // selection — no drag required.
    final Widget interactive = widget.onReschedule == null
        ? visual
        : LongPressDraggable<Map<String, dynamic>>(
            // Press-and-hold for ~500ms before the block starts to
            // float — matches Flutter's default LongPressDraggable
            // timing so it doesn't fire on accidental scrolls.
            data: s,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragFeedbackCard(
              palette: palette,
              subjectName: subjectName,
              className: className,
              teacherName: teacherName,
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: DottedOutline(child: cardContent),
            ),
            child: visual,
          );

    return [
      Positioned(
        top: top,
        left: leftPos,
        width: laneWidth,
        height: blockHeight,
        child: interactive,
      ),
    ];
  }

  /// Stack mode renderer — 4–5 sessions at the same slot are too many
  /// for side-by-side lanes (each would shrink below ~24px) so we
  /// stack them vertically as compact mini-cards inside one positioned
  /// container that fills the slot's time range.
  ///
  /// Each mini-card carries the class + subject abbreviated to fit a
  /// 12dp row, and stays tappable so the admin can open the detail
  /// sheet. Drag is intentionally disabled in this mode — the cards
  /// are too short to grip cleanly; the detail sheet's "Pindah Slot"
  /// action covers the move-out flow.
  Widget _buildStackBlock(
    _SlotGroup group,
    int hourCount, {
    bool isHovered = false,
  }) {
    final top = (group.startMinutes - widget.startMinutes) * widget.pxPerMinute;
    final height = group.durationMinutes * widget.pxPerMinute;

    // Show up to 4 mini-cards; if more, the last row is a "+ N lagi"
    // hint so the count is still visible without overflowing the slot.
    const maxVisible = 4;
    final visible = group.sessions.take(maxVisible).toList();
    final overflow = group.sessions.length - visible.length;

    // Hover styling: cobalt-tinted background + thicker cobalt border
    // so the user sees this slot will receive the dropped session.
    final borderColor = isHovered
        ? ColorUtils.brandCobalt
        : (group.hasConflict
              ? ColorUtils.error600.withValues(alpha: 0.30)
              : ColorUtils.slate200);
    final bgColor = isHovered
        ? ColorUtils.brandCobalt.withValues(alpha: 0.08)
        : (group.hasConflict
              ? ColorUtils.error600.withValues(alpha: 0.04)
              : Colors.white);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height.clamp(36.0, double.infinity),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: borderColor, width: isHovered ? 2 : 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            for (final s in visible)
              Expanded(
                child: _StackMiniCard(
                  schedule: s,
                  palette: widget.paletteFor(s),
                  onTap: widget.onTap == null ? null : () => widget.onTap!(s),
                ),
              ),
            if (overflow > 0)
              Expanded(child: _StackOverflowPill(count: overflow)),
          ],
        ),
      ),
    );
  }

  /// Cluster mode renderer — 6+ sessions at one slot collapse to a
  /// single aggregator card. The card shows the count badge ("21 sesi"),
  /// a short preview of the subjects/classes mix, and a "▾ ketuk untuk
  /// lihat" hint. Tap opens an expansion sheet (wired in TR.I.5);
  /// long-press seeds bulk-select with all cluster session ids.
  Widget _buildClusterCard(
    _SlotGroup group,
    int hourCount, {
    bool isHovered = false,
  }) {
    final top = (group.startMinutes - widget.startMinutes) * widget.pxPerMinute;
    final height = group.durationMinutes * widget.pxPerMinute;

    // Aggregate stats — top-3 distinct subjects to preview.
    final subjects = <String>{};
    final classes = <String>{};
    for (final s in group.sessions) {
      final sub = (s['subject_name'] ?? s['mata_pelajaran_nama'] ?? '')
          .toString();
      if (sub.isNotEmpty) subjects.add(sub);
      final cls = (s['class_name'] ?? s['kelas_nama'] ?? '').toString();
      if (cls.isNotEmpty) classes.add(cls);
    }
    final topSubjects = subjects.take(3).join(' · ');
    final tally = '${subjects.length} mapel · ${classes.length} kelas';

    // Hover styling: thicker border + brighter gradient so a dragged
    // session lands on visible feedback. We override the conflict-red
    // border with cobalt while hovering so the user sees the drop is
    // accepted (not that there's a new conflict to fix).
    final borderColor = isHovered
        ? ColorUtils.brandCobalt
        : (group.hasConflict ? ColorUtils.error600 : ColorUtils.brandCobalt);
    final borderWidth = isHovered ? 2.5 : 1.5;
    final gradientColors = isHovered
        ? [
            ColorUtils.brandCobalt.withValues(alpha: 0.28),
            ColorUtils.brandCobalt.withValues(alpha: 0.14),
          ]
        : (group.hasConflict
              ? [
                  ColorUtils.error600.withValues(alpha: 0.16),
                  ColorUtils.brandCobalt.withValues(alpha: 0.10),
                ]
              : [
                  ColorUtils.brandCobalt.withValues(alpha: 0.14),
                  ColorUtils.brandCobalt.withValues(alpha: 0.06),
                ]);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height.clamp(40.0, double.infinity),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSlotClusterTap == null
            ? null
            : () => widget.onSlotClusterTap!(group.sessions),
        onLongPress: widget.onSlotClusterLongPress == null
            ? null
            : () => widget.onSlotClusterLongPress!(group.sessions),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          // Progressive disclosure: at very short heights (≤30dp inner
          // space) the card shows just the count badge; with a bit more
          // room the subject preview + hint stack in. LayoutBuilder is
          // the right tool here — `height` (slot duration) doesn't
          // account for padding / border chrome, so a `height > 36`
          // threshold would still overflow on 45-min slots in
          // compact-week mode (45 * 0.7 = 31.5px raw, ~22px inside the
          // chrome). Cluster content is purely informational and
          // tappable — clipping it instead of letting RenderFlex throw
          // is the right trade-off.
          child: ClipRect(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final inner = c.maxHeight;
                // Tier thresholds — measured against actual inner
                // height (padding + border already subtracted out).
                //   ≥48 → badge + 2-line preview + hint
                //   ≥34 → badge + 1-line preview
                //   <34 → badge only
                final showPreview = inner >= 34;
                final showTally = inner >= 48;
                final showHint = inner >= 48;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Count badge — red on conflict, navy otherwise.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: group.hasConflict
                              ? ColorUtils.error600
                              : ColorUtils.brandDarkBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${group.sessions.length} sesi',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (showPreview)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topSubjects,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: ColorUtils.brandCobalt,
                                  height: 1.1,
                                ),
                              ),
                              if (showTally)
                                Text(
                                  tally,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate700,
                                    height: 1.1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (showHint)
                      Text(
                        isHovered ? '↓ Lepas di sini' : '▾ ketuk',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: isHovered
                              ? ColorUtils.brandCobalt
                              : ColorUtils.slate500,
                          height: 1.1,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
