// Onboarding tour logic for the grade recap screen.
// Extracted from _GradeRecapPageState to keep the main screen file lean.
// Like a Vue mixin that handles the tutorial/walkthrough lifecycle.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Manages the onboarding tour for [GradeRecapPage].
///
/// Like a Vue mixin or a Laravel service class — encapsulates one concern
/// (the coach-mark walkthrough) so the parent screen stays focused on
/// grade-recap logic.
///
/// Usage:
/// ```dart
/// final _tourHelper = GradeRecapTourHelper(
///   addChapterKey: _addChapterKey,
///   saveKey: _saveKey,
///   exportKey: _exportKey,
/// );
/// // ...
/// await _tourHelper.checkAndShow(context);
/// ```
class GradeRecapTourHelper {
  final GlobalKey addChapterKey;
  final GlobalKey saveKey;
  final GlobalKey exportKey;

  GradeRecapTourHelper({
    required this.addChapterKey,
    required this.saveKey,
    required this.exportKey,
  });

  /// Checks whether the tour should be shown (from cache) and, if so, shows it.
  /// Like checking a Vuex boolean flag before triggering a walkthrough.
  Future<void> checkAndShow(BuildContext context) async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'rekap_nilai_screen',
        'guru',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (context.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) show(context);
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  /// Starts the coach-mark walkthrough targeting the three key UI elements.
  void show(BuildContext context) {
    final List<TargetFocus> targets = _createTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: 'LEWATI',
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'rekap_nilai_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rekap_nilai_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'rekap_nilai_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rekap_nilai_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  /// Builds the ordered list of [TargetFocus] steps for the tour.
  List<TargetFocus> _createTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: 'AddBab',
        keyTarget: addChapterKey,
        alignSkip: Alignment.bottomRight,
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
                    'Tambah Kolom Bab',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Klik tombol ini untuk menambahkan kolom materi '
                      'atau bab baru di kanan tabel Anda.',
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

    targets.add(
      TargetFocus(
        identify: 'SaveRekap',
        keyTarget: saveKey,
        alignSkip: Alignment.bottomRight,
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
                    'Simpan Perubahan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Kapanpun Anda mengubah judul bab, mengedit nilai, '
                      'atau mengisi deskripsi. Jangan lupa tekan Simpan agar '
                      'nilai tersebut dikunci (snapshot) di server.',
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

    targets.add(
      TargetFocus(
        identify: 'ExportRekap',
        keyTarget: exportKey,
        alignSkip: Alignment.bottomRight,
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
                    'Ekspor ke Excel',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'Tabel rekap nilai yang telah Anda buat bisa Anda '
                      'unduh seketika dalam wujud file spreedsheat Excel '
                      'yang rapi.',
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

    return targets;
  }
}
