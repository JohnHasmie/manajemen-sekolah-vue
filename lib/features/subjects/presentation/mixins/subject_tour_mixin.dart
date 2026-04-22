import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/'
    'cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/screens/admin_subject_management_screen.dart';

/// Mixin handling guided tour functionality for subject management.
mixin SubjectTourMixin on ConsumerState<AdminSubjectManagementScreen> {
  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'subject_management',
        'admin',
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
      AppLogger.error('subject', 'Error checking tour status: $e');
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
        getIt<ApiTourService>().completeTour(
          name: 'subject_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'subject_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    return [
      _createMenuTourTarget(),
      _createSearchTourTarget(),
      _createFilterTourTarget(),
      _createAddSubjectTourTarget(),
    ];
  }

  TargetFocus _createMenuTourTarget() {
    final lp = ref.read(languageRiverpod);
    return TargetFocus(
      identify: 'SubjectMenu',
      keyTarget: menuKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return _buildTourContent(
              title: lp.getTranslatedText({
                'en': 'Subject Data Tools',
                'id': 'Alat Data Mata Pelajaran',
              }),
              description: lp.getTranslatedText({
                'en':
                    'Export, import, or download '
                    'subject templates from this menu.',
                'id':
                    'Ekspor, impor, atau unduh '
                    'template mata pelajaran dari '
                    'menu ini.',
              }),
            );
          },
        ),
      ],
    );
  }

  TargetFocus _createSearchTourTarget() {
    final lp = ref.read(languageRiverpod);
    return TargetFocus(
      identify: 'SubjectSearch',
      keyTarget: searchKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return _buildTourContent(
              title: lp.getTranslatedText({
                'en': 'Search Subjects',
                'id': 'Cari Mata Pelajaran',
              }),
              description: lp.getTranslatedText({
                'en':
                    'Quickly find subjects by typing '
                    'their name here.',
                'id':
                    'Temukan mata pelajaran dengan '
                    'cepat dengan mengetikkan namanya '
                    'di sini.',
              }),
            );
          },
        ),
      ],
    );
  }

  TargetFocus _createFilterTourTarget() {
    final lp = ref.read(languageRiverpod);
    return TargetFocus(
      identify: 'SubjectFilter',
      keyTarget: filterKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return _buildTourContent(
              title: lp.getTranslatedText({
                'en': 'Advanced Filtering',
                'id': 'Filter Lanjutan',
              }),
              description: lp.getTranslatedText({
                'en':
                    'Filter subjects by status, grade '
                    'level, or specific class names.',
                'id':
                    'Filter mata pelajaran berdasarkan '
                    'status, tingkat kelas, atau nama '
                    'kelas tertentu.',
              }),
            );
          },
        ),
      ],
    );
  }

  TargetFocus _createAddSubjectTourTarget() {
    final lp = ref.read(languageRiverpod);
    return TargetFocus(
      identify: 'AddSubject',
      keyTarget: fabKey,
      alignSkip: Alignment.topLeft,
      shape: ShapeLightFocus.Circle,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            return _buildTourContent(
              title: lp.getTranslatedText({
                'en': 'Add New Subject',
                'id': 'Tambah Mata Pelajaran Baru',
              }),
              description: lp.getTranslatedText({
                'en':
                    'Click here to manually add a new '
                    'subject to the curriculum.',
                'id':
                    'Klik di sini untuk menambahkan '
                    'mata pelajaran baru secara '
                    'manual ke kurikulum.',
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTourContent({
    required String title,
    required String description,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Text(
            description,
            style: const TextStyle(color: Colors.white, fontSize: 14.0),
          ),
        ),
      ],
    );
  }

  // Abstract keys from screen
  GlobalKey get menuKey;
  GlobalKey get searchKey;
  GlobalKey get filterKey;
  GlobalKey get fabKey;
}
