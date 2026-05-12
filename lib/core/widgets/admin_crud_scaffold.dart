// Canonical scaffold for admin CRUD screens (Siswa, Guru, Kelas, Mapel,
// Jadwal, Tagihan, Pengumuman).
//
// Why this exists
// ---------------
// Every admin CRUD list today reinvents the same shell:
//   gradient header (title + school pill + search + filter) →
//   active-filter chips row →
//   pull-to-refresh wrapping a skeleton/empty/error/list state →
//   a "+ add" FAB →
//   and, when multi-select is on, a floating bulk action bar.
//
// Each feature has a bespoke implementation with subtle differences
// (search debounce wiring, empty-state copy, FAB color, safe-area handling
// around the bulk bar). Those drift becomes visible when an admin swipes
// between Siswa and Guru — different search placeholder placement, different
// FAB shape, different chip style.
//
// `AdminCrudScaffold` locks the shell so callers only own:
//   • their data fetching (isLoading / errorMessage / isEmpty / onRefresh)
//   • their list builder (`childBuilder`)
//   • their filter sheet open handler (`onFilterTap`)
//   • their FAB handler and bulk actions
//
// Under the hood this composes [TeacherPageHeader] (for the gradient header
// + search + chips — admins piggyback on the same widget teachers already
// use, which is the whole point) plus [TeacherAsyncView] (for the 4-state
// body) plus [BulkActionBar]. Everything else (spacing, shadows, FAB radius,
// safe area) is baked in.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/search_filter_bar.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';

/// Canonical admin CRUD shell — header + async body + FAB + bulk bar.
///
/// Example (minimum viable):
/// ```dart
/// AdminCrudScaffold(
///   title: 'Manajemen Siswa',
///   subtitle: '1.248 siswa aktif',
///   primaryColor: ColorUtils.getRoleColor('admin'),
///   schoolName: 'SMA Al-Kamil',
///   onSchoolTap: _openSchoolPicker,
///   searchController: _searchController,
///   searchHint: 'Cari siswa...',
///   onSearchChanged: (q) => _reload(),
///   onFilterTap: _openFilterSheet,
///   hasActiveFilter: _hasActiveFilter,
///   activeFilters: _buildActiveFilterChips(),
///   onClearAllFilters: _clearFilters,
///   isLoading: _isLoading,
///   errorMessage: _error,
///   isEmpty: _items.isEmpty,
///   onRefresh: _reload,
///   emptyTitle: 'Belum ada siswa',
///   emptySubtitle: 'Tap + untuk menambah siswa',
///   emptyIcon: Icons.people_outline,
///   childBuilder: () => _buildList(),
///   onFabTap: _openAddSheet,
///   fabIcon: Icons.add,
///   selectedCount: _selectedIds.length,
///   onClearSelection: _clearSelection,
///   bulkActions: _bulkActions(),
/// );
/// ```
class AdminCrudScaffold extends StatelessWidget {
  // ── Header ──

  /// Page title displayed in the gradient header.
  final String title;

  /// Subtitle under [title] — typically the total count ("1.248 siswa aktif").
  final String subtitle;

  /// Accent color driving the gradient header, FAB, and loading shimmer.
  final Color primaryColor;

  /// Optional back-button override. Pass `null` to use the default (pop
  /// when [Navigator.canPop] is true).
  final VoidCallback? onBackPressed;

  /// Override for the back-button visibility. Defaults to auto-detect.
  final bool? showBackButton;

  // ── School pill (trailing in header) ──

  /// School name shown in the trailing [SchoolPill]. When null, the pill is
  /// hidden — use for screens where a school context is not relevant.
  final String? schoolName;

  /// Optional secondary line in the pill ("2025/2026 · Admin").
  final String? schoolSubtitle;

  /// School logo URL for the pill; falls back to a monogrammed initial.
  final String? schoolLogoUrl;

  /// Tap handler for the school pill — typically opens a school picker.
  final VoidCallback? onSchoolTap;

  // ── Search + filter ──

  /// Controller for the header search field.
  final TextEditingController? searchController;

  /// Placeholder copy inside the search field.
  final String searchHint;

