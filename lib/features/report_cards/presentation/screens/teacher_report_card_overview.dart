/// Teacher (wali kelas) Raport overview hub — Frame A of the
/// `_design/teacher_raport_redesign.html` mockup.
///
/// Layout:
///   • [BrandPageHeader] — cobalt gradient, kicker `Raport Akhir
///     Semester` + live dot, title `Wali Kelas`. Filter icon (with
///     badge) + view-toggle action icons. Periode read-only chip
///     in the bottom slot.
///   • Pinned 4-cell KPI overlap card — Siswa / Terbit / Draft /
///     Belum. Sums across all homeroom classes.
///   • Per-class cards (delegated to [CardViewMixin] / [TableViewMixin]):
///     50dp progress ring, cobalt class kicker, bold class name,
///     siswa count meta, 3-cell stats grid, gradient progress bar.
///   • Tap a class → push the full-page [ReportCardScreen] (was a
///     95% bottom sheet) so the student-list view gets its full
///     SafeArea and the BrandPageHeader doesn't fight a sheet
///     scroll controller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/filter_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/filter_dialog_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/card_view_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/table_view_mixin.dart';

class ReportCardOverviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  const ReportCardOverviewPage({super.key, required this.teacher});

  @override
  ConsumerState<ReportCardOverviewPage> createState() =>
      _ReportCardOverviewPageState();
}

