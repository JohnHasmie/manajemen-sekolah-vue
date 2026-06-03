// Sub-chapter (sub-bab) detail page extracted from
// teacher_material_screen.dart.
//
// Shows content for a single sub-chapter with AI-generated materials,
// quizzes, and references in a tabbed layout.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_ai_generation_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_data_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_material_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_quiz_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_reference_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_tab_content_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_ui_loading_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/sub_chapter_ui_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_section_editor_sheet.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_empty_content.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_fab.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_header.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_tab_bar.dart';

/// Detail page for a sub-chapter (sub-bab) showing its content and AI
/// materials.
class SubBabDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subChapter;
  final Map<String, dynamic> chapter;
  final String teacherId;
  final String subjectId;
  final String? classId;
  final String? className;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;
  final VoidCallback? onGenerated;

  const SubBabDetailPage({
    super.key,
    required this.subChapter,
    required this.chapter,
    required this.teacherId,
    required this.subjectId,
    this.classId,
    this.className,
    required this.checked,
    required this.onCheckChanged,
    this.onGenerated,
  });

  @override
  SubBabDetailPageState createState() => SubBabDetailPageState();
}

class SubBabDetailPageState extends ConsumerState<SubBabDetailPage>
    with
        SingleTickerProviderStateMixin,
        SubChapterDataMixin,
        SubChapterAiGenerationMixin,
        SubChapterMaterialMixin,
        SubChapterQuizMixin,
        SubChapterReferenceMixin,
        SubChapterUiMixin,
        SubChapterUiLoadingMixin,
        SubChapterTabContentMixin {
  // ==================== STATE ====================
  List<dynamic> _contentList = [];
  Map<String, dynamic>? _aiGeneratedData;
  bool _isLoading = false;
  bool _isLoadingAi = false;
  bool _isRegeneratingMateri = false;
  bool _isAddingQuiz = false;
  bool _isRegeneratingRef = false;
  bool _isPollingAi = false;
  String _pollingStatus = '';
  String? _pollingError;
  late TabController _tabController;

  // ==================== MIXIN GETTERS/SETTERS ====================
  @override
  List<dynamic> get contentList => _contentList;
  @override
  set contentList(List<dynamic> value) => _contentList = value;

  @override
  Map<String, dynamic>? get aiGeneratedData => _aiGeneratedData;
  @override
  set aiGeneratedData(Map<String, dynamic>? value) => _aiGeneratedData = value;

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  bool get isLoadingAi => _isLoadingAi;
  @override
  set isLoadingAi(bool value) => _isLoadingAi = value;

  @override
  bool get isRegeneratingMateri => _isRegeneratingMateri;
  @override
  set isRegeneratingMateri(bool value) => _isRegeneratingMateri = value;

  @override
  bool get isAddingQuiz => _isAddingQuiz;
  @override
  set isAddingQuiz(bool value) => _isAddingQuiz = value;

  @override
  bool get isRegeneratingRef => _isRegeneratingRef;
  @override
  set isRegeneratingRef(bool value) => _isRegeneratingRef = value;

  @override
  bool get isPollingAi => _isPollingAi;
  @override
  set isPollingAi(bool value) => _isPollingAi = value;

  @override
  String get pollingStatus => _pollingStatus;
  @override
  set pollingStatus(String value) => _pollingStatus = value;

  @override
  String? get pollingError => _pollingError;
  @override
  set pollingError(String? value) => _pollingError = value;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadContent();
    loadAiContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          SubChapterHeader(
            chapter: widget.chapter,
            subChapter: widget.subChapter,
            primaryColor: getPrimaryColor(),
            cardGradient: getCardGradient(),
            languageProvider: languageProvider,
            isChecked: widget.checked,
            hasAi: _aiGeneratedData != null,
            className: widget.className,
            subjectName:
                widget.subChapter['subject_name']?.toString() ??
                widget.chapter['subject_name']?.toString(),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ==================== CONTENT BUILDING ====================
  Widget _buildContent() {
    if (_isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        showActions: false,
      );
    }

    if (shouldShowEmpty(
      _contentList,
      _aiGeneratedData,
      _isLoading,
      _isLoadingAi,
      _isPollingAi,
    )) {
      return SubChapterEmptyContent(
        isPollingAi: _isPollingAi,
        pollingStatus: _pollingStatus,
        pollingError: _pollingError,
        primaryColor: getPrimaryColor(),
        isLoadingAi: _isLoadingAi,
        onGenerateTap: _navigateToAiResult,
      );
    }

    return _buildTabbedContent();
  }

  Widget? _buildFAB() {
    if (_isLoading || _isPollingAi || _aiGeneratedData == null) {
      return null;
    }

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final quizzes =
            (_aiGeneratedData?['quizzes'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final references =
            (_aiGeneratedData?['references'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        return SubChapterFAB(
          currentTabIndex: _tabController.index,
          isRegeneratingMateri: _isRegeneratingMateri,
          isAddingQuiz: _isAddingQuiz,
          isRegeneratingRef: _isRegeneratingRef,
          isLoading: _isLoading,
          isPollingAi: _isPollingAi,
          quizzes: quizzes,
          references: references,
          primaryColor: getPrimaryColor(),
          onRegenerateMaterial: regenerateMaterialOnly,
          onAddQuiz: addMoreQuiz,
          onGenerateMaterial: _navigateToAiResult,
          onRegenerateReferences: regenerateReferences,
          context: context,
        );
      },
    );
  }

  Widget _buildTabbedContent() {
    final quizzes =
        (_aiGeneratedData?['quizzes'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final references =
        (_aiGeneratedData?['references'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Column(
      children: [
        SubChapterTabBar(
          controller: _tabController,
          primaryColor: getPrimaryColor(),
          quizzes: quizzes,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              buildMaterialTab(
                _isRegeneratingMateri,
                _aiGeneratedData,
                _contentList,
                buildLoadingState,
              ),
              buildKuisTab(_isAddingQuiz, quizzes, buildQuizLoadingState),
              buildReferensiTab(
                _isRegeneratingRef,
                references,
                buildLoadingState,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HELPERS ====================
  void _navigateToAiResult() => generateMaterial(force: true);

  @override
  void onAiResultTap() => _navigateToAiResult();

  @override
  Future<void> generateMaterialFallback({bool force = false}) async {
    await generateMaterial(force: force);
  }

  // ==================== SECTION EDITOR ====================
  /// Open the per-section editor sheet for `fieldKey` with `currentValue`
  /// preloaded. On Save, merge the new value back into the parsed
  /// `material_content` map, re-encode, and rewrite the sub-chapter
  /// cache so the edit survives re-opens.
  ///
  /// The kamiledu-ai service does not yet expose a PATCH endpoint for
  /// `generated_materials.material_content`, so persistence today is
  /// local cache only. When that endpoint lands, this method should
  /// also POST the merged JSON.
  @override
  void onEditSection(String fieldKey, String fieldLabel, String currentValue) {
    _openSectionEditor(fieldKey, fieldLabel, currentValue);
  }

  Future<void> _openSectionEditor(
    String fieldKey,
    String fieldLabel,
    String currentValue,
  ) async {
    final result = await showMaterialSectionEditorSheet(
      context: context,
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      currentValue: currentValue,
    );
    if (result == null || !mounted) return;
    await _applySectionEdit(result.fieldKey, fieldLabel, result.newValue);
  }

  Future<void> _applySectionEdit(
    String fieldKey,
    String fieldLabel,
    String newValue,
  ) async {
    final ai = _aiGeneratedData;
    if (ai == null) return;

    // Decode the existing material_content (string-encoded JSON in the
    // common case, plain Map when the backend already inflated it).
    final raw = ai['material_content'];
    Map<String, dynamic> parsed;
    if (raw is Map<String, dynamic>) {
      parsed = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        parsed = decoded is Map<String, dynamic>
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
      } catch (_) {
        parsed = <String, dynamic>{};
      }
    } else {
      parsed = <String, dynamic>{};
    }

    // List-shaped sections round-trip via newline split. Anything else
    // is stored as a plain string.
    final wasList = parsed[fieldKey] is List;
    if (wasList) {
      final items = newValue
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      parsed[fieldKey] = items;
    } else {
      parsed[fieldKey] = newValue;
    }

    final updated = Map<String, dynamic>.from(ai);
    // Re-encode as string when the upstream shape was a string — the
    // backend stores `material_content` as TEXT and most callers
    // expect to decode it. Keep Map shape intact when it was Map.
    updated['material_content'] = raw is Map<String, dynamic>
        ? parsed
        : json.encode(parsed);

    setState(() {
      _aiGeneratedData = updated;
    });

    // Rewrite the composite cache so the next open reads the edit.
    final aiCacheKey = CacheKeyBuilder.custom(
      'materi_ai',
      '${widget.teacherId}_${widget.chapter['id']}',
      widget.subChapter['id'].toString(),
    );
    try {
      await LocalCacheService.save(aiCacheKey, updated);
    } catch (_) {
      // Cache failure is non-fatal — the edit still lives in memory
      // until the page is disposed.
    }

    if (!mounted) return;
    SnackBarUtils.showInfo(
      context,
      '$fieldLabel diperbarui (lokal — sinkron AI menyusul)',
    );
  }

  // ==================== SUBCHAPTERUILOADINGMIXIN IMPLEMENTATIONS
  // ====================
  @override
  Widget buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildQuizLoadingState(List<Map<String, dynamic>> quizzes) {
    return Column(
      children: [
        if (quizzes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: buildQuizStatsPlaceholder(quizzes),
          ),
        ],
        const Expanded(child: _QuizLoadingCenter()),
      ],
    );
  }

  @override
  Widget buildQuizStatsPlaceholder(List<Map<String, dynamic>> quizzes) {
    return SizedBox(
      height: 50,
      child: Center(
        child: Text(
          '${quizzes.length} kuis tersimpan',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
        ),
      ),
    );
  }
}

/// Centered loading spinner with message for quiz additions.
class _QuizLoadingCenter extends StatelessWidget {
  const _QuizLoadingCenter();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Menambahkan kuis baru...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
