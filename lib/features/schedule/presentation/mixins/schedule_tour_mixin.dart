import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

mixin ScheduleTourMixin on ConsumerState<TeachingScheduleScreen> {
  GlobalKey get toggleViewKey;
  GlobalKey get searchFilterKey;
  GlobalKey get firstScheduleKey;
  GlobalKey get actionButtonsKey;
  List<dynamic> get scheduleList;
  bool get isTableView;

  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'teaching_schedule_screen',
        'guru',
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
      AppLogger.error('schedule', 'Error checking tour status: $e');
    }
  }

  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: 'LEWATI',
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'teaching_schedule_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('teaching_schedule_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'teaching_schedule_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('teaching_schedule_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(_toggleViewTarget());
    targets.add(_searchFilterTarget());

    if (scheduleList.isNotEmpty && !isTableView) {
      targets.add(_scheduleItemTarget());
      targets.add(_actionButtonsTarget());
    }

    return targets;
  }

  TargetFocus _toggleViewTarget() {
    return TargetFocus(
      identify: 'ToggleView',
      keyTarget: toggleViewKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.Circle,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Tampilan Jadwal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    'Ketuk ikon ini untuk beralih antara tampilan kartu interaktif atau tabel yang ringkas.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  TargetFocus _searchFilterTarget() {
    return TargetFocus(
      identify: 'SearchFilter',
      keyTarget: searchFilterKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pencarian & Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    'Cari mata pelajaran, kelas, atau gunakan tombol saring di kanan untuk menampilkan jadwal pada hari tertentu saja.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  TargetFocus _scheduleItemTarget() {
    return TargetFocus(
      identify: 'ScheduleItem',
      keyTarget: firstScheduleKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 16,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Kartu Jadwal Kelas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    'Detail lokasi kelas, mata pelajaran, serta waktu pelaksanaan. Ketuk seluruh area kartu ini langsung untuk masuk ke halaman Presensi Kelas.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  TargetFocus _actionButtonsTarget() {
    return TargetFocus(
      identify: 'ActionButtons',
      keyTarget: actionButtonsKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 10,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Aksi Cepat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    'Gunakan tombol Materi untuk melihat RPP & Bab. Gunakan tombol Aktivitas untuk mencatat absen kelas dan mengisi kehadiran harian siswa.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
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
