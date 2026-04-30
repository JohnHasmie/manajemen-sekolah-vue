// Active-slice cycle controller for `BrandKpiCarousel`.
//
// What this is
// ------------
// The KPI strip on the dashboard auto-cycles through "slices" — anak
// for parent, kelas-yang-diajar for guru, etc. — every few seconds so
// the user can see all their contexts without manually switching.
// This file owns the cycle:
//
//   • holds the current slice index
//   • advances it on a 6-second timer
//   • exposes an animated 0..1 `fillFraction` per tick so each card
//     can paint a Stories-style filling segment
//   • pauses the cycle for 30 s when the user taps a card
//   • can be paused externally (during a scroll gesture)
//   • resets cleanly when total changes (school-switch, child added)
//
// Family-keyed by a string scope so multiple carousels — currently
// just dashboard-home, but anticipating future per-tab strips —
// don't collide. Pattern matches `shellProvider(role)` in this codebase.
//
// Riverpod 3.x note: legacy `StateProvider` lives in
// `flutter_riverpod/legacy.dart`; we use a regular [Notifier] family
// here because we need a Timer + AnimationController-style tick, not a
// passive value holder.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public, immutable snapshot consumed by `BrandKpiCarousel` and the
/// per-card progress strips.
@immutable
class ActiveSliceState {
  /// Total number of slices being cycled. 0 or 1 disables the cycle.
  final int total;

  /// Current slice index, 0..total-1.
  final int activeIndex;

  /// 0..1 fill of the active segment for the current frame.
  final double fillFraction;

  /// True when the cycle is paused (user tapped, or scroll active).
  final bool paused;

  const ActiveSliceState({
    required this.total,
    required this.activeIndex,
    required this.fillFraction,
    required this.paused,
  });

  factory ActiveSliceState.empty() => const ActiveSliceState(
    total: 0,
    activeIndex: 0,
    fillFraction: 0,
    paused: false,
  );

  ActiveSliceState copyWith({
    int? total,
    int? activeIndex,
    double? fillFraction,
    bool? paused,
  }) {
    return ActiveSliceState(
      total: total ?? this.total,
      activeIndex: activeIndex ?? this.activeIndex,
      fillFraction: fillFraction ?? this.fillFraction,
      paused: paused ?? this.paused,
    );
  }
}

/// How long each slice stays visible before advancing.
const Duration kSliceDwell = Duration(seconds: 6);

/// How long taps pause the cycle for (gives the user a moment to
/// read the "tapped" slice before auto-advance resumes).
const Duration kSliceTapPause = Duration(seconds: 30);

/// How often the fill animation ticks. ~33ms = ~30fps; fine for a
/// thin progress bar — anything finer wastes battery.
const Duration kSliceTick = Duration(milliseconds: 33);

/// Notifier that owns the cycle state for one carousel scope.
class ActiveSliceNotifier extends Notifier<ActiveSliceState> {
  /// The scope key the family was instantiated with — kept so we can
  /// log it if we ever want to. Not currently used at runtime.
  final String scope;

  Timer? _tickTimer;
  Timer? _resumeTimer;
  DateTime? _slotStartedAt;

  ActiveSliceNotifier(this.scope);

  @override
  ActiveSliceState build() {
    ref.onDispose(_cancelTimers);
    return ActiveSliceState.empty();
  }

  // ----- public API used by widgets -----

  /// Set or update the total number of slices. Resets to slice 0 when
  /// total changes meaningfully (e.g., parent adds an anak, school
  /// switches change which children are in scope).
  void setTotal(int total) {
    if (total == state.total) return;
    _cancelTimers();
    if (total <= 1) {
      // No cycle needed — render flat.
      state = ActiveSliceState(
        total: total,
        activeIndex: 0,
        fillFraction: 0,
        paused: false,
      );
      return;
    }
    state = ActiveSliceState(
      total: total,
      activeIndex: 0,
      fillFraction: 0,
      paused: false,
    );
    _startCycle();
  }

  /// Manually jump to a specific slice (e.g., user tapped the strip).
  /// Pauses the cycle for [kSliceTapPause] so the user can read.
  void jumpTo(int index) {
    if (state.total <= 1) return;
    final clamped = index.clamp(0, state.total - 1);
    _cancelTimers();
    state = state.copyWith(
      activeIndex: clamped,
      fillFraction: 0,
      paused: true,
    );
    _scheduleResume();
  }

  /// Pause the cycle (e.g., user is scrolling the page). Idempotent.
  void pause() {
    if (state.paused) return;
    _cancelTimers();
    state = state.copyWith(paused: true);
  }

  /// Resume the cycle from where it was. Idempotent.
  void resume() {
    if (!state.paused) return;
    _cancelResumeTimer();
    state = state.copyWith(paused: false);
    if (state.total > 1) _startCycle();
  }

  /// Tap-to-pause: same as [pause] but auto-resumes after
  /// [kSliceTapPause]. Use this from card onTap handlers.
  void notifyTap() {
    if (state.total <= 1) return;
    _cancelTimers();
    state = state.copyWith(paused: true);
    _scheduleResume();
  }

  // ----- internal ticking -----

  void _startCycle() {
    _slotStartedAt = DateTime.now();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(kSliceTick, (_) => _onTick());
  }

  void _onTick() {
    if (state.paused) return;
    final started = _slotStartedAt;
    if (started == null) return;
    final elapsed = DateTime.now().difference(started);
    final fill = elapsed.inMilliseconds / kSliceDwell.inMilliseconds;
    if (fill >= 1.0) {
      // Advance to next slice (loop).
      final next = (state.activeIndex + 1) % state.total;
      _slotStartedAt = DateTime.now();
      state = state.copyWith(activeIndex: next, fillFraction: 0);
    } else {
      state = state.copyWith(fillFraction: fill);
    }
  }

  void _scheduleResume() {
    _cancelResumeTimer();
    _resumeTimer = Timer(kSliceTapPause, () {
      if (!state.paused || state.total <= 1) return;
      state = state.copyWith(paused: false);
      _startCycle();
    });
  }

  void _cancelTimers() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _cancelResumeTimer();
  }

  void _cancelResumeTimer() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }
}

/// Family-keyed provider. Each carousel instance picks its own scope
/// string (e.g., 'parent_dashboard', 'guru_dashboard') so multiple
/// carousels don't share state.
final activeSliceProvider =
    NotifierProvider.family<ActiveSliceNotifier, ActiveSliceState, String>(
      ActiveSliceNotifier.new,
    );
