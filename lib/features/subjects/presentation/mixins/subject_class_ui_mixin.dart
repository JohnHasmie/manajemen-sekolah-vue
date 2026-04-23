// Main UI layout for subject class management
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/subject_class_management_page.dart';

mixin SubjectClassUiMixin on ConsumerState<SubjectClassManagementPage> {
  /// Builds the main UI scaffold
  Widget buildMainScaffold(
    bool isLoading,
    List<dynamic> filteredClasses,
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    VoidCallback onRefresh,
    VoidCallback onFabPressed,
    dynamic subject,
  ) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      appBar: buildAppBar(subject, onRefresh),
      body: buildBody(
        isLoading,
        filteredClasses,
        availableClasses,
        assignedClasses0,
      ),
      floatingActionButton: buildFab(onFabPressed),
    );
  }

  /// Builds app bar with title and refresh button
  PreferredSizeWidget buildAppBar(dynamic subject, VoidCallback onRefresh) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _resolveSubjectName(subject),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Manajemen Kelas',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      backgroundColor: ColorUtils.corporateBlue600,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: onRefresh,
          tooltip: 'Refresh',
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
        buildSearchBar(),
        buildResultCount(filteredClasses),
        buildClassList(filteredClasses),
      ],
    );
  }

  /// Builds stats container at top
  Widget buildStatsContainer(int totalClasses, int assignedCount) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: ColorUtils.corporateShadow(elevation: 2.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          buildStatItem(
            icon: Icons.class_,
            value: totalClasses.toString(),
            label: 'Total Kelas',
            color: Colors.white,
          ),
          buildStatItem(
            icon: Icons.check_circle,
            value: assignedCount.toString(),
            label: 'Terdaftar',
            color: Colors.white,
          ),
          buildStatItem(
            icon: Icons.add_circle,
            value: (totalClasses - assignedCount).toString(),
            label: 'Belum Terdaftar',
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  /// Builds search and filter bar
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
    const SizedBox(height: AppSpacing.xs);

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
        itemCount: filteredClasses.length,
        itemBuilder: (context, index) {
          final classItem = filteredClasses[index];
          final isAssigned = checkIfClassAssigned(classItem['id']);
          return buildClassCard(classItem, index, isAssigned);
        },
      ),
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
