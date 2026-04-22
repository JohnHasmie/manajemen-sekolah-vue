import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_group_card_widget.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_timeline_card_widget.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityBodyBuilderMixin
    on ConsumerState<TeacherClassActivityScreen> {
  Widget buildBody(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: activityErrorMessage,
      isEmpty: groupedActivities.isEmpty,
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: lp.getTranslatedText({
        'en': 'No activities yet',
        'id': 'Belum ada kegiatan',
      }),
      emptySubtitle: lp.getTranslatedText({
        'en': 'Pull down to refresh',
        'id': 'Tarik ke bawah untuk memuat ulang',
      }),
      emptyIcon: Icons.event_note_outlined,
      loadingBuilder: () => const SkeletonListLoading(
        itemCount: 4,
        infoTagCount: 2,
      ),
      childBuilder: () => _buildActivityList(lp),
    );
  }


  Widget _buildActivityList(LanguageProvider lp) {
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: groupedActivities.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groupedActivities.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }
        final g = groupedActivities[index];
        return ActivityGroupCardWidget(
          group: g,
          primaryColor: primaryColor,
          isHomeroomView: isHomeroomView,
          onTap: () => openActivityList(
            classId: g['class_id']?.toString() ?? '',
            className: g['class_name']?.toString() ?? '',
            subjectId: g['subject_id']?.toString() ?? '',
            subjectName: g['subject_name']?.toString() ?? '',
          ),
        );
      },
    );
  }

  Widget buildTimelineBody(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: activityErrorMessage,
      isEmpty: timelineActivities.isEmpty,
      onRefresh: refreshTimeline,
      role: 'guru',
      emptyTitle: lp.getTranslatedText({
        'en': 'No activities yet',
        'id': 'Belum ada kegiatan',
      }),
      emptySubtitle: lp.getTranslatedText({
        'en': 'Pull down to refresh',
        'id': 'Tarik ke bawah untuk memuat ulang',
      }),
      emptyIcon: Icons.event_note_outlined,
      loadingBuilder: () => const SkeletonListLoading(
        itemCount: 5,
        infoTagCount: 1,
      ),
      childBuilder: () => _buildTimelineList(lp),
    );
  }

  Widget _buildTimelineList(LanguageProvider lp) {
    return ListView.builder(
      controller: timelineScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: timelineActivities.length + (timelineLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == timelineActivities.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }
        final a = timelineActivities[index];
        return ActivityTimelineCardWidget(
          activity: a,
          primaryColor: primaryColor,
          isHomeroomView: isHomeroomView,
          onTap: () => openActivityList(
            classId:
                a['class_id']?.toString() ?? a['kelas_id']?.toString() ?? '',
            className:
                a['class_name']?.toString() ??
                a['kelas_nama']?.toString() ??
                '',
            subjectId:
                a['subject_id']?.toString() ??
                a['mata_pelajaran_id']?.toString() ??
                '',
            subjectName:
                a['subject_name']?.toString() ??
                a['mata_pelajaran_nama']?.toString() ??
                '',
          ),
        );
      },
    );
  }

  // Abstract getters
  bool get isLoading;
  bool get isLoadingMore;
  bool get hasActiveFilter;
  bool get timelineLoadingMore;
  String? get activityErrorMessage;
  int get currentPage;
  List<dynamic> get groupedActivities;
  List<dynamic> get timelineActivities;
  TextEditingController get searchController;
  ScrollController get scrollController;
  ScrollController get timelineScrollController;
  Color get primaryColor;

  /// When true the current tab is "Wali Kelas": cards show the authoring
  /// teacher name so the homeroom teacher can identify who recorded each
  /// entry in the aggregated cross-teacher list.
  bool get isHomeroomView;

  void openActivityList({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  });

  Future<void> forceRefresh();
  Future<void> refreshTimeline();
}
