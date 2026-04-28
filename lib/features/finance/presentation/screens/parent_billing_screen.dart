// Parent billing screen — Phase 3 brand-aligned redesign.
//
// Replaces the bespoke gradient hero (with inline search + filter +
// refresh icons) with the canonical Phase-3 stack:
//
//   • BrandPageHeader (role 'wali') — title/kicker, BrandRealtimePill,
//     ChildSelectorChipRow as the childSelector slot, and a
//     BrandFilterChipStrip in the bottomSlot showing the active
//     Periode + Status filters (matches Nilai's chip-only pattern, per
//     the user's brief).
//   • Body wrapped in RefreshIndicator → BillingList.
//
// The previous inline search input is gone (parents tap chips, not
// type bill names). The status + period filters are still authored
// via the existing FinanceFilterSheet — tapping any chip in the
// strip opens it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/billing_list.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_filter_sheet.dart';

class ParentBillingScreen extends ConsumerStatefulWidget {
  const ParentBillingScreen({super.key});

  @override
  ConsumerState<ParentBillingScreen> createState() =>
      _ParentBillingScreenState();
}

class _ParentBillingScreenState extends ConsumerState<ParentBillingScreen> {
  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _billingListKey = GlobalKey();
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkAndShowTour();
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
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14.0),
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
                          "See your child's bill status here, pay bills, and view history.",
                      'id':
                          'Lihat status tagihan anak Anda di sini, bayar tagihan, dan lihat riwayat.',
                    }),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14.0),
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
        primaryColor: ColorUtils.brandAzureDeep,
        onApply: (status, period) {
          ref
              .read(parentFinanceProvider.notifier)
              .updateFilters(status: status, period: period);
        },
      ),
    );
  }

  // ---------- Filter chip helpers --------------------------------------

  String? _periodChipValue(LanguageProvider lp, String? period) {
    if (period == null) return null;
    return lp.getTranslatedText(switch (period) {
      'bulanan' => {'en': 'Monthly', 'id': 'Bulanan'},
      'tahunan' => {'en': 'Yearly', 'id': 'Tahunan'},
      _ => {'en': period, 'id': period},
    });
  }

  String? _statusChipValue(LanguageProvider lp, String? status) {
    if (status == null) return null;
    return lp.getTranslatedText(switch (status) {
      'unpaid' => {'en': 'Unpaid', 'id': 'Belum lunas'},
      'pending' => {'en': 'Pending', 'id': 'Menunggu'},
      'verified' => {'en': 'Verified', 'id': 'Lunas'},
      _ => {'en': status, 'id': status},
    });
  }

  int _activeFilterCount(String? status, String? period) {
    var n = 0;
    if (status != null) n++;
    if (period != null) n++;
    return n;
  }

  // ---------- Build -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final financeAsync = ref.watch(parentFinanceProvider);

    final header = financeAsync.when(
      data: (state) => _buildHeader(
        languageProvider,
        state.students,
        state.selectedStudent?.id,
        state.statusFilter,
        state.periodFilter,
      ),
      loading: () => _buildHeader(
        languageProvider,
        const [],
        null,
        null,
        null,
      ),
      error: (_, __) => _buildHeader(
        languageProvider,
        const [],
        null,
        null,
        null,
      ),
    );

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: RefreshIndicator(
        color: ColorUtils.brandAzureDeep,
        onRefresh: () async {
          await ref.read(parentFinanceProvider.notifier).forceRefresh();
          if (mounted) setState(() => _lastSync = DateTime.now());
        },
        // Single outer ListView so the gradient hero scrolls with
        // the billing list — matches the dashboard / Kehadiran
        // hero idiom (not pinned).
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            header,
            BillingList(
              key: _billingListKey,
              languageProvider: languageProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    LanguageProvider lp,
    List<dynamic> students,
    String? selectedStudentId,
    String? statusFilter,
    String? periodFilter,
  ) {
    final summaries = students
        .map<ChildSummary>((s) {
          final id = s.id?.toString() ?? '';
          final name = (s.name as String?) ?? '';
          final klass = (s.className as String?) ?? '';
          return ChildSummary(
            id: id,
            shortName: name.isEmpty ? '?' : name,
            klass: klass.isEmpty ? '-' : 'Kelas $klass',
          );
        })
        .toList(growable: false);

    final activeCount = _activeFilterCount(statusFilter, periodFilter);

    return BrandPageHeader(
      role: 'wali',
      subtitle: lp.getTranslatedText({
        'en': 'Finance · Child',
        'id': 'Keuangan · Anak',
      }),
      title: lp.getTranslatedText({
        'en': 'Billing',
        'id': 'Tagihan',
      }),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => _showFilterSheet(lp),
          badgeCount: activeCount > 0 ? activeCount : null,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
      ],
      realtimeIndicator: BrandRealtimePill(
        isFresh: true,
        lastSync: _lastSync,
      ),
      childSelector: summaries.length < 2
          ? null
          : ChildSelectorChipRow(
              key: _studentSelectorKey,
              children: summaries,
              selectedChildId: selectedStudentId ?? summaries.first.id,
              onSelected: (id) {
                final picked = students.firstWhere(
                  (s) => s.id?.toString() == id,
                  orElse: () => null,
                );
                if (picked != null) {
                  ref
                      .read(parentFinanceProvider.notifier)
                      .selectStudent(picked);
                }
              },
              accentColor: ColorUtils.brandAzureDeep,
            ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lp.getTranslatedText({
              'en': 'Period',
              'id': 'Periode',
            }),
            value: _periodChipValue(lp, periodFilter),
            onTap: () => _showFilterSheet(lp),
            width: 172,
          ),
          BrandFilterChip(
            label: lp.getTranslatedText({
              'en': 'Status',
              'id': 'Status',
            }),
            value: _statusChipValue(lp, statusFilter),
            onTap: () => _showFilterSheet(lp),
          ),
        ],
      ),
    );
  }
}
