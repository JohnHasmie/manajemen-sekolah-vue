// Sub-chapter (sub-bab) detail page extracted from teacher_material_screen.dart.
//
// Shows content for a single sub-chapter with AI-generated materials,
// quizzes, and references in a tabbed layout.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/sub_chapter_header.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_tab_content.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/empty_tab_state.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/quiz_stats_bar.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mc_quiz_card.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/essay_quiz_card.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/reference_tab_content.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_ai_polling_view.dart';

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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
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
      primaryColor: _getPrimaryColor(),
      cardGradient: _getCardGradient(),
      languageProvider: languageProvider,
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
                      !_isLoadingAi && !_isPollingAi)
                ? _buildEmptyContent(languageProvider)
                : (_isLoadingAi || _isPollingAi) && _aiGeneratedData == null
                    ? _buildEmptyContent(languageProvider)
                    : _buildTabbedContent(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    if (_isLoading || _isPollingAi || _aiGeneratedData == null) {
      return null;
    }

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final currentIndex = _tabController.index;
        
        switch (currentIndex) {
          case 0: // Materi
            return FloatingActionButton.extended(
              onPressed: _isRegeneratingMateri ? null : _regenerateMaterialOnly,
              backgroundColor: _isRegeneratingMateri ? ColorUtils.slate400 : _getPrimaryColor(),
              elevation: 4,
              icon: _isRegeneratingMateri
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: Text(_isRegeneratingMateri ? 'Memproses...' : 'Ganti Materi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            );
          case 1: // Kuis
            final quizzes = (_aiGeneratedData?['quizzes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final canRegenQuiz = _aiGeneratedData?['regen_status']?['quiz']?['can_regenerate'] ?? true;
            final quizMax = _aiGeneratedData?['regen_status']?['quiz']?['max'] ?? 10;
            if (!canRegenQuiz && quizzes.isNotEmpty) {
              return FloatingActionButton.extended(
                onPressed: () => SnackBarUtils.showInfo(context, 'Batas tambah kuis telah tercapai (${quizMax}x)'),
                backgroundColor: ColorUtils.slate400,
                elevation: 2,
                icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                label: const Text('Batas Tercapai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              );
            }
            return FloatingActionButton.extended(
              onPressed: _isAddingQuiz ? null : (quizzes.isEmpty ? () => _generateMaterial(force: true) : _addMoreQuiz),
              backgroundColor: _isAddingQuiz ? ColorUtils.slate400 : _getPrimaryColor(),
              elevation: 4,
              icon: _isAddingQuiz
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(_isAddingQuiz ? 'Memproses...' : 'Tambah Kuis', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            );
          case 2: // Referensi
            final references = (_aiGeneratedData?['references'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final canRegenRef = _aiGeneratedData?['regen_status']?['reference']?['can_regenerate'] ?? true;
            final refMax = _aiGeneratedData?['regen_status']?['reference']?['max'] ?? 5;
            if (!canRegenRef && references.isNotEmpty) {
              return FloatingActionButton.extended(
                onPressed: () => SnackBarUtils.showInfo(context, 'Batas ganti referensi telah tercapai (${refMax}x)'),
                backgroundColor: ColorUtils.slate400,
                elevation: 2,
                icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                label: const Text('Batas Tercapai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              );
            }
            return FloatingActionButton.extended(
              onPressed: _isRegeneratingRef ? null : (references.isNotEmpty ? _regenerateReferences : () => _generateMaterial(force: true)),
              backgroundColor: _isRegeneratingRef ? ColorUtils.slate400 : _getPrimaryColor(),
              elevation: 4,
              icon: _isRegeneratingRef
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: Text(_isRegeneratingRef ? 'Memproses...' : 'Ganti Referensi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildEmptyContent(LanguageProvider languageProvider) {
    if (_isPollingAi) {
      return MaterialAiPollingView(
        pollingStatus: _pollingStatus,
        primaryColor: _getPrimaryColor(),
      );
    }
    
    if (_pollingError != null) {
      final isRateLimit = _pollingError!.toLowerCase().contains('tunggu') || 
                          _pollingError!.toLowerCase().contains('menit') ||
                          _pollingError!.toLowerCase().contains('batas');
      
      final title = isRateLimit ? 'Istirahat Sejenak' : 'Mohon Maaf, Ada Kendala';
      final icon = isRateLimit ? Icons.hourglass_empty_rounded : Icons.info_outline_rounded;
      final iconColor = isRateLimit ? Colors.orange[600] : Colors.red[400];
      final bgColor = isRateLimit ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.05);

      String displayMessage = _pollingError!;
      if (isRateLimit) {
        displayMessage = 'Sistem membutuhkan sedikit waktu pemulihan untuk hasil terbaik. $_pollingError';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate200.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: ColorUtils.slate100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 42, color: iconColor),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: ColorUtils.slate500,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryColor(),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _generateMaterial, 
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: ColorUtils.info600.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 48, color: ColorUtils.info600),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Belum Ada Konten',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Materi, soal, dan referensi belum tersedia untuk sub-bab ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: ColorUtils.slate500,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: ElevatedButton.icon(
                onPressed: _isLoadingAi ? null : _generateMaterial,
                icon: _isLoadingAi 
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                    : const Icon(Icons.auto_awesome_rounded, size: 22),
                label: Text(
                  _isLoadingAi ? ' Sedang Memproses...' : ' Generate Materi AI',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _getPrimaryColor().withValues(alpha: 0.7),
                  disabledForegroundColor: Colors.white,
                  elevation: _isLoadingAi ? 0 : 8,
                  shadowColor: _getPrimaryColor().withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    if (_isRegeneratingMateri) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
        SizedBox(height: 16),
        Text('Memperbarui materi...', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      ]));
    }
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
    if (_isAddingQuiz) {
      return Column(children: [
        if (quizzes.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: _buildQuizStats(quizzes)),
        ],
        const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(height: 16),
          Text('Menambahkan kuis baru...', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        ]))),
      ]);
    }
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
    if (_isRegeneratingRef) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
        SizedBox(height: 16),
        Text('Memperbarui referensi...', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      ]));
    }
    return ReferenceTabContent(
      references: references,
      primaryColor: _getPrimaryColor(),
      stripHtml: _stripHtml,
      onEmptyGenerateTap: _navigateToAiResult,
    );
  }

  // ==================== SHARED HELPERS ====================

  Future<void> _generateMaterial({String prompt = '', bool force = false}) async {
    setState(() {
      _isLoadingAi = true;
      _pollingError = null;
      if (force) _aiGeneratedData = null; // Clear old data to show loading
    });

    // Clear local cache when force regenerating
    if (force) {
      final aiCacheKey = CacheKeyBuilder.custom('materi_ai', '${widget.teacherId}_${widget.chapter['id']}', widget.subChapter['id'].toString());
      await LocalCacheService.clearStartingWith(aiCacheKey);
    }

    try {
      final payload = <String, dynamic>{
        'teacher_id': widget.teacherId,
        'subject_id': widget.subjectId,
        'chapter_id': widget.chapter['id'].toString(),
        'sub_chapter_id': widget.subChapter['id'].toString(),
      };

      if (prompt.isNotEmpty) payload['prompt'] = prompt;
      if (force) payload['force'] = true;

      final response = await getIt<ApiSubjectService>().generateMaterialRaw(payload);
      if (!mounted) return;

      final resultBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 202) {
        final pollUrl = (resultBody['poll_url'] ?? resultBody['polling_url'] ?? resultBody['status_url']) as String?;
        final jobId = (resultBody['job_id'] ?? resultBody['jobId'] ?? resultBody['id'] ?? resultBody['data']?['id'] ?? resultBody['data']?['job_id']) as String?;

        setState(() {
          _isPollingAi = true;
          _isLoadingAi = true;
          _pollingStatus = 'Sedang memproses materi... ini bisa memakan waktu hingga 1 menit.';
        });

        await _startPolling(jobId: jobId, pollUrl: pollUrl);
        return;
      }

      if (response.statusCode == 429) {
        final message = resultBody['message'] ?? 'Batas penggunaan AI harian telah tercapai.';
        if (mounted) {
          setState(() {
            _isLoadingAi = false;
            _pollingError = message;
          });
        }
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = resultBody['data'] ?? resultBody;
        _applyResult(data);
        return;
      }

      throw Exception(resultBody['message'] ?? 'Gagal menghasilkan materi dari AI.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAi = false;
        _isPollingAi = false;
        _pollingError = e.toString();
      });
    }
  }

  Future<void> _startPolling({String? jobId, String? pollUrl}) async {
    final token = PreferencesService().getString('token');

    int attempts = 0;
    const maxAttempts = 60;

    while (attempts < maxAttempts) {
      if (!mounted) return;
      attempts++;

      try {
        final jobIdForPoll = jobId ?? pollUrl?.split('/').last ?? '';
        if (jobIdForPoll.isNotEmpty) {
          final response = await getIt<ApiSubjectService>().pollAiJob(jobIdForPoll, token ?? '');
          
          if (!mounted) return;

          if (response.statusCode == 200) {
            final resultBody = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : <String, dynamic>{};
            final jobData = resultBody['data'] ?? resultBody;
            final status = jobData['status'] ?? resultBody['status'];

            if (status == 'completed' || status == 'success') {
              final materialData = jobData['result'] ?? jobData['data'] ?? resultBody['result'] ?? resultBody;
              _applyResult(materialData);
              return;
            } else if (status == 'failed' || status == 'error') {
              setState(() {
                _isPollingAi = false;
                _isLoadingAi = false;
                _pollingError = jobData['error_message'] ?? 'AI gagal memproses materi.';
              });
              return;
            }
          }
        }
      } catch (e) {
        AppLogger.error('material', e.toString());
      }

      await Future.delayed(const Duration(seconds: 4));
    }

    if (mounted) {
      setState(() {
        _isPollingAi = false;
        _isLoadingAi = false;
        _pollingError = 'Proses memakan waktu terlalu lama. Silakan coba lagi.';
      });
    }
  }

  void _applyResult(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _aiGeneratedData = data;
      _isLoadingAi = false;
      _isPollingAi = false;
      _pollingError = null;
    });

    widget.onGenerated?.call();
  }

  Future<void> _regenerateMaterialOnly() async {
    final materialId = _aiGeneratedData?['id']?.toString();
    if (materialId == null) {
      _generateMaterial(force: true);
      return;
    }
    // Only set materi-loading, keep _aiGeneratedData so quiz+ref tabs stay visible
    setState(() => _isRegeneratingMateri = true);
    final aiCacheKey = CacheKeyBuilder.custom('materi_ai', '${widget.teacherId}_${widget.chapter['id']}', widget.subChapter['id'].toString());
    await LocalCacheService.clearStartingWith(aiCacheKey);
    try {
      final result = await getIt<ApiSubjectService>().regenerateMaterialContent(materialId);
      if (!mounted) return;
      final data = result is Map ? (result['data'] ?? result) : null;
      if (data != null && data is Map<String, dynamic>) {
        setState(() { _aiGeneratedData = data; _isRegeneratingMateri = false; });
        await LocalCacheService.save(aiCacheKey, data);
      } else {
        setState(() => _isRegeneratingMateri = false);
        _loadAiContent();
      }
    } catch (e) {
      AppLogger.error('material', 'Regenerate material error: $e');
      if (mounted) {
        setState(() => _isRegeneratingMateri = false);
        // If 404/422, material doesn't exist on this server — do full regeneration
        if (e.toString().contains('404') || e.toString().contains('422')) {
          _generateMaterial(force: true);
          return;
        }
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _addMoreQuiz() async {
    final materialId = _aiGeneratedData?['id']?.toString();
    if (materialId == null) return;
    setState(() => _isAddingQuiz = true);
    try {
      final response = await getIt<ApiSubjectService>().regenerateQuizRaw(materialId);
      if (!mounted) return;

      if (response.statusCode == 202) {
        // Async — poll for result
        final body = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : <String, dynamic>{};
        final jobId = (body['job_id'] ?? body['data']?['job_id'])?.toString();
        if (jobId != null) {
          await _pollAndReload(materialId, jobId, onDone: () { if (mounted) setState(() => _isAddingQuiz = false); });
          return;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _reloadMaterialFromApi(materialId);
        if (mounted) {
          setState(() => _isAddingQuiz = false);
          SnackBarUtils.showSuccess(context, 'Kuis baru berhasil ditambahkan');
        }
        return;
      }

      final msg = (response.data is Map ? response.data['message'] : null) ?? 'Gagal menambah kuis';
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('material', 'Add quiz error: $e');
      if (mounted) {
        setState(() => _isAddingQuiz = false);
        SnackBarUtils.showError(context, e.toString().contains('404')
            ? 'Materi perlu di-generate ulang terlebih dahulu'
            : ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _regenerateReferences() async {
    final materialId = _aiGeneratedData?['id']?.toString();
    if (materialId == null) return;
    setState(() => _isRegeneratingRef = true);
    try {
      final response = await getIt<ApiSubjectService>().regenerateReferencesRaw(materialId);
      if (!mounted) return;

      if (response.statusCode == 202) {
        final body = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : <String, dynamic>{};
        final jobId = (body['job_id'] ?? body['data']?['job_id'])?.toString();
        if (jobId != null) {
          await _pollAndReload(materialId, jobId, onDone: () { if (mounted) setState(() => _isRegeneratingRef = false); });
          return;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _reloadMaterialFromApi(materialId);
        if (mounted) {
          setState(() => _isRegeneratingRef = false);
          SnackBarUtils.showSuccess(context, 'Referensi berhasil diperbarui');
        }
        return;
      }

      final msg = (response.data is Map ? response.data['message'] : null) ?? 'Gagal memperbarui referensi';
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('material', 'Regenerate references error: $e');
      if (mounted) {
        setState(() => _isRegeneratingRef = false);
        SnackBarUtils.showError(context, e.toString().contains('404')
            ? 'Materi perlu di-generate ulang terlebih dahulu'
            : ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Polls an AI job until complete, then reloads the material.
  Future<void> _pollAndReload(String materialId, String jobId, {VoidCallback? onDone}) async {
    final token = PreferencesService().getString('token');
    int attempts = 0;
    while (attempts < 60 && mounted) {
      attempts++;
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final pollResponse = await getIt<ApiSubjectService>().pollAiJob(jobId, token ?? '');
        if (pollResponse.statusCode == 200) {
          final body = pollResponse.data is Map<String, dynamic> ? pollResponse.data as Map<String, dynamic> : <String, dynamic>{};
          final jobData = body['data'] ?? body;
          final status = jobData['status'] ?? body['status'];
          if (status == 'completed' || status == 'success') {
            await _reloadMaterialFromApi(materialId);
            onDone?.call();
            return;
          } else if (status == 'failed' || status == 'error') {
            if (mounted) SnackBarUtils.showError(context, jobData['error_message']?.toString() ?? 'Gagal memproses');
            onDone?.call();
            return;
          }
        }
      } catch (_) {}
    }
    onDone?.call();
  }

  /// Fetches fresh material data from API and updates state + cache.
  Future<void> _reloadMaterialFromApi(String materialId) async {
    final aiCacheKey = CacheKeyBuilder.custom('materi_ai', '${widget.teacherId}_${widget.chapter['id']}', widget.subChapter['id'].toString());
    await LocalCacheService.clearStartingWith(aiCacheKey);
    final result = await getIt<ApiSubjectService>().getGeneratedMaterial(materialId, classId: widget.classId);
    if (!mounted) return;
    final data = result is Map ? (result['data'] ?? result) : null;
    if (data != null && data is Map<String, dynamic>) {
      setState(() => _aiGeneratedData = data);
      await LocalCacheService.save(aiCacheKey, data);
    }
  }

  void _navigateToAiResult() {
    _generateMaterial(force: true);
  }

}
