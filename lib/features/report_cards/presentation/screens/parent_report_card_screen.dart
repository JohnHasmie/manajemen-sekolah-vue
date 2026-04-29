// Parent report card list screen — Phase 3 brand-aligned redesign.
//
// Displays the parent's children with their report card
// availability per semester. Tapping a student navigates to the
// detail screen.
//
// The data mixin (load + cache + force refresh) is unchanged. The
// presentation overrides the generic UI mixin's `buildHeader()` and
// `buildFilterSection()` so the screen renders the canonical Phase-3
// stack: BrandPageHeader (role 'wali') + BrandFilterChipStrip in the
// bottomSlot for the Semester chip + RefreshIndicator-wrapped list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/mixins/report_card_data_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/mixins/report_card_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/parent_report_card_filter_mixin.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';

/// Parent's report card list -- shows children with semester selector.
///
/// Props: optional [academicYearId].
/// Navigates to [ParentReportCardDetailScreen] on student tap.
class ParentReportCardScreen extends ConsumerStatefulWidget {
  final String? academicYearId;
  const ParentReportCardScreen({super.key, this.academicYearId});

  @override
  ConsumerState createState() => _ParentReportCardScreenState();
}

/// State for [ParentReportCardScreen].
///
/// Like a Vue component with
/// `data() { return { isLoading, studentsData, selectedTermId } }`.
/// Auto-resolves the current semester and loads student raport data.
class _ParentReportCardScreenState extends ConsumerState<ParentReportCardScreen>
    with ReportCardDataMixin<ParentReportCardScreen>, ReportCardUIBuilderMixin<ParentReportCardScreen>, ParentReportCardFilterMixin {
  @override
  bool isLoading = true;
  @override
  String errorMessage = '';
  @override
  List<dynamic> studentsData = [];
  @override
  Map<String, dynamic> parentData = {};
  @override
  String selectedTermId = '1';

  @override
  String? get academicYearId => widget.academicYearId;

  /// Like Vue's `mounted()` -- loads report card data on screen init.
  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  dynamic getAcademicYearProvider() => ref.read(academicYearRiverpod);

  // Drives the realtime pill — bumped after every successful refresh.
  DateTime _lastSync = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildBrandHeader(lang),
          Expanded(
            child: RefreshIndicator(
              color: ColorUtils.brandAzureDeep,
              onRefresh: () async {
                await forceRefresh();
                if (mounted) setState(() => _lastSync = DateTime.now());
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: buildContentArea(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(LanguageProvider lang) {
    final semesterLabel = selectedTermId == '2'
        ? lang.getTranslatedText({'en': 'Genap', 'id': 'Genap'})
        : lang.getTranslatedText({'en': 'Ganjil', 'id': 'Ganjil'});

    return BrandPageHeader(
      role: 'wali',
      showBackButton: true,
      onBackPressed: () => AppNavigator.pop(context),
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({
        'en': 'Report Card',
        'id': 'E-Raport',
      }),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: showFilterSheet,
        ),
      ],
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lang.getTranslatedText({
              'en': 'Semester',
              'id': 'Semester',
            }),
            value: semesterLabel,
            onTap: showFilterSheet,
            width: 172,
          ),
        ],
      ),
    );
  }
}
