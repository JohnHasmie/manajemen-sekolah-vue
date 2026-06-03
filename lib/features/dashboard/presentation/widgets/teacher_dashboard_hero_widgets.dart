// Hero-row leaf widgets for the teacher dashboard body.
//
// Why this exists
// ---------------
// Mirrors `admin_dashboard_hero_widgets.dart` and
// `parent_dashboard_hero_widgets.dart` for the teacher role — the same
// RealtimePill + PulsingDot + HeroIconButton shapes the admin hero uses,
// driven from the same l10n keys (the teacher realtime caption flips
// EN/ID with the language picker just like admin).
//
// None of them touch the dashboard state, so they pull cleanly out of
// `teacher_dashboard_body.dart` and keep the screen focused on the
// guru slice carousel + the priority inbox + the quick-action grid.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Static dot rendered under the teacher realtime pill — green + soft
/// glow when [animate] is true, grey static otherwise.
///
/// Internal: `TeacherDashboardRealtimePill` is the only consumer; exposed
/// publicly here so tests can drive the pill without instantiating the
/// whole dashboard.
class TeacherDashboardPulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const TeacherDashboardPulsingDot({
    super.key,
    required this.animate,
    required this.color,
  });

  @override
  State<TeacherDashboardPulsingDot> createState() =>
      _TeacherDashboardPulsingDotState();
}

class _TeacherDashboardPulsingDotState
    extends State<TeacherDashboardPulsingDot> {
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
/// rendered inside the teal gradient teacher header. Drives the dot from
/// the same [isFresh] flag the screen polls.
class TeacherDashboardRealtimePill extends StatelessWidget {
  final bool isFresh;
  final DateTime lastSync;

  const TeacherDashboardRealtimePill({
    super.key,
    required this.isFresh,
    required this.lastSync,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isFresh ? ColorUtils.green400 : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeacherDashboardPulsingDot(color: dotColor, animate: isFresh),
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
    return '${AppLocalizations.dbLastUpdated.tr} $mins '
        '${AppLocalizations.dbMinsAgo.tr}';
  }
}

/// 36×36 white-translucent button rendered inside the teal gradient teacher
/// hero. [showDot] paints a small red dot at top-right (notification badge).
class TeacherDashboardHeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color gradientBg;
  final bool showDot;

  const TeacherDashboardHeroIconButton({
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
                color: ColorUtils.red500,
                shape: BoxShape.circle,
                border: Border.all(color: gradientBg, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
