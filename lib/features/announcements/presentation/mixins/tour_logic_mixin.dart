import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for tour tutorial logic.
///
/// Provides tour/tutorial functionality for announcement screens.
/// Requires the mixing class to extend ConsumerState with a
/// ParentAnnouncementScreen or compatible widget.
mixin TourLogicMixin on ConsumerState<ParentAnnouncementScreen> {
  String get userRole;
  List<dynamic> get filteredAnnouncement;
  GlobalKey? get searchKey;
  GlobalKey? get listKey;

  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'announcement_screen',
        userRole,
      );
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
      AppLogger.error('announcement', e);
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
        _completeTourAndSaveCache();
      },
      onSkip: () {
        _completeTourAndSaveCache();
        return true;
      },
    ).show(context: context);
  }

  void _completeTourAndSaveCache() {
    getIt<ApiTourService>().completeTour(
      name: 'announcement_screen_tour',
      role: 'walimurid',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('announcement_screen', userRole),
      {'should_show': false},
    );
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    if (searchKey != null) {
      targets.add(
        TargetFocus(
          identify: 'SearchBar',
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
                        'id': 'Pencarian Pengumuman',
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
                              'Quickly find specific announcements by '
                              'typing keywords here.',
                          'id':
                              'Temukan pengumuman spesifik dengan cepat '
                              'dengan mengetikkan kata kunci di sini.',
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

    if (filteredAnnouncement.isNotEmpty && listKey != null) {
      targets.add(
        TargetFocus(
          identify: 'AnnouncementList',
          keyTarget: listKey!,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 12,
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
                        'en': 'Important Updates',
                        'id': 'Pembaruan Penting',
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
                              'Tap any announcement card to read the '
                              'full details and download attachments '
                              'if available.',
                          'id':
                              'Ketuk kartu pengumuman mana saja untuk '
                              'membaca detail lengkap dan mengunduh '
                              'lampiran jika tersedia. Pengumuman yang '
                              'belum dibaca akan memiliki titik merah.',
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
