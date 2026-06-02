// Parent report card detail — Phase 3 brand-aligned redesign.
//
// Sections (per Parent_Phase3_RaporLengkap_Mockup.svg):
//   1. BrandPageHeader (role 'wali') with subtitle, student name, PDF
//      icon, realtime "Diterbitkan · DD MMM YYYY" pill, class+semester
//      chip and UTS/UAS toggle in the bottomSlot.
//   2. Hero KPI strip (Rata-rata · Sikap · Kehadiran) overlapping the
//      header.
//   3. Sikap card (spiritual + sosial predicates with descriptions).
//   4. Per-subject grade cards with knowledge/skill split + KKM verdict.
//   5. Ekstrakurikuler card (auto-hidden when empty).
//   6. Prestasi card (auto-hidden when empty).
//   7. Kehadiran 4-cell breakdown (Hadir / Sakit / Izin / Alpa).
//   8. Catatan Wali Kelas quote card (auto-hidden when empty).
//   9. Keputusan Kenaikan banner — ONLY for Semester Genap. For Ganjil
//      we show a soft slate info note ("Keputusan kenaikan kelas akan
//      diumumkan setelah Semester Genap.") because promotion is a
//      year-end decision, not mid-year.
//   10. Sticky bottom CTA bar — Bagikan + Cetak PDF.
//
// All sub-widgets live next door in
// `widgets/parent_report_card_detail_widgets.dart` so this screen only
// owns lifecycle + composition + the two action handlers.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_report_card_detail_widgets.dart';

class ParentReportCardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> reportCardData;
  final String studentName;
  final Map<String, dynamic> studentData;
  final String userRole;

  const ParentReportCardDetailScreen({
    super.key,
    required this.reportCardData,
    required this.studentName,
    required this.studentData,
    this.userRole = 'wali',
  });

  @override
  State<ParentReportCardDetailScreen> createState() =>
      _ParentReportCardDetailScreenState();
}

