import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Shows a modern themed date picker as a bottom sheet.
/// Matches the pattern used in add_activity_dialog.dart.
Future<DateTime?> showModernDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  String title = 'Pilih Tanggal',
  DateTime? firstDate,
  DateTime? lastDate,
  Color? primaryColor,
}) async {
  DateTime? result;
  final p = primaryColor ?? ColorUtils.getRoleColor('guru');
  DateTime tempDate = initialDate;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p, p.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          // Calendar — use ThemeData.light() to avoid inheriting global colorScheme.fromSeed
          SizedBox(
            height: 350,
            child: Theme(
              data: ThemeData(
                useMaterial3: true,
                primaryColor: p,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: p,
                  primary: p,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: ColorUtils.slate800,
                  secondary: p,
                ),
                datePickerTheme: DatePickerThemeData(
                  headerBackgroundColor: p,
                  headerForegroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.any(
                      (s) =>
                          s == WidgetState.selected || s == WidgetState.pressed,
                    )) {
                      return Colors.white;
                    }
                    return ColorUtils.slate800;
                  }),
                  dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.any(
                      (s) =>
                          s == WidgetState.selected || s == WidgetState.pressed,
                    )) {
                      return p;
                    }
                    return Colors.transparent;
                  }),
                  todayForegroundColor: WidgetStateProperty.all(p),
                  todayBackgroundColor: WidgetStateProperty.all(
                    p.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: CalendarDatePicker(
                  initialDate: tempDate,
                  firstDate: firstDate ?? DateTime(2024),
                  lastDate:
                      lastDate ?? DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (date) {
                    tempDate = date;
                  },
                ),
              ),
            ),
          ),
          // Footer
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  result = tempDate;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: p,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pilih Tanggal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return result;
}
