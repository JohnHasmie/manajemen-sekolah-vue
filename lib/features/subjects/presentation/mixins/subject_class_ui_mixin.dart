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
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/subject_class_management_page.dart';

mixin SubjectClassUiMixin on ConsumerState<SubjectClassManagementPage> {
  /// Builds the main UI scaffold. The header carries the navy gradient
  /// + kicker pattern + edit/refresh action icons, and an optional
  /// [headerFilterChips] slot hosts the Status filter chip strip so
  /// the applied filter is visible without opening a sheet.
  Widget buildMainScaffold(
    bool isLoading,
    List<dynamic> filteredClasses,
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    VoidCallback onRefresh,
    VoidCallback onFabPressed,
    dynamic subject, {
    VoidCallback? onEdit,
    Widget? headerFilterChips,
  }) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'admin',
            title: _resolveSubjectName(subject),
            subtitle: 'MANAJEMEN KELAS',
            actionIcons: [
              if (onEdit != null)
                BrandHeaderIconButton(icon: Icons.edit_outlined, onTap: onEdit),
              BrandHeaderIconButton(
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
            ],
            bottomSlot: headerFilterChips,
          ),
          Expanded(
            child: buildBody(
              isLoading,
              filteredClasses,
              availableClasses,
              assignedClasses0,
            ),
          ),
        ],
      ),
      floatingActionButton: buildFab(onFabPressed),
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

  /// Builds main body content
  Widget buildBody(
    bool isLoading,
    List<dynamic> filteredClasses,
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
  ) {
    if (isLoading) {
      return const SkeletonListLoading(itemCount: 6, infoTagCount: 2);
    }

    return Column(
      children: [
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

  /// Builds class list or empty state
  Widget buildClassList(List<dynamic> filteredClasses) {
    if (filteredClasses.isEmpty) {
      return const Expanded(
        child: EmptyState(
          title: 'Tidak ada kelas',
          subtitle:
              'Tidak ditemukan hasil '
              'pencarian',
          icon: Icons.class_outlined,
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 96),
        itemCount: filteredClasses.length,
        itemBuilder: (context, index) {
          final classItem = filteredClasses[index];
          final isAssigned = checkIfClassAssigned(classItem['id']);
          return buildClassCard(classItem, index, isAssigned);
        },
      ),
    );
  }

  /// Builds the Status filter chip strip used inside the header's
  /// bottomSlot. The single "Status" chip displays the applied value
  /// ("Semua" / "Terdaftar" / "Belum Terdaftar") and opens a picker
  /// sheet on tap.
  Widget buildStatusFilterChipStrip({
    required String currentFilter,
    required VoidCallback onTap,
  }) {
    String label;
    switch (currentFilter) {
      case 'Assigned':
        label = 'Terdaftar';
        break;
      case 'Unassigned':
        label = 'Belum Terdaftar';
        break;
      case 'All':
      default:
        label = 'Semua';
    }
    return BrandFilterChipStrip(
      chips: [BrandFilterChip(label: 'Status', value: label, onTap: onTap)],
    );
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
