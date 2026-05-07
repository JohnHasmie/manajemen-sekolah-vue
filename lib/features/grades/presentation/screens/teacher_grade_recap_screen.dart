import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_service.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_table_builder.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_grade_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_ui_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/add_chapter_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_chapter_rename_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_modal_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_save_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_table_skeleton.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_table_view.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_tour_helper.dart';
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
  /// Screen-only, not part of any mixin contract.
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
  bool isLoading = false;
  @override
  bool isSaving = false;
  @override
  bool isExporting = false;
  @override
  bool hasUnsavedChanges = false;

  int _currentStep = 0;
  @override
  int get currentStep => _currentStep;

  @override
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _exportKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();
  final GlobalKey _addChapterKey = GlobalKey();

  late final GradeRecapTourHelper _tourHelper = GradeRecapTourHelper(
    addChapterKey: _addChapterKey,
    saveKey: _saveKey,
    exportKey: _exportKey,
  );

  void checkAndShowTour() => _tourHelper.checkAndShow(context);

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
      WidgetsBinding.instance.addPostFrameCallback((_) => checkAndShowTour());
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
  String? recalculateRow(
    Map<String, dynamic> row, {
    required TextEditingController? Function(
      String studentClassId,
      String type,
      int? chapterIndex,
    )?
    getController,
  }) {
    // Weighted average across three buckets: bab (40%), UTS (20%),
    // UAS (40%). We only include a bucket in the weight denominator if
    // it actually has data — otherwise an empty UTS/UAS would silently
    // drag the final score toward zero and a 100 on bab alone would
    // score 40, stamping the student with a "D".
    final babScores = row['bab_scores'] as List?;
    double babSum = 0;
    int babCount = 0;
    if (babScores != null) {
      for (final s in babScores) {
        if (s is num && s > 0) {
          babSum += s.toDouble();
          babCount++;
        }
      }
    }
    final double? babAvg = babCount > 0 ? babSum / babCount : null;

    final utsRaw = (row['uts'] as num?)?.toDouble();
    final uasRaw = (row['uas'] as num?)?.toDouble();
    // Treat 0 as "not yet entered". A real zero is rare and teachers can
    // always bump it to 0.1 if they need to preserve an actual failing
    // mark while UAS is pending.
    final double? uts = (utsRaw != null && utsRaw > 0) ? utsRaw : null;
    final double? uas = (uasRaw != null && uasRaw > 0) ? uasRaw : null;

    double weightedSum = 0;
    double totalWeight = 0;
    if (babAvg != null) {
      weightedSum += babAvg * 0.4;
      totalWeight += 0.4;
    }
    if (uts != null) {
      weightedSum += uts * 0.2;
      totalWeight += 0.2;
    }
    if (uas != null) {
      weightedSum += uas * 0.4;
      totalWeight += 0.4;
    }

    if (totalWeight == 0) return null; // nothing filled yet

    final finalScore = weightedSum / totalWeight;
    row['final_score'] = finalScore;

    // Auto-generate predikat.
    final scId = row['student_class_id'];
    final predikat = finalScore >= 90
        ? 'A'
        : finalScore >= 80
        ? 'B'
        : finalScore >= 70
        ? 'C'
        : 'D';
    predikatControllers[scId]?.text = predikat;
    return null;
  }

  @override
  void showBulkDialog(String type, [int? chapterIndex]) {
    // TODO: Implement bulk grade selection dialog
  }

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

  @override
  void addChapter() async {
    // Two-step sheet:
    //   (1) Materi / Bab — pick a lesson-plan title or type a custom name.
    //   (2) Cara mengisi nilai — pick an existing assessment to pull scores
    //       from, or "Input Manual" to leave the new column blank.
    final assessments = GradeRecapTableBuilder.deriveAvailableAssessments(
      rawGrades,
    );
    final result = await showAddChapterSheet(
      context: context,
      primaryColor: getPrimaryColor(),
      nextChapterIndex: chapters.length,
      availableMaterials: availableMaterials,
      availableAssessments: assessments,
    );
    if (result == null || result.name.isEmpty || !mounted) return;

    setState(() {
      final newIndex = chapters.length;
      chapters = [
        ...chapters,
        {'judul_bab': result.name},
      ];

      // Build a per-student lookup from the chosen assessment. If the
      // teacher picked "Input Manual" (assessment == null), every student
      // gets a blank cell.
      final Map<String, double> perStudentScore = {};
      if (result.assessment != null) {
        final pickTitle = (result.assessment!['title'] ?? '').toString();
        final pickType = (result.assessment!['type'] ?? '').toString();
        final pickDate = (result.assessment!['date'] ?? '').toString();
        for (final g in rawGrades) {
          if (g is! Map) continue;
          final title = (g['title'] ?? g['judul'] ?? '').toString();
          final type = (g['type'] ?? g['grade_type'] ?? '')
              .toString()
              .toLowerCase();
          final date = (g['date'] ?? g['tanggal'] ?? '').toString();
          if (title != pickTitle || type != pickType || date != pickDate) {
            continue;
          }
          final scId = (g['student_class_id'] ?? '').toString();
          final score = g['score'] ?? g['nilai'];
          if (scId.isEmpty || score == null) continue;
          final parsed = score is num
              ? score.toDouble()
              : double.tryParse(score.toString());
          if (parsed != null) perStudentScore[scId] = parsed;
        }
      }

      for (final row in tableData) {
        final scId = row['student_class_id'].toString();
        final pulled = perStudentScore[scId];
        (row['bab_scores'] as List).add(pulled);
        final key = '$scId|bab|$newIndex';
        scoreControllers[key] = TextEditingController(
          text: pulled != null ? pulled.toStringAsFixed(0) : '',
        );
        scoreFocusNodes[key] = FocusNode(debugLabel: 'score:$key');
      }

      // If we pre-filled any cell, recalculate every row so final score
      // and predikat reflect the new column immediately.
      if (perStudentScore.isNotEmpty) {
        for (final row in tableData) {
          recalculateRowInternal(row);
        }
      }
      hasUnsavedChanges = true;
    });
  }

  @override
  void editChapter(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return;
    final ch = chapters[chapterIndex] as Map;
    final currentName =
        (ch['judul_bab'] ??
                ch['judul'] ??
                ch['title'] ??
                'Bab ${chapterIndex + 1}')
            .toString();
    final newName = await showGradeRecapChapterRenameDialog(
      context: context,
      currentName: currentName,
    );
    if (newName == null || !mounted) return;
    setState(() {
      // Mutate in place so any other key the source data carries
      // (judul / title fallback) stays — we just override the
      // canonical `judul_bab` and clean up the legacy aliases so
      // re-reading via the same fallback chain returns the new name.
      final updated = Map<String, dynamic>.from(ch);
      updated['judul_bab'] = newName;
      updated['judul'] = newName;
      updated['title'] = newName;
      chapters = List.from(chapters)..[chapterIndex] = updated;
      hasUnsavedChanges = true;
    });
  }

  @override
  void deleteChapter(int chapterIndex) async {
    if (chapters.length <= 1) return;

    // Long-press already raised the gesture cost, but the actual
    // mutation wipes scores from every student row in this column.
    // Route through the shared ConfirmationDialog (gradient header,
    // "Hapus" / "Batal" pair) so the destructive confirm matches
    // every other destructive flow in the app.
    final ch = chapters[chapterIndex] as Map;
    final name =
        (ch['judul_bab'] ??
                ch['judul'] ??
                ch['title'] ??
                'Bab ${chapterIndex + 1}')
            .toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Hapus bab',
        content:
            'Yakin ingin menghapus "$name"? Semua nilai siswa di kolom ini akan ikut terhapus.',
        confirmText: 'Hapus',
        confirmColor: ColorUtils.error600,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      chapters = List.from(chapters)..removeAt(chapterIndex);
      for (final row in tableData) {
        (row['bab_scores'] as List).removeAt(chapterIndex);
      }
      // Rebuild score controllers + focus nodes for bab columns. We drop
      // every existing bab entry and re-create in sequence so the column
      // index in the key matches its new position in `bab_scores`.
      final keysToRemove = scoreControllers.keys
          .where((k) => k.contains('|bab|'))
          .toList();
      for (final key in keysToRemove) {
        scoreControllers[key]?.dispose();
        scoreControllers.remove(key);
        scoreFocusNodes[key]?.dispose();
        scoreFocusNodes.remove(key);
      }
      for (final row in tableData) {
        final scId = row['student_class_id'];
        final scores = row['bab_scores'] as List;
        for (int i = 0; i < scores.length; i++) {
          final key = '$scId|bab|$i';
          scoreControllers[key] = TextEditingController(
            text: scores[i] != null
                ? (scores[i] as num).toStringAsFixed(0)
                : '',
          );
          scoreFocusNodes[key] = FocusNode(debugLabel: 'score:$key');
        }
      }
      hasUnsavedChanges = true;
    });
  }

  // `saveRecaps()` and `exportToExcel()` are implemented by
  // [GradeRecapDataOpsMixin]. We intentionally do NOT declare empty
  // overrides here — doing so would shadow the mixin implementation
  // and make the Simpan / Export buttons no-op.

  // ── Lifecycle ────────────────────────────────

  @override
  void initState() {
    super.initState();
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
    if (!mounted || !success) return;
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
      if (mounted) AppNavigator.pop(context);
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
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            if (widget.initialClass != null &&
                widget.initialSubject != null) ...[
              // Modal-style entry: custom header with Export + Close on the
              // right, matching the app's "Buku Nilai" UX.
              GradeRecapModalHeader(
                title:
                    widget.initialSubject?['nama'] ??
                    widget.initialSubject?['name'] ??
                    'Subject',
                subtitle:
                    widget.initialClass?['nama'] ??
                    widget.initialClass?['name'] ??
                    'Class',
                primaryColor: getPrimaryColor(),
                onExport: exportToExcel,
                onClose: handleBackButton,
                isExporting: isExporting,
                exportKey: _exportKey,
              ),
            ] else ...[
              buildMainHeader(lp),
              if (_currentStep < 2) buildRecapSearchBar(lp),
            ],
            Expanded(child: _buildBody(lp)),
          ],
        ),
        bottomNavigationBar: (_currentStep == 2 && tableData.isNotEmpty)
            ? GradeRecapSaveBar(
                saveKey: _saveKey,
                isSaving: isSaving,
                hasUnsavedChanges: hasUnsavedChanges,
                onSave: _onSavePressed,
                lp: lp,
              )
            : null,
        floatingActionButton: (_currentStep == 2 && tableData.isNotEmpty)
            ? FloatingActionButton(
                key: _addChapterKey,
                heroTag: 'grade_recap_add_chapter_fab',
                onPressed: addChapter,
                backgroundColor: getPrimaryColor(),
                foregroundColor: Colors.white,
                elevation: 4,
                tooltip: 'Tambah kolom / bab',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_rounded, size: 28),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        cellBuilder: (studentClassId, type, chapterIndex) {
          return buildEditableGradeCell(studentClassId, type, chapterIndex);
        },
        onBulkSelect: (type, chapterIndex) =>
            showBulkDialog(type, chapterIndex),
        onDeleteChapter: deleteChapter,
        onEditChapter: editChapter,
        onDeskripsiTap: showEditDeskripsi,
      ),
    );
  }
}
