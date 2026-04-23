import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';

/// Mixin for tour/tutorial functionality.
mixin FinanceTourMixin on ConsumerState<FinanceScreen> {
  GlobalKey get tabBarKey;

  GlobalKey get addButtonKey;

  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('finance', 'admin');
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
      AppLogger.error('finance', e);
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
          name: 'admin_finance_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(CacheKeyBuilder.tourStatus('finance', 'admin'), {
          'should_show': false,
        });
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_finance_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(CacheKeyBuilder.tourStatus('finance', 'admin'), {
          'should_show': false,
        });
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: 'FinanceTabBar',
        keyTarget: tabBarKey,
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
                      'en': 'Finance Tabs',
                      'id': 'Tab Keuangan',
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
                            'Switch between different views '
                            'like Dashboard, Payment Types, '
                            'Bills, and Pending Payments.',
                        'id':
                            'Pindah antara tampilan berbeda '
                            'seperti Dashboard, Jenis '
                            'Pembayaran, Tagihan, dan '
                            'Pembayaran Tertunda.',
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
        identify: 'FinanceAddButton',
        keyTarget: addButtonKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
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
                      'en': 'Add Action',
                      'id': 'Aksi Tambah',
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
                            'Use this button to quickly add '
                            'new payment types or generate '
                            'bills based on the active tab.',
                        'id':
                            'Gunakan tombol ini untuk '
                            'menambahkan jenis pembayaran '
                            'baru atau membuat tagihan '
                            'dengan cepat, tergantung tab '
                            'yang aktif.',
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
}