  /// Called on every keystroke in the search field.
  final ValueChanged<String>? onSearchChanged;

  /// Called when the search field is submitted (keyboard "done").
  final ValueChanged<String>? onSearchSubmitted;

  /// Called when the filter-icon button is tapped — typically opens an
  /// [AppFilterBottomSheet].
  final VoidCallback? onFilterTap;

  /// Whether the filter button shows an active-filter badge.
  final bool hasActiveFilter;

  // ── Active filter chips ──

  /// Dismissible chips rendered in a white bar below the gradient.
  final List<ActiveFilter>? activeFilters;

  /// Called when the "Hapus" clear-all button is tapped.
  final VoidCallback? onClearAllFilters;

  // ── Async body ──

  /// Initial-load spinner flag.
  final bool isLoading;

  /// Error message; when non-null, an [AppErrorState] replaces the body.
  final String? errorMessage;

  /// Whether the underlying data list is empty.
  final bool isEmpty;

  /// Pull-to-refresh callback; also wired to the error retry button.
  final Future<void> Function() onRefresh;

  /// Builder for the main content (typically a scrollable list).
  final Widget Function() childBuilder;

  /// Empty-state title shown when [isEmpty] is true.
  final String emptyTitle;

  /// Empty-state subtitle.
  final String emptySubtitle;

  /// Empty-state icon.
  final IconData emptyIcon;

  /// Optional CTA label in the empty state (renders a button).
  final String? emptyActionLabel;

  /// Optional CTA callback in the empty state.
  final VoidCallback? onEmptyAction;

  // ── FAB ──

  /// FAB tap handler. When null, no FAB is rendered.
  final VoidCallback? onFabTap;

  /// FAB icon. Default: `Icons.add`.
  final IconData fabIcon;

  /// FAB accent color. Defaults to [primaryColor] so role theming is
  /// automatic — set explicitly only when overriding.
  final Color? fabColor;

  /// Optional key for tour targeting.
  final Key? fabKey;

  /// When true, hide the FAB even if [onFabTap] is set. Useful for read-only
  /// academic years ("siswa arsip 2024/2025").
  final bool hideFab;

  // ── Bulk action bar ──

  /// Current selection size. When zero, the bulk bar is hidden.
  final int selectedCount;

  /// Clear-selection handler.
  final VoidCallback? onClearSelection;

  /// Actions exposed in the bulk bar.
  final List<BulkAction> bulkActions;

  /// Noun used in the "N item terpilih" pill (default: 'item').
  final String bulkItemNoun;

  // ── Escape hatch ──

  /// Optional widget injected BELOW the active-filter chips and ABOVE the
  /// async body. Use sparingly — e.g., a stat row or a view toggle that
  /// isn't part of the header gradient.
  final Widget? toolbar;

  /// Optional widget injected ABOVE the header (e.g., a banner). Keep it
  /// short — it will squeeze the header.
  final Widget? topBanner;

  /// When false, the default `AppBar` isn't rendered at all and the caller
  /// becomes responsible for the entire header region. Default: true.
  final bool renderHeader;

  /// Optional header action widget rendered in the trailing area, peer to
  /// the [SchoolPill] (e.g., a `PopupMenuButton` for refresh / export /
  /// import / template). When both [schoolName] and [actionMenu] are set,
  /// they render in a single row with the menu on the right of the pill.
  /// When only [actionMenu] is set, it occupies the trailing slot alone.
  final Widget? actionMenu;

  /// Optional custom FAB widget. When non-null, replaces the default
  /// [FloatingActionButton] that would be built from
  /// [onFabTap] / [fabIcon] / [fabColor]. Use when a screen needs a
  /// speed-dial, a column of actions, or any non-standard FAB shape
  /// (e.g., Kelas — add + promote-class). Still respects [hideFab] and
  /// the bulk-bar hide behavior.
  final Widget? customFab;

