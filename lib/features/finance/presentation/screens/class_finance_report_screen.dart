// Class-level finance report screen - shows billing/payment status
// per student. Supports filtering by student name, payment type,
// month, and payment status.
//
// Used both as a stand-alone route AND as an embedded drill-down inside
// the admin finance hub's Class Report tab. When [embedded] is true,
// the outer [Scaffold] is dropped and [onBack] replaces route-pop so the
// hub keeps its header + tab-bar visible during the drill-down.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/search_filter_bar.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_data_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_payment_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_ui_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_utils_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_jenis_tabs.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_matrix.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_student_cards.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Class finance report screen showing billing and payment details
/// for a specific class. Displays students and their bills with
/// filtering and payment management capabilities.
class ClassFinanceReportScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String? academicYearId;

  /// Whether this widget is embedded inside the admin finance hub.
  ///
  /// When `true`, the outer [Scaffold] + gradient hero are dropped in favour
  /// of a compact back-bar so the hub's header and tab-bar stay visible.
  final bool embedded;

  /// Called when the user taps the back chevron. Only used when [embedded] is
  /// true — outside the hub the screen falls back to [AppNavigator.pop].
  final VoidCallback? onBack;

  const ClassFinanceReportScreen({
    super.key,
    required this.classId,
    required this.className,
    this.academicYearId,
    this.embedded = false,
    this.onBack,
  });

  @override
  State<ClassFinanceReportScreen> createState() =>
      _ClassFinanceReportScreenState();
}

