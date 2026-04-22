import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Builds the role toggle component for switching
/// between teaching and homeroom views.
mixin AttendanceUIRoleToggleMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──
  Color get primaryColor;
  bool get isHomeroomView;
  set isHomeroomView(bool v);

  Map<String, dynamic>? get selectedHomeroomClass;
  List<dynamic> get homeroomClassesList;

  Future<void> forceRefresh();

  // ─────────────────────────────────────────
  // ROLE TOGGLE
  // ─────────────────────────────────────────

  Widget buildRoleToggle(LanguageProvider lp) {
    final p = primaryColor;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRoleToggleIndicator(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoleOption(
                lp,
                p,
                icon: Icons.person_outline_rounded,
                label: lp.getTranslatedText({
                  'en': 'Teaching',
                  'id': 'Mengajar',
                }),
                active: !isHomeroomView,
                onTap: () {
                  if (isHomeroomView) {
                    setState(() {
                      isHomeroomView = false;
                    });
                    forceRefresh();
                  }
                },
              ),
              _buildRoleOption(
                lp,
                p,
                icon: Icons.class_outlined,
                label: _buildRoleLabel(lp),
                active: isHomeroomView,
                onTap: () {
                  if (!isHomeroomView) {
                    setState(() {
                      isHomeroomView = true;
                    });
                    forceRefresh();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleToggleIndicator() {
    return AnimatedAlign(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: isHomeroomView ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildRoleLabel(LanguageProvider lp) {
    if (isHomeroomView && selectedHomeroomClass != null) {
      final name =
          selectedHomeroomClass!['name'] ??
          selectedHomeroomClass!['nama'] ??
          '';
      return 'Kelas $name';
    }
    return lp.getTranslatedText({'en': 'Homeroom', 'id': 'Wali Kelas'});
  }

  Widget _buildRoleOption(
    LanguageProvider lp,
    Color p, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? p : Colors.white.withValues(alpha: 0.9);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