  // ── v3 brand-aligned mode ──
  //
  // When [brandChips] is non-null the scaffold renders the parent-aligned
  // v3 hero (BrandPageHeader with embedded BrandFilterChipStrip) and a
  // white search bar that overlaps the hero's bottom rounded edge —
  // matching the parent Tagihan/Nilai/Kehadiran visual language.
  //
  // When [brandChips] is null the scaffold falls back to the legacy
  // [TeacherPageHeader] + active-filter-chips bar so older callers keep
  // working unchanged.

  /// Filter chips rendered inside the gradient header (v3 mode). When
  /// provided, the scaffold uses [BrandPageHeader] instead of
  /// [TeacherPageHeader] and hides the legacy [activeFilters] white bar.
  final List<BrandFilterChip>? brandChips;

  /// Optional small kicker line above the title (e.g. `MANAJEMEN DATA`).
  /// Only used in v3 mode. Falls back to [subtitle] when null.
  final String? headerKicker;

  /// Role driving the brand gradient when v3 mode is active. Defaults to
  /// `'admin'` (navy). Pass `'guru'` / `'wali'` if the same scaffold ever
  /// needs to render under teacher / parent.
  final String role;

  /// Whether to render the green "REAL-TIME" pill in the v3 hero. Default
  /// true. Only used when [brandChips] is non-null.
  final bool showRealtimePill;

  /// Optional total-counter chip rendered next to the realtime pill in the
  /// v3 hero. E.g. `"86 GURU"`, `"1.248 SISWA"`. Hidden when null.
  final String? counterLabel;

