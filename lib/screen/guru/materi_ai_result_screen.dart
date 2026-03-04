import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';

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
  Map<String, dynamic>? _aiData;
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateMateri();
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

  Future<void> _generateMateri({String prompt = ''}) async {
    setState(() {
      if (_aiData != null) {
        _isRegenerating = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final payload = {
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

      final response = await ApiSubjectService.generateMaterial(payload);

      // Async or sync response handling based on documentation
      if (response['job_id'] != null) {
        // Just mock it for now or display a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Proses generate sedang berjalan di latar belakang (Job ID: ${response['job_id']})',
            ),
          ),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        _aiData = response['data'];
        _isLoading = false;
        _isRegenerating = false;
      });
    } catch (e) {
      // Tampilkan data contoh / mock data jika API gagal atau belum terkoneksi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Menggunakan data contoh (Mock Data) karena: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
          ),
        );
      }

      setState(() {
        _aiData = {
          "id": "mock-uuid-1234",
          "material_content":
              "<h2>Materi Aljabar Linear</h2><p>Aljabar linear adalah bidang studi matematika yang mempelajari sistem persamaan linear dan solusinya, vektor, serta transformasi linear. Konsep ini sangat penting dalam berbagai bidang ilmu, termasuk fisika, teknik, ilmu komputer, dan ekonomi.</p><h3>Konsep Utama</h3><ul><li>Vektor dan Ruang Vektor</li><li>Matriks dan Operasi Matriks</li><li>Sistem Persamaan Linear</li></ul>",
          "quizzes": [
            {
              "id": "quiz-uuid-1",
              "question": "Jika 2x + 3 = 11, berapakah nilai x?",
              "question_type": "multiple_choice",
              "options": ["A. x = 3", "B. x = 4", "C. x = 5", "D. x = 6"],
              "correct_answer": "B. x = 4",
              "explanation":
                  "Pindahkan 3 ke ruas kanan: 2x = 11 - 3, sehingga 2x = 8. Bagi kedua ruas dengan 2: x = 4.",
              "difficulty": "easy",
              "generation_batch": 1,
            },
            {
              "id": "quiz-uuid-2",
              "question":
                  "Jelaskan apa yang dimaksud dengan matriks identitas!",
              "question_type": "essay",
              "correct_answer":
                  "Matriks persegi yang elemen-elemen pada diagonal utamanya bernilai 1 dan elemen lainnya bernilai 0.",
              "explanation":
                  "Matriks identitas bertindak seperti angka 1 dalam perkalian bilangan biasa. Jika matriks A dikalikan dengan matriks identitas I, hasilnya adalah matriks A itu sendiri.",
              "difficulty": "medium",
              "generation_batch": 1,
            },
          ],
          "references": [
            {
              "id": "ref-uuid-1",
              "title": "Konsep Dasar Aljabar dan Persamaan",
              "content":
                  "<p>Untuk memahami aljabar, kita harus terbiasa dengan penggunaan huruf (variabel) untuk mewakili angka yang belum diketahui nilainya. Persamaan adalah kalimat matematika yang menyamakan dua ekspresi aljabar.</p>",
              "type": "concept_deep_dive",
              "generation_batch": 1,
            },
            {
              "id": "ref-uuid-2",
              "title": "Kesalahan Umum Pemula",
              "content":
                  "<p>Banyak siswa yang salah dalam mendistribusikan tanda negatif saat menyelesaikan persamaan. Ingatlah bahwa -(x + 3) sama dengan -x - 3, bukan -x + 3.</p>",
              "type": "common_misconception",
              "generation_batch": 1,
            },
          ],
        };
        _isLoading = false;
        _isRegenerating = false;
      });
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
              Icon(Icons.auto_awesome, color: ColorUtils.primary),
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
                      borderSide: BorderSide(color: ColorUtils.primary),
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
                backgroundColor: ColorUtils.primary,
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
          GestureDetector(
            onTap: _isRegenerating ? null : _showRegenerateDialog,
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
                  : Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
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
            child: _isLoading
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
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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

                        if ((_aiData!['quizzes'] as List?)?.isNotEmpty ==
                            true) ...[
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.quiz_rounded,
                                color: ColorUtils.primary,
                              ),
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
                          SizedBox(height: 12),
                          ...(_aiData!['quizzes'] as List).asMap().entries.map((
                            entry,
                          ) {
                            int idx = entry.key;
                            var quiz = entry.value;

                            // Menentukan warna badge kesulitan
                            Color diffColor = Colors.grey;
                            String difficulty =
                                quiz['difficulty']?.toString().toLowerCase() ??
                                '';
                            if (difficulty == 'easy')
                              diffColor = Colors.green;
                            else if (difficulty == 'medium')
                              diffColor = Colors.orange;
                            else if (difficulty == 'hard')
                              diffColor = Colors.red;

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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: ColorUtils.slate100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
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
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: diffColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: diffColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                ),
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
                                        (quiz['options'] as List)
                                            .isNotEmpty) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: ColorUtils.slate50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: (quiz['options'] as List).map((
                                            opt,
                                          ) {
                                            bool isTargetAnswer =
                                                opt.toString().trim() ==
                                                quiz['correct_answer']
                                                    ?.toString()
                                                    .trim();
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    isTargetAnswer
                                                        ? Icons.check_circle
                                                        : Icons
                                                              .radio_button_unchecked,
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
                                                            ? Colors
                                                                  .green
                                                                  .shade700
                                                            : ColorUtils
                                                                  .slate700,
                                                        fontWeight:
                                                            isTargetAnswer
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
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            Divider(
                                              color: Colors.green.shade200,
                                            ),
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
                          }),
                        ],

                        if ((_aiData!['references'] as List?)?.isNotEmpty ==
                            true) ...[
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: ColorUtils.primary,
                              ),
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
                          SizedBox(height: 12),
                          ...(_aiData!['references'] as List).map((ref) {
                            String refType =
                                ref['type']
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
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ColorUtils.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            refType,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: ColorUtils.primary,
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
                          }),
                        ],
                      ],
                    ),
                  ),
          ),
          if (!_isLoading && _aiData != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: Offset(0, -4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Implementasi API Save nanti
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Fitur simpan ke database akan segera hadir.',
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.save_rounded),
                label: Text(
                  'Simpan ke Database',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
