import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/services/api_services.dart';

class ApiRecommendationService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, dynamic>> getRecommendations({
    required String studentId,
    String? academicYearId,
    String? semesterId,
  }) async {
    try {
      // In production, this would be an API call
      // String url = '/recommendations?student_id=$studentId';
      // if (academicYearId != null) url += '&academic_year_id=$academicYearId';
      // if (semesterId != null) url += '&semester_id=$semesterId';
      // final response = await ApiService().get(url);

      // Mocking for development as requested
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network latency

      return {
        "success": true,
        "message": "Rekomendasi berhasil dibuat untuk siswa.",
        "data": [
          {
            "id": "uuid-rec-1",
            "student_id": studentId,
            "type": "remedial",
            "category": "weak_topic",
            "priority": "high",
            "title": "Penguatan Materi Aljabar Linear",
            "description":
                "<p>Siswa menunjukkan kesulitan dalam memahami konsep dasar aljabar linear, terutama pada bagian operasi matriks dan eliminasi Gauss. Hal ini terlihat dari penurunan nilai kuis dalam 3 pertemuan terakhir.</p>",
            "ai_reasoning":
                "Berdasarkan analisis nilai pada topik Matematika (Aljabar), siswa memiliki rata-rata di bawah KKM (65/75). Data absensi menunjukkan siswa sempat tidak hadir saat pembahasan kunci eliminasi Gauss.",
            "status": "pending",
            "materials": [
              {
                "id": "mat-1",
                "title": "Dasar-dasar Operasi Matriks",
                "type": "video",
                "content":
                    "<p>Pelajari kembali video tutorial operasi penjumlahan, pengurangan, dan perkalian matriks di portal belajar.</p>",
              },
              {
                "id": "mat-2",
                "title": "Latihan Soal Aljabar",
                "type": "exercise",
                "content":
                    "<p>Kerjakan 10 soal latihan eliminasi Gauss untuk memperkuat pemahaman prosedur.</p>",
              },
            ],
          },
          {
            "id": "uuid-rec-2",
            "student_id": studentId,
            "type": "enrichment",
            "category": "interest",
            "priority": "medium",
            "title": "Eksplorasi Algoritma Pemrograman",
            "description":
                "<p>Siswa memiliki minat dan bakat yang menonjol di bidang logika komputer. Disarankan untuk memberikan tantangan tambahan.</p>",
            "ai_reasoning":
                "Siswa selalu menyelesaikan tugas Informatika lebih cepat dengan nilai sempurna (100). Partisipasi aktif dalam kegiatan diskusi pemrograman sangat tinggi.",
            "status": "pending",
            "materials": [
              {
                "id": "mat-3",
                "title": "Pengenalan Struktur Data Lanjut",
                "type": "reading",
                "content":
                    "<p>Artikel mendalam mengenai Tree dan Graph untuk memperluas cakrawala logika siswa.</p>",
              },
            ],
          },
        ],
        "count": 2,
      };
    } catch (e) {
      if (kDebugMode) print('Error fetching recommendations: $e');
      return {
        "success": false,
        "message": "Gagal mengambil rekomendasi: $e",
        "data": [],
      };
    }
  }
}
