import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/student_selector.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/billing_list.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_filter_sheet.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class ParentBillingScreen extends ConsumerStatefulWidget {
  const ParentBillingScreen({super.key});

  @override
  ConsumerState<ParentBillingScreen> createState() =>
      _ParentBillingScreenState();
}

class _ParentBillingScreenState extends ConsumerState<ParentBillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _billingListKey = GlobalKey();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _checkAndShowTour();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'parent_billing_screen',
        'wali',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map && cached['should_show'] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showTour();
        });
      }
    } catch (e) {
      AppLogger.error('finance', e);
    }
  }

  void _showTour() {
    final languageProvider = ref.read(languageRiverpod);
    final targets = _createTourTargets(languageProvider);
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
      onFinish: _completeTour,
      onSkip: () {
        _completeTour();
        return true;
      },
    ).show(context: context);
  }

  void _completeTour() {
    getIt<ApiTourService>().completeTour(
      name: 'parent_billing_screen_tour',
      role: 'wali',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('parent_billing_screen', 'wali'),
      {'should_show': false},
    );
  }

  List<TargetFocus> _createTourTargets(LanguageProvider languageProvider) {
    return [
      TargetFocus(
        identify: 'StudentSelector',
        keyTarget: _studentSelectorKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Child',
                    'id': 'Pilih Anak',
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
                          'Select your child to view their billings and payments.',
                      'id':
                          'Pilih anak Anda untuk melihat tagihan dan pembayaran mereka.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'BillingList',
        keyTarget: _billingListKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Billing List',
                    'id': 'Daftar Tagihan',
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
                          'See your child\'s bill status here, pay bills, and view history.',
                      'id':
                          'Lihat status tagihan anak Anda di sini, bayar tagihan, dan lihat riwayat.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  void _showFilterSheet(LanguageProvider lp) {
    final state = ref.read(parentFinanceProvider).value;
    if (state == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FinanceFilterSheet(
        currentStatus: state.statusFilter,
        currentPeriod: state.periodFilter,
        languageProvider: lp,
        onApply: (status, period) {
          ref
              .read(parentFinanceProvider.notifier)
              .updateFilters(status: status, period: period);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final financeAsync = ref.watch(parentFinanceProvider);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHero(languageProvider),
          // Student Selector — stays directly under hero, on slate-50.
          financeAsync.when(
            data: (state) => StudentSelector(
              key: _studentSelectorKey,
              students: state.students,
              selectedStudent: state.selectedStudent,
              onSelected: (student) => ref
                  .read(parentFinanceProvider.notifier)
                  .selectStudent(student),
            ),
            loading: () => const SizedBox(height: 90),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Divider(height: 1, color: ColorUtils.slate200),
          // Billing List
          Expanded(
            child: BillingList(
              key: _billingListKey,
              languageProvider: languageProvider,
            ),
          ),
        ],
      ),
    );
  }

  /// Phase-3 azure gradient hero for the parent Billing tab.
  ///
  /// Mirrors the dashboard's hero composition (gradient + icon-row +
  /// title block + inline search) so the parent-role surfaces share a
  /// visual language. The gradient comes from
  /// `ColorUtils.brandGradient('wali')`, the same source the parent
  /// Beranda uses, so a brand refresh here flows through automatically.
  Widget _buildHero(LanguageProvider lp) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ColorUtils.brandGradient('wali'),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.brandAzure.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        statusBarHeight + 12,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lp.getTranslatedText({
                        'en': 'School Billing',
                        'id': 'Tagihan Sekolah',
                      }),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lp.getTranslatedText({
                        'en': 'Track and pay your child\'s bills',
                        'id': 'Pantau dan bayar tagihan anak Anda',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildHeroIconButton(
                icon: Icons.filter_list,
                onTap: () => _showFilterSheet(lp),
              ),
              const SizedBox(width: 6),
              _buildHeroIconButton(
                icon: Icons.refresh,
                onTap: () =>
                    ref.read(parentFinanceProvider.notifier).forceRefresh(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Inline search field in the hero — same idiom as the dashboard
          // SchoolPill: white-translucent fill, white text, slate-200 hint.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                  ref.read(parentFinanceProvider.notifier).updateSearch(val);
                });
              },
              decoration: InputDecoration(
                hintText: lp.getTranslatedText({
                  'en': 'Search billing...',
                  'id': 'Cari tagihan...',
                }),
                hintStyle: TextStyle(color: ColorUtils.slate400),
                prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 36×36 white-translucent icon button used in the hero's top row;
  /// same idiom as `_HeroIconButton` in the dashboard bodies.
  Widget _buildHeroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
