// View-mode toggle strip + enum for the admin Jadwal hub.
//
// Extracted verbatim from `admin_schedule_management_screen.dart` during
// the Phase-2 readability split. Behaviour is unchanged — the strip is a
// pure StatelessWidget driven by [mode] + [onChanged], and the enum keeps
// its original name + ordering so the screen and its body builder read it
// without any call-site changes.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// View modes for the admin Jadwal hub.
///
/// Local to the schedule feature (not promoted to the shared
/// `ViewToggleButton.ViewMode` enum) because the labels + ordering are
/// schedule-specific (Grid is the new mockup default; Matrix is the
/// legacy timetable; List is the existing card list).
enum ScheduleViewMode { grid, list, matrix }

/// 2-tab view toggle strip — Grid · List.
///
/// The legacy "Matrix" tab was dropped: it rendered a row=time × col=day
/// table (`AdminScheduleMatrixView`) which the new Grid view supersedes
/// on every dimension (color coding, drag-drop, now-line, density
/// layout, zoom-in day view). The matrix widget file stays on disk for
/// now but is no longer reachable from the UI.
class ScheduleViewToggleStrip extends StatelessWidget {
  const ScheduleViewToggleStrip({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ScheduleViewMode mode;
  final ValueChanged<ScheduleViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _tab(
            label: 'Grid',
            icon: Icons.grid_view_rounded,
            active: mode == ScheduleViewMode.grid,
            onTap: () => onChanged(ScheduleViewMode.grid),
          ),
          _tab(
            label: 'List',
            icon: Icons.view_agenda_outlined,
            active: mode == ScheduleViewMode.list,
            onTap: () => onChanged(ScheduleViewMode.list),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? ColorUtils.brandDarkBlue : ColorUtils.slate600,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: active
                      ? ColorUtils.brandDarkBlue
                      : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
