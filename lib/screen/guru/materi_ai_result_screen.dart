import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MateriAiResultScreen extends StatefulWidget {
  final String teacherId;
  final String subjectId;
  final String chapterId;
  final String? subChapterId;
  final String title;

  const MateriAiResultScreen({
    super.key,
    required this.teacherId,
    required this.subjectId,
    required this.chapterId,
    this.subChapterId,
    required this.title,
  });

  @override
  MateriAiResultScreenState createState() => MateriAiResultScreenState();
}

class MateriAiResultScreenState extends State<MateriAiResultScreen>
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Show AI polling view immediately (not blue LoadingScreen)
    _isPolling = true;
    _pollingStatus = 'AI sedang memproses materi (percobaan 1)...';
    _generateMateri();
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _generateMateri({String prompt = ''}) async {
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

      final response = await ApiSubjectService.generateMaterialRaw(payload);

      if (!mounted) return;

      if (kDebugMode) {
        print('📥 Generate Material Response: ${response.statusCode}');
        print('📥 Body: ${response.body}');
      }

      if (response.statusCode == 202) {
        // Async mode - start polling
        final resultBody = json.decode(response.body);
        final pollUrl = (resultBody['poll_url'] ??
                resultBody['polling_url'] ??
                resultBody['status_url'])
            as String?;
        final jobId = (resultBody['job_id'] ??
                resultBody['jobId'] ??
                resultBody['id'] ??
                resultBody['data']?['id'] ??
                resultBody['data']?['job_id'])
            as String?;

        if (kDebugMode) print('⏳ Job Queued: $jobId | Polling at: $pollUrl');

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
        final errorBody = json.decode(response.body);
        final message = errorBody['message'] ??
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
        final resultBody = json.decode(response.body);
        final data = resultBody['data'] ?? resultBody;
        _applyResult(data, cached: resultBody['cached'] == true);
        return;
      }

      // Other errors
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['message'] ?? 'Gagal generate materi');
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) print('❌ Generate error: $e');

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

    if (kDebugMode) print('🔄 Starting polling at: $fullUrl');

    int attempts = 0;
    const maxAttempts = 60; // 5 minutes max (60 * 5s)

    while (attempts < maxAttempts) {
      if (!mounted) return;
      attempts++;

      try {
        if (kDebugMode) print('🔄 Poll attempt #$attempts');

        final response = await http
            .get(
              Uri.parse(fullUrl),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (!mounted) return;

        if (kDebugMode) {
          print('📥 Poll status: ${response.statusCode}');
        }

        if (response.statusCode == 200) {
          final resultBody = json.decode(response.body);
          final jobData = resultBody['data'] ?? resultBody;
          final status = jobData['status'] ?? resultBody['status'];

          if (status == 'completed' || status == 'success') {
            final materialData = jobData['result'] ??
                jobData['data'] ??
                resultBody['result'] ??
                resultBody;
            _applyResult(materialData);
            return;
          } else if (status == 'failed' || status == 'error') {
            setState(() {
              _isPolling = false;
              _isLoading = false;
              _pollingError = jobData['error_message'] ??
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
        if (kDebugMode) print('⚠️ Poll error: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Materi dimuat dari cache.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _regenerateQuiz() async {
    if (_materialId == null) return;

    setState(() => _isRegenerating = true);
    try {
      final response =
          await ApiSubjectService.regenerateQuiz(_materialId!);

      if (!mounted) return;

      final newQuizzes = response['data'] as List?;
      if (newQuizzes != null && _aiData != null) {
        setState(() {
          final existing = List.from(_aiData!['quizzes'] ?? []);
          existing.addAll(newQuizzes);
          _aiData!['quizzes'] = existing;
          _isRegenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Kuis baru ditambahkan (sisa regenerasi: ${response['remaining'] ?? '?'})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Gagal regenerasi kuis: ${ErrorUtils.getFriendlyMessage(e)}')),
      );
    }
  }

  Future<void> _regenerateReferences() async {
    if (_materialId == null) return;

    setState(() => _isRegenerating = true);
    try {
      final response =
          await ApiSubjectService.regenerateReferences(_materialId!);

      if (!mounted) return;

      final newRefs = response['data'] as List?;
      if (newRefs != null && _aiData != null) {
        setState(() {
          _aiData!['references'] = newRefs;
          _isRegenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Referensi diperbarui (sisa regenerasi: ${response['remaining'] ?? '?'})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Gagal regenerasi referensi: ${ErrorUtils.getFriendlyMessage(e)}')),
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
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: _getPrimaryColor()),
              SizedBox(width: 8),
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
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(10),
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
                      SizedBox(height: 4),
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
                SizedBox(height: 16),
                Text(
                  'Instruksi Tambahan (Opsional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 8),
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.slate300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _getPrimaryColor()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateMateri(prompt: _promptController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
            padding: EdgeInsets.all(16),
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
                SizedBox(height: 4),
                Text(
                  'Pilih bagian yang ingin di-generate ulang oleh AI',
                  style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome,
                        color: _getPrimaryColor(), size: 20),
                  ),
                  title: Text('Generate Ulang Semua',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Buat ulang materi, kuis, dan referensi'),
                  onTap: () {
                    Navigator.pop(context);
                    _showRegenerateDialog();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.quiz_rounded, color: Colors.orange, size: 20),
                  ),
                  title: Text('Tambah Kuis Baru',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      Text('Menambahkan kuis baru ke daftar yang sudah ada'),
                  onTap: () {
                    Navigator.pop(context);
                    _regenerateQuiz();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: Colors.blue, size: 20),
                  ),
                  title: Text('Ganti Referensi',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      Text('Mengganti seluruh referensi dengan yang baru'),
                  onTap: () {
                    Navigator.pop(context);
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

  Widget _buildHeader() {
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
      child: Row(
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
                  'AI Generated Materi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (!_isLoading && _aiData != null)
            GestureDetector(
              onTap: _isRegenerating ? null : _showRegenOptions,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isRegenerating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPollingView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: _getPrimaryColor(),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              _pollingStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mohon tunggu, proses ini membutuhkan waktu beberapa saat...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
            SizedBox(height: 16),
            Text(
              'Gagal Generate Materi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _pollingError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ColorUtils.slate600,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _generateMateri(),
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(int idx, Map<String, dynamic> quiz) {
    Color diffColor = Colors.grey;
    String difficulty =
        quiz['difficulty']?.toString().toLowerCase() ?? '';
    if (difficulty == 'easy') {
      diffColor = Colors.green;
    } else if (difficulty == 'medium') {
      diffColor = Colors.orange;
    } else if (difficulty == 'hard') {
      diffColor = Colors.red;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pertanyaan ${idx + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate500,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quiz['question_type']
                                ?.toString()
                                .replaceAll('_', ' ')
                                .toUpperCase() ??
                            'KUIS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: diffColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        difficulty.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: diffColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: ColorUtils.slate800,
              ),
            ),
            SizedBox(height: 12),
            if (quiz['options'] != null &&
                (quiz['options'] as List).isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (quiz['options'] as List).map((opt) {
                    bool isTargetAnswer = opt.toString().trim() ==
                        quiz['correct_answer']?.toString().trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isTargetAnswer
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isTargetAnswer
                                ? Colors.green
                                : ColorUtils.slate400,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opt.toString(),
                              style: TextStyle(
                                color: isTargetAnswer
                                    ? Colors.green.shade700
                                    : ColorUtils.slate700,
                                fontWeight: isTargetAnswer
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunci Jawaban:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    quiz['correct_answer'] ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                  if (quiz['explanation'] != null) ...[
                    SizedBox(height: 8),
                    Divider(color: Colors.green.shade200),
                    SizedBox(height: 4),
                    Text(
                      'Penjelasan:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(Map<String, dynamic> ref) {
    String refType = ref['type']
            ?.toString()
            .replaceAll('_', ' ')
            .toUpperCase() ??
        'REFERENSI';

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    refType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getPrimaryColor(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              ref['title'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate800,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _stripHtml(ref['content'] ?? ''),
              style: TextStyle(
                color: ColorUtils.slate600,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTab() {
    final sections = _parseMaterialContent();
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final title = sections.keys.elementAt(index);
        final content = sections.values.elementAt(index);
        return _buildSectionCard(title, content, index);
      },
    );
  }

  Widget _buildSectionCard(String title, String content, int index) {
    final colors = [
      _getPrimaryColor(),
      Colors.orange,
      Colors.teal,
      Colors.purple,
      Colors.indigo,
      Colors.pink,
    ];
    final accentColor = colors[index % colors.length];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section content
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildFormattedContent(content),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    // Split into paragraphs and render
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paragraphs.length <= 1) {
      // Single paragraph - check for bullet-like lines
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length > 1 && lines.any((l) => l.trim().startsWith(RegExp(r'[-•\d]+[.)]?\s')))) {
        return _buildBulletList(lines);
      }
      return Text(
        content.replaceAll(r'\n', '\n'),
        style: TextStyle(
          fontSize: 14,
          color: ColorUtils.slate700,
          height: 1.6,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final paragraph = entry.value.trim();
        final lines = paragraph.split('\n').where((l) => l.trim().isNotEmpty).toList();

        // Check if this paragraph is a bullet list
        if (lines.length > 1 && lines.every((l) => l.trim().startsWith(RegExp(r'[-•\d]+[.)]?\s')))) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _buildBulletList(lines),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            paragraph,
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate700,
              height: 1.6,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBulletList(List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        // Check if it starts with a bullet or number
        final isBullet = trimmed.startsWith(RegExp(r'[-•]\s'));
        final isNumbered = trimmed.startsWith(RegExp(r'\d+[.)]\s'));

        String text = trimmed;
        if (isBullet) {
          text = trimmed.replaceFirst(RegExp(r'^[-•]\s*'), '');
        } else if (isNumbered) {
          text = trimmed.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
        }

        if (isBullet || isNumbered) {
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(top: 7, right: 10, left: 4),
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.slate700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            trimmed,
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate700,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuizTab() {
    final quizzes = _aiData?['quizzes'] as List? ?? [];
    if (quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 48, color: ColorUtils.slate300),
            SizedBox(height: 12),
            Text(
              'Belum ada kuis',
              style: TextStyle(color: ColorUtils.slate500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_materialId != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${quizzes.length} Pertanyaan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isRegenerating ? null : _regenerateQuiz,
                  icon: Icon(Icons.add, size: 16, color: _getPrimaryColor()),
                  label: Text(
                    'Tambah Kuis',
                    style: TextStyle(fontSize: 12, color: _getPrimaryColor()),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              return _buildQuizCard(
                index,
                Map<String, dynamic>.from(quizzes[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceTab() {
    final refs = _aiData?['references'] as List? ?? [];
    if (refs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: ColorUtils.slate300),
            SizedBox(height: 12),
            Text(
              'Belum ada referensi',
              style: TextStyle(color: ColorUtils.slate500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_materialId != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${refs.length} Referensi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isRegenerating ? null : _regenerateReferences,
                  icon: Icon(Icons.refresh, size: 16, color: Colors.blue),
                  label: Text(
                    'Ganti',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: refs.length,
            itemBuilder: (context, index) {
              return _buildReferenceCard(
                Map<String, dynamic>.from(refs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _pollingError != null
                ? _buildErrorView()
                : _isPolling
                    ? _buildPollingView()
                    : _isLoading
                        ? LoadingScreen(
                            message:
                                'AI sedang menyusun materi untuk ${widget.title}...',
                          )
                        : _aiData == null
                            ? Center(child: Text('Gagal memuat materi.'))
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
                                        _buildMaterialTab(),
                                        _buildQuizTab(),
                                        _buildReferenceTab(),
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
