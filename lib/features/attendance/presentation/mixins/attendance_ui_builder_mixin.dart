import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_embedded_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_body_mixin.dart';

/// Composes UI builder methods for main and embedded
/// screens. Delegates header building to TeacherPageHeader
/// shared component.
mixin AttendanceUIBuilderMixin
    on
        ConsumerState<AttendancePage>,
        AttendanceUIEmbeddedMixin,
        AttendanceUIBodyMixin {
  // ── Abstract state accessors ──

  @override
  Color get primaryColor;
  bool get isHomeroomView;
  set isHomeroomView(bool v);
  @override
  TextEditingController get searchController;
  @override
  bool get isTimelineView;
  @override
  bool get hasActiveFilter;
  List<dynamic> get homeroomClassesList;
  Map<String, dynamic>? get selectedHomeroomClass;

  // Methods to call
  void showAddAttendanceFlow(LanguageProvider lp);
  @override
  Future<void> refreshGroupedAttendance();
  void showFilterDialog(LanguageProvider lp);
  List<ActiveFilter> buildActiveFilterChips(LanguageProvider lp);
  void clearAllFilters();

  // ═══════════════════════════════════════════
  // MAIN BUILD METHODS
  // ═══════════════════════════════════════════

  Widget buildEmbedded(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            buildEmbeddedHeader(lp),
            Expanded(child: buildInputMode()),
          ],
        ),
      ),
    );
  }

  Widget buildMainScreen(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            TeacherPageHeader(
              title: lp.getTranslatedText({
                'en': 'Attendance',
                'id': 'Presensi',
              }),
              subtitle: isHomeroomView && selectedHomeroomClass != null
                  ? lp.getTranslatedText({
                      'en': 'Homeroom class attendance overview',
                      'id': 'Rekap presensi kelas perwalian',
                    })
                  : lp.getTranslatedText({
                      'en': 'Track and manage student attendance',
                      'id': 'Pantau dan kelola presensi siswa',
                    }),
              primaryColor: primaryColor,
              showRoleToggle: homeroomClassesList.isNotEmpty,
              isHomeroomView: isHomeroomView,
              onRoleChanged: (val) {
                setState(() => isHomeroomView = val);
                forceRefresh();
              },
              homeroomClassName:
                  selectedHomeroomClass?['name'] ??
                  selectedHomeroomClass?['nama'],
              showSearchFilter: true,
              searchController: searchController,
              onSearchSubmitted: (_) {
                refreshGroupedAttendance();
                FocusScope.of(context).unfocus();
              },
              onSearchTap: () {
                refreshGroupedAttendance();
                FocusScope.of(context).unfocus();
              },
              onFilterTap: () => showFilterDialog(lp),
              hasActiveFilter: hasActiveFilter,
              searchHintText: lp.getTranslatedText({
                'en': 'Search class or subject...',
                'id': 'Cari kelas atau mapel...',
              }),
              activeFilters: buildActiveFilterChips(lp),
              onClearAllFilters: clearAllFilters,
              trailing: GestureDetector(
                onTap: toggleView,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTimelineView
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Expanded(
              child: isTimelineView ? buildTimelineBody(lp) : buildBody(lp),
            ),
          ],
        ),
        floatingActionButton: isHomeroomView
            ? null
            : FloatingActionButton(
                onPressed: () => showAddAttendanceFlow(lp),
                backgroundColor: primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }

  void toggleView();
  @override
  Future<void> forceRefresh();
  @override
  void setState(VoidCallback fn);

  @override
  Widget buildEmbeddedHeader(LanguageProvider lp);
  @override
  Widget buildInputMode();
  @override
  Widget buildTimelineBody(LanguageProvider lp);
  @override
  Widget buildBody(LanguageProvider lp);
}
