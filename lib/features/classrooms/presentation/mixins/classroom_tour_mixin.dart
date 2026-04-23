import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';

/// Mixin for tour/tutorial management.
///
/// Provides methods for showing guided tours and managing tour state.
/// Assumes the State class provides context and ref.
mixin ClassroomTourMixin on ConsumerState<AdminClassManagementScreen> {
  // Abstract state fields
  GlobalKey get menuKey;
  GlobalKey get searchKey;
  GlobalKey get filterKey;
  GlobalKey get fabKey;

  bool get isMounted => mounted;

  /// Checks if tour should be shown and displays it.
  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_management',
        'admin',
      );

      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (isMounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isMounted) showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('classroom', 'Error checking tour status: $e');
    }
  }

  /// Displays the guided tour.
  void showTour() {
    final targets = createTourTargets();
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
      onFinish: _completeTour,
      onSkip: () {
        _completeTour();
        return true;
      },
    ).show(context: context);
  }

  /// Creates the list of tour targets.
  List<TargetFocus> createTourTargets() {
    final lang = ref.read(languageRiverpod);
    return [
      _createMenuTarget(lang),
      _createSearchTarget(lang),
      _createFilterTarget(lang),
      _createAddClassTarget(lang),
    ];
  }

  TargetFocus _createMenuTarget(LanguageProvider lang) {
    return TargetFocus(
      identify: 'ClassMenu',
      keyTarget: menuKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTourContent(
            title: lang.getTranslatedText({
              'en': 'Class Tools',
              'id': 'Alat Manajemen Kelas',
            }),
            message: lang.getTranslatedText({
              'en':
                  'Export, import, or download class templates '
                  'from here.',
              'id':
                  'Ekspor, impor, atau unduh template data '
                  'kelas dari sini.',
            }),
          ),
        ),
      ],
    );
  }

  TargetFocus _createSearchTarget(LanguageProvider lang) {
    return TargetFocus(
      identify: 'ClassSearch',
      keyTarget: searchKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTourContent(
            title: lang.getTranslatedText({
              'en': 'Find Classes',
              'id': 'Cari Kelas',
            }),
            message: lang.getTranslatedText({
              'en':
                  'Quickly find classes by name using this '
                  'search bar.',
              'id':
                  'Temukan kelas dengan cepat berdasarkan nama '
                  'menggunakan bilah pencarian ini.',
            }),
          ),
        ),
      ],
    );
  }

  TargetFocus _createFilterTarget(LanguageProvider lang) {
    return TargetFocus(
      identify: 'ClassFilter',
      keyTarget: filterKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.Circle,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTourContent(
            title: lang.getTranslatedText({
              'en': 'Filter Options',
              'id': 'Opsi Filter',
            }),
            message: lang.getTranslatedText({
              'en':
                  'Filter classes by grade level or homeroom '
                  'teacher status.',
              'id':
                  'Filter kelas berdasarkan tingkat kelas atau '
                  'status wali kelas.',
            }),
          ),
        ),
      ],
    );
  }

  TargetFocus _createAddClassTarget(LanguageProvider lang) {
    return TargetFocus(
      identify: 'AddClass',
      keyTarget: fabKey,
      alignSkip: Alignment.topLeft,
      shape: ShapeLightFocus.Circle,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTourContent(
            title: lang.getTranslatedText({
              'en': 'Add New Class',
              'id': 'Tambah Kelas Baru',
            }),
            message: lang.getTranslatedText({
              'en':
                  'Create a new class and assign a homeroom '
                  'teacher.',
              'id': 'Buat kelas baru dan tugaskan wali kelas.',
            }),
          ),
        ),
      ],
    );
  }

  /// Builds a tour content widget.
  Widget _buildTourContent({required String title, required String message}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14.0),
          ),
        ),
      ],
    );
  }

  /// Completes the tour and updates cache.
  void _completeTour() {
    getIt<ApiTourService>().completeTour(
      name: 'admin_class_management_tour',
      role: 'admin',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('class_management', 'admin'),
      {'should_show': false},
    );
  }
}
