// AI-generated teaching material result screen.
// Like `pages/teacher/Material/AiResult.vue` in a Vue app.
//
// Displays AI-generated teaching materials organized in tabs (ringkasan,
// materi lengkap, latihan soal). Supports regeneration with custom prompts
// and uses a polling mechanism for async AI processing.
// In Laravel terms, this is like an AI job result viewer with polling
// (similar to checking a Laravel Queue job status repeatedly).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/loading_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_ai_error_view.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_ai_header.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_ai_polling_view.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_quiz_tab.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_reference_tab.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_section_card.dart';

/// Displays AI-generated teaching materials with tabbed content and
/// regeneration capability.
///
/// Props (like Vue props):
/// - [teacherId], [subjectId], [chapterId] -- context for AI generation
/// - [subChapterId] -- optional sub-chapter filter
/// - [title] -- display title for the material
class MaterialAiResultScreen extends StatefulWidget {
  final String teacherId;
  final String subjectId;
  final String chapterId;
  final String? subChapterId;
  final String title;

  const MaterialAiResultScreen({
    super.key,
    required this.teacherId,
    required this.subjectId,
    required this.chapterId,
    this.subChapterId,
    required this.title,
  });

  @override
  MaterialAiResultScreenState createState() => MaterialAiResultScreenState();
}

