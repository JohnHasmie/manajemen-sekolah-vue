import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';

/// Mixin for tour/tutorial functionality.
mixin AdminReportCardTourMixin on ConsumerState<AdminReportCardScreen> {
  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('raport_screen', 'admin');
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
      AppLogger.error('report_card', e);
    }
  }

  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
    if (targets.isEmpty) return;

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
        getIt<ApiTourService>().completeTour(
          name: 'admin_raport_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_screen', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_raport_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_screen', 'admin'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: 'RaportClassSelector',
        keyTarget: selectClassKey,
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
                      'en': 'Select Class',
                      'id': 'Pilih Kelas',
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
                            'Choose a class to view and manage '
                            'students\' records here.',
                        'id':
                            'Pilih kelas untuk melihat dan '
                            'mengelola raport siswa.',
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
        identify: 'RaportStudentList',
        keyTarget: studentListKey,
        alignSkip: Alignment.bottomRight,
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
                      'en': 'Student List',
                      'id': 'Daftar Siswa',
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
                            'Tap on a student to see or edit their '
                            'individual raport details.',
                        'id':
                            'Ketuk pada siswa untuk melihat atau '
                            'mengedit detail raport mereka secara '
                            'individu.',
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
        identify: 'RaportExportBtn',
        keyTarget: exportBtnKey,
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
                      'en': 'Export to Excel',
                      'id': 'Ekspor ke Excel',
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
                            'Download the whole class raport data '
                            'in an Excel format.',
                        'id':
                            'Unduh seluruh data raport kelas dalam '
                            'format Excel.',
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
        identify: 'RaportPublishBtn',
        keyTarget: publishBtnKey,
        alignSkip: Alignment.topLeft,
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
                      'en': 'Publish Raport',
                      'id': 'Publikasikan Raport',
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
                            'Publish the raport and send a '
                            'notification directly to the '
                            'parents/guardians.',
                        'id':
                            'Publikasikan raport dan kirim notifikasi '
                            'langsung kepada wali murid.',
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

  // Abstract properties
  LanguageProvider get languageProvider;
  GlobalKey get selectClassKey;
  GlobalKey get studentListKey;
  GlobalKey get exportBtnKey;
  GlobalKey get publishBtnKey;
}
