/// absensi_summary.dart - Aggregated attendance summary per subject per date.
/// Like Laravel's Absensi summary Resource/DTO - presents pre-aggregated attendance data.
/// In Vue terms, this is the shape returned by a "GET /absensi/summary" API call.
library;

/// Holds a summarized attendance snapshot for one subject on one date.
/// Like a Laravel Eloquent Model but simpler - just a data class with fromJson
/// (similar to a Laravel Resource or DTO).
///
/// Key properties:
/// - [mataPelajaranId] / [mataPelajaranNama]: The subject this summary belongs to.
/// - [totalSiswa]: Total number of students expected.
/// - [hadir]: Count of students who were present.
/// - [tidakHadir]: Count of students who were absent (sakit + izin + alpha combined).
class AbsensiSummary {
  final String id;
  final String mataPelajaranId;
  final String mataPelajaranNama;
  final DateTime tanggal;
  final int totalSiswa;
  final int hadir;
  final int tidakHadir;

  AbsensiSummary({
    required this.id,
    required this.mataPelajaranId,
    required this.mataPelajaranNama,
    required this.tanggal,
    required this.totalSiswa,
    required this.hadir,
    required this.tidakHadir,
  });

  /// Constructs an [AbsensiSummary] from a JSON map returned by the backend API.
  /// Like Laravel's `fromJson` or a Laravel Resource's `toArray` in reverse.
  ///
  /// [json] - The raw `Map<String, dynamic>` from the API response body.
  /// Returns a fully populated [AbsensiSummary] with safe defaults (empty string / 0)
  /// for any missing keys.
  factory AbsensiSummary.fromJson(Map<String, dynamic> json) {
    return AbsensiSummary(
      id: json['id'] ?? '',
      mataPelajaranId: json['mata_pelajaran_id'] ?? '',
      mataPelajaranNama: json['mata_pelajaran_nama'] ?? '',
      tanggal: DateTime.parse(json['tanggal']),
      totalSiswa: json['total_siswa'] ?? 0,
      hadir: json['hadir'] ?? 0,
      tidakHadir: json['tidak_hadir'] ?? 0,
    );
  }
}