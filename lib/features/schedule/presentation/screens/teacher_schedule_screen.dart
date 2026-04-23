/// Teaching schedule screen -- the teacher's timetable/calendar view.
/// Displays the teacher's weekly schedule with two view modes: card and
/// table view. Supports filtering by day, semester, class, real-time sync
/// via FCM push notifications, and quick navigation to related screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/core/widgets/view_toggle_button.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_card_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_tour_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_data_loading_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_cache_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_filter_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_preferences_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_ui_mixin.dart';

/// Teacher's weekly schedule screen with card and table view modes.
class TeachingScheduleScreen extends ConsumerStatefulWidget {
  const TeachingScheduleScreen({super.key});

  @override
  TeachingScheduleScreenState createState() => TeachingScheduleScreenState();
}

/// State for [TeachingScheduleScreen].
/// Manages schedule display, filtering, view modes, and real-time sync.
class TeachingScheduleScreenState extends ConsumerState<TeachingScheduleScreen>
    with
        ScheduleTourMixin,
        TeacherScheduleDataLoadingMixin,
        TeacherScheduleCacheMixin,
        TeacherScheduleFilterMixin,
        TeacherSchedulePreferencesMixin,
        TeacherScheduleUiMixin {
  // Tour properties (bridge for ScheduleTourMixin)
  final GlobalKey _toggleViewKey = GlobalKey();
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _firstScheduleKey = GlobalKey();
  final GlobalKey _actionButtonsKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();

  /// True only until the first schedule load completes. Controls whether the
  /// card view auto-scrolls to the current/next lesson.
  bool _isInitialLoad = true;

  @override
  GlobalKey get toggleViewKey => _toggleViewKey;
  @override
  GlobalKey get searchFilterKey => _searchFilterKey;
  @override
  GlobalKey get firstScheduleKey => _firstScheduleKey;
  @override
  GlobalKey get actionButtonsKey => _actionButtonsKey;

  @override
  void initState() {
    super.initState();
    setDefaultAcademicPeriod();
    loadUserData().then((_) {
      if (!mounted) return;
      loadSchedule(
        searchController: _searchController,
        selectedDayIds: selectedDayIdsInternal,
        selectedClassId: selectedClassIdInternal,
        selectedFilterSemester: selectedFilterSemesterInternal,
        dayIdMap: dayIdMapInternal,
      ).then((_) {
        if (mounted) _isInitialLoad = false;
      });
    });
    loadViewPreference();
    FCMService().syncTrigger.addListener(onSyncTriggered);
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(onSyncTriggered);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final filteredSchedules = getFilteredSchedules(
      scheduleList,
      _searchController.text,
    );

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          TeacherPageHeader(
            primaryColor: getPrimaryColor(),
            title: languageProvider.getTranslatedText({
              'en': 'Teaching Schedule',
              'id': 'Jadwal Mengajar',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': isHomeroomView && selectedHomeroomClass != null
                  ? 'Viewing Homeroom Schedule'
                  : 'View your teaching schedule',
              'id': isHomeroomView && selectedHomeroomClass != null
                  ? 'Melihat Jadwal Wali Kelas'
                  : 'Lihat jadwal mengajar Anda',
            }),
            showRoleToggle: homeroomClassesList.isNotEmpty,
            isHomeroomView: isHomeroomView,
            onRoleChanged: (isHomeroom) {
              setState(() {
                isHomeroomView = isHomeroom;
                if (isHomeroom &&
                    selectedHomeroomClass == null &&
                    homeroomClassesList.isNotEmpty) {
                  selectedHomeroomClass = homeroomClassesList.first;
                }
                scheduleList = [];
                isLoading = true;
              });
              loadSchedule(
                useCache: true,
                searchController: _searchController,
                selectedDayIds: selectedDayIds,
                selectedClassId: selectedClassId,
                selectedFilterSemester: selectedFilterSemester,
                dayIdMap: dayIdMap,
              );
            },
            homeroomClassName: selectedHomeroomClass?['name'],
            showSearchFilter: true,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            onFilterTap: () => showFilterSheet(
              getPrimaryColor(),
              languageProvider,
              selectedTerm,
              ({
                required dayIdMap,
                required searchController,
                required selectedDayIds,
                required selectedClassId,
                required selectedFilterSemester,
              }) => loadSchedule(
                useCache: true,
                searchController: searchController,
                selectedDayIds: selectedDayIds,
                selectedClassId: selectedClassId,
                selectedFilterSemester: selectedFilterSemester,
                dayIdMap: dayIdMap,
              ),
              _searchController,
            ),
            hasActiveFilter: hasActiveFilter,
            searchHintText: languageProvider.getTranslatedText({
              'en': 'Search schedules...',
              'id': 'Cari jadwal...',
            }),
            onBackPressed: () => AppNavigator.pop(context),
            activeFilters: hasActiveFilter
                ? buildFilterChips(
                    languageProvider,
                    selectedTerm,
                    ({
                      required dayIdMap,
                      required searchController,
                      required selectedDayIds,
                      required selectedClassId,
                      required selectedFilterSemester,
                    }) => loadSchedule(
                      useCache: true,
                      searchController: searchController,
                      selectedDayIds: selectedDayIds,
                      selectedClassId: selectedClassId,
                      selectedFilterSemester: selectedFilterSemester,
                      dayIdMap: dayIdMap,
                    ),
                    _searchController,
                  )
                : null,
            onClearAllFilters: () => clearAllFilters(
              selectedTerm,
              loadTermData,
              ({
                required dayIdMap,
                required searchController,
                required selectedDayIds,
                required selectedClassId,
                required selectedFilterSemester,
              }) => loadSchedule(
                useCache: true,
                searchController: searchController,
                selectedDayIds: selectedDayIds,
                selectedClassId: selectedClassId,
                selectedFilterSemester: selectedFilterSemester,
                dayIdMap: dayIdMap,
              ),
              _searchController,
            ),
            trailing: ViewToggleButton(
              key: _toggleViewKey,
              currentMode: isTableView ? ViewMode.table : ViewMode.card,
              availableModes: const [ViewMode.card, ViewMode.table],
              onChanged: (mode) => setState(() {
                isTableView = mode == ViewMode.table;
              }),
            ),
          ),
          Expanded(
            child: TeacherAsyncView(
              isLoading: isLoading,
              errorMessage: errorMessage,
              isEmpty: filteredSchedules.isEmpty,
              onRefresh: () => forceRefresh(
                _searchController,
                selectedDayIds,
                selectedClassId,
                selectedFilterSemester,
                dayIdMap,
                ({
                  required searchController,
                  required selectedDayIds,
                  required selectedClassId,
                  required selectedFilterSemester,
                }) => loadSchedule(
                  useCache: true,
                  searchController: searchController,
                  selectedDayIds: selectedDayIds,
                  selectedClassId: selectedClassId,
                  selectedFilterSemester: selectedFilterSemester,
                  dayIdMap: dayIdMap,
                ),
              ),
              role: 'guru',
              emptyTitle: languageProvider.getTranslatedText({
                'en': 'No Teaching Schedules',
                'id': 'Tidak Ada Jadwal Mengajar',
              }),
              emptySubtitle: languageProvider.getTranslatedText({
                'en': _searchController.text.isNotEmpty || hasActiveFilter
                    ? 'No schedules found for search and filters'
                    : 'There are no teaching schedules available',
                'id': _searchController.text.isNotEmpty || hasActiveFilter
                    ? 'Tidak ada jadwal yang sesuai'
                    : 'Tidak ada jadwal mengajar',
              }),
              emptyIcon: Icons.schedule_outlined,
              childBuilder: () => isTableView
                  ? TeacherScheduleTableView(
                      schedules: filteredSchedules,
                      dayIdMap: dayIdMap,
                      dayColorMap: dayColorMap,
                      dayOptions: dayOptions,
                      primaryColor: getPrimaryColor(),
                      teacherId: teacherId,
                      teacherNama: teacherNama,
                      dailySummary: dailySummary,
                      isHomeroomView: isHomeroomView,
                      onRefresh: () => forceRefresh(
                        _searchController,
                        selectedDayIds,
                        selectedClassId,
                        selectedFilterSemester,
                        dayIdMap,
                        ({
                          required searchController,
                          required selectedDayIds,
                          required selectedClassId,
                          required selectedFilterSemester,
                        }) => loadSchedule(
                          useCache: true,
                          searchController: searchController,
                          selectedDayIds: selectedDayIds,
                          selectedClassId: selectedClassId,
                          selectedFilterSemester: selectedFilterSemester,
                          dayIdMap: dayIdMap,
                        ),
                      ),
                      languageProvider: languageProvider,
                    )
                  : TeacherScheduleCardView(
                      schedules: filteredSchedules,
                      languageProvider: languageProvider,
                      dayIdMap: dayIdMap,
                      dayColorMap: dayColorMap,
                      dayOptions: dayOptions,
                      selectedAcademicYear: selectedAcademicYear,
                      teacherId: teacherId,
                      teacherNama: teacherNama,
                      firstScheduleKey: _firstScheduleKey,
                      actionButtonsKey: _actionButtonsKey,
                      dailySummary: dailySummary,
                      onRefresh: refreshDailySummary,
                      isHomeroomView: isHomeroomView,
                      autoScroll: _isInitialLoad,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
