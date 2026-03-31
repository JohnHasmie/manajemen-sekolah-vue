// Sub-chapter (sub-bab) detail page extracted from teacher_material_screen.dart.
//
// Shows content for a single sub-chapter with AI-generated materials,
// quizzes, and references in a tabbed layout.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/material_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_header.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_tab_content.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/empty_tab_state.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/quiz_stats_bar.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mc_quiz_card.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/essay_quiz_card.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/reference_tab_content.dart';

/// Detail page for a sub-chapter (sub-bab) showing its content and AI materials.
///
/// Like a Vue `<SubChapterDetail>` component that shows content and allows
/// AI material generation. Contains both static content and AI-generated content
/// loaded asynchronously. Props include the sub-chapter data, parent chapter,
/// teacher/subject IDs, and a checkbox callback.
class SubBabDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subChapter;
  final Map<String, dynamic> chapter;
  final String teacherId;
  final String subjectId;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;

  const SubBabDetailPage({
    super.key,
    required this.subChapter,
    required this.chapter,
    required this.teacherId,
    required this.subjectId,
    required this.checked,
    required this.onCheckChanged,
  });

  @override
  SubBabDetailPageState createState() => SubBabDetailPageState();
}

class SubBabDetailPageState extends ConsumerState<SubBabDetailPage>
    with SingleTickerProviderStateMixin {
  late bool _isChecked;
  List<dynamic> _contentList = [];
  Map<String, dynamic>? _aiGeneratedData;
  bool _isLoading = false;
  bool _isLoadingAi = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.checked;
    _tabController = TabController(length: 3, vsync: this);
    _loadContent();
    _loadAiContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final contentCacheKey = CacheKeyBuilder.custom(
      'materi_content',
      widget.subChapter['id'].toString(),
    );

    // Try cache — return early if hit
    try {
      final cached = await LocalCacheService.load(
        contentCacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is List && mounted) {
        setState(() {
          _contentList = List<dynamic>.from(cached);
          _isLoading = false;
        });
        AppLogger.debug(
          'material',
          'ContentMateri ${widget.subChapter['id']}: from cache',
        );
        return;
      }
    } catch (e) {
      AppLogger.error('material', 'Content cache load error: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => _isLoading = true);

    try {
      final contentMaterial = await getIt<ApiSubjectService>()
          .getContentMaterials(
            subChapterId: widget.subChapter['id'].toString(),
          );
      if (!mounted) return;

      setState(() {
        _contentList = contentMaterial;
        _isLoading = false;
      });

      await LocalCacheService.save(contentCacheKey, contentMaterial);
    } catch (e) {
      AppLogger.error('material', 'Error loading content materi: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAiContent() async {
    final aiCacheKey = CacheKeyBuilder.custom(
      'materi_ai',
      '${widget.teacherId}_${widget.chapter['id']}',
      widget.subChapter['id'].toString(),
    );

    // Try local cache — return early if hit
    try {
      final cached = await LocalCacheService.load(
        aiCacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is Map && mounted) {
        setState(() {
          _aiGeneratedData = Map<String, dynamic>.from(cached);
          _isLoadingAi = false;
        });
        AppLogger.debug(
          'material',
          'AI content ${widget.subChapter['id']}: from cache',
        );
        return;
      }
    } catch (e) {
      AppLogger.error('material', 'AI local cache load error: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => _isLoadingAi = true);

    try {
      Map<String, dynamic>? aiData;

      try {
        final cacheResult = await getIt<ApiSubjectService>().checkMaterialCache(
          teacherId: widget.teacherId,
          chapterId: widget.chapter['id'].toString(),
          subChapterId: widget.subChapter['id'].toString(),
        );
        if (!mounted) return;

        if (cacheResult != null) {
          final cacheData = cacheResult is Map && cacheResult['data'] is Map
              ? cacheResult['data']
              : cacheResult;

          final isCached = cacheData['cached'] == true;
          final materialId = (cacheData['material_id'] ?? cacheData['id'])
              ?.toString();

          if (isCached && materialId != null) {
            final materialResult = await getIt<ApiSubjectService>()
                .getGeneratedMaterial(materialId);
            if (!mounted) return;

            final data = materialResult is Map
                ? (materialResult['data'] ?? materialResult)
                : null;
            if (data != null && data is Map<String, dynamic>) {
              aiData = data;
            }
          }
        }
      } catch (cacheError) {
        AppLogger.error(
          'material',
          'Check-cache failed: $cacheError, trying list fallback...',
        );
      }

      // Fallback: use list endpoint if check-cache failed
      if (aiData == null && mounted) {
        try {
          final listResult = await getIt<ApiSubjectService>()
              .listGeneratedMaterials(
                teacherId: widget.teacherId,
                chapterId: widget.chapter['id'].toString(),
              );
          if (!mounted) return;

          final items = listResult is Map
              ? (listResult['data'] is List ? listResult['data'] : null)
              : (listResult is List ? listResult : null);

          if (items != null && items.isNotEmpty) {
            final subChapterId = widget.subChapter['id'].toString();
            Map<String, dynamic>? match;

            for (final item in items) {
              if (item is Map<String, dynamic>) {
                final itemSubChapter =
                    (item['sub_chapter_id'] ?? item['sub_bab_id'])?.toString();
                if (itemSubChapter == subChapterId) {
                  match = item;
                  break;
                }
              }
            }

            if (match != null) {
              final materialId = match['id']?.toString();
              if (materialId != null) {
                final materialResult = await getIt<ApiSubjectService>()
                    .getGeneratedMaterial(materialId);
                if (!mounted) return;

                final data = materialResult is Map
                    ? (materialResult['data'] ?? materialResult)
                    : null;
                if (data != null && data is Map<String, dynamic>) {
                  aiData = data;
                }
              }
            }
          }
        } catch (listError) {
          AppLogger.error(
            'material',
            'List materials fallback also failed: $listError',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _aiGeneratedData = aiData;
        _isLoadingAi = false;
      });

      if (aiData != null) {
        await LocalCacheService.save(aiCacheKey, aiData);
      }
    } catch (e) {
      AppLogger.error('material', 'Error loading AI content: $e');
      if (!mounted) return;
      setState(() => _isLoadingAi = false);
    }
  }

  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (text.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n\n');
    return text.trim();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return SubChapterHeader(
      chapter: widget.chapter,
      subChapter: widget.subChapter,
      isChecked: _isChecked,
      primaryColor: _getPrimaryColor(),
      cardGradient: _getCardGradient(),
      languageProvider: languageProvider,
      onCheckToggle: () {
        final newValue = !_isChecked;
        setState(() => _isChecked = newValue);
        widget.onCheckChanged(newValue);
      },
      onAiTap: _navigateToAiResult,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(languageProvider),
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    showActions: false,
                  )
                : (_contentList.isEmpty &&
                      _aiGeneratedData == null &&
                      !_isLoadingAi)
                ? _buildEmptyContent(languageProvider)
                : _buildTabbedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContent(LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Content',
        'id': 'Tidak Ada Konten',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en':
            'Content for this sub-chapter is not available yet. Tap the AI button to generate.',
        'id':
            'Konten untuk sub bab ini belum tersedia. Tekan tombol AI untuk generate.',
      }),
      icon: Icons.article,
    );
  }

  // ==================== TABBED CONTENT ====================

  Map<String, dynamic>? _parseMaterialContent() {
    final raw = _aiGeneratedData?['material_content'];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final parsed = json.decode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return null;
  }

  Widget _buildTabbedContent() {
    final primaryColor = _getPrimaryColor();
    final quizzes =
        (_aiGeneratedData?['quizzes'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final references =
        (_aiGeneratedData?['references'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: ColorUtils.slate100,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: primaryColor,
            unselectedLabelColor: ColorUtils.slate500,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Materi'),
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Kuis'),
                    if (quizzes.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Text(
                          '${quizzes.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Referensi'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMaterialTab(),
              _buildKuisTab(quizzes),
              _buildReferensiTab(references),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 1: MATERI ====================

  Widget _buildMaterialTab() {
    return MaterialTabContent(
      parsedContent: _parseMaterialContent(),
      aiGeneratedData: _aiGeneratedData,
      contentList: _contentList,
      primaryColor: _getPrimaryColor(),
      stripHtml: _stripHtml,
      onRegenerateTap: _navigateToAiResult,
    );
  }

  // ==================== TAB 2: KUIS ====================

  Widget _buildKuisTab(List<Map<String, dynamic>> quizzes) {
    if (quizzes.isEmpty) {
      return EmptyTabState(
        icon: Icons.quiz_rounded,
        title: 'Belum Ada Kuis',
        subtitle: 'Generate materi AI untuk mendapatkan kuis otomatis.',
        primaryColor: _getPrimaryColor(),
        onGenerateTap: _navigateToAiResult,
      );
    }

    // Separate MC and essay
    final mcQuizzes = quizzes
        .where((q) => q['question_type'] == 'multiple_choice')
        .toList();
    final essayQuizzes = quizzes
        .where((q) => q['question_type'] == 'essay')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Stats row
        _buildQuizStats(quizzes),
        const SizedBox(height: AppSpacing.lg),

        // Pilihan Ganda
        if (mcQuizzes.isNotEmpty) ...[
          _buildSubSectionHeader(
            icon: Icons.check_circle_outline_rounded,
            title: 'Pilihan Ganda',
            count: mcQuizzes.length,
            color: _getPrimaryColor(),
          ),
          const SizedBox(height: 10),
          ...mcQuizzes.asMap().entries.map(
            (entry) =>
                _buildMcQuizCard(entry.key, entry.value, mcQuizzes.length),
          ),
        ],

        // Essay
        if (essayQuizzes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildSubSectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'Essay',
            count: essayQuizzes.length,
            color: ColorUtils.violet500,
          ),
          const SizedBox(height: 10),
          ...essayQuizzes.asMap().entries.map(
            (entry) => _buildEssayQuizCard(entry.key, entry.value),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizStats(List<Map<String, dynamic>> quizzes) {
    return QuizStatsBar(quizzes: quizzes, primaryColor: _getPrimaryColor());
  }

  Widget _buildSubSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.all(Radius.circular(7)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMcQuizCard(int index, Map<String, dynamic> quiz, int totalMc) {
    return McQuizCard(
      index: index,
      quiz: quiz,
      primaryColor: _getPrimaryColor(),
    );
  }

  Widget _buildEssayQuizCard(int index, Map<String, dynamic> quiz) {
    return EssayQuizCard(index: index, quiz: quiz);
  }

  // ==================== TAB 3: REFERENSI ====================

  Widget _buildReferensiTab(List<Map<String, dynamic>> references) {
    return ReferenceTabContent(
      references: references,
      primaryColor: _getPrimaryColor(),
      stripHtml: _stripHtml,
      onEmptyGenerateTap: _navigateToAiResult,
    );
  }

  // ==================== SHARED HELPERS ====================

  void _navigateToAiResult() {
    AppNavigator.push(
      context,
      MaterialAiResultScreen(
        teacherId: widget.teacherId,
        subjectId: widget.subjectId,
        chapterId: widget.chapter['id'].toString(),
        subChapterId: widget.subChapter['id'].toString(),
        title: widget.subChapter['judul_sub_bab'] ?? 'Materi Pembelajaran',
      ),
    ).then((_) {
      // Reload AI content when returning
      _loadAiContent();
    });
  }

}