/// State for [MaterialAiResultScreen].
///
/// Like a Vue component with `data() { return { isLoading, aiData, isPolling, ... } }`.
/// Uses `SingleTickerProviderStateMixin` for the tab animation controller.
///
/// Key state:
/// - [_aiData] -- the AI-generated content (summary, full material, exercises)
/// - [_isPolling] / [_pollingStatus] -- tracks async AI job progress
/// - [_isRegenerating] -- whether a regeneration request is in progress
/// - [_tabController] -- manages the 3-tab layout (like Vue `<el-tabs>`)
class MaterialAiResultScreenState extends State<MaterialAiResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isRegenerating = false;
  bool _isPolling = false;
  String _pollingStatus = '';
  String? _pollingError;
  String? _materialId;
  Map<String, dynamic>? _aiData;
  final TextEditingController _promptController = TextEditingController();

  /// Like Vue's `mounted()` -- sets up the tab controller and starts AI generation.
  /// The polling view is shown immediately while the AI processes.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Show AI polling view immediately (not blue LoadingScreen)
    _isPolling = true;
    _pollingStatus = 'AI sedang memproses materi (percobaan 1)...';
    _generateMaterial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
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

  Future<String?> _getToken() async {
    final prefs = PreferencesService();
    return prefs.getString('token');
  }

  /// Triggers AI material generation and starts polling for results.
  /// Like calling `axios.post('/api/ai/generate-material')` then polling
  /// the job status endpoint. Similar to dispatching a Laravel Queue job
  /// and checking `Job::find($id)->status` periodically.
  Future<void> _generateMaterial({String prompt = ''}) async {
    setState(() {
      if (_aiData != null) {
        _isRegenerating = true;
      } else {
        _isLoading = true;
      }
      _pollingError = null;
    });

    try {
      final payload = <String, dynamic>{
        'teacher_id': widget.teacherId,
        'subject_id': widget.subjectId,
        'chapter_id': widget.chapterId,
      };

      if (widget.subChapterId != null) {
        payload['sub_chapter_id'] = widget.subChapterId!;
      }

      if (prompt.isNotEmpty) {
        payload['prompt'] = prompt;
      }

      final response = await getIt<ApiSubjectService>().generateMaterialRaw(
        payload,
      );

      if (!mounted) return;

      AppLogger.debug(
        'material',
        'Generate Material Response: ${response.statusCode}',
      );
      AppLogger.debug('material', 'Body: ${response.data}');

      // Dio auto-decodes JSON, so response.data is already a Map/List
      final resultBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 202) {
        // Async mode - start polling
        final pollUrl =
            (resultBody['poll_url'] ??
                    resultBody['polling_url'] ??
                    resultBody['status_url'])
                as String?;
        final jobId =
            (resultBody['job_id'] ??
                    resultBody['jobId'] ??
                    resultBody['id'] ??
                    resultBody['data']?['id'] ??
                    resultBody['data']?['job_id'])
                as String?;

        AppLogger.debug(
          'material',
          'Job Queued: $jobId | Polling at: $pollUrl',
        );

        setState(() {
          _isPolling = true;
          _isLoading = true;
          _isRegenerating = false;
          _pollingStatus = 'AI sedang menyusun materi...';
        });

        await _startPolling(jobId: jobId, pollUrl: pollUrl);
        return;
      }

      if (response.statusCode == 429) {
        final message =
            resultBody['message'] ??
            'Batas pembuatan materi AI harian/bulanan telah tercapai.';
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isRegenerating = false;
            _pollingError = message;
          });
        }
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = resultBody['data'] ?? resultBody;
        _applyResult(data, cached: resultBody['cached'] == true);
        return;
      }

      // Other errors
      throw Exception(resultBody['message'] ?? AppLocalizations.failedToGenerateMaterial.tr);
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('material', e);

      setState(() {
        _isLoading = false;
        _isRegenerating = false;
        _isPolling = false;
        _pollingError = ErrorUtils.getFriendlyMessage(e);
      });
    }
  }

  Future<void> _startPolling({String? jobId, String? pollUrl}) async {
    if (jobId == null && pollUrl == null) {
      if (mounted) {
        setState(() {
          _isPolling = false;
          _isLoading = false;
          _pollingError = 'Tidak ada informasi polling dari server.';
        });
      }
      return;
    }

    final token = await _getToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _isPolling = false;
          _isLoading = false;
          _pollingError = 'Token autentikasi tidak ditemukan.';
        });
      }
      return;
    }

    final pollPath = pollUrl ?? '/api/ai-jobs/$jobId';
    final fullUrl = 'https://edu-ai-api.kamillabs.com$pollPath';

    AppLogger.debug('material', 'Starting polling at: $fullUrl');

    int attempts = 0;
    const maxAttempts = 60; // 5 minutes max (60 * 5s)

    while (attempts < maxAttempts) {
      if (!mounted) return;
      attempts++;

      try {
        AppLogger.debug('material', 'Poll attempt #$attempts');

        // Use the AI service's pollAiJob which returns a Dio Response
        // (with validateStatus: (_) => true, so it won't throw on non-2xx)
        final jobIdForPoll = jobId ?? fullUrl.split('/').last;
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobIdForPoll,
          token,
        );

        if (!mounted) return;

        AppLogger.debug('material', 'Poll status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final resultBody = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};
          final jobData = resultBody['data'] ?? resultBody;
          final status = jobData['status'] ?? resultBody['status'];

          if (status == 'completed' || status == 'success') {
            final materialData =
                jobData['result'] ??
                jobData['data'] ??
                resultBody['result'] ??
                resultBody;
            _applyResult(materialData);
            return;
          } else if (status == 'failed' || status == 'error') {
            setState(() {
              _isPolling = false;
              _isLoading = false;
              _pollingError =
                  jobData['error_message'] ??
                  'AI gagal memproses materi. Silakan coba lagi.';
            });
            return;
          }

          // Still processing
          if (mounted) {
            setState(() {
              _pollingStatus = status == 'processing'
                  ? 'AI sedang memproses materi (percobaan $attempts)...'
                  : 'Menunggu antrian AI (percobaan $attempts)...';
            });
          }
        }
      } catch (e) {
        AppLogger.error('material', e);
      }

      // Wait 5 seconds before next poll
      await Future.delayed(const Duration(seconds: 5));
    }

    // Timeout
    if (mounted) {
      setState(() {
        _isPolling = false;
        _isLoading = false;
        _pollingError =
            'Proses AI memakan waktu terlalu lama. Silakan coba lagi nanti.';
      });
    }
  }

  void _applyResult(Map<String, dynamic> data, {bool cached = false}) {
    if (!mounted) return;

    setState(() {
      _aiData = data;
      _materialId = data['id']?.toString();
      _isLoading = false;
      _isRegenerating = false;
      _isPolling = false;
      _pollingError = null;
    });

    if (cached && mounted) {
      SnackBarUtils.showInfo(context, 'Materi dimuat dari cache.');
    }
  }

  Future<void> _regenerateQuiz() async {
    if (_materialId == null) return;

    setState(() => _isRegenerating = true);
    try {
      final response = await getIt<ApiSubjectService>().regenerateQuiz(
        _materialId!,
      );

      if (!mounted) return;

      final newQuizzes = response['data'] as List?;
      if (newQuizzes != null && _aiData != null) {
        setState(() {
          final existing = List.from(_aiData!['quizzes'] ?? []);
          existing.addAll(newQuizzes);
          _aiData!['quizzes'] = existing;
          _isRegenerating = false;
        });

        SnackBarUtils.showInfo(
          context,
          'Kuis baru ditambahkan (sisa regenerasi: ${response['remaining'] ?? '?'})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      SnackBarUtils.showInfo(
        context,
        '${AppLocalizations.failedToGenerate.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> _regenerateReferences() async {
    if (_materialId == null) return;

    setState(() => _isRegenerating = true);
    try {
      final response = await getIt<ApiSubjectService>().regenerateReferences(
        _materialId!,
      );

      if (!mounted) return;

      final newRefs = response['data'] as List?;
      if (newRefs != null && _aiData != null) {
        setState(() {
          _aiData!['references'] = newRefs;
          _isRegenerating = false;
        });

        SnackBarUtils.showInfo(
          context,
          'Referensi diperbarui (sisa regenerasi: ${response['remaining'] ?? '?'})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      SnackBarUtils.showInfo(
        context,
        '${AppLocalizations.failedToGenerate.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  void _showRegenerateDialog() {
    _promptController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: _getPrimaryColor()),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Generate Ulang AI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistem akan menyusun ulang materi berdasarkan Bab/Sub-Bab. Anda dapat menambahkan instruksi spesifik di bawah.',
                  style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Topik / Judul',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Instruksi Tambahan (Opsional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Contoh: Buat penjelasan lebih interaktif dan tambahkan kuis yang sedikit menantang...',
                    hintStyle: TextStyle(
                      color: ColorUtils.slate400,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: ColorUtils.slate300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: _getPrimaryColor()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                AppNavigator.pop(context);
                _generateMaterial(prompt: _promptController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: Text('Generate'),
            ),
          ],
        );
      },
    );
  }

  void _showRegenOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regenerasi Konten',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Pilih bagian yang ingin di-generate ulang oleh AI',
                  style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: _getPrimaryColor(),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Generate Ulang Semua',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Buat ulang materi, kuis, dan referensi'),
                  onTap: () {
                    AppNavigator.pop(context);
                    _showRegenerateDialog();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Tambah Kuis Baru',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Menambahkan kuis baru ke daftar yang sudah ada',
                  ),
                  onTap: () {
                    AppNavigator.pop(context);
                    _regenerateQuiz();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Ganti Referensi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Mengganti seluruh referensi dengan yang baru',
                  ),
                  onTap: () {
                    AppNavigator.pop(context);
                    _regenerateReferences();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Parse material_content which might be JSON string or plain text/HTML
  Map<String, String> _parseMaterialContent() {
    final raw = _aiData?['material_content'];
    if (raw == null) return {'Konten': 'Konten tidak tersedia.'};

    final rawStr = raw.toString().trim();

    // Try parsing as JSON object
    if (rawStr.startsWith('{')) {
      try {
        final parsed = json.decode(rawStr);
        if (parsed is Map) {
          final result = <String, String>{};
          for (final entry in parsed.entries) {
            final key = _formatSectionTitle(entry.key.toString());
            var value = entry.value.toString();
            // Replace literal \n with actual newlines
            value = value.replaceAll(r'\n', '\n');
            result[key] = value.trim();
          }
          return result;
        }
      } catch (_) {}
    }

    // Fallback: treat as plain text/HTML
    return {'Ringkasan': _stripHtml(rawStr)};
  }

  String _formatSectionTitle(String key) {
    // Convert snake_case/camelCase keys to readable titles
    final map = {
      'ringkasan': 'Ringkasan',
      'summary': 'Ringkasan',
      'penjelasan': 'Penjelasan',
      'explanation': 'Penjelasan',
      'materi': 'Materi',
      'content': 'Konten',
      'tujuan_pembelajaran': 'Tujuan Pembelajaran',
      'learning_objectives': 'Tujuan Pembelajaran',
      'poin_penting': 'Poin Penting',
      'key_points': 'Poin Penting',
      'contoh': 'Contoh',
      'examples': 'Contoh',
      'kesimpulan': 'Kesimpulan',
      'conclusion': 'Kesimpulan',
      'latihan': 'Latihan',
      'exercises': 'Latihan',
      'catatan': 'Catatan',
      'notes': 'Catatan',
    };

    final lower = key.toLowerCase();
    if (map.containsKey(lower)) return map[lower]!;

    // Convert snake_case to Title Case
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          MaterialAiHeader(
            title: widget.title,
            gradient: _getCardGradient(),
            primaryColor: _getPrimaryColor(),
            isLoading: _isLoading,
            isRegenerating: _isRegenerating,
            hasData: _aiData != null,
            onRegenOptions: _showRegenOptions,
          ),
          Expanded(
            child: _pollingError != null
                ? MaterialAiErrorView(
                    errorMessage: _pollingError!,
                    primaryColor: _getPrimaryColor(),
                    onRetry: _generateMaterial,
                  )
                : _isPolling
                ? MaterialAiPollingView(
                    pollingStatus: _pollingStatus,
                    primaryColor: _getPrimaryColor(),
                  )
                : _isLoading
                ? LoadingScreen(
                    message: languageProvider.getTranslatedText({
                      'en': 'AI is preparing material for ${widget.title}...',
                      'id':
                          'AI sedang menyusun materi untuk ${widget.title}...',
                    }),
                  )
                : _aiData == null
                ? Center(
                    child: Text(
                      AppLocalizations.failedToLoadMaterial.tr,
                    ),
                  )
                : Column(
                    children: [
                      // Tab bar
                      Container(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: _getPrimaryColor(),
                          unselectedLabelColor: ColorUtils.slate400,
                          indicatorColor: _getPrimaryColor(),
                          indicatorWeight: 3,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          tabs: [
                            Tab(
                              icon: Icon(Icons.article_outlined, size: 20),
                              text: 'Materi',
                            ),
                            Tab(
                              icon: Icon(Icons.quiz_outlined, size: 20),
                              text: 'Kuis',
                            ),
                            Tab(
                              icon: Icon(Icons.menu_book_outlined, size: 20),
                              text: 'Referensi',
                            ),
                          ],
                        ),
                      ),
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Material tab — inline (12 lines, below extract threshold)
                            ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: _parseMaterialContent().length,
                              itemBuilder: (context, index) {
                                final sections = _parseMaterialContent();
                                final title = sections.keys.elementAt(index);
                                final content = sections.values.elementAt(index);
                                return MaterialSectionCard(
                                  title: title,
                                  content: content,
                                  index: index,
                                  primaryColor: _getPrimaryColor(),
                                );
                              },
                            ),
                            MaterialQuizTab(
                              quizzes: _aiData?['quizzes'] as List? ?? [],
                              materialId: _materialId,
                              isRegenerating: _isRegenerating,
                              primaryColor: _getPrimaryColor(),
                              onAddQuiz: _regenerateQuiz,
                            ),
                            MaterialReferenceTab(
                              refs: _aiData?['references'] as List? ?? [],
                              materialId: _materialId,
                              isRegenerating: _isRegenerating,
                              primaryColor: _getPrimaryColor(),
                              onRegenRefs: _regenerateReferences,
                              stripHtml: _stripHtml,
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
}
