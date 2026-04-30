// Brand-aligned KPI carousel for dashboards.
//
// What this is
// ------------
// The shared "row of two large KPI cards" used by admin / guru / wali
// murid dashboards. Replaces the per-role hand-rolled HeroStatsRow
// invocations. One implementation, three role consumers — same
// "satu implementasi, tiga role" rule that the rest of the codebase
// follows.
//
// Two independent axes of interaction:
//
//   • Slice axis (auto-cycle) — anak / kelas / homeroom-vs-taught.
//     Driven by `activeSliceProvider`. Each card has a Stories-style
//     progress strip at its top edge that fills over [kSliceDwell],
//     then advances to the next slice. Single-slice configurations
//     skip the strip and render flat.
//
//   • Page axis (manual swipe) — when there are more than `perPage`
//     cards per slice, user swipes horizontally to flip pages. A dot
//     indicator below the strip tracks the current page. Single-page
//     configurations skip the dot indicator.
//
// The caller supplies:
//
//   • `scope`: stable string identifying this carousel's slice state
//     (e.g., 'parent_dashboard'). Multiple carousels with different
//     scopes don't share state.
//   • `slices`: list of opaque slice descriptors. The carousel only
//     uses `.length` and the index into it; values flow through to
//     [cardBuilder].
//   • `cardBuilder`: callback that maps `(sliceIndex)` to a list of
//     [HeroStatsCard] for that slice. Cards must NOT pass their own
//     `progress` — the carousel injects it.
//
// Why a builder (not pre-built lists): the cards' subtitle, value,
// trend, etc. all depend on the active slice. A builder keeps the
// caller's data lookup co-located with the card definition and makes
// it trivial to read `slices[i]` exactly once per slice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/active_slice_provider.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';

/// Builds the cards for a given slice index. Return value is the
/// flat list of cards for that slice; the carousel chunks them into
/// pages of [BrandKpiCarousel.perPage].
typedef KpiCardBuilder = List<HeroStatsCard> Function(int sliceIndex);

/// Shared dashboard KPI strip with auto-cycling slices and paginated
/// cards. See file header for the design rationale.
class BrandKpiCarousel extends ConsumerStatefulWidget {
  /// Stable family key for `activeSliceProvider` — keep it constant
  /// across rebuilds for one screen.
  final String scope;

  /// Total number of slices to cycle through. Pass `1` (or `0`) to
  /// disable the cycle and render the cards flat without progress
  /// strips.
  final int sliceCount;

  /// Per-slice card builder. Called with the active slice index every
  /// time the active slice changes. Should be cheap — typically a
  /// switch on the slice's pre-loaded data.
  final KpiCardBuilder cardBuilder;

  /// Number of cards rendered per page. Default 2 to match the admin
  /// hero pattern. If [cardBuilder] returns fewer cards than this,
  /// the carousel renders without paging chrome.
  final int perPage;

  /// Outer horizontal padding (matches the rest of the dashboard
  /// brand-page layout).
  final EdgeInsets padding;

  /// When true, the card pages auto-slide every [autoSlideDuration].
  /// Tapping a card pauses the auto-slide; tapping again resumes.
  final bool autoSlideCards;

  /// Duration between auto-slide page transitions.
  final Duration autoSlideDuration;

  const BrandKpiCarousel({
    super.key,
    required this.scope,
    required this.sliceCount,
    required this.cardBuilder,
    this.perPage = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.autoSlideCards = false,
    this.autoSlideDuration = const Duration(seconds: 5),
  });

  /// Default extent the carousel overlaps the gradient hero by, so
  /// callers can pass it to `BrandPageHeader.kpiOverlayHeight`.
  static const double defaultOverlap = 40;

  @override
  ConsumerState<BrandKpiCarousel> createState() => _BrandKpiCarouselState();
}

