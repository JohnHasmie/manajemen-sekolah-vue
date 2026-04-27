import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A modern speed-dial style FAB for the grade recap screen.
///
/// Collapsed: a single circular `+` button in the primary color.
/// Expanded: rotates to `×`, reveals two labeled mini-FABs — `+ Bab` and
/// `Export` — stacked above with staggered fade + slide-in.
///
/// Tapping outside the expanded menu dismisses it (a soft scrim is painted
/// across the screen while open). The dial also auto-collapses after the
/// user picks an action.
class GradeRecapFab extends StatefulWidget {
  final Color primaryColor;
  final bool isExporting;
  final VoidCallback onAddChapter;
  final VoidCallback onExport;

  /// Optional keys so the onboarding tour can target the mini-FAB
  /// affordances. Passed through to the mini-FAB containers.
  final Key? addChapterKey;
  final Key? exportKey;

  const GradeRecapFab({
    super.key,
    required this.primaryColor,
    required this.isExporting,
    required this.onAddChapter,
    required this.onExport,
    this.addChapterKey,
    this.exportKey,
  });

  @override
  State<GradeRecapFab> createState() => GradeRecapFabState();
}

class GradeRecapFabState extends State<GradeRecapFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Programmatic open — used by the onboarding tour so it can spotlight
  /// the mini-FABs before coach-marking them.
  void expand() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _controller.forward();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // The widget occupies only the main FAB's bounds (56×56) so it can sit
    // inline in a Row next to the Simpan button. Mini-FABs overflow upward
    // via `Stack(clipBehavior: Clip.none)` so they float above the bottom
    // bar instead of inflating its height.
    const double mainFabSize = 56;
    const double miniFabSize = 44;
    const double gap = 12;
    // Vertical offsets measured from the bottom of the 56x56 main FAB.
    const double firstMiniBottom = mainFabSize + gap; // +Bab
    const double secondMiniBottom =
        mainFabSize + gap + miniFabSize + gap; // Export

    return SizedBox(
      width: mainFabSize,
      height: mainFabSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          // Export mini-FAB — farther from main FAB, appears first.
          Positioned(
            bottom: secondMiniBottom,
            right: 0,
            child: _MiniFab(
              key: widget.exportKey,
              label: 'Export',
              icon: Icons.download_rounded,
              color: ColorUtils.corporateBlue600,
              controller: _controller,
              intervalStart: 0.0,
              intervalEnd: 0.65,
              isLoading: widget.isExporting,
              onTap: () {
                _close();
                widget.onExport();
              },
            ),
          ),
          // +Bab mini-FAB — closer to main FAB, appears later.
          Positioned(
            bottom: firstMiniBottom,
            right: 0,
            child: _MiniFab(
              key: widget.addChapterKey,
              label: '+ Bab',
              icon: Icons.add_rounded,
              color: widget.primaryColor,
              controller: _controller,
              intervalStart: 0.15,
              intervalEnd: 0.85,
              onTap: () {
                _close();
                widget.onAddChapter();
              },
            ),
          ),
          // Main FAB — anchors the widget in its parent's layout.
          SizedBox(
            width: mainFabSize,
            height: mainFabSize,
            child: Material(
              color: widget.primaryColor,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: widget.primaryColor.withValues(alpha: 0.4),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggle,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _controller.value * 0.785, // 45°
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labeled mini-FAB. Animates in on an interval of the parent controller.
class _MiniFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final AnimationController controller;
  final double intervalStart;
  final double intervalEnd;
  final VoidCallback onTap;
  final bool isLoading;

  const _MiniFab({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.controller,
    required this.intervalStart,
    required this.intervalEnd,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutCubic),
      reverseCurve: Interval(
        intervalStart,
        intervalEnd,
        curve: Curves.easeInCubic,
      ),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final value = curved.value;
        return IgnorePointer(
          ignoring: value < 0.05,
          child: Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 16),
              child: child,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pill label — tappable too, for easier hit.
          Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: isLoading ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Icon button.
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: isLoading ? ColorUtils.slate400 : color,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: color.withValues(alpha: 0.35),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isLoading ? null : onTap,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
