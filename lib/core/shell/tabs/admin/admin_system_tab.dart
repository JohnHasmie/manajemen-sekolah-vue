// Admin "Profil" (Profile/Settings) tab root.
//
// Existing `SystemSettingsScreen` (built in Phase 4 / T4.5) is already a
// hub for school profile, time settings, master-data, and account
// management — it slots in as the Profil tab without modification.
//
// The screen takes optional `schoolName` / `schoolLogoUrl` parameters
// for the SchoolPill in its hero. We don't have access to them at this
// level (they live in DashboardState), so we pass null — the screen
// falls back to its placeholder. Sub-PR 6 may revisit by either
// passing them through Riverpod or having SystemSettingsScreen pull
// from the dashboard provider directly.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/system_settings_screen.dart';

class AdminSystemTab extends StatelessWidget {
  const AdminSystemTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SystemSettingsScreen();
  }
}
