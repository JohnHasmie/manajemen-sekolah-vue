import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Builds the embedded bottom sheet header and
/// small icon widget helpers for the attendance UI.
mixin AttendanceUIEmbeddedMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──
  bool get compactMode;

  void setCompactMode(bool v);

  // ─────────────────────────────────────────
  // EMBEDDED HEADER
  // ─────────────────────────────────────────

  Widget buildEmbeddedHeader(LanguageProvider lp) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Row(
              children: [
                _buildIconBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lp.getTranslatedText({
                      'en': 'Take Attendance',
                      'id': 'Ambil Presensi',
                    }),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                _buildCompactToggle(),
                const SizedBox(width: 6),
                _buildCloseBtn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // SMALL WIDGET HELPERS
  // ─────────────────────────────────────────

  Widget _buildIconBox() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.fact_check_outlined,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildCompactToggle() {
    return GestureDetector(
      onTap: () => setState(() => setCompactMode(!compactMode)),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          compactMode
              ? Icons.view_agenda_outlined
              : Icons.density_small_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildCloseBtn() {
    return IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }

  // ─────────────────────────────────────────
  // STATIC HELPERS
  // ─────────────────────────────────────────

  static LinearGradient _getCardGradient() {
    final p = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [p, p.withValues(alpha: 0.7)],
    );
  }

  static Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');
}
