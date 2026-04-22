import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_card.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_table_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';

/// Builds the body of the schedule management screen.
///
/// Handles loading state, empty state, table view, and card list view.
/// Extracted to keep build methods focused.
class AdminScheduleListBuilder extends ConsumerWidget {
  final bool isLoading;
  final bool showTableView;
  final List<dynamic> filteredSchedules;
  final List<ScheduleGridData> gridData;
  final dynamic timetableDataSource;
  final List<dynamic> dayList;
  final List<dynamic> classList;
  final bool hasMoreData;
  final bool isLoadingMore;
  final String? selectedClassId;
  final Color primaryColor;
  final AdminScheduleController controller;
  final ScrollController scrollController;
  final bool isReadOnly;
  final String currentLanguage;

  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onScheduleTap;
  final Function(Map<String, dynamic>) onScheduleEdit;
  final Function(String) onScheduleDelete;

  const AdminScheduleListBuilder({
    super.key,
    required this.isLoading,
    required this.showTableView,
    required this.filteredSchedules,
    required this.gridData,
    required this.timetableDataSource,
    required this.dayList,
    required this.classList,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.selectedClassId,
    required this.primaryColor,
    required this.controller,
    required this.scrollController,
    required this.isReadOnly,
    required this.currentLanguage,
    required this.onRefresh,
    required this.onScheduleTap,
    required this.onScheduleEdit,
    required this.onScheduleDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
    }

    if (showTableView) {
      return _buildTableView(ref);
    }

    if (filteredSchedules.isEmpty) {
      return EmptyState(
        title: ref.read(languageRiverpod).getTranslatedText({
          'en': 'No Schedules Found',
          'id': 'Jadwal Tidak Ditemukan',
        }),
        subtitle: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Try adjusting your filters',
          'id': 'Coba sesuaikan filter Anda',
        }),
        icon: Icons.event_busy,
      );
    }

    return _buildScheduleList();
  }

  Widget _buildTableView(WidgetRef ref) {
    if (timetableDataSource == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ScheduleTableView(
      timetableDataSource: timetableDataSource,
      dayList: dayList,
      classList: classList,
      selectedClassId: selectedClassId,
      gridData: gridData,
      primaryColor: primaryColor,
      languageProvider: ref.read(languageRiverpod),
      onExport: () {}, // Export handled by main screen
      translateDay: controller.translateDay,
    );
  }

  Widget _buildScheduleList() {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filteredSchedules.length + (hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredSchedules.length) {
            return _buildLoadingIndicator();
          }
          return _buildScheduleCard(filteredSchedules[index], index);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, int index) {
    return AdminScheduleCard(
      schedule: schedule,
      index: index,
      isReadOnly: isReadOnly,
      primaryColor: primaryColor,
      dayLabel: controller.formatScheduleDays(
        schedule,
        dayList,
        currentLanguage,
      ),
      timeLabel: controller.formatTime(schedule),
      onTap: () => onScheduleTap(schedule),
      onEdit: () => onScheduleEdit(schedule),
      onDelete: () => onScheduleDelete(schedule['id']),
    );
  }
}
