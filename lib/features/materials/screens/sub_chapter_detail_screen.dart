// Sub-chapter (sub-bab) detail page extracted from teacher_material_screen.dart.
//
// Shows content for a single sub-chapter with AI-generated materials,
// quizzes, and references in a tabbed layout.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/materials/screens/material_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

/// Detail page for a sub-chapter (sub-bab) showing its content and AI materials.
///
/// Like a Vue `<SubChapterDetail>` component that shows content and allows
/// AI material generation. Contains both static content and AI-generated content
/// loaded asynchronously. Props include the sub-chapter data, parent chapter,
/// teacher/subject IDs, and a checkbox callback.
class SubBabDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subBab;
  final Map<String, dynamic> bab;
  final String teacherId;
  final String subjectId;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;

  const SubBabDetailPage({
    super.key,
    required this.subBab,
    required this.bab,
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
  List<dynamic> _contentMateriList = [];
  Map<String, dynamic>? _aiGeneratedData;
  bool _isLoading = false;
  bool _isLoadingAi = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.checked;
    _tabController = TabController(length: 3, vsync: this);
    _loadContentMateri();
    _loadAiContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContentMateri() async {
    final contentCacheKey = 'materi_content_${widget.subBab['id']}';

    // Try cache — return early if hit
    try {
      final cached = await LocalCacheService.load(contentCacheKey, ttl: const Duration(hours: 6));
      if (cached != null && cached is List && mounted) {
        setState(() {
          _contentMateriList = List<dynamic>.from(cached);
          _isLoading = false;
        });
        AppLogger.debug('material', 'ContentMateri ${widget.subBab['id']}: from cache');
        return;
      }
    } catch (e) {
      AppLogger.error('material', 'Content cache load error: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => _isLoading = true);

    try {
      final kontenMateri = await getIt<ApiSubjectService>().getContentMateri(
        subBabId: widget.subBab['id'].toString(),
      );
      if (!mounted) return;

      setState(() {
        _contentMateriList = kontenMateri;
        _isLoading = false;
      });

      await LocalCacheService.save(contentCacheKey, kontenMateri);
    } catch (e) {
      AppLogger.error('material', 'Error loading content materi: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAiContent() async {
    final aiCacheKey = 'materi_ai_${widget.teacherId}_${widget.bab['id']}_${widget.subBab['id']}';

    // Try local cache — return early if hit
    try {
      final cached = await LocalCacheService.load(aiCacheKey, ttl: const Duration(hours: 6));
      if (cached != null && cached is Map && mounted) {
        setState(() {
          _aiGeneratedData = Map<String, dynamic>.from(cached);
          _isLoadingAi = false;
        });
        AppLogger.debug('material', 'AI content ${widget.subBab['id']}: from cache');
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
          chapterId: widget.bab['id'].toString(),
          subChapterId: widget.subBab['id'].toString(),
        );
        if (!mounted) return;

        if (cacheResult != null) {
          final cacheData = cacheResult is Map && cacheResult['data'] is Map
              ? cacheResult['data']
              : cacheResult;

          final isCached = cacheData['cached'] == true;
          final materialId =
              (cacheData['material_id'] ?? cacheData['id'])?.toString();

          if (isCached && materialId != null) {
            final materialResult =
                await getIt<ApiSubjectService>().getGeneratedMaterial(materialId);
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
        AppLogger.error('material', 'Check-cache failed: $cacheError, trying list fallback...');
      }

      // Fallback: use list endpoint if check-cache failed
      if (aiData == null && mounted) {
        try {
          final listResult = await getIt<ApiSubjectService>().listGeneratedMaterials(
            teacherId: widget.teacherId,
            chapterId: widget.bab['id'].toString(),
          );
          if (!mounted) return;

          final items = listResult is Map
              ? (listResult['data'] is List ? listResult['data'] : null)
              : (listResult is List ? listResult : null);

          if (items != null && items.isNotEmpty) {
            final subChapterId = widget.subBab['id'].toString();
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
                final materialResult =
                    await getIt<ApiSubjectService>().getGeneratedMaterial(materialId);
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
          AppLogger.error('material', 'List materials fallback also failed: $listError');
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BAB ${widget.bab['urutan']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      widget.bab['judul_bab'] ?? 'Judul Bab',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  final newValue = !_isChecked;
                  setState(() {
                    _isChecked = newValue;
                  });
                  widget.onCheckChanged(newValue);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isChecked
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isChecked
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Done',
                          'id': 'Selesai',
                        }),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _navigateToAiResult,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub Bab ${widget.subBab['urutan']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                        padding: EdgeInsets.only(top: 8, bottom: 80),
                        showActions: false,
                      )
                    : (_contentMateriList.isEmpty && _aiGeneratedData == null && !_isLoadingAi)
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
          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: ColorUtils.slate100,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
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
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
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
                    SizedBox(width: 6),
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
                    SizedBox(width: 6),
                    Text('Kuis'),
                    if (quizzes.isNotEmpty) ...[
                      SizedBox(width: 4),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
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
                    SizedBox(width: 6),
                    Text('Referensi'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMateriTab(),
              _buildKuisTab(quizzes),
              _buildReferensiTab(references),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 1: MATERI ====================

  Widget _buildMateriTab() {
    final parsedContent = _parseMaterialContent();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // AI Materi Section
        if (parsedContent != null) ...[
          // Ringkasan Card
          if (parsedContent['ringkasan'] != null)
            _buildSectionCard(
              icon: Icons.summarize_rounded,
              iconColor: Color(0xFF8B5CF6),
              title: 'Ringkasan',
              child: Text(
                parsedContent['ringkasan'] ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),

          // Poin Utama Card
          if (parsedContent['poin_utama'] is List) ...[
            SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.lightbulb_rounded,
              iconColor: Color(0xFFF59E0B),
              title: 'Poin Utama',
              child: Column(
                children: (parsedContent['poin_utama'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          entry.key < (parsedContent['poin_utama'] as List).length - 1
                              ? 10
                              : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: TextStyle(
                              color: ColorUtils.slate700,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Cara Mengajar Card
          if (parsedContent['cara_mengajar'] != null) ...[
            SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.school_rounded,
              iconColor: _getPrimaryColor(),
              title: 'Cara Mengajar',
              child: Text(
                parsedContent['cara_mengajar'] ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ] else if (_aiGeneratedData != null) ...[
          // Fallback: raw material_content as text
          _buildSectionCard(
            icon: Icons.auto_awesome,
            iconColor: Colors.orange,
            title: 'Materi AI',
            child: Text(
              _stripHtml(
                  _aiGeneratedData!['material_content']?.toString() ?? ''),
              style: TextStyle(
                color: ColorUtils.slate700,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],

        // AI Info Badge
        if (_aiGeneratedData != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _getPrimaryColor().withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 16,
                    color: _getPrimaryColor().withValues(alpha: 0.6)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dibuat oleh AI  •  ${_aiGeneratedData!['ai_model_used'] ?? 'Claude'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _navigateToAiResult,
                  child: Text(
                    'Regenerate',
                    style: TextStyle(
                      fontSize: 11,
                      color: _getPrimaryColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Regular content from main backend
        if (_contentMateriList.isNotEmpty) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.article_rounded,
                    color: ColorUtils.slate600, size: 16),
              ),
              SizedBox(width: 8),
              Text(
                'Konten Manual',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._contentMateriList.asMap().entries.map((entry) {
            final index = entry.key;
            final content = entry.value;
            final cardColor = ColorUtils.getColorForIndex(index);

            return Container(
              margin: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content['judul_konten'] ??
                                content['title'] ??
                                'Judul Konten',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            content['isi_konten'] ??
                                content['description'] ??
                                '',
                            style: TextStyle(
                              color: ColorUtils.slate600,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ==================== TAB 2: KUIS ====================

  Widget _buildKuisTab(List<Map<String, dynamic>> quizzes) {
    if (quizzes.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.quiz_rounded,
        title: 'Belum Ada Kuis',
        subtitle: 'Generate materi AI untuk mendapatkan kuis otomatis.',
      );
    }

    // Separate MC and essay
    final mcQuizzes =
        quizzes.where((q) => q['question_type'] == 'multiple_choice').toList();
    final essayQuizzes =
        quizzes.where((q) => q['question_type'] == 'essay').toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Stats row
        _buildQuizStats(quizzes),
        SizedBox(height: 16),

        // Pilihan Ganda
        if (mcQuizzes.isNotEmpty) ...[
          _buildSubSectionHeader(
            icon: Icons.check_circle_outline_rounded,
            title: 'Pilihan Ganda',
            count: mcQuizzes.length,
            color: _getPrimaryColor(),
          ),
          SizedBox(height: 10),
          ...mcQuizzes.asMap().entries.map((entry) =>
              _buildMcQuizCard(entry.key, entry.value, mcQuizzes.length)),
        ],

        // Essay
        if (essayQuizzes.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildSubSectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'Essay',
            count: essayQuizzes.length,
            color: Color(0xFF8B5CF6),
          ),
          SizedBox(height: 10),
          ...essayQuizzes.asMap().entries
              .map((entry) => _buildEssayQuizCard(entry.key, entry.value)),
        ],
      ],
    );
  }

  Widget _buildQuizStats(List<Map<String, dynamic>> quizzes) {
    final easy =
        quizzes.where((q) => q['difficulty'] == 'easy').length;
    final medium =
        quizzes.where((q) => q['difficulty'] == 'medium').length;
    final hard =
        quizzes.where((q) => q['difficulty'] == 'hard').length;
    final mc =
        quizzes.where((q) => q['question_type'] == 'multiple_choice').length;
    final essay = quizzes.where((q) => q['question_type'] == 'essay').length;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPrimaryColor().withValues(alpha: 0.08),
            _getPrimaryColor().withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _getPrimaryColor().withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _buildStatItem('Total', '${quizzes.length}', _getPrimaryColor()),
          _buildStatDivider(),
          _buildStatItem('PG', '$mc', Color(0xFF2563EB)),
          _buildStatDivider(),
          _buildStatItem('Essay', '$essay', Color(0xFF8B5CF6)),
          _buildStatDivider(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDiffDot(Colors.green, easy),
                SizedBox(width: 6),
                _buildDiffDot(Colors.orange, medium),
                SizedBox(width: 6),
                _buildDiffDot(Colors.red, hard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: ColorUtils.slate200,
    );
  }

  Widget _buildDiffDot(Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
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
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
        SizedBox(width: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
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

  Widget _buildMcQuizCard(
      int index, Map<String, dynamic> quiz, int totalMc) {
    final difficulty = quiz['difficulty']?.toString().toLowerCase() ?? '';
    final diffConfig = _getDifficultyConfig(difficulty);
    final options = quiz['options'] as List? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.03),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _getPrimaryColor(),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pertanyaan ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffConfig.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: diffConfig.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    diffConfig.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: diffConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Question text
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate900,
                height: 1.5,
              ),
            ),
          ),
          // Options
          ...options.map((opt) {
            final option = opt as Map<String, dynamic>;
            final isCorrect = option['is_correct'] == true;
            return Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Color(0xFF10B981).withValues(alpha: 0.08)
                    : ColorUtils.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect
                      ? Color(0xFF10B981).withValues(alpha: 0.3)
                      : ColorUtils.slate200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Color(0xFF10B981).withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCorrect
                            ? Color(0xFF10B981)
                            : ColorUtils.slate300,
                      ),
                    ),
                    child: Center(
                      child: isCorrect
                          ? Icon(Icons.check_rounded,
                              size: 14, color: Color(0xFF10B981))
                          : Text(
                              option['label'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option['text'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isCorrect ? FontWeight.w600 : FontWeight.w400,
                        color: isCorrect
                            ? Color(0xFF059669)
                            : ColorUtils.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Explanation
          if (quiz['explanation'] != null &&
              quiz['explanation'].toString().isNotEmpty) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 4, 14, 14),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Color(0xFF3B82F6).withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF3B82F6).withValues(alpha: 0.7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEssayQuizCard(int index, Map<String, dynamic> quiz) {
    final difficulty = quiz['difficulty']?.toString().toLowerCase() ?? '';
    final diffConfig = _getDifficultyConfig(difficulty);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: Color(0xFF8B5CF6).withValues(alpha: 0.03),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8B5CF6),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Essay ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffConfig.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: diffConfig.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    diffConfig.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: diffConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Question
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate900,
                height: 1.5,
              ),
            ),
          ),
          // Answer key
          if (quiz['correct_answer'] != null) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF10B981).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key_rounded,
                          size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Kunci Jawaban',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    quiz['correct_answer'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: ColorUtils.slate700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Explanation / Penilaian
          if (quiz['explanation'] != null &&
              quiz['explanation'].toString().isNotEmpty) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF8B5CF6).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Color(0xFF8B5CF6).withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.grading_rounded,
                      size: 14,
                      color: Color(0xFF8B5CF6).withValues(alpha: 0.7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: 6),
        ],
      ),
    );
  }

  // ==================== TAB 3: REFERENSI ====================

  Widget _buildReferensiTab(List<Map<String, dynamic>> references) {
    if (references.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.menu_book_rounded,
        title: 'Belum Ada Referensi',
        subtitle: 'Generate materi AI untuk mendapatkan referensi otomatis.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: references.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ref = references[index];
        final refType = ref['type']?.toString() ?? '';
        final typeConfig = _getReferenceTypeConfig(refType);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type badge
              Container(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.04),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: typeConfig.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Icon(typeConfig.icon, size: 15, color: typeConfig.color),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeConfig.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeConfig.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: typeConfig.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Text(
                  ref['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                    fontSize: 15,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  _stripHtml(ref['content'] ?? ''),
                  style: TextStyle(
                    color: ColorUtils.slate600,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SHARED HELPERS ====================

  void _navigateToAiResult() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MateriAiResultScreen(
          teacherId: widget.teacherId,
          subjectId: widget.subjectId,
          chapterId: widget.bab['id'].toString(),
          subChapterId: widget.subBab['id'].toString(),
          title: widget.subBab['judul_sub_bab'] ?? 'Materi Pembelajaran',
        ),
      ),
    ).then((_) {
      // Reload AI content when returning
      _loadAiContent();
    });
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.04),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: ColorUtils.slate400),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate500,
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: _navigateToAiResult,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _getPrimaryColor(),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Generate AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Color color, String label}) _getDifficultyConfig(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return (color: Color(0xFF10B981), label: 'Mudah');
      case 'medium':
        return (color: Color(0xFFF59E0B), label: 'Sedang');
      case 'hard':
        return (color: Color(0xFFEF4444), label: 'Sulit');
      default:
        return (color: ColorUtils.slate500, label: difficulty.toUpperCase());
    }
  }

  ({Color color, String label, IconData icon}) _getReferenceTypeConfig(
      String type) {
    switch (type) {
      case 'concept_deep_dive':
        return (
          color: Color(0xFF3B82F6),
          label: 'Pendalaman Konsep',
          icon: Icons.psychology_rounded
        );
      case 'real_world_example':
        return (
          color: Color(0xFF10B981),
          label: 'Contoh Nyata',
          icon: Icons.public_rounded
        );
      case 'common_misconception':
        return (
          color: Color(0xFFF59E0B),
          label: 'Miskonsepsi Umum',
          icon: Icons.warning_amber_rounded
        );
      case 'teaching_tip':
        return (
          color: Color(0xFF8B5CF6),
          label: 'Tips Mengajar',
          icon: Icons.tips_and_updates_rounded
        );
      default:
        return (
          color: Color(0xFF6366F1),
          label: type.replaceAll('_', ' ').toUpperCase(),
          icon: Icons.bookmark_rounded
        );
    }
  }
}