class _ParentReportCardDetailScreenState
    extends State<ParentReportCardDetailScreen> {
  /// Visual-only filter for the assessment phase chip row. The rapor
  /// payload itself is already a UTS+UAS aggregate, so toggling these
  /// chips doesn't refetch — it just nudges the screen to remind the
  /// parent which scoring window is in view via a SnackBar.
  String? _assessmentFilter; // null | 'uts' | 'uas'

  Map<String, dynamic> get reportCardData => widget.reportCardData;
  String get studentName => widget.studentName;
  Map<String, dynamic> get studentData => widget.studentData;
  String get userRole => widget.userRole;

  // ---- Derived getters --------------------------------------------------

  String get _className =>
      (studentData['class_name'] ??
              studentData['class'] ??
              reportCardData['class_name'] ??
              '')
          .toString();

  /// Backend stores semester as string ID; '1' = Ganjil, '2' = Genap.
  /// Promotion decisions are only meaningful at end-of-year (Genap).
  bool get _isGenap => reportCardData['semester_id']?.toString() == '2';

  String get _semesterLabel {
    final yearLabel =
        (reportCardData['academic_year_label'] ??
                reportCardData['academic_year_name'] ??
                '')
            .toString();
    final base = _isGenap ? 'Sem. Genap' : 'Sem. Ganjil';
    return yearLabel.isEmpty ? base : '$base $yearLabel';
  }

  DateTime? get _publishedAt {
    final raw =
        (reportCardData['published_at'] ??
                reportCardData['updated_at'] ??
                reportCardData['created_at'])
            ?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// True when the rapor has been formally published. Backed by
  /// `reportCardData['status']` (the same field the parent-side list
  /// already filters on with `status == 'published'`). When false, the
  /// backend export endpoint will 404 (or 403 for parents), so the UI
  /// disables all Cetak affordances upstream.
  bool get _isPublished {
    final status = (reportCardData['status'] ?? '').toString().toLowerCase();
    return status == 'published';
  }

  bool get _isAdmin => userRole == 'admin' || userRole == 'administrator';

  List<dynamic> get _subjects =>
      // Backend rename: `raport_subjects` → `report_card_subjects`.
      (reportCardData['reportCardSubjects'] ??
              reportCardData['report_card_subjects'] ??
              reportCardData['raportSubjects'] ??
              reportCardData['raport_subjects'] ??
              const [])
          as List<dynamic>;

  List<dynamic> get _extras =>
      (reportCardData['extracurriculars'] ?? const []) as List<dynamic>;

  List<dynamic> get _achievements =>
      (reportCardData['achievements'] ?? const []) as List<dynamic>;

  // ---- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        header: _buildHeader(context),
        kpiCard: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ParentRaporKpiStrip(reportCardData: reportCardData),
        ),
        bodyChildren: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ParentRaporSectionHeader(
                  title: 'Sikap',
                  trailing: 'Wali kelas',
                ),
                const SizedBox(height: 8),
                ParentRaporSikapCard(reportCardData: reportCardData),
                const SizedBox(height: 18),
                ParentRaporSectionHeader(
                  title: 'Nilai per mata pelajaran',
                  trailing: '${_subjects.length} mapel',
                ),
                const SizedBox(height: 8),
                ..._subjects.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Builder(
                      builder: (ctx) => ParentRaporSubjectCard(
                        subject: s as Map,
                        onTap: () =>
                            showParentRaporDeskripsiSheet(ctx, subject: s),
                      ),
                    ),
                  ),
                ),
                if (_subjects.isEmpty)
                  const ParentRaporEmptyHint(
                    label: 'Belum ada nilai mata pelajaran.',
                  ),
                if (_extras.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ParentRaporSectionHeader(
                    title: 'Ekstrakurikuler',
                    trailing: '${_extras.length} kegiatan',
                  ),
                  const SizedBox(height: 8),
                  ParentRaporExtrasCard(extras: _extras),
                ],
                if (_achievements.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ParentRaporSectionHeader(
                    title: 'Prestasi',
                    trailing: '${_achievements.length} prestasi',
                  ),
                  const SizedBox(height: 8),
                  ParentRaporAchievementsCard(achievements: _achievements),
                ],
                const SizedBox(height: 18),
                ParentRaporSectionHeader(
                  title: 'Kehadiran',
                  trailing: _attendanceTotalLabel(),
                ),
                const SizedBox(height: 8),
                ParentRaporAttendanceCard(reportCardData: reportCardData),
                if ((reportCardData['homeroom_notes'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ParentRaporSectionHeader(
                    title: 'Catatan Wali Kelas',
                    trailing: _homeroomTeacherName(),
                  ),
                  const SizedBox(height: 8),
                  ParentRaporNotesCard(
                    notes: reportCardData['homeroom_notes'].toString().trim(),
                    teacher: _homeroomTeacherName(),
                  ),
                ],
                const SizedBox(height: 18),
                if (_isGenap)
                  ParentRaporDecisionBanner(reportCardData: reportCardData)
                else
                  const ParentRaporGanjilDecisionNote(),
                const SizedBox(height: 12),
                const ParentRaporExportNote(),
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ParentRaporBottomActionBar(
          role: userRole,
          isPublished: _isPublished,
          onShare: () => _share(context),
          onPrintRaport: () => _downloadPdf(context, variant: 'raport'),
          onPrintCertificate: () =>
              _downloadPdf(context, variant: 'certificate'),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final published = _publishedAt;
    return BrandPageHeader(
      role: userRole,
      kpiOverlayHeight: 40,
      showBackButton: true,
      onBackPressed: () => AppNavigator.pop(context),
      subtitle: 'Akademik · Rapor',
      title: 'Rapor $studentName',
      actionIcons: [
        BrandHeaderIconButton(
          icon: _isPublished
              ? Icons.file_download_outlined
              : Icons.file_download_off_outlined,
          onTap: () => _onHeroDownloadTap(context),
        ),
      ],
      isRealtimeFresh: published != null,
      bottomSlot: Row(
        children: [
          Expanded(
            child: ParentRaporHeroChip(
              label: _className.isEmpty
                  ? _semesterLabel
                  : 'Kelas $_className · $_semesterLabel',
              filled: true,
              onTap: () => _showSemesterSheet(context),
              trailingIcon: Icons.keyboard_arrow_down_rounded,
            ),
          ),
          const SizedBox(width: 6),
          ParentRaporHeroChip(
            label: 'UTS',
            filled: false,
            active: _assessmentFilter == 'uts',
            onTap: () => _toggleAssessment('uts'),
            width: 60,
          ),
          const SizedBox(width: 6),
          ParentRaporHeroChip(
            label: 'UAS',
            filled: false,
            active: _assessmentFilter == 'uas',
            onTap: () => _toggleAssessment('uas'),
            width: 60,
          ),
        ],
      ),
    );
  }

  void _toggleAssessment(String which) {
    setState(() {
      _assessmentFilter = _assessmentFilter == which ? null : which;
    });
    final label = which == 'uts' ? 'UTS' : 'UAS';
    SnackBarUtils.showInfo(
      context,
      'Rapor ini sudah merangkum capaian UTS + UAS. '
      'Untuk skor per ujian $label, buka Buku Nilai.',
    );
  }

  void _showSemesterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate200,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih semester',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Untuk membuka rapor semester lain, kembali ke daftar '
                'E-Raport dan pilih semester pada filter di kepala halaman.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    AppNavigator.pop(sheetCtx);
                    AppNavigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.brandAzureDeep,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  child: const Text(
                    'Kembali ke daftar E-Raport',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _homeroomTeacherName() =>
      (reportCardData['homeroom_teacher_name'] ??
              reportCardData['homeroom_teacher'] ??
              'Wali Kelas')
          .toString();

  String _attendanceTotalLabel() {
    final total = _attendanceTotal();
    if (total == 0) return 'Belum dihitung';
    return '$total hari efektif';
  }

  int _attendanceTotal() {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final total = toInt(reportCardData['attendance_total']);
    if (total > 0) return total;
    final present = toInt(reportCardData['attendance_present']);
    final sick = toInt(reportCardData['attendance_sick']);
    final permit = toInt(reportCardData['attendance_permit']);
    final absent = toInt(reportCardData['attendance_absent']);
    return present + sick + permit + absent;
  }

  // ---- Actions ---------------------------------------------------------

  /// Triggers a PDF download. [variant] selects the Blade template on
  /// the backend:
  ///
  /// * `'raport'` → `/raports/export-pdf` → `raport.pdf` (the official
  ///   single-document layout with KI 3 + KI 4 columns and the
  ///   B.1 Deskripsi Capaian section).
  /// * `'certificate'` → `/raports/export-certificate-pdf` →
  ///   `raport.certificate` (the modern certificate layout used by the
  ///   parent download icon).
  ///
  /// When the rapor is still in draft state the upstream UI disables
  /// the affordance, so this method assumes [_isPublished] is true by
  /// the time it runs. We still keep a defensive guard in case the
  /// caller bypasses it.
  Future<void> _downloadPdf(
    BuildContext context, {
    required String variant,
  }) async {
    if (!_isPublished) {
      SnackBarUtils.showInfo(
        context,
        'Rapor masih draft — cetak PDF belum tersedia.',
      );
      return;
    }

    final studentClassId = (reportCardData['student_class_id'] ?? '')
        .toString();
    final academicYearId = (reportCardData['academic_year_id'] ?? '')
        .toString();
    final semesterId = (reportCardData['semester_id'] ?? '').toString();
    if (studentClassId.isEmpty ||
        academicYearId.isEmpty ||
        semesterId.isEmpty) {
      SnackBarUtils.showError(
        context,
        'Data raport belum lengkap untuk dicetak.',
      );
      return;
    }

    SnackBarUtils.showInfo(context, 'Menyiapkan file PDF...');
    try {
      if (variant == 'certificate') {
        await ExcelReportCardService.exportCertificateRaportPdf(
          studentClassId: studentClassId,
          academicYearId: academicYearId,
          semesterId: semesterId,
          studentName: studentName,
          context: context,
        );
      } else {
        await ExcelReportCardService.exportSingleRaportPdf(
          studentClassId: studentClassId,
          academicYearId: academicYearId,
          semesterId: semesterId,
          studentName: studentName,
          context: context,
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// For admin: opens an AppBottomSheet chooser when the hero
  /// download icon is tapped, so admin can pick between the two
  /// PDF formats. For guru/wali the icon downloads the role-default
  /// format directly.
  void _onHeroDownloadTap(BuildContext context) {
    if (!_isPublished) {
      SnackBarUtils.showInfo(
        context,
        'Rapor masih draft — cetak PDF belum tersedia.',
      );
      return;
    }
    if (_isAdmin) {
      _showAdminDownloadChooser(context);
      return;
    }
    // wali → certificate; guru → single raport.
    _downloadPdf(
      context,
      variant: userRole == 'wali' ? 'certificate' : 'raport',
    );
  }

  void _showAdminDownloadChooser(BuildContext context) {
    AppBottomSheet.show<void>(
      context: context,
      title: 'Pilih format PDF',
      subtitle: 'Pilih format dokumen yang ingin dicetak',
      icon: Icons.picture_as_pdf_outlined,
      primaryColor: ColorUtils.getRoleColor(userRole),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdminPdfChoiceTile(
            title: 'Raport (Format Guru)',
            subtitle:
                'Dokumen resmi lengkap — KI 3 + KI 4, sikap, kehadiran, deskripsi capaian.',
            icon: Icons.description_outlined,
            accent: ColorUtils.brandCobalt,
            onTap: () {
              AppNavigator.pop(context);
              _downloadPdf(context, variant: 'raport');
            },
          ),
          const SizedBox(height: 10),
          _AdminPdfChoiceTile(
            title: 'E-Raport (Format Wali)',
            subtitle:
                'Sertifikat ringkas — rata-rata, badge, dan layout modern untuk orang tua.',
            icon: Icons.workspace_premium_outlined,
            accent: const Color(0xFF7C3AED),
            onTap: () {
              AppNavigator.pop(context);
              _downloadPdf(context, variant: 'certificate');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    SnackBarUtils.showInfo(
      context,
      'Bagikan rapor — fitur ini akan tersedia setelah PDF tersimpan.',
    );
  }
}

/// Tappable list-tile used inside the admin "Pilih format PDF" sheet.
/// Renders a leading colored square icon (accent), title + subtitle, and
/// a trailing chevron. Wraps the row in [Material] + [InkWell] so it
/// behaves like a button (ripple on press).
class _AdminPdfChoiceTile extends StatelessWidget {
  const _AdminPdfChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: accent.withValues(alpha: 0.22), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.05), Colors.white],
              stops: const [0.0, 0.7],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: ColorUtils.slate600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: ColorUtils.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
