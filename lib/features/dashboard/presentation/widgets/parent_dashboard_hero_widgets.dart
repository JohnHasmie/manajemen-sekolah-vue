// Hero-row leaf widgets for the parent dashboard body.
//
// Why this exists
// ---------------
// Mirrors `admin_dashboard_hero_widgets.dart` for the parent role —
// the same RealtimePill + PulsingDot + HeroIconButton shapes the admin
// hero uses, but the parent strings stay literal Indonesian (no l10n
// key indirection for the realtime caption).
//
// Pulling them out of `parent_dashboard_body.dart` drops ~140 lines and
// keeps the screen focused on the per-child slice carousel + the
// quick-action grid.
import 'package:flutter/material.dart';

/// Static dot rendered under the parent realtime pill — green + soft
/// glow when [animate] is true, grey static otherwise.
class ParentDashboardPulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const ParentDashboardPulsingDot({
    super.key,
    required this.color,
    required this.animate,
  });

  @override
  State<ParentDashboardPulsingDot> createState() =>
      _ParentDashboardPulsingDotState();
}

class _ParentDashboardPulsingDotState extends State<ParentDashboardPulsingDot> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: widget.animate
            ? [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// "Terhubung realtime · HH:MM" / "Terakhir diperbarui N menit lalu" pill
/// rendered inside the violet gradient parent header. Drives the dot
/// from the same [isFresh] flag the screen polls.
class ParentDashboardRealtimePill extends StatelessWidget {
  final bool isFresh;
  final DateTime lastSync;

  const ParentDashboardRealtimePill({
    super.key,
    required this.isFresh,
    required this.lastSync,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isFresh ? const Color(0xFF4ADE80) : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParentDashboardPulsingDot(color: dotColor, animate: isFresh),
        const SizedBox(width: 8),
        Text(
          _buildLabel(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.72),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  String _buildLabel() {
    if (isFresh) {
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      return 'Terhubung realtime · $hh:$mm';
    }
    final mins = DateTime.now().difference(lastSync).inMinutes;
    if (mins <= 0) return 'Mencoba menyambungkan ulang…';
    return 'Terakhir diperbarui $mins menit lalu';
  }
}

/// 36×36 white-translucent button rendered inside the violet parent
/// gradient hero. [showDot] paints a small red notification badge at
/// top-right.
class ParentDashboardHeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color gradientBg;
  final bool showDot;

  const ParentDashboardHeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.gradientBg,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: gradientBg, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
