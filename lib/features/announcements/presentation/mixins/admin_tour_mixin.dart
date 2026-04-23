import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';

/// Mixin for admin announcement tour/tutorial logic.
///
/// Provides onboarding tour functionality for admin users.
mixin AdminTourMixin on ConsumerState<AdminAnnouncementScreen> {
  GlobalKey? get addKey;

  GlobalKey? get searchKey;

  GlobalKey? get filterKey;

  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('announcement', 'admin');
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('announcement', 'Error checking tour status: $e');
    }
  }

  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
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
        completeTourAndSaveCache();
      },
      onSkip: () {
        completeTourAndSaveCache();
        return true;
      },
    ).show(context: context);
  }

  void completeTourAndSaveCache() {
    getIt<ApiTourService>().completeTour(
      name: 'admin_announcement_tour',
      role: 'admin',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('announcement', 'admin'),
      {'should_show': false},
    );
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    if (addKey != null) {
      targets.add(
        TargetFocus(
          identify: 'AnnouncementAdd',
          keyTarget: addKey!,
          alignSkip: Alignment.bottomRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Create Announcement',
                        'id': 'Buat Pengumuman',
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
                              'Tap here to create a new announcement for '
                              'school users.',
                          'id':
                              'Ketuk di sini untuk membuat pengumuman baru '
                              'bagi pengguna sekolah.',
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
    }

    if (searchKey != null) {
      targets.add(
        TargetFocus(
          identify: 'AnnouncementSearch',
          keyTarget: searchKey!,
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
                        'en': 'Search Announcements',
                        'id': 'Cari Pengumuman',
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
                              'Quickly find announcements by title or '
                              'content keywords.',
                          'id':
                              'Temukan pengumuman dengan cepat berdasarkan '
                              'judul atau kata kunci konten.',
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
    }

    if (filterKey != null) {
      targets.add(
        TargetFocus(
          identify: 'AnnouncementFilter',
          keyTarget: filterKey!,
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
                        'en': 'Filter Options',
                        'id': 'Opsi Filter',
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
                              'Narrow down announcements by priority, '
                              'target role, or status.',
                          'id':
                              'Persempit pengumuman berdasarkan prioritas, '
                              'peran target, atau status.',
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
    }

    return targets;
  }
}
