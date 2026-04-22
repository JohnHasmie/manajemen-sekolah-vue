// Tour logic for TeacherMaterialScreen.
//
// Extracted from TeacherMaterialScreenState to keep the main screen under the
// line-count limit. Mirrors the pattern in GradeRecapTourHelper — the State
// creates one instance and calls [checkAndShow].
//
// In Laravel terms this is a View Composer: it knows how to set up the coach-
// mark overlay and delegates the completion side-effect (API + cache) back
// through the same paths as before.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Encapsulates the coach-mark tour for [TeacherMaterialScreen].
///
/// Accepts the two [GlobalKey]s that identify highlighted widgets, then
/// exposes [checkAndShow] which the State calls after data loads.
///
/// Like a standalone Mixin/Service in Vue — zero widget-tree knowledge.
class MaterialTourHelper {
  final GlobalKey filterKey;
  final GlobalKey searchKey;

  const MaterialTourHelper({required this.filterKey, required this.searchKey});

  /// Checks the cache for `should_show == true` and, if so, schedules the
  /// tour on the next frame. Safe to call while the widget is still mounted.
  Future<void> checkAndShow(BuildContext context) async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('materi_screen', 'guru');
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map && cached['should_show'] == true) {
        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _show(context);
          });
        }
      }
    } catch (e) {
      AppLogger.error('material', 'Error checking tour status: $e');
    }
  }

  void _show(BuildContext context) {
    final targets = _buildTargets();
    if (targets.isEmpty) return;

    void markDone() {
      getIt<ApiTourService>().completeTour(
        name: 'materi_screen_tour',
        role: 'guru',
        platform: 'mobile',
      );
      LocalCacheService.save(
        CacheKeyBuilder.tourStatus('materi_screen', 'guru'),
        {'should_show': false},
      );
    }

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: 'LEWATI',
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: markDone,
      onSkip: () {
        markDone();
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _buildTargets() {
    return [
      TargetFocus(
        identify: 'FilterSection',
        keyTarget: filterKey,
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
                    'Pilih Kelas & Mata Pelajaran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Pilih kelas dan mata pelajaran yang Anda ampu di sini untuk melihat daftar Bab dan Sub-bab materi yang telah ditentukan oleh kurikulum.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: 'SearchBar',
        keyTarget: searchKey,
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
                    'Pencarian Materi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Gunakan kolom ini untuk mencari nama bab atau sub-bab dengan cepat.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ];
  }
}
