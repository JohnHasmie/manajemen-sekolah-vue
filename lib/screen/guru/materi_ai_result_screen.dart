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

class MateriAiResultScreenState extends State<MateriAiResultScreen> {
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
    _generateMateri();
  }

  @override
  void dispose() {
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
                            : SingleChildScrollView(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Material content
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: ColorUtils.slate200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: ColorUtils.slate800,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Divider(),
                                          Text(
                                            _stripHtml(
                                              _aiData!['material_content'] ??
                                                  '<p>Konten tidak tersedia.</p>',
                                            ),
                                            style: TextStyle(
                                              height: 1.5,
                                              color: ColorUtils.slate700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Quizzes
                                    if ((_aiData!['quizzes'] as List?)
                                            ?.isNotEmpty ==
                                        true) ...[
                                      SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.quiz_rounded,
                                                  color: _getPrimaryColor()),
                                              SizedBox(width: 8),
                                              Text(
                                                'Kuis & Evaluasi',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: ColorUtils.slate800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_materialId != null)
                                            TextButton.icon(
                                              onPressed: _isRegenerating
                                                  ? null
                                                  : _regenerateQuiz,
                                              icon: Icon(Icons.add,
                                                  size: 16,
                                                  color: _getPrimaryColor()),
                                              label: Text(
                                                'Tambah Kuis',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _getPrimaryColor(),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      ...(_aiData!['quizzes'] as List)
                                          .asMap()
                                          .entries
                                          .map((entry) => _buildQuizCard(
                                              entry.key,
                                              Map<String, dynamic>.from(
                                                  entry.value))),
                                    ],

                                    // References
                                    if ((_aiData!['references'] as List?)
                                            ?.isNotEmpty ==
                                        true) ...[
                                      SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.menu_book_rounded,
                                                  color: _getPrimaryColor()),
                                              SizedBox(width: 8),
                                              Text(
                                                'Referensi Pembelajaran',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: ColorUtils.slate800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_materialId != null)
                                            TextButton.icon(
                                              onPressed: _isRegenerating
                                                  ? null
                                                  : _regenerateReferences,
                                              icon: Icon(Icons.refresh,
                                                  size: 16,
                                                  color: Colors.blue),
                                              label: Text(
                                                'Ganti',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      ...(_aiData!['references'] as List).map(
                                          (ref) => _buildReferenceCard(
                                              Map<String, dynamic>.from(ref))),
                                    ],

                                    SizedBox(height: 16),
                                  ],
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
