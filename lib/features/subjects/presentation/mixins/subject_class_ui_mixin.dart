// Main UI layout for subject class management.
//
// Visual contract (matches the admin Akademik detail pattern used by
// Raport, Pengumuman, Buku Nilai etc.):
//
//   ┌───────────────────────────────────────┐
//   │  BrandPageHeader (navy gradient)      │
//   │   subtitle = "MANAJEMEN KELAS"        │
//   │   title    = <subject name>           │
//   │   actions  = ✎ edit · ↻ refresh       │
//   │   bottomSlot = BrandFilterChipStrip   │
//   │     [ Status: <Semua|Terdaftar|...> ] │
//   └───────────────────────────────────────┘
//   │  BrandKpiStrip (Total / Terdaftar /   │
//   │  Belum Terdaftar)                     │
//   │  SearchFilterBar (solid)              │
//   │  ListView<BrandListRow>               │
//
// The filter chip lives inside the gradient so the "currently applied"
// state is visible at a glance — matching every other admin detail
// screen that follows the parent-pioneered chip-strip pattern.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_filter_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/subject_class_management_page.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_meta_card.dart';

mixin SubjectClassUiMixin on ConsumerState<SubjectClassManagementPage> {
  Set<String> get selectedIds;
  bool get bulkMode;
  void clearSelection();
  Future<void> bulkDetachSelected();
  TextEditingController get searchController;
  /// Builds the main UI scaffold. The header carries the navy
  /// gradient + kicker pattern and an optional [headerFilterChips]
  /// slot. Edit is exposed via the [SubjectMetaCard] inside the body,
  /// and refresh is via pull-to-refresh — so the action-icon slot is
  /// empty, matching the parent / teacher detail screens.
  Widget buildMainScaffold(
    bool isLoading,
    List<dynamic> filteredClasses,
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    Future<void> Function() onRefresh,
    VoidCallback onFabPressed,
    dynamic subject, {
    VoidCallback? onEdit,
    List<BrandFilterChip>? brandChips,
  }) {
    return AdminCrudScaffold(
      title: _resolveSubjectName(subject),
      subtitle: 'MANAJEMEN KELAS',
      role: 'admin',
      primaryColor: getPrimaryColor(),
      searchController: searchController,
      searchHint: 'Cari kelas...',
      onSearchChanged: (_) => setState(() {}),
      brandChips: brandChips,
      isLoading: isLoading,
      isEmpty: false, // We handle the empty state internally inside buildClassList
      onRefresh: onRefresh,
      emptyTitle: 'Tidak ada kelas',
      emptySubtitle: 'Tidak ditemukan hasil pencarian',
      emptyIcon: Icons.class_outlined,
      childBuilder: () => buildClassList(
        filteredClasses,
        availableClasses,
        assignedClasses0,
        subject,
        onEdit,
      ),
      onFabTap: onFabPressed,
      fabIcon: Icons.add,
      hideFab: ref.read(academicYearRiverpod).isReadOnly,
      selectedCount: selectedIds.length,
      onClearSelection: clearSelection,
      bulkItemNoun: 'kelas',
      bulkActions: [
        BulkAction(
          icon: Icons.delete_outline_rounded,
          label: 'Lepas',
          onTap: bulkDetachSelected,
          isDestructive: true,
        ),
      ],
    );
  }

  /// Resolves the display name from either Indonesian or English keys,
  /// going through the typed [Subject] model when possible.
  String _resolveSubjectName(dynamic subject) {
    if (subject is Map<String, dynamic>) {
      final name = Subject.fromJson(subject).name;
      if (name.isNotEmpty) return name;
    }
    return 'Subject';
  }

  /// Builds main body content. The body is a single scrollable so the
  /// pull-to-refresh gesture works everywhere — even when the list is
  /// empty. The class list slots into the bottom as a sliver-style
  /// `ListView.builder` wrapped in a `NeverScrollable` shrink-wrap so
  /// the outer scroll handles all gestures.
  Widget buildBody(
    bool isLoading,
    List<dynamic> filteredClasses,
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0, {
    dynamic subject,
    VoidCallback? onEdit,
  }) {
    if (isLoading) {
      return ListView(
        children: const [
          SizedBox(height: AppSpacing.md),
          SkeletonListLoading(itemCount: 6, infoTagCount: 2),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (subject != null)
          buildSubjectMetaCard(
            subject: subject,
            totalClasses: availableClasses.length,
            onEdit: onEdit,
          ),
        buildStatsContainer(availableClasses.length, assignedClasses0.length),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: buildSearchBar(),
        ),
        const SizedBox(height: AppSpacing.sm),
        buildResultCount(filteredClasses),
        buildClassList(filteredClasses),
      ],
    );
  }

  /// Builds the subject identity card sitting above the KPI strip.
  /// Reads the subject map via [Subject.fromJson] so admin/parent key
  /// variations are handled at one site. The card flips to a slate
  /// "Hanya baca" pill instead of the Edit CTA when the dashboard is
  /// pointed at a past academic year.
  Widget buildSubjectMetaCard({
    required dynamic subject,
    required int totalClasses,
    VoidCallback? onEdit,
  }) {
    if (subject is! Map<String, dynamic>) return const SizedBox.shrink();
    final model = Subject.fromJson(subject);
    return SubjectMetaCard(
      subject: model,
      totalClasses: totalClasses,
      onEdit: onEdit ?? () {},
      isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
    );
  }

  /// Builds the KPI strip — replaces the legacy corporate-blue stats
  /// card with the shared `BrandKpiStrip` so the visual identity
  /// matches every other admin detail screen (Raport, Kehadiran, etc.).
  Widget buildStatsContainer(int totalClasses, int assignedCount) {
    final remaining = totalClasses - assignedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
      child: BrandKpiStrip(
        columns: [
          BrandKpiColumn(label: 'Total Kelas', value: totalClasses.toString()),
          BrandKpiColumn(
            label: 'Terdaftar',
            value: assignedCount.toString(),
            valueColor: ColorUtils.success600,
          ),
          BrandKpiColumn(
            label: 'Belum Terdaftar',
            value: remaining.toString(),
            valueColor: remaining > 0
                ? ColorUtils.warning600
                : ColorUtils.slate600,
          ),
        ],
      ),
    );
  }

  /// Builds search bar widget
  Widget buildSearchBar();

  /// Builds result count text
  Widget buildResultCount(List<dynamic> filteredClasses) {
    if (filteredClasses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '${filteredClasses.length} '
            'kelas ditemukan',
            style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget buildClassList(
    List<dynamic> filteredClasses,
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    dynamic subject,
    VoidCallback? onEdit,
  ) {
    final bool isEmpty = filteredClasses.isEmpty;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: isEmpty ? 3 : filteredClasses.length + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (subject != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: buildSubjectMetaCard(
                subject: subject,
                totalClasses: availableClasses.length,
                onEdit: onEdit,
              ),
            );
          }
          return const SizedBox.shrink();
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: buildStatsContainer(availableClasses.length, assignedClasses0.length),
          );
        }
        if (index == 2) {
          if (isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: EmptyState(
                title: 'Tidak ada kelas',
                subtitle: 'Tidak ditemukan hasil pencarian',
                icon: Icons.class_outlined,
              ),
            );
          }
          return buildResultCount(filteredClasses);
        }

        final classIndex = index - 3;
        final classItem = filteredClasses[classIndex];
        final id = classItem['id']?.toString() ?? '';
        final isSelected = selectedIds.contains(id);
        final isAssigned = checkIfClassAssigned(id);
        return buildClassCard(classItem, classIndex, isAssigned, isSelected);
      },
    );
  }

  List<BrandFilterChip> buildBrandChips({
    required String currentFilter,
    required SubjectClassSort currentSort,
    required VoidCallback onTap,
  }) {
    return [
      BrandFilterChip(
        label: 'Status',
        value: _statusLabel(currentFilter),
        onTap: onTap,
      ),
      BrandFilterChip(
        label: 'Urutkan',
        value: _sortLabel(currentSort),
        onTap: onTap,
      ),
    ];
  }

  String _statusLabel(String currentFilter) {
    switch (currentFilter) {
      case 'Assigned':
        return 'Terdaftar';
      case 'Unassigned':
        return 'Belum Terdaftar';
      case 'All':
      default:
        return 'Semua';
    }
  }

  String _sortLabel(SubjectClassSort sort) {
    switch (sort) {
      case SubjectClassSort.assignedFirst:
        return 'Terdaftar dulu';
      case SubjectClassSort.unassignedFirst:
        return 'Belum dulu';
      case SubjectClassSort.nameAsc:
        return 'Nama A→Z';
      case SubjectClassSort.nameDesc:
        return 'Nama Z→A';
      case SubjectClassSort.gradeAsc:
        return 'Tingkat ↑';
    }
  }

  /// Builds floating action button
  FloatingActionButton? buildFab(VoidCallback onPressed) {
    if (ref.read(academicYearRiverpod).isReadOnly) {
      return null;
    }
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: getPrimaryColor(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 20),
    );
  }

  /// Gets primary color for UI
  Color getPrimaryColor();

  /// Builds individual class card
  Widget buildClassCard(
    Map<String, dynamic> classItem,
    int index,
    bool isAssigned,
    bool isSelected,
  );

  /// Builds stat item
  Widget buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  });

  /// Checks if a class is assigned
  bool checkIfClassAssigned(String classId);
}
