// AI-generated RPP viewer/editor, now presented as a flat-flow bottom sheet
// so polling + the eventual detail handoff all happen over the list screen
// (matches the teacher recommendation flow from task #145). Call
// [LessonPlanAiResultScreen.show] — the old Scaffold + AppBar was replaced
// with a sheet-shaped Container.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_polling_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_data_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_utils_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_regenerate_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_export_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_save_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_ui_mixin.dart';

/// AI-generated lesson plan viewer/editor with rich text editing.
///
/// Supports two modes:
/// 1. Direct mode -- [lessonPlanData] is provided (sync 201 response).
///    The AI backend already saved the data. Auto-completes and goes back.
/// 2. Polling mode -- [pollUrl]/[jobId] provided, polls for AI job completion.
///    The AI backend saves on completion. Auto-completes and goes back.
///
/// After generation, user can open the RPP detail from the list to view/edit.
class LessonPlanAiResultScreen extends StatefulWidget {
  final Map<String, dynamic>? lessonPlanData;
  final String teacherId;
  final VoidCallback onSaved;

  /// Polling mode fields - when set, the screen will poll for results
  final String? pollUrl;
  final String? jobId;
  final String? token;

  /// Metadata to build lessonPlanData after polling completes
  final Map<String, dynamic>? pollingMetadata;

  const LessonPlanAiResultScreen({
    super.key,
    this.lessonPlanData,
    required this.teacherId,
    required this.onSaved,
    this.pollUrl,
    this.jobId,
    this.token,
    this.pollingMetadata,
  });

  /// Opens the AI result screen as a modal bottom sheet.
  ///
  /// Polling / save state stays inside the sheet; when generation completes
  /// the sheet pops itself and [RPPDetailPage.show] is presented on the
  /// underlying list so the user never leaves the flat-flow.
  static Future<void> show({
    required BuildContext context,
    Map<String, dynamic>? lessonPlanData,
    required String teacherId,
    required VoidCallback onSaved,
    String? pollUrl,
    String? jobId,
    String? token,
    Map<String, dynamic>? pollingMetadata,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      // Disallow swipe-to-dismiss while polling — the job is running in
      // the background and an accidental drag should not abort it.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => LessonPlanAiResultScreen(
        lessonPlanData: lessonPlanData,
        teacherId: teacherId,
        onSaved: onSaved,
        pollUrl: pollUrl,
        jobId: jobId,
        token: token,
        pollingMetadata: pollingMetadata,
      ),
    );
  }

  @override
  State<LessonPlanAiResultScreen> createState() =>
      _LessonPlanAiResultScreenState();
}

/// State for [LessonPlanAiResultScreen].
///
/// Manages Quill controllers for each lesson plan section and delegates
/// to specialized mixins for polling, data management, UI, export,
/// regeneration, and save operations.
class _LessonPlanAiResultScreenState extends State<LessonPlanAiResultScreen>
    with
        LessonPlanAiResultUtilsMixin,
        LessonPlanAiResultDataMixin,
        LessonPlanAiResultSaveMixin,
        LessonPlanAiResultPollingMixin,
        LessonPlanAiResultRegenerateMixin,
        LessonPlanAiResultExportMixin,
        LessonPlanAiResultUiMixin {
  /// When true, skip disposing controllers (sync mode skips init).
  bool _skipDispose = false;

  @override
  void initState() {
    super.initState();
    if (widget.pollUrl != null || widget.jobId != null) {
      // Async mode: poll for results (AI backend auto-saves)
      initControllers({});
      isPolling = true;
      pollingStatus = 'Menyusun kompetensi dan tujuan pembelajaran...';
      startPolling();
    } else if (widget.lessonPlanData != null) {
      // Sync mode: data already received and saved by AI backend.
      // Don't init controllers — we navigate away immediately.
      _skipDispose = true;
      lessonPlanAiId = widget.lessonPlanData!['id']?.toString();

      // Navigate to detail/preview with the generated data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          handleGenerationComplete(lessonPlanData: widget.lessonPlanData);
        }
      });
    }
  }

  @override
  void dispose() {
    if (!_skipDispose) {
      disposeControllers();
      disposeRegenerateResources();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ColorUtils.getRoleColor('guru');
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.onSaved();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          constraints: BoxConstraints(maxHeight: mediaHeight * 0.95),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BottomSheetHeader(
                    title: 'Generate RPP AI',
                    subtitle: isPolling
                        ? 'AI sedang bekerja…'
                        : (pollingError != null
                            ? 'Gagal menghasilkan RPP'
                            : 'Hasil siap ditinjau'),
                    icon: Icons.auto_awesome_rounded,
                    primaryColor: primaryColor,
                  ),
                  Expanded(
                    child: isPolling || pollingError != null
                        ? buildPollingBody(
                            isPolling, pollingStatus, pollingError)
                        : buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
