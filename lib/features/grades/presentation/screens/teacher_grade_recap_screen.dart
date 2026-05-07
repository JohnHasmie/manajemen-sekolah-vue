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
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_grade_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_data_ops_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_recap_ui_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/add_chapter_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_modal_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_table_view.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_tour_helper.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_unsaved_changes_dialog.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
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
        _fetchMaterialsForSubject(
          teacherId: teacherId,
          subjectId: subjectId,
          classId: classId,
          academicYearId: ayId,
        ),
        _fetchGradesForSubject(
          teacherId: teacherId,
          subjectId: subjectId,
          academicYearId: ayId,
        ),
      ]);

      if (!mounted) return;

      final data = results[0] as List<dynamic>;
      availableMaterials = results[1] as List<String>;
      rawGrades = results[2] as List<dynamic>;

      // Parse response into tableData format expected by mixins
      _buildTableData(data);

      setState(() => isLoading = false);

      // Show tour after first load
      WidgetsBinding.instance.addPostFrameCallback((_) => checkAndShowTour());
    } catch (e) {
      AppLogger.error('grade_recap', 'Error loading recap data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Converts API response into the tableData format expected by the table
  /// mixins. Also initialises controllers for predikat, description, and scores.
  void _buildTableData(List<dynamic> apiData) {
    // Determine chapters from the first student that has bab data
    List<dynamic> babNames = [];
    int maxBabs = 0;
    for (final row in apiData) {
      final scores = row['bab_scores'];
      final names = row['bab_names'];
      if (scores is List && scores.length > maxBabs) {
        maxBabs = scores.length;
        if (names is List && names.length == scores.length) {
          babNames = names;
        }
      }
    }

    // Build chapter list
    if (maxBabs == 0) {
      // Default to 1 empty chapter if none exist
      maxBabs = 1;
      babNames = ['Bab 1'];
    }
    chapters = List.generate(maxBabs, (i) {
      final name = i < babNames.length ? babNames[i]?.toString() : null;
      return {'judul_bab': name ?? 'Bab ${i + 1}'};
    });

    // Dispose old controllers + focus nodes
    for (final c in scoreControllers.values) {
      c.dispose();
    }
    for (final f in scoreFocusNodes.values) {
      f.dispose();
    }
    for (final c in predikatControllers.values) {
      c.dispose();
    }
    for (final c in descriptionControllers.values) {
      c.dispose();
    }
    scoreControllers.clear();
    scoreFocusNodes.clear();
    predikatControllers.clear();
    descriptionControllers.clear();

    // Build table rows
    tableData = apiData.map<Map<String, dynamic>>((row) {
      final scId = row['student_class_id']?.toString() ?? '';
      // Use growable list — JSON decode returns fixed-length lists
      final babScores = row['bab_scores'] is List
          ? List<double?>.from(
              (row['bab_scores'] as List).map(
                (v) => v is num ? v.toDouble() : null,
              ),
            )
          : List<double?>.generate(maxBabs, (_) => null);

      // Pad bab_scores to maxBabs
      while (babScores.length < maxBabs) {
        babScores.add(null);
      }

      final uts = row['uts_score'] is num
          ? (row['uts_score'] as num).toDouble()
          : null;
      final uas = row['uas_score'] is num
          ? (row['uas_score'] as num).toDouble()
          : null;
      final finalScore = row['final_score'] is num
          ? (row['final_score'] as num).toDouble()
          : null;
      final skillScore = row['skill_score'] is num
          ? (row['skill_score'] as num).toDouble()
          : null;

      // Create controllers
      predikatControllers[scId] = TextEditingController(
        text: row['predikat']?.toString() ?? '',
      );
      descriptionControllers[scId] = TextEditingController(
        text: row['deskripsi']?.toString() ?? '',
      );

      // Score controllers + focus nodes keyed as "scId|type|chapterIndex".
      // Keeping both maps in lock-step lets the cell builder look up its
      // own focus node AND the adjacent row's focus node by the same key
      // shape, which is what powers Enter/Arrow-Down → next row.
      void registerCell(String cellKey, String text) {
        scoreControllers[cellKey] = TextEditingController(text: text);
        scoreFocusNodes[cellKey] = FocusNode(debugLabel: 'score:$cellKey');
      }

      for (int i = 0; i < maxBabs; i++) {
        registerCell(
          '$scId|bab|$i',
          babScores[i] != null ? babScores[i]!.toStringAsFixed(0) : '',
        );
      }
      registerCell('$scId|uts|null', uts != null ? uts.toStringAsFixed(0) : '');
      registerCell('$scId|uas|null', uas != null ? uas.toStringAsFixed(0) : '');
      registerCell(
        '$scId|skill_score|null',
        skillScore != null ? skillScore.toStringAsFixed(0) : '',
      );

      return {
        'student_class_id': scId,
        'student_id': row['student_id']?.toString() ?? '',
        'nama': row['student_name']?.toString() ?? '-',
        'nis': row['nis']?.toString() ?? '',
        'bab_scores': babScores,
        'uts': uts,
        'uas': uas,
        'final_score': finalScore,
        'skill_score': skillScore,
      };
    }).toList();

    hasUnsavedChanges = false;
  }

  Future<void> loadTodaySchedules() async {
    // Not needed for recap — placeholder for mixin compatibility
  }

  /// Pulls lesson-plan titles for the current (teacher, subject, class,
  /// academic-year) slice and returns them as a clean, deduped list of
  /// materi names. Failures return `[]` — the add-bab sheet handles the
  /// empty case by dropping straight into custom-input mode.
  Future<List<String>> _fetchMaterialsForSubject({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String academicYearId,
  }) async {
    try {
      final resp = await LessonPlanService.getLessonPlansPaginated(
        page: 1,
        limit: 100,
        teacherId: teacherId.isEmpty ? null : teacherId,
        subjectId: subjectId.isEmpty ? null : subjectId,
        classId: classId.isEmpty ? null : classId,
        academicYearId: academicYearId.isEmpty ? null : academicYearId,
      );
      final list = resp['data'];
      if (list is! List) return <String>[];
      final titles = <String>{};
      for (final item in list) {
        if (item is! Map) continue;
        final title = (item['title'] ?? item['judul'] ?? item['nama'])
            ?.toString()
            .trim();
        if (title != null && title.isNotEmpty) titles.add(title);
      }
      return titles.toList();
    } catch (e) {
      AppLogger.error('grade_recap', 'Error loading lesson-plan titles: $e');
      return <String>[];
    }
  }

  /// Pulls every grade recorded for this (teacher, subject, year) combo.
  /// Used in two ways: (1) as the pool the add-bab sheet dedupes into a
  /// list of assessments, and (2) as the per-student lookup we consult
  /// when the teacher picks an assessment to fill a new column from.
  Future<List<dynamic>> _fetchGradesForSubject({
    required String teacherId,
    required String subjectId,
    required String academicYearId,
  }) async {
    try {
      return await GradeService.getGrades(
        teacherId: teacherId.isEmpty ? null : teacherId,
        subjectId: subjectId.isEmpty ? null : subjectId,
        academicYearId: academicYearId.isEmpty ? null : academicYearId,
      );
    } catch (e) {
      AppLogger.error('grade_recap', 'Error loading grades pool: $e');
      return <dynamic>[];
    }
  }

  /// Collapses [rawGrades] into a deduped list of assessments,
  /// keyed by (title, date, type). Each entry is the shape the
  /// add-bab sheet expects:
  /// ```
  /// { 'title': 'Tugas 1', 'type': 'tugas', 'date': '2025-09-14' }
  /// ```
  List<Map<String, dynamic>> _deriveAvailableAssessments() {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final g in rawGrades) {
      if (g is! Map) continue;
      final title = (g['title'] ?? g['judul'] ?? '').toString().trim();
      final type = (g['type'] ?? g['grade_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final date = (g['date'] ?? g['tanggal'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final key = '$title|$type|$date';
      if (seen.add(key)) {
        out.add({'title': title, 'type': type, 'date': date});
      }
    }
    // Sort: group by type first (tugas/uh/…), then by date ascending.
    out.sort((a, b) {
      final t = (a['type'] as String).compareTo(b['type'] as String);
      if (t != 0) return t;
      return (a['date'] as String).compareTo(b['date'] as String);
    });
    return out;
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
    final assessments = _deriveAvailableAssessments();
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
    final currentName = (ch['judul_bab'] ??
            ch['judul'] ??
            ch['title'] ??
            'Bab ${chapterIndex + 1}')
        .toString();
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ubah nama bab'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nama bab',
            hintText: 'Mis. "Bab 1: Pengantar"',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(dialogCtx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Defer disposal — the dialog's close animation may still
    // rebuild the TextField on the next frame and would crash
    // with "TextEditingController used after disposed".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (newName == null || newName.isEmpty || newName == currentName) return;
    if (!mounted) return;
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
    final name = (ch['judul_bab'] ??
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
      WidgetsBinding.instance.addPostFrameCallback((_) => loadRecapData());
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
            ? _buildBottomBar(lp)
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

  /// Sticky bottom bar: Simpan-only primary action.
  ///
  /// Export lives in the header; the `+` FAB handles add-chapter. This
  /// leaves the bottom bar free to present a single full-width save
  /// affordance with an inline unsaved-changes hint. The FAB floats above
  /// the bar via [FloatingActionButtonLocation.endFloat], so the Simpan
  /// button takes the full available width.
  Widget _buildBottomBar(LanguageProvider lp) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        key: _saveKey,
        height: 52,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : _onSavePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorUtils.success600,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorUtils.slate300,
            elevation: 2,
            shadowColor: ColorUtils.success600.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSaving
                    ? lp.getTranslatedText({
                        'en': 'Saving...',
                        'id': 'Menyimpan...',
                      })
                    : lp.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              // Inline unsaved-changes indicator — small white dot next
              // to the label when there are pending changes.
              if (hasUnsavedChanges && !isSaving) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
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