class _BrandKpiCarouselState extends ConsumerState<BrandKpiCarousel> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  bool _autoSlidePaused = false;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(activeSliceProvider(widget.scope).notifier)
          .setTotal(widget.sliceCount);
    });
  }

  @override
  void didUpdateWidget(covariant BrandKpiCarousel old) {
    super.didUpdateWidget(old);
    if (old.sliceCount != widget.sliceCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(activeSliceProvider(widget.scope).notifier)
            .setTotal(widget.sliceCount);
      });
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAutoSlide(int totalPages) {
    _autoSlideTimer?.cancel();
    if (!widget.autoSlideCards || totalPages <= 1) return;
    _autoSlideTimer = Timer.periodic(widget.autoSlideDuration, (_) {
      if (!mounted || _autoSlidePaused) return;
      final next = (_currentPage + 1) % totalPages;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _togglePause() {
    if (_autoSlidePaused) {
      setState(() => _autoSlidePaused = false);
      _startAutoSlide(_totalPages);
      ref.read(activeSliceProvider(widget.scope).notifier).resume();
    } else {
      setState(() => _autoSlidePaused = true);
      _autoSlideTimer?.cancel();
      ref.read(activeSliceProvider(widget.scope).notifier).notifyTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slice = ref.watch(activeSliceProvider(widget.scope));
    final cards = widget.cardBuilder(slice.activeIndex);

    if (cards.isEmpty) return const SizedBox.shrink();

    // Inject progress into each card.
    final wrappedCards = [
      for (final card in cards) _wrapCard(card, slice),
    ];

    // Chunk cards into pages of perPage (default 2).
    final pages = <List<HeroStatsCard>>[];
    for (var i = 0; i < wrappedCards.length; i += widget.perPage) {
      final end = (i + widget.perPage).clamp(0, wrappedCards.length);
      pages.add(wrappedCards.sublist(i, end));
    }

    // Start auto-slide when page count is known.
    if (_totalPages != pages.length) {
      _totalPages = pages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAutoSlide(pages.length);
      });
    }

    final showDots = pages.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: widget.padding,
          child: SizedBox(
            height: 120,
            child: pages.length <= 1
                ? _PageRow(cards: pages.first)
                : PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) =>
                        setState(() => _currentPage = i),
                    itemCount: pages.length,
                    itemBuilder: (_, pageIndex) =>
                        _PageRow(cards: pages[pageIndex]),
                  ),
          ),
        ),
        if (showDots) ...[
          const SizedBox(height: 8),
          _PageDots(total: pages.length, active: _currentPage),
        ],
      ],
    );
  }

  /// Inject the active-slice progress + a tap-pause wrapper into the
  /// card's existing tap handler. Re-creates the card with the same
  /// visuals — passes through everything except `progress` and `onTap`.
  HeroStatsCard _wrapCard(HeroStatsCard card, ActiveSliceState slice) {
    final originalTap = card.onTap;
    return HeroStatsCard(
      key: card.key,
      label: card.label,
      value: card.value,
      icon: card.icon,
      accentColor: card.accentColor,
      caption: card.caption,
      trend: card.trend,
      sliceLabel: card.sliceLabel,
      sliceLabelMuted: card.sliceLabelMuted,
      progress: slice.total > 1
          ? KpiProgress(
              total: slice.total,
              activeIndex: slice.activeIndex,
              fillFraction: slice.fillFraction,
            )
          : null,
      padding: card.padding,
      // Short tap = pause/play auto-slide. Navigation is via long press.
      onTap: _togglePause,
      onLongPress: originalTap,
    );
  }
}

/// One page worth of cards laid out side-by-side, equal width.
class _PageRow extends StatelessWidget {
  final List<HeroStatsCard> cards;

  const _PageRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Capsule + dot indicator used below the carousel when there's
/// more than one page. Active page is rendered as a 20×6 capsule;
/// inactive pages as 6×6 dots. Matches the v3 mockup.
class _PageDots extends StatelessWidget {
  final int total;
  final int active;

  const _PageDots({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active
                  ? const Color(0xFF1A8FBE)
                  : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
