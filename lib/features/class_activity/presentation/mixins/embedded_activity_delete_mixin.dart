import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// Handles activity deletion and auto-unchecking of materials.
mixin EmbeddedActivityDeleteMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract method
  void onActivityChanged();

  Future<void> deleteActivity(
    dynamic activity,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Delete Activity',
        'id': 'Hapus Kegiatan',
      }),
      message: languageProvider.getTranslatedText({
        'en':
            'Are you sure you want to delete "${activity['title']}"? This action cannot be undone.',
        'id':
            'Apakah Anda yakin ingin menghapus "${activity['title']}"? Tindakan ini tidak dapat dibatalkan.',
      }),
      confirmText: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      isDestructive: true,
    );

    if (confirmed != true) return;

    try {
      await getIt<ApiClassActivityService>().deleteActivity(
        activity['id'].toString(),
      );

      if (!mounted) return;

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Activity deleted successfully',
          'id': 'Kegiatan berhasil dihapus',
        }),
      );

      onActivityChanged();
      await autoUncheckMaterials(activity);
    } catch (e) {
      AppLogger.error('class_activity', 'Delete activity error: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${languageProvider.getTranslatedText({'en': 'Failed to delete activity: ', 'id': 'Gagal menghapus kegiatan: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> autoUncheckMaterials(dynamic activity) async {
    if (activity['chapter_id'] == null) return;

    final List<Map<String, dynamic>> progressItems = [];

    Future<bool> isMaterialUsed(String chapterId, String? subChapterId) async {
      try {
        final response = await getIt<ApiClassActivityService>()
            .getClassActivityPaginated(
              page: 1,
              limit: 1,
              teacherId: widget.teacherId,
              subjectId:
                  activity['subject_id'] ?? activity['mata_pelajaran_id'],
              chapterId: chapterId,
              subChapterId: subChapterId,
            );
        return (response['pagination']?['total_items'] ?? 0) > 0;
      } catch (e) {
        AppLogger.error('class_activity', 'Error checking material usage: $e');
        return true;
      }
    }

    try {
      if (activity['sub_chapter_id'] != null) {
        final inUse = await isMaterialUsed(
          activity['chapter_id'].toString(),
          activity['sub_chapter_id'].toString(),
        );
        if (!inUse) {
          progressItems.add({
            'bab_id': activity['chapter_id'],
            'sub_bab_id': activity['sub_chapter_id'],
            'is_checked': false,
          });
        }
      } else {
        final subChapters = await getIt<ApiSubjectService>()
            .getSubChapterMaterials(
              chapterId: activity['chapter_id'].toString(),
            );

        for (final sub in subChapters) {
          final subId = sub['id'].toString();
          final isSpecificUsed = await isMaterialUsed(
            activity['chapter_id'].toString(),
            subId,
          );
          final isGenericUsed = await isMaterialUsed(
            activity['chapter_id'].toString(),
            'null',
          );
          if (!isSpecificUsed && !isGenericUsed) {
            progressItems.add({
              'bab_id': activity['chapter_id'],
              'sub_bab_id': subId,
              'is_checked': false,
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error(
        'class_activity',
        'Error unchecking primary material: $e',
      );
    }

    if (activity['additional_material'] != null) {
      try {
        List<dynamic> additionalMaterials = [];
        if (activity['additional_material'] is String) {
          additionalMaterials = json.decode(activity['additional_material']);
        } else if (activity['additional_material'] is List) {
          additionalMaterials = activity['additional_material'];
        }

        for (final item in additionalMaterials) {
          if (item['chapter_id'] != null && item['sub_chapter_id'] != null) {
            final subId = item['sub_chapter_id'].toString();
            final chapId = item['chapter_id'].toString();
            final isSpecificUsed = await isMaterialUsed(chapId, subId);
            final isGenericUsed = await isMaterialUsed(chapId, 'null');
            if (!isSpecificUsed && !isGenericUsed) {
              progressItems.add({
                'bab_id': chapId,
                'sub_bab_id': subId,
                'is_checked': false,
              });
            }
          }
        }
      } catch (e) {
        AppLogger.error(
          'class_activity',
          'Error parsing additional materials: $e',
        );
      }
    }

    if (progressItems.isNotEmpty) {
      try {
        await getIt<ApiSubjectService>().batchSaveMateriProgress({
          'guru_id': widget.teacherId,
          'mata_pelajaran_id':
              activity['subject_id'] ?? activity['mata_pelajaran_id'],
          'progress_items': progressItems,
        });
        AppLogger.debug(
          'class_activity',
          'Auto-unchecked ${progressItems.length} materials.',
        );
      } catch (e) {
        AppLogger.error(
          'class_activity',
          'Error auto-unchecking materials: $e',
        );
      }
    }
  }
}
