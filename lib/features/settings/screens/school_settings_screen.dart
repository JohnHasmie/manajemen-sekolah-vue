// School settings hub - navigation to school info and time settings sub-screens.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/admin/settings/school.vue` - a menu page linking to:
// 1. General settings (school name, address, level)
// 2. Time settings (lesson hours per day)
//
// Includes a guided tour feature (tutorial coach marks) for first-time users.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/settings/screens/school_level_settings_screen.dart';
import 'package:manajemensekolah/features/settings/screens/time_settings_screen.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

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
/// Manages the guided tour feature. setState() triggers re-render like Vue's reactivity.
class _SchoolSettingsScreenState extends ConsumerState<SchoolSettingsScreen> {
  String? _tourId;
  final GlobalKey _generalSettingsKey = GlobalKey();
  final GlobalKey _timeSettingsKey = GlobalKey();

  /// Like Vue's `mounted()` - checks if a guided tour should be shown after a short delay.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('school_settings', 'admin');
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('settings', e);
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save(CacheKeyBuilder.tourStatus('school_settings', 'admin'), {'should_show': false});
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save(CacheKeyBuilder.tourStatus('school_settings', 'admin'), {'should_show': false});
        return true;
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "GeneralSettingsCard",
        keyTarget: _generalSettingsKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'General Settings',
                      'id': 'Pengaturan Umum',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Manage school information and view active levels.',
                        'id':
                            'Kelola informasi sekolah dan atur jenjang pendidikan.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "TimeSettingsCard",
        keyTarget: _timeSettingsKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Time Settings',
                      'id': 'Pengaturan Waktu',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Configure schedules and learning time for your school.',
                        'id':
                            'Atur jadwal pelajaran dan waktu pembelajaran di sekolah.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);

    final menuItems = [
      _MenuItem(
        key: _generalSettingsKey,
        title: AppLocalizations.generalSettings.tr,
        subtitle: 'Jenjang & informasi sekolah',
        icon: Icons.school_rounded,
        color: ColorUtils.getColorForIndex(0),
        onTap: () => AppNavigator.push(context, SchoolLevelSettingsScreen()),
      ),
      _MenuItem(
        key: _timeSettingsKey,
        title: AppLocalizations.timeSettings.tr,
        subtitle: 'Jadwal & waktu pembelajaran',
        icon: Icons.access_time_rounded,
        color: ColorUtils.getColorForIndex(2),
        onTap: () => AppNavigator.push(context, TimeSettingsScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Custom Gradient Header
          Container(
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
                colors: [
                  ColorUtils.corporateBlue600,
                  ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.getTranslatedText(AppLocalizations.schoolSettings),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kelola pengaturan sekolah',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body content
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ColorUtils.corporateBlue600.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: ColorUtils.corporateBlue600,
                              size: 17,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            lang.getTranslatedText(
                              AppLocalizations.settingsMenu,
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) =>
                          _buildMenuCard(menuItems[index]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(_MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: item.key,
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: ColorUtils.slate500,
                      size: 18,
                    ),
                  ),
                ],
              ),
              Spacer(),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                item.subtitle,
                style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final GlobalKey key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
