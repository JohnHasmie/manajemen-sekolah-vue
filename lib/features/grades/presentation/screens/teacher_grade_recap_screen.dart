import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_service.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_table_builder.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_grade_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_column_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_ui_mixin.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_save_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_ctx_strip.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_kpi_card.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_kpi_skeleton.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_table_skeleton.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_table_view.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_unsaved_changes_dialog.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';

/// Grade recap wizard: class -> subject -> table.
class GradeRecapPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic>? initialClass;
  final Map<String, dynamic>? initialSubject;

  const GradeRecapPage({
    super.key,
    required this.teacher,
    this.initialClass,
    this.initialSubject,
  });

  @override
  ConsumerState<GradeRecapPage> createState() => _GradeRecapPageState();
}

class _GradeRecapPageState extends ConsumerState<GradeRecapPage>
    with
        GradeRecapDataMixin,
        GradeRecapGradeOpsMixin,
        GradeRecapDataOpsMixin,
        GradeRecapColumnOpsMixin,
        GradeRecapUiMixin {
  // ── State fields (bridged to mixins) ─────────
  // Screen-only state (not part of any mixin contract).
  List<dynamic> classList = [];
  List<dynamic> subjectList = [];
  List<dynamic> todaySchedules = [];
  Map<String, String> dayIdMap = {};
  bool hasMoreData = true;
  bool isLoadingMore = false;
  int currentPage = 1;
  int get perPage => 20;

  // Fields bridged to mixin getter/setter contracts.
  @override
  List<dynamic> chapters = [];
  @override
  List<dynamic> allAvailableChapters = [];
  @override
  List<Map<String, dynamic>> tableData = [];
  @override
  List<dynamic> rawGrades = [];

  /// Lesson-plan titles for the current subject — fed into the "add bab"
  /// sheet so the teacher can pick an existing materi instead of typing.
  /// Bridged to [GradeRecapColumnOpsMixin].
  @override
  List<String> availableMaterials = [];

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;
  @override
  Map<String, dynamic>? get selectedClass => _selectedClass;
  @override
  Map<String, dynamic>? get selectedSubject => _selectedSubject;

  @override
  final Map<String, TextEditingController> predikatControllers = {};
  @override
  final Map<String, TextEditingController> descriptionControllers = {};
  @override
  final Map<String, TextEditingController> scoreControllers = {};
  @override
  final Map<String, FocusNode> scoreFocusNodes = {};

  @override
  bool isSaving = false;
  @override
  bool isExporting = false;
  @override
  bool hasUnsavedChanges = false;

  int _currentStep = 0;
  @override
  int get currentStep => _currentStep;

  // isLoading and searchController are provided by GradeRecapDataMixin and
  // initialized in initState.
  final ScrollController _scrollController = ScrollController();

  // Save-bar + Add-chapter FAB anchor keys. Previously also doubled as
  // tour-target anchors; the tour wiring has been removed per
  // [Tour Cleanup BB.4] but the keys themselves are still passed to
  // GradeRecapSaveBar + FloatingActionButton so we keep them.
  final GlobalKey _saveKey = GlobalKey();
  final GlobalKey _addChapterKey = GlobalKey();

  @override
  Map<String, dynamic> get teacherData => widget.teacher;

  @override
  Color getPrimaryColor() =>
      ColorUtils.getRoleColor(Teacher.fromJson(widget.teacher).role);

  // ── Data loading methods ────────────────────────

  Future<void> loadRecapData() async {
    if (_selectedClass == null || _selectedSubject == null) return;

    setState(() => isLoading = true);
    try {
      final provider = ref.read(academicYearRiverpod);
      final ayId =
          (provider.selectedAcademicYear?['id'] ??
                  provider.activeAcademicYear?['id'])
              ?.toString() ??
          '';

      final classId =
          (_selectedClass!['id'] ?? _selectedClass!['class_id'])?.toString() ??
          '';
      final subjectId = _selectedSubject!['id']?.toString() ?? '';

      AppLogger.debug(
        'grade_recap',
        'Loading recap: class=$classId, subject=$subjectId, ay=$ayId',
      );

      final teacherId = widget.teacher['id']?.toString() ?? '';

      // Fan out the three queries in parallel — the recap table, the
      // lesson-plan titles (for the "pick a materi" step of add-bab), and
      // the grades feed (for the "pick an assessment" step). The add-bab
      // flow is synchronous after load; we want both lists ready up front
      // so there's no network spinner inside the sheet.
      final results = await Future.wait<dynamic>([
        getIt<ApiGradeRecapService>().getGradeRecaps(
          classId: classId,
          subjectId: subjectId,
          academicYearId: ayId,
        ),
        GradeRecapTableBuilder.fetchMaterialsForSubject(
          teacherId: teacherId,
          subjectId: subjectId,
          classId: classId,
          academicYearId: ayId,
        ),
        GradeRecapTableBuilder.fetchGradesForSubject(
          teacherId: teacherId,
          subjectId: subjectId,
          classId: classId,
          academicYearId: ayId,
        ),
      ]);

      if (!mounted) return;

      final data = results[0] as List<dynamic>;
      availableMaterials = results[1] as List<String>;
      rawGrades = results[2] as List<dynamic>;

      // Parse response into tableData format expected by mixins. The
      // builder mutates the controller maps in place; the screen still
      // owns disposal in [dispose].
      final built = GradeRecapTableBuilder.build(
        apiData: data,
        predikatControllers: predikatControllers,
        descriptionControllers: descriptionControllers,
        scoreControllers: scoreControllers,
        scoreFocusNodes: scoreFocusNodes,
      );
      chapters = built.chapters;
      tableData = built.tableData;
      hasUnsavedChanges = false;

      setState(() => isLoading = false);

      // Show tour after first load
    } catch (e) {
      AppLogger.error('grade_recap', 'Error loading recap data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadTodaySchedules() async {
    // Not needed for recap — placeholder for mixin compatibility
  }

  void loadClasses() {
    setState(() => isLoading = true);
    try {
      // TODO: Implement class list loading for wizard step 0
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void loadMoreClasses() {
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);
    try {
      currentPage++;
      if (mounted) setState(() => isLoadingMore = false);
    } catch (e) {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  void loadSubjects() {
    setState(() => isLoading = true);
    try {
      // TODO: Implement subject list loading for wizard step 1
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> forceRefresh() async {
    setState(() => isLoading = true);
    try {
      await loadRecapData();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Abstract method implementations ─────────────

  @override
  void updateAllDescriptions() {
    // Descriptions are already tracked via controllers
  }

  @override
  void recalculateRowInternal(Map<String, dynamic> row) {
    recalculateRow(row, getController: null);
  }

  @override
  void updateTableValue(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  ) {
    final row = findRow(studentClassId);
    if (row == null) return;
    setRowValue(row, type, chapterIndex, newValue);

    final key = '$studentClassId|$type|$chapterIndex';
    scoreControllers[key]?.text = newValue.toStringAsFixed(0);

    recalculateRowInternal(row);
    setState(() => hasUnsavedChanges = true);
  }

  @override
  void updateTableValueSilently(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  ) {
    final row = findRow(studentClassId);
    if (row == null) return;
    setRowValue(row, type, chapterIndex, newValue);
    recalculateRowInternal(row);
    hasUnsavedChanges = true;
  }

  @override
  void setRowValue(
    Map<String, dynamic> row,
    String type,
    int? chapterIndex,
    double value,
  ) {
    if (type == 'bab' && chapterIndex != null) {
      final scores = row['bab_scores'] as List;
      if (chapterIndex < scores.length) {
        scores[chapterIndex] = value;
      }
    } else if (type == 'uts') {
      row['uts'] = value;
    } else if (type == 'uas') {
      row['uas'] = value;
    } else if (type == 'skill_score') {
      row['skill_score'] = value;
    }
  }

  @override
  Map<String, dynamic>? findRow(String studentClassId) {
    final idx = tableData.indexWhere(
      (r) => r['student_class_id'] == studentClassId,
    );
    return idx != -1 ? tableData[idx] : null;
  }

  @override
  void applyBulkGrades(
    String type,
    List<Map<String, dynamic>> selected, [
    int? chapterIndex,
  ]) {
    // TODO: Implement bulk grade application
  }

  @override
  double? calcBulkAverage(
    String studentClassId,
    String type,
    List<Map<String, dynamic>> assessments,
  ) {
    return null;
  }

  // `addChapter`, `deleteChapter`, `recalculateRow`, and `showBulkDialog`
  // (plus the private fixed-column source picker) live in
  // [GradeRecapColumnOpsMixin]. That mixin is applied after
  // [GradeRecapDataOpsMixin] so its implementations win over the
  // defaults, preserving the original screen-overrides behaviour.

  // `saveRecaps()` and `exportToExcel()` are implemented by
  // [GradeRecapDataOpsMixin]. We intentionally do NOT declare empty
  // overrides here — doing so would shadow the mixin implementation
  // and make the Simpan / Export buttons no-op.

  // ── Lifecycle ────────────────────────────────

  @override
  void initState() {
    super.initState();
    isLoading = false;
    searchController = TextEditingController();
    _scrollController.addListener(_onScroll);

    if (widget.initialClass != null && widget.initialSubject != null) {
      _selectedClass = widget.initialClass;
      _selectedSubject = widget.initialSubject;
      _currentStep = 2;
      // Set isLoading synchronously so the first frame shows the skeleton,
      // not the "Tidak Ada Siswa" empty state (tableData starts empty and
      // loadRecapData only runs after the first build via post-frame).
      isLoading = true;
      // Defer the heavy fetch + controller creation until AFTER the modal
      // bottom sheet finishes its open animation (~250ms). Doing it
      // synchronously janks the slide-up transition because building
      // 100s of TextEditingController + FocusNode instances blocks the
      // UI thread mid-animation.
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) loadRecapData();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await loadTodaySchedules();
        loadClasses();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    for (final c in predikatControllers.values) {
      c.dispose();
    }
    for (final c in descriptionControllers.values) {
      c.dispose();
    }
    for (final c in scoreControllers.values) {
      c.dispose();
    }
    for (final f in scoreFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreData && !isLoading && _currentStep == 0) {
        loadMoreClasses();
      }
    }
  }

  // ── Navigation ───────────────────────────────

  Future<bool> onWillPop() async {
    if (!hasUnsavedChanges) return true;
    return showGradeRecapUnsavedChangesDialog(context, ref);
  }

  /// Save handler for the sticky bottom-bar "Simpan" button.
  ///
  /// When the screen was opened as a modal dialog (i.e. the caller passed
  /// [GradeRecapPage.initialClass] and [GradeRecapPage.initialSubject]),
  /// we close the route on a successful save — this matches the
  /// "edit-in-a-sheet" UX where tapping the primary action commits and
  /// dismisses. From the wizard flow (no initials), we just save in place
  /// and let the teacher keep editing or navigate back manually.
  Future<void> _onSavePressed() async {
    final success = await saveRecaps();
    if (!context.mounted || !success) return;
    final isDialogEntry =
        widget.initialClass != null && widget.initialSubject != null;
    if (isDialogEntry) AppNavigator.pop(context);
  }

  @override
  void handleBackButton() async {
    if (hasUnsavedChanges) {
      final canLeave = await onWillPop();
      if (!canLeave) return;
    }

    // In modal-style entry (initialClass + initialSubject) there is no
    // wizard to step back through — close should pop the route directly.
    // Otherwise, step back in the wizard or pop if already at step 0.
    final isDialogEntry =
        widget.initialClass != null && widget.initialSubject != null;

    if (!isDialogEntry && _currentStep > 0) {
      setState(() {
        _currentStep--;
        searchController.clear();
        hasUnsavedChanges = false;
      });
    } else {
      if (context.mounted) AppNavigator.pop(context);
    }
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await onWillPop();
        if (canLeave && context.mounted) {
          AppNavigator.pop(context, result);
        }
      },
      child: (widget.initialClass != null && widget.initialSubject != null)
          ? _buildBrandScaffold(lp)
          : _buildWizardScaffold(lp),
    );
  }

  /// Brand-migrated full-screen scaffold for the modal-style entry —
  /// wraps the matrix table inside `BrandPageLayout` (gradient header +
  /// 3-cell KPI overlap + scrollable body). Mirrors Frame C from
  /// `_design/teacher_grade_recap_mockup.html`.
  Widget _buildBrandScaffold(LanguageProvider lp) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'guru',
        header: _buildBrandHeader(lp),
        kpiCard: _buildBrandKpiCard(lp),
        bodyChildren: [_buildBrandBody(lp)],
      ),
      // SS4-HH — the previous floating FAB for "+ tambah bab" covered
      // the right edge of the matrix table. The action moved into the
      // bottom Save bar (see `GradeRecapSaveBar.onAddChapter`); no
      // more `floatingActionButton` on this scaffold.
      bottomNavigationBar: (_currentStep == 2 && tableData.isNotEmpty)
          ? GradeRecapSaveBar(
              saveKey: _saveKey,
              addChapterKey: _addChapterKey,
              isSaving: isSaving,
              hasUnsavedChanges: hasUnsavedChanges,
              onSave: _onSavePressed,
              onAddChapter: addChapter,
              lp: lp,
            )
          : null,
    );
  }

  /// Wizard scaffold — kept for callers that don't pre-pick class +
  /// subject. Uses the legacy `buildMainHeader` + step-aware body.
  Widget _buildWizardScaffold(LanguageProvider lp) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildMainHeader(lp),
          if (_currentStep < 2) buildRecapSearchBar(lp),
          Expanded(child: _buildBody(lp)),
        ],
      ),
      // SS4-HH — same FAB→bottom-bar relocation as the brand scaffold
      // above. Kept in lockstep so the wizard entry point doesn't drift
      // from the modal entry point.
      bottomNavigationBar: (_currentStep == 2 && tableData.isNotEmpty)
          ? GradeRecapSaveBar(
              saveKey: _saveKey,
              addChapterKey: _addChapterKey,
              isSaving: isSaving,
              hasUnsavedChanges: hasUnsavedChanges,
              onSave: _onSavePressed,
              onAddChapter: addChapter,
              lp: lp,
            )
          : null,
    );
  }

  /// Brand header — kicker shows class + subject, ctx-strip below
  /// shows the subject letter avatar + "Subject · Class · Sem 2025/2026 · N siswa".
  /// Tune icon top-right runs the export-to-Excel flow.
  Widget _buildBrandHeader(LanguageProvider lp) {
    final subjectName =
        (widget.initialSubject?['nama'] ??
                widget.initialSubject?['name'] ??
                '-')
            .toString();
    final className =
        (widget.initialClass?['nama'] ?? widget.initialClass?['name'] ?? '-')
            .toString();
    final initial = subjectName.isNotEmpty ? subjectName[0].toUpperCase() : '?';
    final ay = ref.watch(academicYearRiverpod).selectedAcademicYear;
    final ayLabel = ay == null
        ? ''
        : ' · ${(ay['name'] ?? ay['nama'] ?? '').toString()}';
    final studentCount = tableData.length;
    final studentLine = studentCount > 0 ? ' · $studentCount siswa' : '';

    return BrandPageHeader(
      role: 'guru',
      title: '$subjectName · $className',
      subtitle: lp.getTranslatedText({
        'en': 'Recap · Grades',
        'id': 'Rekap · Nilai',
      }),
      isRealtimeFresh: true,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      onBackPressed: handleBackButton,
      actionIcons: [
        BrandHeaderIconButton(
          icon: isExporting
              ? Icons.hourglass_top_rounded
              : Icons.download_rounded,
          onTap: isExporting ? () {} : exportToExcel,
        ),
      ],
      bottomSlot: GradeRecapCtxStrip(
        initial: initial,
        title: '$subjectName · $className',
        subtitle: '$className · $subjectName$ayLabel$studentLine',
      ),
    );
  }

  /// 3-cell KPI overlap card — Tuntas · Belum · Rata-rata. Computed
  /// from `tableData` so the card stays in sync with the matrix the
  /// teacher is editing.
  ///
  /// While `isLoading` is true, returns a shimmer skeleton with the
  /// same shape/dimensions so the slot stays anchored and there's no
  /// flash of "0 / 0 / —" before the data resolves.
  Widget _buildBrandKpiCard(LanguageProvider lp) {
    if (isLoading) {
      return const GradeRecapKpiSkeleton();
    }
    return GradeRecapKpiCard(
      tableData: tableData,
      scoreControllers: scoreControllers,
      lp: lp,
    );
  }

  /// Body for the brand-migrated scaffold. Mirrors the legacy step-2
  /// branch but drops the outer `SingleChildScrollView` since
  /// BrandPageLayout already provides the outer scrollable.
  Widget _buildBrandBody(LanguageProvider lp) {
    if (isLoading) {
      return GradeRecapTableSkeleton(primaryColor: getPrimaryColor());
    }
    if (tableData.isEmpty) {
      return SizedBox(
        height: 360,
        child: EmptyState(
          icon: Icons.assessment_outlined,
          title: lp.getTranslatedText({
            'en': 'No Students',
            'id': 'Tidak Ada Siswa',
          }),
          subtitle: lp.getTranslatedText({
            'en': 'No students found in this class',
            'id': 'Tidak ada siswa di kelas ini',
          }),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
      child: GradeRecapTableView(
        tableData: tableData,
        chapters: chapters,
        scoreControllers: scoreControllers,
        predikatControllers: predikatControllers,
        descriptionControllers: descriptionControllers,
        primaryColor: getPrimaryColor(),
        labels: {
          'finalLabel': lp.getTranslatedText({'en': 'Final', 'id': 'NA'}),
          'skillLabel': lp.getTranslatedText({
            'en': 'Skill',
            'id': 'Keterampilan',
          }),
          'gradeLabel': lp.getTranslatedText({'en': 'Grade', 'id': 'Nilai'}),
          'descLabel': lp.getTranslatedText({'en': 'Desc.', 'id': 'Desk.'}),
        },
        cellBuilder: buildEditableGradeCell,
        onBulkSelect: showBulkDialog,
        onDeleteChapter: deleteChapter,
        onDeskripsiTap: showEditDeskripsi,
      ),
    );
  }

  Widget _buildBody(LanguageProvider lp) {
    if (_currentStep == 0) {
      return const SizedBox.shrink(); // Wizard step 0 — class selection
    }
    if (_currentStep == 1) {
      return const SizedBox.shrink(); // Wizard step 1 — subject selection
    }

    // Step 2 — table view
    if (isLoading) {
      return GradeRecapTableSkeleton(primaryColor: getPrimaryColor());
    }

    if (tableData.isEmpty) {
      return EmptyState(
        icon: Icons.assessment_outlined,
        title: lp.getTranslatedText({
          'en': 'No Students',
          'id': 'Tidak Ada Siswa',
        }),
        subtitle: lp.getTranslatedText({
          'en': 'No students found in this class',
          'id': 'Tidak ada siswa di kelas ini',
        }),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: GradeRecapTableView(
        tableData: tableData,
        chapters: chapters,
        scoreControllers: scoreControllers,
        predikatControllers: predikatControllers,
        descriptionControllers: descriptionControllers,
        primaryColor: getPrimaryColor(),
        labels: {
          'finalLabel': lp.getTranslatedText({'en': 'Final', 'id': 'NA'}),
          'skillLabel': lp.getTranslatedText({
            'en': 'Skill',
            'id': 'Keterampilan',
          }),
          'gradeLabel': lp.getTranslatedText({'en': 'Grade', 'id': 'Nilai'}),
          'descLabel': lp.getTranslatedText({'en': 'Desc.', 'id': 'Desk.'}),
        },
        cellBuilder: buildEditableGradeCell,
        onBulkSelect: showBulkDialog,
        onDeleteChapter: deleteChapter,
        onDeskripsiTap: showEditDeskripsi,
      ),
    );
  }
}
