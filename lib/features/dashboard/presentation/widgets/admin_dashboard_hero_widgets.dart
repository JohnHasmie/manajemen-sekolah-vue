// Hero-row leaf widgets for the admin dashboard body.
//
// Why this exists
// ---------------
// `admin_dashboard_body.dart` was inlining three small widgets used inside
// the navy gradient header — the realtime "connected" pill, the green
// pulsing dot it depends on, and the 36-square translucent icon button
// that sits on the gradient. None of them touch the dashboard state, so
// they pull cleanly into a co-located widgets file and drop ~150 lines
// from the screen body.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Subtle 1.5 s pulse on the green "connected" dot. Skips the animation
/// when [animate] is false so the stale/grey dot is a static marker.
///
/// Internal: `AdminDashboardRealtimePill` is the only consumer; exposed
/// publicly here so tests can drive the pill without instantiating the
/// whole dashboard.
class AdminDashboardPulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const AdminDashboardPulsingDot({
    super.key,
    required this.color,
    required this.animate,
  });

  @override
  State<AdminDashboardPulsingDot> createState() =>
      _AdminDashboardPulsingDotState();
}

class _AdminDashboardPulsingDotState extends State<AdminDashboardPulsingDot> {
  @override
  Widget build(BuildContext context) {
    // Static dot — the pulsing animation was causing parentDataDirty
    // framework assertions when the dashboard stayed mounted behind
    // pushed screens. A static dot is visually equivalent at 8px.
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

/// Inline "Terhubung realtime · HH:MM" / "Terakhir N menit lalu" pill
/// shown under the greeting in the navy gradient header. The dot is
/// green + animated when [isFresh]; grey + static otherwise.
class AdminDashboardRealtimePill extends StatelessWidget {
  final bool isFresh;
  final DateTime lastSync;

  const AdminDashboardRealtimePill({
    super.key,
    required this.isFresh,
    required this.lastSync,
  });

  @override
  Widget build(BuildContext context) {
    // Match SVG mockup line 27-28: small green dot (no pill bg) + faint
    // 10.5pt white-72% text inline. Goes UNDER the greeting/name row, ABOVE
    // the school pill.
    final dotColor = isFresh ? const Color(0xFF4ADE80) : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminDashboardPulsingDot(color: dotColor, animate: isFresh),
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
      return '${AppLocalizations.dbConnectedRealtime.tr}$hh:$mm';
    }
    final mins = DateTime.now().difference(lastSync).inMinutes;
    if (mins <= 0) return AppLocalizations.dbConnecting.tr;
    return '${AppLocalizations.dbLastUpdated.tr} $mins ${AppLocalizations.dbMinsAgo.tr}';
  }
}

/// A 36×36 white-translucent icon button used in the dashboard hero's
/// top row. Optional [showDot] paints a small red dot at top-right,
/// rendering the unread-notifications badge from the mockup.
class AdminDashboardHeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color gradientBg;
  final bool showDot;

  const AdminDashboardHeroIconButton({
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
