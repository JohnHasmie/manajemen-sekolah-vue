import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_activity_detail_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_form_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_quick_actions_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_session_card.dart';
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
      loadingBuilder: () =>
          const SkeletonListLoading(itemCount: 4, infoTagCount: 2),
      childBuilder: () => _buildActivityList(lp),
    );
  }

  Widget _buildActivityList(LanguageProvider lp) {
    // Flatten groups → per-activity items so each card maps to a
    // single (class, subject, title) entry per the redesigned list
    // mockup (Frame 0). Bucket by date: today vs older.
    final today = DateTime.now();
    final todayItems = <Map<String, dynamic>>[];
    final otherItems = <Map<String, dynamic>>[];

    Map<String, dynamic> hydrate(
      Map<String, dynamic> g,
      Map<String, dynamic> a,
    ) => {
      ...a,
      'class_id': a['class_id'] ?? g['class_id'],
      'class_name': a['class_name'] ?? g['class_name'],
      'subject_id': a['subject_id'] ?? g['subject_id'],
      'subject_name': a['subject_name'] ?? g['subject_name'],
      'teacher_id': a['teacher_id'] ?? g['teacher_id'],
      'teacher_name': a['teacher_name'] ?? g['teacher_name'],
    };

    for (final raw in groupedActivities) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);
      final latest = (g['latest_activities'] as List?) ?? const [];
      if (latest.isEmpty) continue;
      for (final a in latest) {
        if (a is! Map) continue;
        final item = hydrate(g, Map<String, dynamic>.from(a));
        final dateStr = (item['date'] ?? '').toString();
        final d = DateTime.tryParse(dateStr);
        final isToday =
            d != null &&
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
        if (isToday) {
          todayItems.add(item);
        } else {
          otherItems.add(item);
        }
      }
    }

    // Sort each bucket by date desc (today's bucket may have time
    // ordering instead but we use date desc as the safe default).
    int sorter(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ad = DateTime.tryParse((a['date'] ?? '').toString());
      final bd = DateTime.tryParse((b['date'] ?? '').toString());
      if (ad == null || bd == null) return 0;
      return bd.compareTo(ad);
    }

    todayItems.sort(sorter);
    otherItems.sort(sorter);

    final hasMore = isLoadingMore ? 1 : 0;
    final total =
        (todayItems.isNotEmpty ? todayItems.length + 1 : 0) +
        (otherItems.isNotEmpty ? otherItems.length + 1 : 0) +
        hasMore;

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: total,
      itemBuilder: (context, index) {
        int cursor = index;
        if (todayItems.isNotEmpty) {
          if (cursor == 0) {
            return _sectionHead(
              title: lp.getTranslatedText({'en': 'Today', 'id': 'Hari ini'}),
              count: todayItems.length,
            );
          }
          if (cursor < todayItems.length + 1) {
            return _activityCard(todayItems[cursor - 1]);
          }
          cursor -= todayItems.length + 1;
        }
        if (otherItems.isNotEmpty) {
          if (cursor == 0) {
            return _sectionHead(
              title: lp.getTranslatedText({
                'en': 'Earlier',
                'id': 'Sebelumnya',
              }),
              count: otherItems.length,
            );
          }
          if (cursor < otherItems.length + 1) {
            return _activityCard(otherItems[cursor - 1]);
          }
          cursor -= otherItems.length + 1;
        }
        // Loading more spinner.
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(color: primaryColor)),
        );
      },
    );
  }

  Widget _activityCard(Map<String, dynamic> a) {
    return ActivitySessionCard(
      activity: a,
      isHomeroomView: isHomeroomView,
      // Frame A · tap → open the per-activity detail screen with the
      // already-loaded payload, fully wired to Frame C edit, Frame D
      // quick actions, and the destructive Hapus action.
      onTap: () => _openDetail(a),
    );
  }

  /// Opens Frame A and wires up Frame B/C/D handlers that share the
  /// same activity payload. Refreshes the list when any of them
  /// completes so the card updates inline.
  void _openDetail(Map<String, dynamic> a) {
    openTeacherActivityDetail(
      context: context,
      activity: a,
      canEdit: !isHomeroomView,
      onEdit: () => _openEditSheet(a),
      onDelete: () => _confirmDelete(a),
      onMoreActions: () => _openQuickActions(a),
    );
  }

  Future<void> _openEditSheet(Map<String, dynamic> a) async {
    final lp = ref.read(languageRiverpod);
    // Subjects list — fall back to an empty list if not loaded; the
    // sheet will show "Pilih mapel" as the locked label.
    final subjects = (filterSubjectList)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final classes = classList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final res = await showActivityFormSheet(
      context: context,
      initial: a,
      classes: classes,
      subjects: subjects,
      onSave: (payload) async {
        final id = (a['id'] ?? '').toString();
        if (id.isEmpty) return;
        await ClassActivityService().updateActivity(id, payload);
      },
    );
    if (res != null) {
      SnackBarUtils.showSuccess(
        context,
        lp.getTranslatedText({
          'en': 'Activity saved',
          'id': 'Kegiatan tersimpan',
        }),
      );
      await forceRefresh();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> a) async {
    final lp = ref.read(languageRiverpod);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: lp.getTranslatedText({
          'en': 'Delete activity?',
          'id': 'Hapus kegiatan?',
        }),
        content: lp.getTranslatedText({
          'en':
              'Are you sure you want to delete this activity? This cannot be undone.',
          'id':
              'Yakin ingin menghapus kegiatan ini? Tindakan ini tidak dapat dibatalkan.',
        }),
        confirmText: lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
        confirmColor: ColorUtils.error600,
      ),
    );
    if (ok != true) return;
    final id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await ClassActivityService().deleteActivity(id);
      if (!mounted) return;
      // Pop the detail screen if still on top.
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      SnackBarUtils.showSuccess(
        context,
        lp.getTranslatedText({
          'en': 'Activity deleted',
          'id': 'Kegiatan dihapus',
        }),
      );
      await forceRefresh();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal menghapus: $e');
    }
  }

  void _openQuickActions(Map<String, dynamic> a) {
    showActivityQuickActionsSheet(
      context: context,
      actions: ActivityQuickActions(
        onCopyLink: () => _copyLink(a),
        // Duplicate / export still need backend wiring — Frame 3.8
        // batches those additions. Leaving them null hides the rows
        // gracefully so the sheet doesn't render dead affordances.
        onDuplicate: null,
        onExportPdf: null,
        onDelete: () => _confirmDelete(a),
      ),
    );
  }

  void _copyLink(Map<String, dynamic> a) {
    final id = (a['id'] ?? '').toString();
    final title = (a['title'] ?? '').toString();
    SnackBarUtils.showSuccess(context, 'Link disalin: kegiatan/$id ($title)');
  }

  Widget _sectionHead({required String title, required int count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            '$count kegiatan',
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
      loadingBuilder: () =>
          const SkeletonListLoading(itemCount: 5, infoTagCount: 1),
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
