// School settings hub - navigation to school info and time settings sub-screens.
//
// Like `pages/admin/settings/school.vue` - a menu page linking to:
// 1. General settings (school name, address, level)
// 2. Time settings (lesson hours per day)
//
// Includes a guided tour feature (tutorial coach marks) for first-time users.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/settings/presentation/screens/mixins/tour_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/mixins/ui_mixin.dart';

/// School settings hub screen - navigates to sub-settings pages.
///
/// This is a [StatefulWidget] because it manages the guided tour state.
/// Like a Vue page with `mounted()` that checks if a tour should be shown.
class SchoolSettingsScreen extends ConsumerStatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  ConsumerState createState() => _SchoolSettingsScreenState();
}

/// Mutable state for [SchoolSettingsScreen].
/// Manages the guided tour feature and UI rendering.
class _SchoolSettingsScreenState extends ConsumerState<SchoolSettingsScreen>
    with TourMixin, UIMixin {
  final GlobalKey _generalSettingsKey = GlobalKey();
  final GlobalKey _timeSettingsKey = GlobalKey();

  @override
  GlobalKey get generalSettingsKey => _generalSettingsKey;

  @override
  GlobalKey get timeSettingsKey => _timeSettingsKey;

  /// Like Vue's `mounted()` - checks if tour should show after delay.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkAndShowTour();
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildMainScaffold();
  }
}
