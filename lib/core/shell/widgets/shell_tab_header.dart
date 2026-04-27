// Shared header widget for shell tab roots.
//
// Lives at the top of every hub-style tab root (admin/teacher/parent
// hubs) and provides the gradient strip with title + subtitle. Mirrors
// the existing pattern from `data_management_screen.dart` but without
// a back button — the shell handles back-nav via `PopScope` on the
// `RoleShell` itself.
//
// Replaces 7 inline `_ShellTabHeader` copies that lived in each hub
// file before this widget was extracted.

import 'package:flutter/material.dart';

class ShellTabHeader extends StatelessWidget {
  /// Section title — typically the tab name in Indonesian (e.g.
  /// "Akademik", "Mengajar"). Renders bold white on the gradient.
  final String title;

  /// One-line subtitle describing what's in the tab. Renders muted
  /// white below the title.
  final String subtitle;

  /// Gradient + shadow accent. Pass the role color from
  /// `ColorUtils.getRoleColor('admin' | 'guru' | 'wali')` so each
  /// role's tabs stay on-brand.
  final Color accentColor;

  const ShellTabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withValues(alpha: 0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
