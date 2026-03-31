// Detail page for admin lesson plan view. Extracted from admin_lesson_plan_screen.dart.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/update_status_dialog.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class LessonPlanAdminDetailPage extends StatelessWidget {
  final Map<String, dynamic> lessonPlan;

  const LessonPlanAdminDetailPage({super.key, required this.lessonPlan});
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(lessonPlan['status'] ?? '');

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Inline Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  getPrimaryColor(),
                  getPrimaryColor().withValues(alpha: 0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail RPP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if ((lessonPlan['judul'] ?? lessonPlan['title'] ?? '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          lessonPlan['judul'] ?? lessonPlan['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton(
                  onSelected: (value) {
                    if (value == 'approve') {
                      showUpdateStatusDialog(context, 'Disetujui');
                    } else if (value == 'reject') {
                      showUpdateStatusDialog(context, 'Ditolak');
                    }
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: ColorUtils.success600,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Setujui RPP'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: ColorUtils.error600,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Tolak RPP'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lessonPlan['judul'] ?? lessonPlan['title'] ?? '-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                getStatusLabelDetail(lessonPlan['status']),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Informasi Detail
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi RPP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        buildDetailItem(
                          'Guru Pengajar',
                          lessonPlan['teacher_name'] ??
                              lessonPlan['teacher']?['name'] ??
                              '-',
                        ),
                        buildDetailItem(
                          'Mata Pelajaran',
                          lessonPlan['subject_name'] ??
                              lessonPlan['mata_pelajaran_nama'] ??
                              '-',
                        ),
                        buildDetailItem(
                          'Kelas',
                          lessonPlan['class_name'] ??
                              lessonPlan['kelas_nama'] ??
                              '-',
                        ),
                        buildDetailItem(
                          'Tahun Ajaran',
                          '${lessonPlan['academic_year'] ?? lessonPlan['tahun_ajaran'] ?? '-'}',
                        ),
                        buildDetailItem(
                          'Semester',
                          lessonPlan['semester'] ?? '-',
                        ),
                        buildDetailItem(
                          'Tanggal Dibuat',
                          lessonPlan['created_at']?.toString().substring(
                                0,
                                10,
                              ) ??
                              '-',
                        ),
                        if (lessonPlan['catatan'] != null &&
                            lessonPlan['catatan'].toString().isNotEmpty)
                          buildDetailItem('Catatan', lessonPlan['catatan']),

                        if (lessonPlan['catatan_admin'] != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Divider(),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Catatan Admin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            lessonPlan['catatan_admin']!,
                            style: TextStyle(
                              fontSize: 14,
                              color: ColorUtils.slate600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Isi RPP
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Isi RPP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        buildContentSection(
                          'Kompetensi Inti',
                          lessonPlan['core_competence'],
                        ),
                        buildContentSection(
                          'Kompetensi Dasar',
                          lessonPlan['basic_competence'],
                        ),
                        buildContentSection(
                          'Indikator',
                          lessonPlan['indicator'],
                        ),
                        buildContentSection(
                          'Tujuan Pembelajaran',
                          lessonPlan['learning_objective'],
                        ),
                        buildContentSection(
                          'Materi Pokok',
                          lessonPlan['main_material'],
                        ),
                        buildContentSection(
                          'Metode Pembelajaran',
                          lessonPlan['learning_method'],
                        ),
                        buildContentSection(
                          'Media/Alat',
                          lessonPlan['media_tools'],
                        ),
                        buildContentSection(
                          'Sumber Belajar',
                          lessonPlan['learning_source'],
                        ),
                        buildContentSection(
                          'Langkah-langkah Pembelajaran',
                          lessonPlan['learning_activities'],
                        ),
                        buildContentSection(
                          'Penilaian',
                          lessonPlan['assessment'],
                        ),
                      ],
                    ),
                  ),

                  // File Attachment
                  if (lessonPlan['file_path'] != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: ColorUtils.slate200),
                        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lampiran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton.icon(
                            onPressed: () => downloadAndOpenFile(
                              context,
                              lessonPlan['file_path'],
                            ),
                            icon: Icon(Icons.download),
                            label: Text('Download RPP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getStatusLabelDetail(String? status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return status ?? '-';
    }
  }

  void showUpdateStatusDialog(BuildContext context, String status) {
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        lessonPlanId: lessonPlan['id'],
        currentStatus: lessonPlan['status'],
        currentNote: lessonPlan['catatan'],
        onStatusUpdated: () {
          AppNavigator.pop(context); // Return to list
        },
      ),
    );
  }

  Widget buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: TextStyle(color: ColorUtils.slate700)),
          ),
        ],
      ),
    );
  }

  Widget buildContentSection(String title, String? content) {
    if (content == null || content.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Text(
              content,
              style: TextStyle(color: ColorUtils.slate800, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> downloadAndOpenFile(
    BuildContext context,
    String? filePath,
  ) async {
    if (filePath == null) return;

    // Capture ScaffoldMessenger before any await so we never touch
    // BuildContext across an async gap (lint: use_build_context_synchronously).
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(SnackBar(content: Text('Mengunduh file...')));

      // Create proper URL
      // ApiService.baseUrl usually ends with /api
      // We need base URL without /api
      final baseUrlBase = ApiService.baseUrl.replaceAll('/api', '');
      String fileUrl;
      if (filePath.startsWith('http')) {
        fileUrl = filePath;
      } else {
        fileUrl = '$baseUrlBase/storage/$filePath';
      }

      AppLogger.debug('lesson_plan', 'Downloading from: $fileUrl');

      final dio = Dio();
      final response = await dio.get<List<int>>(
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = filePath.split('/').last;
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(response.data ?? []);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.downloadSuccessful.tr)),
      );

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.failedToOpenFile.tr}: ${result.message}',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.failedToDownload.tr}: $e'),
        ),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return ColorUtils.success600;
      case 'Pending':
      case 'Menunggu':
        return ColorUtils.warning600;
      case 'Rejected':
      case 'Ditolak':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }
}