class _ReportCardOverviewPageState extends ConsumerState<ReportCardOverviewPage>
    with FilterMixin, FilterDialogMixin, CardViewMixin, TableViewMixin {
  List<dynamic> _classData = [];
  bool _isLoading = true;
  bool _isTableView = false;
  String? _filterStatus;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  String get _teacherId => Teacher.fromJson(widget.teacher).id;

  @override
  String? get filterStatus => _filterStatus;
  @override
  set filterStatus(String? value) => _filterStatus = value;

  @override
  TextEditingController get searchController => _searchController;
  @override
  bool get isTableView => _isTableView;

  @override
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final cached = await LocalCacheService.load('raport_overview_view');
    if (cached != null && mounted) {
      setState(() => _isTableView = cached['isTableView'] == true);
    }
  }

  void _saveViewPreference() {
    LocalCacheService.save('raport_overview_view', {
      'isTableView': _isTableView,
    });
  }

  String get _raportCacheKey {
    final ayId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'raport_overview_${_teacherId}_$ayId';
  }

  Future<void> _loadData({bool useCache = true}) async {
    try {
      if (useCache && _classData.isEmpty) {
        try {
          final cached = await LocalCacheService.load(
            _raportCacheKey,
            ttl: const Duration(hours: 1),
          );
          if (cached is List && cached.isNotEmpty && mounted) {
            setState(() {
              _classData = cached;
              _isLoading = false;
            });
          }
        } catch (_) {}
      }

      if (_classData.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final data = await ApiReportCardService.getTeacherRaportSummary(
        teacherId: _teacherId,
        academicYearId: ayId,
      );
      if (mounted) {
        setState(() {
          _classData = data;
          _isLoading = false;
          _errorMessage = null;
        });
        await LocalCacheService.save(_raportCacheKey, data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  @override
  void openClassReport(dynamic classItem) {
    // Push as a full Material page route so the BrandPageHeader gets
    // its full SafeArea (no clock / battery overlap) and ESC /
    // system-back behave predictably. Was a 95% modal bottom sheet.
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => ReportCardScreen(
              teacher: widget.teacher.map(
                (k, v) => MapEntry(k, v?.toString() ?? ''),
              ),
              initialClassId: classItem['class_id']?.toString(),
            ),
          ),
        )
        .then((_) => _loadData());
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header + KPI overlap. The header reserves 45dp of bottom
          // padding via `kpiOverlayHeight` so the gradient extends
          // past where the KPI's top edge sits; the Stack +
          // Transform.translate combo drops the KPI 22dp into the
          // gradient — same visual idiom shipped on Materi/Jadwal.
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildBrandHeader(lp),
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: Transform.translate(
                  offset: const Offset(0, 22),
                  child: _buildKpiStrip(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(child: buildContentArea(lp)),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(LanguageProvider lp) {
    final ayLabel = ref
        .watch(academicYearRiverpod)
        .selectedAcademicYear?['year']
        ?.toString();
    final periodeChips = <BrandFilterChip>[
      BrandFilterChip(
        label: 'Periode',
        value: ayLabel != null ? 'Tahun $ayLabel' : 'Periode aktif',
        showChevron: false,
        onTap: null,
      ),
    ];

    return BrandPageHeader(
      role: 'guru',
      subtitle: lp.getTranslatedText({
        'en': 'Final Report Cards',
        'id': 'Raport Akhir Semester',
      }),
      title: lp.getTranslatedText({
        'en': 'Homeroom Teacher',
        'id': 'Wali Kelas',
      }),
      isRealtimeFresh: true,
      kpiOverlayHeight: 45,
      actionIcons: [
        BrandHeaderIconButton(
          icon: _isTableView
              ? Icons.view_agenda_rounded
              : Icons.table_chart_rounded,
          onTap: () {
            setState(() => _isTableView = !_isTableView);
            _saveViewPreference();
          },
        ),
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => showFilterDialog(lp),
          badgeCount: activeFilterCount > 0 ? activeFilterCount : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      bottomSlot: BrandFilterChipStrip(chips: periodeChips),
    );
  }

  Widget _buildKpiStrip() {
    final stats = _kpiStats();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpiCell('${stats.students}', 'SISWA', ColorUtils.brandCobalt),
            _kpiDivider(),
            _kpiCell('${stats.published}', 'TERBIT', ColorUtils.success600),
            _kpiDivider(),
            _kpiCell('${stats.drafts}', 'DRAFT', ColorUtils.warning600),
            _kpiDivider(),
            _kpiCell('${stats.belum}', 'BELUM', ColorUtils.error600),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: ColorUtils.slate100,
  );

  ({int students, int published, int drafts, int belum}) _kpiStats() {
    var students = 0;
    var published = 0;
    var drafts = 0;
    var totalFilled = 0;
    for (final c in _classData) {
      if (c is! Map) continue;
      students += (c['student_count'] is num)
          ? (c['student_count'] as num).toInt()
          : 0;
      published += (c['published_count'] is num)
          ? (c['published_count'] as num).toInt()
          : 0;
      drafts += (c['draft_count'] is num)
          ? (c['draft_count'] as num).toInt()
          : 0;
      totalFilled += (c['total_raports'] is num)
          ? (c['total_raports'] as num).toInt()
          : 0;
    }
    final belum = (students - totalFilled).clamp(0, 1 << 31);
    return (
      students: students,
      published: published,
      drafts: drafts,
      belum: belum,
    );
  }

  Widget buildContentArea(LanguageProvider lp) {
    if (_isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
    }
    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: () => _loadData(),
        role: 'guru',
      );
    }
    final filteredData = getFilteredData(_classData, _searchController.text);
    return buildContentView(filteredData, _classData, lp);
  }

  Widget buildContentView(
    List<dynamic> filteredData,
    List<dynamic> classData,
    LanguageProvider lp,
  ) {
    if (classData.isEmpty) {
      return buildEmptyClassState(lp);
    }
    if (filteredData.isEmpty) {
      return buildNoResultsState();
    }
    return AppRefreshIndicator(
      onRefresh: _loadData,
      role: 'guru',
      child: _isTableView
          ? buildTableView(filteredData)
          : buildCardView(filteredData, classData),
    );
  }

  Widget buildEmptyClassState(LanguageProvider lp) {
    return EmptyState(
      icon: Icons.assignment_outlined,
      title: lp.getTranslatedText({
        'en': 'No Homeroom Class',
        'id': 'Bukan Wali Kelas',
      }),
      subtitle: lp.getTranslatedText({
        'en': 'Report cards are managed by homeroom teachers',
        'id': 'Raport dikelola oleh wali kelas',
      }),
    );
  }

  Widget buildNoResultsState() {
    return const EmptyState(
      icon: Icons.search_off,
      title: 'Tidak Ditemukan',
      subtitle: 'Tidak ada kelas yang cocok dengan filter',
    );
  }
}
