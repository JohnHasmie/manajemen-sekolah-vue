import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

/// Tour/onboarding mixin for the grade book screen.
mixin GradeBookTourMixin on ConsumerState<GradeBookPage> {
  GlobalKey get addGradeKey;
  bool get canEditGrades;

  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'input_grade_screen',
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
      AppLogger.error('grades', e);
    }
  }

  void showTour() {
    final targets = createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: 'LEWATI',
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'input_grade_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('input_grade_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'input_grade_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('input_grade_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];

    if (canEditGrades) {
      targets.add(
        TargetFocus(
          identify: 'AddGrade',
          keyTarget: addGradeKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Tambah Penilaian',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(
                        'Ketuk tombol ini untuk membuat kolom penilaian baru secara massal untuk seluruh siswa di kelas ini.',
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
}
