import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';

/// Mixin for tour functionality.
mixin TeacherReportCardTourMixin on ConsumerState<ReportCardScreen> {
  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('raport_screen', 'guru');
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
      textSkip: 'LEWATI',
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _completeTour,
      onSkip: () {
        _completeTour();
        return true;
      },
    ).show(context: context);
  }

  void _completeTour() {
    getIt<ApiTourService>().completeTour(
      name: 'raport_screen_tour',
      role: 'guru',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('raport_screen', 'guru'),
      {'should_show': false},
    );
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: 'ClassSelector',
        keyTarget: getClassSelectorKey(),
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pilih Kelas Evaluasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Karena Anda bertugas sebagai wali kelas, gunakan '
                      'area ini untuk memilih salah satu dari kelas perwalian '
                      'Anda untuk mengevaluasi data raport siswa-siswinya.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (shouldShowExportTour()) {
      targets.add(
        TargetFocus(
          identify: 'ExportRaport',
          keyTarget: getExportKey(),
          alignSkip: Alignment.bottomLeft,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Unduh Seluruh Raport',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(
                        'Dapatkan rekapan gabungan keseluruhan nilai raport '
                        'untuk seisi kelas di dalam dokumen Excel (.xlsx).',
                        style: TextStyle(color: Colors.white, fontSize: 14),
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

  // Abstract methods
  GlobalKey getClassSelectorKey();
  GlobalKey getExportKey();
  bool shouldShowExportTour();
}