/// State for [ClassFinanceReportScreen] with data loading, payment
/// handling, and UI management.
///
/// Loading / data / error state lives on [ClassFinanceDataMixin]'s
/// `late` fields (`isLoadingData`, `errorMessage`, `students`,
/// `billsByStudent`, `monthGroups`). They are seeded in [initState]
/// before [loadData] runs — without that, the mixin's `setState`
/// would trip a `LateInitializationError` on the very first read.
///
/// Earlier versions kept private final shadows here (`_isLoading =
/// true`, `_students = []`, …) which never got mutated, so `build()`
/// rendered a perpetual loading screen even after the mixin's fetch
/// returned successfully — the loaded data lived on different
/// fields. Don't reintroduce those shadows.
class _ClassFinanceReportScreenState extends State<ClassFinanceReportScreen>
    with
        ClassFinanceDataMixin,
        ClassFinancePaymentMixin,
        ClassFinanceUtilsMixin,
        ClassFinanceUIMixin {
  @override
  File? selectedFile;

  String _searchQuery = '';
  String? _selectedPaymentTypeId;
  String? _selectedMonthKey;
  String _selectedStatus = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  /// Body view mode — Matrix (C1, default) vs Per-siswa (C2). Toggled
  /// by the [ViewToggleButton] above the body.
  _ReportView _viewMode = _ReportView.matrix;

  /// Measured BrandPageHeader height. The Stack-based body layout
  /// positions the NestedScrollView at `_headerH - overlap`, letting
  /// the KPI strip tuck into the navy gradient — same overlap idiom
  /// as the admin finance hub. Updated in a post-frame callback;
  /// `setState` only fires on real changes so we don't churn.
  final GlobalKey _headerKey = GlobalKey();
  double _headerH = 0;

  void _measureHeader() {
    if (!mounted) return;
    final ctx = _headerKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _headerH).abs() > 0.5) {
      setState(() => _headerH = h);
    }
  }

  @override
  void initState() {
    super.initState();
    // Seed the mixin's late fields so the first `setState` inside
    // loadData() doesn't trip LateInitializationError. The screen
    // owns no shadow state — mixin fields are the single source.
    apiService = ApiService();
    students = const [];
    billsByStudent = const {};
    monthGroups = const [];
    isLoadingData = true;
    errorMessage = null;
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return _buildLoadingScreen();
    }
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      final errorChild = ErrorScreen(
        errorMessage: errorMessage!,
        onRetry: loadData,
      );
      return widget.embedded ? errorChild : errorChild;
    }
    return _buildMainContent();
  }

  Widget _buildLoadingScreen() {
    // Same Column-fallback layout the loaded path uses on first
    // frame, keeping the header height consistent across loading
    // and content states.
    final column = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const SkeletonListLoading(itemCount: 6, infoTagCount: 1),
          ),
        ),
      ],
    );

    if (widget.embedded) return column;
    return Scaffold(backgroundColor: ColorUtils.slate50, body: column);
  }

  Widget _buildMainContent() {
    // No auto-select — the [ClassFinanceJenisTabs] strip now exposes
    // a "Semua" leading tab so an unscoped (jenis == null) view is a
    // first-class option. Admin opts into a jenis explicitly when
    // they want the cleaner single-jenis layout the C1 mockup shows.
    //
    // Scroll model: NestedScrollView wraps the body so the KPI strip
    // and (optional) active-filters chip row scroll AWAY with the
    // content while the jenis tabs + Matrix/Per-Siswa toggle PIN
    // sticky directly under the header. Mirrors the admin finance
    // hub's KPI-scrolls / NavBar-pins pattern.
    //
    // Header overlap: schedule a post-frame measurement so the
    // Stack-based body layout below can position the
    // NestedScrollView at `_headerH - overlap` and let the KPI
    // strip visually tuck into the navy gradient. Same idiom as
    // admin_finance_screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
    const overlap = BrandPageLayout.kpiOverlapHeight; // 45dp

    final scrollBody = NestedScrollView(
      headerSliverBuilder: (context, _) => [
        // KPI strip — Lunas / Belum / Tempo counts scoped to the
        // current jenis + bulan filter. Scrolls with the content.
        // Top padding is 0: it sits flush at the top of the body
        // region, which is itself positioned `overlap` dp inside
        // the header gradient — so the KPI card visually overlays
        // the navy band.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 12),
            child: _buildKpiStrip(),
          ),
        ),
        // Only render the Status/Bulan chip strip when one of THOSE
        // two is actually set. Jenis lives in the dedicated
        // [ClassFinanceJenisTabs] strip below, so counting it as a
        // "row filter" would render a row of empty-placeholder chips
        // (Status: —, Bulan: —). The filter button on the header
        // still uses [_hasActiveFilters()] (which DOES include
        // jenis) so the tune-icon highlight stays accurate.
        if (_hasActiveChipRowFilters())
          SliverToBoxAdapter(child: _buildActiveFiltersRow()),
        // Sticky sliver — jenis tabs (38dp + 12dp padding = 50) +
        // Matrix/Per-Siswa toggle (~42dp). Pinned so the admin
        // always has the per-jenis + per-view controls within thumb
        // reach even when the student list is scrolled deep.
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabsDelegate(
            height: _stickyTabsHeight,
            primaryColor: getPrimaryColor(),
            monthGroups: monthGroups,
            selectedPaymentTypeId: _selectedPaymentTypeId,
            onJenisChanged: (id) => setState(() => _selectedPaymentTypeId = id),
            viewMode: _viewMode,
            onViewModeChanged: (m) => setState(() => _viewMode = m),
          ),
        ),
      ],
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: students.isEmpty
            ? const EmptyState(
                title: 'Tidak ada siswa',
                subtitle: 'Kelas ini belum memiliki siswa',
                icon: Icons.people_outline,
              )
            : _buildBodyForMode(),
      ),
    );

    // Stack-based KPI-overlap layout. Mirrors
    // [admin_finance_screen]'s body composition exactly:
    //   1. Header pinned at top:0 (full-width).
    //   2. Scrollable body positioned at `headerH - overlap`,
    //      bleeding `overlap` dp INTO the header gradient.
    // The first frame before `_headerH` is measured falls back to
    // a Column so the BrandPageHeader can lay itself out and
    // report its height.
    final headerWidget = KeyedSubtree(key: _headerKey, child: _buildHeader());
    final body = _headerH == 0
        ? Column(
            children: [
              headerWidget,
              Expanded(child: scrollBody),
            ],
          )
        : Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, child: headerWidget),
              Positioned(
                top: (_headerH - overlap).clamp(0.0, double.infinity),
                left: 0,
                right: 0,
                bottom: 0,
                child: scrollBody,
              ),
            ],
          );

    if (widget.embedded) return body;
    return Scaffold(backgroundColor: ColorUtils.slate50, body: body);
  }

  /// Total height of the pinned tabs sliver (jenis strip + view
  /// toggle row). Kept here so the [_StickyTabsDelegate] and the
  /// [SliverPersistentHeader] stay in sync.
  ///
  /// Sized to exactly match what the inner Column actually paints
  /// (96dp on this build). Bumping it any higher than the painted
  /// content trips the `layoutExtent > paintExtent` assertion in
  /// `SliverPersistentHeader` — that's what was causing the blank
  /// screen + null-check crashes. The delegate's `build` ALSO
  /// wraps its child in `SizedBox(height: height, …)` so the
  /// declared extent always equals the painted extent.
  static const double _stickyTabsHeight = 96.0;

  /// Build the KPI strip that overlaps the header.
  ///
  /// Counts are computed across every bill currently in scope (i.e.
  /// matching the selected jenis tab + month filter). The strip
  /// renders three cells — Lunas / Belum / Tempo — using the shared
  /// [BrandKpiStrip] so the visual treatment matches the rest of the
  /// admin surfaces (Raport, Kehadiran, etc).
  Widget _buildKpiStrip() {
    int lunas = 0;
    int belum = 0;
    int tempo = 0;
    final now = DateTime.now();
    for (final list in billsByStudent.values) {
      for (final bill in list) {
        // Apply the active jenis + month filter so the numbers always
        // reflect what's on the user's screen.
        if (_selectedPaymentTypeId != null &&
            bill['payment_type_id']?.toString() != _selectedPaymentTypeId) {
          continue;
        }
        if (_selectedMonthKey != null) {
          final due = DateTime.tryParse((bill['due_date'] ?? '').toString());
          if (due == null) continue;
          final key = "${due.year}-${due.month.toString().padLeft(2, '0')}";
          if (key != _selectedMonthKey) continue;
        }
        final status = (bill['status'] ?? '').toString();
        final paid =
            status == 'paid' || status == 'verified' || status == 'success';
        if (paid) {
          lunas++;
        } else {
          final due = DateTime.tryParse((bill['due_date'] ?? '').toString());
          if (due != null && due.isBefore(now)) {
            tempo++;
          } else {
            belum++;
          }
        }
      }
    }
    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: 'Lunas',
          value: lunas.toString(),
          valueColor: ColorUtils.success600,
        ),
        BrandKpiColumn(
          label: 'Belum',
          value: belum.toString(),
          valueColor: ColorUtils.error600,
        ),
        BrandKpiColumn(
          label: 'Tempo',
          value: tempo.toString(),
          valueColor: ColorUtils.warning600,
        ),
      ],
    );
  }

  Widget _buildBodyForMode() {
    switch (_viewMode) {
      case _ReportView.matrix:
        return _buildTableContent();
      case _ReportView.cards:
        return ClassFinanceStudentCards(
          students: students,
          billsByStudent: billsByStudent,
          monthGroups: monthGroups,
          searchQuery: _searchQuery,
          selectedPaymentTypeId: _selectedPaymentTypeId,
          selectedMonthKey: _selectedMonthKey,
          selectedStatus: _selectedStatus,
          onBillTap: showPaymentOptions,
        );
    }
  }

  Widget _buildTableContent() {
    return ClassFinanceMatrix(
      students: students,
      billsByStudent: billsByStudent,
      monthGroups: monthGroups,
      searchQuery: _searchQuery,
      selectedPaymentTypeId: _selectedPaymentTypeId,
      selectedMonthKey: _selectedMonthKey,
      selectedStatus: _selectedStatus,
      primaryColor: getPrimaryColor(),
      onBillTap: showPaymentOptions,
    );
  }

  Widget _buildHeader() {
    if (widget.embedded) return _buildEmbeddedHeader();

    // Standalone path now uses the shared [BrandPageHeader] so the
    // chrome (gradient, status-bar inset, back chevron, role tint)
    // stays identical to every other admin screen. Search + Filter
    // chip live in the header's bottomSlot — the bespoke white search
    // pill that used to overlap the gradient is gone.
    return BrandPageHeader(
      role: 'admin',
      title: widget.className,
      subtitle: 'OPERASIONAL · KEUANGAN',
      onBackPressed: _onBackPressed,
      // Extend the gradient `kpiOverlapHeight` dp past the search
      // bar so the KPI strip (rendered at the top of the body
      // region — positioned `overlap` dp inside the header by the
      // Stack layout below) has a navy band to tuck into. Same
      // overlap idiom as every other admin hub.
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      bottomSlot: SearchFilterBar(
        controller: _searchController,
        hintText: 'Cari siswa...',
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        onFilterTap: () => showFilterSheet(
          monthGroups,
          _selectedStatus,
          _selectedMonthKey,
          _selectedPaymentTypeId,
        ),
        hasActiveFilter: _hasActiveFilters(),
        transparentStyle: true,
        primaryColor: getPrimaryColor(),
      ),
    );
  }

  /// Compact back-bar used when rendered inside the admin finance hub.
  ///
  /// Keeps the hub's own gradient header + tab-bar visible above and falls
  /// back to a white tile with a back chevron, class name, and the shared
  /// search + filter row.
  Widget _buildEmbeddedHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _onBackPressed,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: ColorUtils.slate700,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.className,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Laporan Keuangan',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildEmbeddedSearchRow(),
        ],
      ),
    );
  }

  Widget _buildEmbeddedSearchRow() {
    final active = _hasActiveFilters();
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari siswa...',
                hintStyle: TextStyle(color: ColorUtils.slate400),
                prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => showFilterSheet(
            monthGroups,
            _selectedStatus,
            _selectedMonthKey,
            _selectedPaymentTypeId,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: active ? getPrimaryColor() : ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: active ? getPrimaryColor() : ColorUtils.slate200,
              ),
            ),
            child: Icon(
              Icons.tune,
              color: active ? Colors.white : ColorUtils.slate700,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  void _onBackPressed() {
    if (widget.embedded && widget.onBack != null) {
      widget.onBack!.call();
    } else {
      AppNavigator.pop(context);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Re-uses the same `BrandFilterChipStrip` widget the rest of the
  /// admin screens use (RPP, Jadwal, Kegiatan Kelas) so the filter
  /// row is visually consistent. Tapping any chip opens the
  /// consolidated [TagihanFilterSheet]; the chip itself just acts as
  /// an at-a-glance summary of what's currently applied.
  Widget _buildActiveFiltersRow() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: 'Status',
            value: _selectedStatus == 'Semua' ? null : _selectedStatus,
            onTap: () => showFilterSheet(
              monthGroups,
              _selectedStatus,
              _selectedMonthKey,
              _selectedPaymentTypeId,
            ),
          ),
          BrandFilterChip(
            label: 'Bulan',
            value: _selectedMonthKey == null ? null : _getSelectedMonthName(),
            onTap: () => showFilterSheet(
              monthGroups,
              _selectedStatus,
              _selectedMonthKey,
              _selectedPaymentTypeId,
            ),
          ),
        ],
      ),
    );
  }

  String _getSelectedMonthName() {
    return monthGroups
        .firstWhere(
          (m) => m.monthKey == _selectedMonthKey,
          orElse: () => MonthGroup(
            monthKey: '',
            monthName: _selectedMonthKey!,
            paymentTypes: [],
          ),
        )
        .monthName;
  }

  bool _hasActiveFilters() {
    return _selectedStatus != 'Semua' ||
        _selectedMonthKey != null ||
        _selectedPaymentTypeId != null;
  }

  /// Predicate scoped to the [BrandFilterChipStrip] row above the
  /// jenis tabs. That row only surfaces Status + Bulan chips — jenis
  /// is presented in its own dedicated tabs strip — so we don't want
  /// it to render at all when jenis is the only active filter.
  /// Otherwise the row would show two empty placeholders and leave a
  /// visible gap below the KPI card.
  bool _hasActiveChipRowFilters() {
    return _selectedStatus != 'Semua' || _selectedMonthKey != null;
  }

  // === Mixin implementations ===
  @override
  String getClassId() => widget.classId;
  @override
  void onImagePicked(File file) => selectedFile = file;
  @override
  void onFilePicked(File file) => selectedFile = file;
  @override
  void onPaymentSuccess() => loadData();
  @override
  void onStatusFilterChanged(String s) => setState(() => _selectedStatus = s);
  @override
  void onMonthFilterChanged(String? m) => setState(() => _selectedMonthKey = m);
  @override
  void onPaymentTypeFilterChanged(String? t) =>
      setState(() => _selectedPaymentTypeId = t);
}