  const AdminCrudScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onRefresh,
    required this.childBuilder,
    this.onBackPressed,
    this.showBackButton,
    this.schoolName,
    this.schoolSubtitle,
    this.schoolLogoUrl,
    this.onSchoolTap,
    this.searchController,
    this.searchHint = 'Cari...',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.activeFilters,
    this.onClearAllFilters,
    this.isLoading = false,
    this.errorMessage,
    this.isEmpty = false,
    this.emptyTitle = 'Belum ada data',
    this.emptySubtitle = 'Tarik ke bawah untuk memuat ulang',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onFabTap,
    this.fabIcon = Icons.add,
    this.fabColor,
    this.fabKey,
    this.hideFab = false,
    this.selectedCount = 0,
    this.onClearSelection,
    this.bulkActions = const [],
    this.bulkItemNoun = 'item',
    this.toolbar,
    this.topBanner,
    this.renderHeader = true,
    this.actionMenu,
    this.customFab,
    this.brandChips,
    this.headerKicker,
    this.role = 'admin',
    this.showRealtimePill = true,
    this.counterLabel,
  });

  bool get _showSearch =>
      searchController != null &&
      (onSearchChanged != null ||
          onSearchSubmitted != null ||
          onFilterTap != null);

  bool get _showBulkBar =>
      selectedCount > 0 && onClearSelection != null && bulkActions.isNotEmpty;

  bool get _useBrandHeader => brandChips != null;

  @override
  Widget build(BuildContext context) {
    final trailing = _buildTrailing();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50
      body: Column(
        children: [
          if (topBanner != null) topBanner!,
          if (renderHeader && _useBrandHeader)
            _buildBrandHeader()
          else if (renderHeader)
            TeacherPageHeader(
              title: title,
              subtitle: subtitle,
              primaryColor: primaryColor,
              onBackPressed: onBackPressed,
              showBackButton: showBackButton,
              trailing: trailing,
              showSearchFilter: _showSearch,
              searchController: searchController,
              searchHintText: searchHint,
              onSearchChanged: onSearchChanged,
              onSearchSubmitted: onSearchSubmitted,
              onFilterTap: onFilterTap,
              hasActiveFilter: hasActiveFilter,
              activeFilters: activeFilters,
              onClearAllFilters: onClearAllFilters,
            ),
          if (renderHeader && _useBrandHeader && _showSearch)
            _buildBrandSearchBar(),
          if (toolbar != null) toolbar!,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: TeacherAsyncView(
                isLoading: isLoading,
                errorMessage: errorMessage,
                isEmpty: isEmpty,
                onRefresh: onRefresh,
                role: role,
                emptyTitle: emptyTitle,
                emptySubtitle: emptySubtitle,
                emptyIcon: emptyIcon,
                emptyActionLabel: emptyActionLabel,
                onEmptyAction: onEmptyAction,
                childBuilder: childBuilder,
              ),
            ),
          ),
          // Bulk bar sits above the home indicator — it self-handles
          // SafeArea. When nothing is selected it collapses to shrink().
          if (_showBulkBar)
            BulkActionBar(
              selectedCount: selectedCount,
              onClear: onClearSelection!,
              actions: bulkActions,
              itemNoun: bulkItemNoun,
              accentColor: primaryColor,
            ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  /// Build the trailing slot in the header. Handles the four combinations of
  /// [schoolName] × [actionMenu] (both/either/none) so callers only worry
  /// about which props they want to set.
  Widget? _buildTrailing() {
    final hasPill = schoolName != null;
    final hasMenu = actionMenu != null;
    if (!hasPill && !hasMenu) return null;

    final pill = hasPill
        ? SchoolPill(
            schoolName: schoolName!,
            subtitle: schoolSubtitle,
            logoUrl: schoolLogoUrl,
            onTap: onSchoolTap,
            accentColor: primaryColor,
            onDarkSurface: true,
          )
        : null;

    if (hasPill && hasMenu) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [pill!, const SizedBox(width: 4), actionMenu!],
        ),
      );
    }

    if (hasPill) {
      return Padding(padding: const EdgeInsets.only(left: 8), child: pill!);
    }

    // Only actionMenu.
    return Padding(padding: const EdgeInsets.only(left: 8), child: actionMenu!);
  }

  /// Build the v3 brand-aligned hero — matches parent Tagihan/Nilai pattern.
  /// Renders: BrandPageHeader with kicker / big title / realtime pill +
  /// counter / embedded BrandFilterChipStrip. Filter & action menu icons
  /// sit at top-right.
  Widget _buildBrandHeader() {
    final actions = <Widget>[];
    if (onFilterTap != null) {
      actions.add(
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: onFilterTap!,
          badgeCount: hasActiveFilter ? _activeFilterCount() : null,
          badgeBorderColor: primaryColor,
        ),
      );
    }
    if (actionMenu != null) actions.add(actionMenu!);

    return BrandPageHeader(
      role: role,
      title: title,
      subtitle: headerKicker ?? subtitle,
      onBackPressed: onBackPressed,
      showBackButton: showBackButton,
      actionIcons: actions.isEmpty ? null : actions,
      isRealtimeFresh: showRealtimePill ? true : null,
      bottomSlot: BrandFilterChipStrip(chips: brandChips!),
    );
  }

  /// White search bar rendered just below the gradient hero in v3 mode.
  ///
  /// Drops the earlier negative-offset overlap — on real devices the
  /// translate created an inconsistent gap with the chip strip above. A
  /// flat 12 px top / 8 px bottom padding gives the chips room to breathe
  /// and the section header / list below room to read.
  Widget _buildBrandSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        12,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        elevation: 2,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        shadowColor: Colors.black.withValues(alpha: 0.10),
        child: SearchFilterBar(
          controller: searchController!,
          hintText: searchHint,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
          onFilterTap: null,
          hasActiveFilter: false,
          activeFilterCount: 0,
          transparentStyle: false,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  int _activeFilterCount() {
    if (brandChips == null) return 0;
    return brandChips!.where((c) => c.value != null).length;
  }

  Widget? _buildFab() {
    if (hideFab) return null;
    // The bulk bar is also a bottom-anchored surface; when it's visible we
    // hide the FAB to avoid a double-stacked floating element. Callers that
    // want the FAB during bulk mode can opt back in by wrapping this widget
    // themselves.
    if (_showBulkBar) return null;
    // Custom FAB takes precedence — used by Kelas (speed-dial with
    // add + promote-class) and any other screen that needs a non-standard
    // FAB shape.
    if (customFab != null) return customFab;
    if (onFabTap == null) return null;
    return FloatingActionButton(
      key: fabKey,
      onPressed: onFabTap,
      backgroundColor: fabColor ?? primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Icon(fabIcon, color: Colors.white, size: 22),
    );
  }
}
