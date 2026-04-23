import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';

mixin AdminReportTourMixin on ConsumerState<AdminAttendanceReportScreen> {
  GlobalKey get searchKey;
  GlobalKey get filterKey;
  GlobalKey get moreKey;
  GlobalKey get infoKey;
  bool get isTourShowing;
  set isTourShowing(bool value);

  Future<void> checkAndShowTour() async {
    if (isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'presence_report',
        'admin',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted && !isTourShowing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !isTourShowing) showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('attendance', 'Error checking tour status: $e');
    }
  }

  void showTour() {
    final targets = createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    setState(() => isTourShowing = true);

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
        setState(() => isTourShowing = false);
        getIt<ApiTourService>().completeTour(
          name: 'admin_presence_report_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        setState(() => isTourShowing = false);
        getIt<ApiTourService>().completeTour(
          name: 'admin_presence_report_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          {'should_show': false},
        );
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final languageProvider = ref.read(languageRiverpod);
    return [
      _infoTarget(languageProvider),
      _searchTarget(languageProvider),
      _filterTarget(languageProvider),
      _moreTarget(languageProvider),
    ];
  }

  TargetFocus _infoTarget(LanguageProvider lp) {
    return TargetFocus(
      identify: 'PresenceReportInfo',
      keyTarget: infoKey,
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
                  lp.getTranslatedText({
                    'en': 'Attendance Reports',
                    'id': 'Laporan Absensi',
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
                    lp.getTranslatedText({
                      'en':
                          'View and manage student attendance reports across all classes.',
                      'id':
                          'Lihat dan kelola laporan absensi siswa di semua kelas.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  TargetFocus _searchTarget(LanguageProvider lp) {
    return TargetFocus(
      identify: 'PresenceReportSearch',
      keyTarget: searchKey,
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
                  lp.getTranslatedText({
                    'en': 'Search Attendance',
                    'id': 'Cari Absensi',
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
                    lp.getTranslatedText({
                      'en': 'Search for specific classes or subjects.',
                      'id': 'Cari kelas atau mata pelajaran tertentu.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  TargetFocus _filterTarget(LanguageProvider lp) {
    return TargetFocus(
      identify: 'PresenceReportFilter',
      keyTarget: filterKey,
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
                  lp.getTranslatedText({
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
                    lp.getTranslatedText({
                      'en': 'Narrow down results by date, subject, or class.',
                      'id':
                          'Persempit hasil berdasarkan tanggal, mata pelajaran, atau kelas.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  TargetFocus _moreTarget(LanguageProvider lp) {
    return TargetFocus(
      identify: 'PresenceReportMore',
      keyTarget: moreKey,
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
                  lp.getTranslatedText({
                    'en': 'More Options',
                    'id': 'Opsi Lanjutan',
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
                    lp.getTranslatedText({
                      'en': 'Refresh data or export reports to Excel.',
                      'id': 'Segarkan data atau export laporan ke Excel.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
