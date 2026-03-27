// rpp_service.dart - AI-powered lesson plan (RPP) generation via OpenAI API.
// Like a Laravel Service class that calls an external AI API to auto-generate
// lesson plans. Similar to how you might use OpenAI in a Laravel app via
// `Http::withToken($apiKey)->post('https://api.openai.com/...')`.
// RPP = Rencana Pelaksanaan Pembelajaran (Lesson Plan, Indonesian curriculum).

import 'package:dio/dio.dart';

/// Service that generates RPP (lesson plans) using the OpenAI GPT API.
/// Like a Laravel service class (e.g., `App\Services\AILessonPlanService`) that:
/// 1. Builds a structured prompt from teacher input
/// 2. Calls the OpenAI chat completions endpoint
/// 3. Parses the AI response into a structured RPP map
/// 4. Falls back to a template if the AI call fails
///
/// The generated RPP follows Indonesia's Kurikulum 2013 (K13) format with
/// three main components as per Mendikbud Circular No. 14/2019:
/// A. Learning Objectives, B. Learning Activities, C. Assessment.
///
/// Note: This is an instance class (not static) unlike the Excel services,
/// because it could potentially hold state for ongoing generation sessions.
class LessonPlanService {
  /// Create a fallback/template RPP when the AI API call fails.
  /// Like a Laravel factory default: provides placeholder content so the
  /// user gets a skeleton RPP they can edit manually instead of nothing.
  /// [customContent] - optional AI-generated content to use for objectives.
  Map<String, dynamic> _createFallbackLessonPlan({
    required String title,
    required String subjectId,
    required String subjectName,
    List<Map<String, dynamic>> materialContent = const [],
    String customContent = '',
  }) {
    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'learning_objectives': customContent.isNotEmpty
          ? customContent
          : 'Tujuan pembelajaran belum tersedia.',
      'preliminary_activities': 'Kegiatan pendahuluan belum tersedia.',
      'core_activities': 'Kegiatan inti belum tersedia.',
      'closing_activities': 'Kegiatan penutup belum tersedia.',
      'assessment': 'Penilaian belum tersedia.',
      'education_unit': 'SD/MI',
      'class_semester': '1 / 1',
      'theme': title,
      'sub_theme': 'Sub Tema 1',
      'learning_sequence': '1',
      'time_allocation': '1 Hari',
      'preliminary_time': '15',
      'core_time': '140',
      'closing_time': '15',
      'created_at': DateTime.now().toIso8601String(),
      'is_ai_generated': false,
      'material_content': materialContent,
    };
  }

  /// OpenAI Chat Completions API endpoint.
  /// Like setting `OPENAI_API_URL` in Laravel's `.env` file.
  static const String baseUrl = "https://api.openai.com/v1/chat/completions";
  // Replace with your OpenAI API key
  /// OpenAI API key. In production, this should come from a secure source
  /// (like Laravel's `config('services.openai.key')` from `.env`).
  static const String apiKey = "your-openai-api-key";

  /// Generate a complete RPP using the OpenAI GPT-3.5-turbo model.
  /// Like a Laravel controller action that calls an AI service:
  /// `$rpp = $aiService->generateLessonPlan($request->validated());`
  ///
  /// [title] - lesson plan title. [subjectId]/[subjectName] - subject info.
  /// [materialContent] - list of material/content maps to include.
  /// [learningObjectives] - optional custom learning objectives.
  /// [toolsMedia] - optional tools/media description.
  ///
  /// Returns a structured RPP map. Falls back to [_createFallbackLessonPlan] on any error
  /// (network failure, API error, parsing error) -- never throws.
  Future<Map<String, dynamic>> generateLessonPlan({
    required String title,
    required String subjectId,
    required String subjectName,
    required List<Map<String, dynamic>> materialContent,
    String learningObjectives = '',
    String toolsMedia = '',
  }) async {
    try {
      // Prepare prompt for AI
      final prompt = _buildPrompt(
        title: title,
        subjectName: subjectName,
        materialContent: materialContent,
        learningObjectives: learningObjectives,
        toolsMedia: toolsMedia,
      );

      // Call OpenAI API via Dio
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ));

      final response = await dio.post(
        '',
        data: {
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Anda adalah ahli pembuatan RPP (Rencana Pelaksanaan Pembelajaran) yang profesional. Buatlah RPP yang lengkap dan terstruktur berdasarkan materi yang diberikan.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 3000,
        },
      );

      // Dio auto-decodes JSON; response.data is already a Map
      final data = response.data;
      final content = data['choices'][0]['message']['content'];

      // Parse AI response into RPP structure
      return _parseAIResponse(
        content: content,
        title: title,
        subjectId: subjectId,
        subjectName: subjectName,
      );
    } catch (e) {
      // Fallback: Create a simple RPP if AI fails
      return _createFallbackLessonPlan(
        title: title,
        subjectId: subjectId,
        subjectName: subjectName,
        materialContent: materialContent,
      );
    }
  }

  /// Build the prompt string for the OpenAI API call.
  /// Constructs a detailed example-based prompt following the K13 RPP format.
  /// Like a Laravel Blade template that generates the AI instruction text.
  /// The prompt includes a complete example RPP and then asks the AI to
  /// create a new one for the given subject and materials.
  String _buildPrompt({
    required String title,
    required String subjectName,
    required List<Map<String, dynamic>> materialContent,
    required String learningObjectives,
    required String toolsMedia,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
      'Buatkan RPP (Rencana Pelaksanaan Pembelajaran) format 1 lembar dengan 3 komponen utama seperti contoh berikut:',
    );
    buffer.writeln();
    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln('KURIKULUM 2013 (3 KOMPONEN)');
    buffer.writeln('(Sesuai Edaran Mendikbud Nomor 14 Tahun 2019)');
    buffer.writeln();
    buffer.writeln('Satuan Pendidikan\t: SD/MI ......');
    buffer.writeln('Kelas / Semester\t: 1 / 1');
    buffer.writeln('Tema\t\t\t: Kegemaranku (Tema 2)');
    buffer.writeln('Sub Tema\t\t: Gemar Berolahraga (Sub Tema 1)');
    buffer.writeln('Pembelajaran ke\t: 1');
    buffer.writeln('Alokasi waktu\t: 1 Hari');
    buffer.writeln();
    buffer.writeln('A. TUJUAN PEMBELAJARAN');
    buffer.writeln(
      '1. Dengan mengamati gambar, siswa dapat memahami kosakata tentang cara memelihara kesehatan dengan tepat.',
    );
    buffer.writeln(
      '2. Dengan menirukan kata-kata yang dibacakan oleh guru, siswa dapat menambah kosakata tentang cara memelihara kesehatan dengan tepat dan percaya diri.',
    );
    buffer.writeln(
      '3. Melalui kegiatan membaca, siswa dapat menggunakan kosakata tentang olahraga sebagai cara memelihara kesehatan dengan tepat.',
    );
    buffer.writeln();
    buffer.writeln('B. KEGIATAN PEMBELAJARAN');
    buffer.writeln();
    buffer.writeln('Kegiatan Pendahuluan (15 menit)');
    buffer.writeln('• Melakukan Pembukaan dengan Salam dan Membaca Doa');
    buffer.writeln(
      '• Mengaitkan Materi Sebelumnya dengan Materi yang akan dipelajari',
    );
    buffer.writeln(
      '• Memberikan gambaran tentang manfaat mempelajari pelajaran',
    );
    buffer.writeln();
    buffer.writeln('Kegiatan Inti (140 menit)');
    buffer.writeln('A. Ayo Mengamati');
    buffer.writeln('• Siswa menyimak teks yang dibacakan oleh guru');
    buffer.writeln('• Guru menunjukkan gambar jenis permainan dan olahraga');
    buffer.writeln('B. Ayo Membaca');
    buffer.writeln('• Siswa menirukan kata-kata yang dibacakan guru');
    buffer.writeln('C. Ayo Mencoba');
    buffer.writeln('• Siswa mengidentifikasi gambar kegiatan yang menyehatkan');
    buffer.writeln();
    buffer.writeln('Kegiatan Penutup (15 menit)');
    buffer.writeln('• Siswa membuat resume dengan bimbingan guru');
    buffer.writeln('• Guru memeriksa pekerjaan siswa');
    buffer.writeln();
    buffer.writeln('C. PENILAIAN (ASESMEN)');
    buffer.writeln(
      'Penilaian terhadap materi ini dapat dilakukan sesuai kebutuhan guru yaitu dari pengamatan sikap, tes pengetahuan dan presentasi unjuk kerja atau hasil karya/projek dengan rubric penilaian.',
    );
    buffer.writeln();
    buffer.writeln(
      'Buat RPP dengan format yang sama untuk mata pelajaran: $subjectName',
    );
    buffer.writeln('Judul: $title');

    if (learningObjectives.isNotEmpty) {
      buffer.writeln(
        'Tujuan Pembelajaran yang diinginkan: $learningObjectives',
      );
    }

    if (materialContent.isNotEmpty) {
      buffer.writeln('Materi yang akan diajarkan:');
      for (var material in materialContent) {
        buffer.writeln('- ${material['judul']}');
      }
    }

    return buffer.toString();
  }

  /// Parse the raw AI text response into a structured RPP map.
  /// Extracts sections by their headers (A. TUJUAN, B. KEGIATAN, C. PENILAIAN).
  /// Like a Laravel service that parses unstructured text into a model's fields.
  /// Falls back to [_createFallbackLessonPlan] with the raw content if parsing fails.
  Map<String, dynamic> _parseAIResponse({
    required String content,
    required String title,
    required String subjectId,
    required String subjectName,
  }) {
    try {
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'learning_objectives': _extractSection(
          content,
          'A. TUJUAN PEMBELAJARAN',
        ),
        'preliminary_activities': _extractSection(
          content,
          'Kegiatan Pendahuluan',
        ),
        'core_activities': _extractSection(content, 'Kegiatan Inti'),
        'closing_activities': _extractSection(content, 'Kegiatan Penutup'),
        'assessment': _extractSection(content, 'C. PENILAIAN'),
        'education_unit': 'SD/MI',
        'class_semester': '1 / 1',
        'theme': title,
        'sub_theme': 'Sub Tema 1',
        'learning_sequence': '1',
        'time_allocation': '1 Hari',
        'preliminary_time': '15',
        'core_time': '140',
        'closing_time': '15',
        'created_at': DateTime.now().toIso8601String(),
        'is_ai_generated': true,
      };
    } catch (e) {
      return _createFallbackLessonPlan(
        title: title,
        subjectId: subjectId,
        subjectName: subjectName,
        materialContent: [],
        customContent: content,
      );
    }
  }

  /// Extract text content for a specific section from the AI response.
  /// Scans line-by-line from the section header until it hits the next section
  /// or end of content. Like a simple text parser / regex extraction in PHP.
  /// Returns empty string if the section is not found.
  String _extractSection(String content, String sectionTitle) {
    try {
      final lines = content.split('\n');
      bool foundSection = false;
      final sectionContent = StringBuffer();

      for (String line in lines) {
        if (line.contains(sectionTitle)) {
          foundSection = true;
          continue;
        }

        if (foundSection) {
          if (line.trim().isEmpty ||
              line.contains('B. KEGIATAN PEMBELAJARAN') ||
              line.contains('C. PENILAIAN') ||
              line.contains('Mengetahui')) {
            break;
          }
          sectionContent.writeln(line);
        }
      }

      return sectionContent.toString().trim();
    } catch (e) {
      return '';
    }
  }
}