/// Body view modes for the per-kelas Laporan Keuangan screen.
///
/// `matrix` keeps the legacy frozen-column grid (good on tablets and
/// wide phones), `cards` switches to a per-siswa stack of cards each
/// carrying the same data but laid out vertically (friendlier on
/// narrow screens because there's no horizontal scroll).
enum _ReportView { matrix, cards }

/// Two-segment Matrix ↔ Per Siswa toggle. Sits between the jenis tabs
/// and the body so it visually anchors the active layout choice.
class _ViewToggleRow extends StatelessWidget {
  final _ReportView mode;
  final Color primaryColor;
  final ValueChanged<_ReportView> onChanged;

  const _ViewToggleRow({
    required this.mode,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSeg(
              label: 'Matrix',
              icon: Icons.grid_view_rounded,
              selected: mode == _ReportView.matrix,
              primaryColor: primaryColor,
              onTap: () => onChanged(_ReportView.matrix),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToggleSeg(
              label: 'Per Siswa',
              icon: Icons.view_agenda_rounded,
              selected: mode == _ReportView.cards,
              primaryColor: primaryColor,
              onTap: () => onChanged(_ReportView.cards),
            ),
          ),
        ],
      ),
    );
  }
}

/// SliverPersistentHeader delegate that pins the [ClassFinanceJenisTabs]
/// + Matrix/Per-Siswa toggle below the [BrandPageHeader] once the KPI
/// strip has scrolled past. White background so the navy gradient
/// behind it never bleeds through during the pin transition.
class _StickyTabsDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Color primaryColor;
  final List<MonthGroup> monthGroups;
  final String? selectedPaymentTypeId;
  final ValueChanged<String?> onJenisChanged;
  final _ReportView viewMode;
  final ValueChanged<_ReportView> onViewModeChanged;

  const _StickyTabsDelegate({
    required this.height,
    required this.primaryColor,
    required this.monthGroups,
    required this.selectedPaymentTypeId,
    required this.onJenisChanged,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // SizedBox(height: …) forces the painted extent to equal the
    // declared minExtent/maxExtent. Without this, the inner Column
    // shrink-wraps to its content (96dp) while the sliver declares
    // a larger maxExtent, and the framework throws
    // "layoutExtent exceeds paintExtent" — which presents to the
    // user as a blank screen + cascading null-check crashes from
    // `RenderViewportBase.visitChildrenForSemantics`.
    return SizedBox(
      height: height,
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: ClassFinanceJenisTabs(
                monthGroups: monthGroups,
                selectedPaymentTypeId: selectedPaymentTypeId,
                primaryColor: primaryColor,
                onChanged: onJenisChanged,
              ),
            ),
            // Matrix ↔ Per-siswa toggle. Implemented as a tight inline
            // pill row rather than the shared ViewToggleButton because
            // we need text labels (Matrix / Per Siswa) and per-mode
            // icons.
            _ViewToggleRow(
              mode: viewMode,
              primaryColor: primaryColor,
              onChanged: onViewModeChanged,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabsDelegate old) =>
      old.height != height ||
      old.primaryColor != primaryColor ||
      old.monthGroups != monthGroups ||
      old.selectedPaymentTypeId != selectedPaymentTypeId ||
      old.viewMode != viewMode;
}

class _ToggleSeg extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ToggleSeg({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? primaryColor : ColorUtils.slate50;
    final fg = selected ? Colors.white : ColorUtils.slate700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.transparent : ColorUtils.slate200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
