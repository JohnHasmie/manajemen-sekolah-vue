import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';

/// Mixin for handling form submission in AddActivityDialog
mixin ActivitySubmissionMixin on ConsumerState<AddActivityDialog> {
  // Abstract getters/setters - bridge to state fields
  GlobalKey<FormState> get formKey;
  TextEditingController get titleController;
  TextEditingController get descriptionController;

  bool get isSubmitting;
  set isSubmitting(bool v);

  String? get selectedSubjectId;
  String? get selectedClassId;
  String? get selectedChapterId;
  String? get selectedSubChapterId;
  DateTime? get selectedDate;
  DateTime? get deadline;
  String? get selectedDay;
  bool get useMaterialTitle;
  List<String> get selectedSubChapterIds;
  List<String> get selectedStudents;

  // Widget data getters
  String get teacherId;
  String get activityType;
  String get initialTarget;
  bool get isEditMode;
  dynamic get activityData;
  List<Map<String, dynamic>>? get initialAdditionalMaterials;
  List<Map<String, dynamic>>? get materialsToMarkAsGenerated;

  // Methods for helper lookups
  String getChapterName(dynamic chapter);
  String getSubChapterName(dynamic subChapter);

  Future<void> submitForm() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedSubjectId == null || selectedClassId == null) {
      _showError('Pilih mata pelajaran dan kelas terlebih dahulu');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final languageProvider = ref.read(languageRiverpod);

      final lessonHourId = widget.lessonHourId;
      // Backend canonical enums (rename guide §4):
      //   class_activities.type → assignment / test / quiz / activity /
      //     exam / material (was tugas / ulangan / kuis / kegiatan / materi).
      //   class_activities.target_role → student / all / specific
      //     (was siswa / umum / khusus).
      //   days.name → english lowercase (was senin/selasa/...).
      final canonicalType = _toCanonicalActivityType(activityType);
      final canonicalTarget = _toCanonicalTargetRole(initialTarget);
      final canonicalDay = _toCanonicalDay(selectedDay);

      final Map<String, dynamic> data = {
        'teacher_id': teacherId,
        'subject_id': selectedSubjectId,
        'class_id': selectedClassId,
        'title': titleController.text,
        'description': descriptionController.text,
        'type': canonicalType,
        'target_role': canonicalTarget,
        'date': selectedDate!.toIso8601String().split('T')[0],
        'day': canonicalDay,
        if (lessonHourId != null) 'lesson_hour_id': lessonHourId,
      };

      // Save chapter_id and sub_chapter_id if selected from materi
      if (useMaterialTitle && selectedChapterId != null) {
        data['chapter_id'] = selectedChapterId;
      } else if (selectedChapterId != null) {
        data['chapter_id'] = selectedChapterId;
      }

      if (useMaterialTitle && selectedSubChapterId != null) {
        data['sub_chapter_id'] = selectedSubChapterId;
      } else if (selectedSubChapterId != null) {
        data['sub_chapter_id'] = selectedSubChapterId;
      }

      // Handle Additional Material (from LIVE selection)
      if (selectedSubChapterIds.isNotEmpty) {
        final List<Map<String, dynamic>> extraMaterials = [];
        final primarySubId = data['sub_chapter_id']?.toString();

        for (final subId in selectedSubChapterIds) {
          // Skip if this is the primary sub chapter
          if (subId == primarySubId) continue;

          String? chapterIdForSub = selectedChapterId;

          // If not found in current list, check initialAdditionalMaterials
          if (initialAdditionalMaterials != null) {
            final found = initialAdditionalMaterials!.firstWhere(
              (m) => m['sub_chapter_id'].toString() == subId,
              orElse: () => {},
            );
            if (found.isNotEmpty) {
              chapterIdForSub =
                  found['chapter_id']?.toString() ?? selectedChapterId;
            }
          }

          if (chapterIdForSub != null) {
            extraMaterials.add({
              'chapter_id': chapterIdForSub,
              'sub_chapter_id': subId,
            });
          } else {
            extraMaterials.add({'sub_chapter_id': subId});
          }
        }

        if (extraMaterials.isNotEmpty) {
          data['additional_material'] = extraMaterials;
        }
      }

      if (deadline != null &&
          (canonicalType == 'assignment' || activityType == 'tugas')) {
        data['batas_waktu'] = deadline!.toIso8601String();
      }

      // Add target students for specific activities
      final Map<String, dynamic> requestData = Map<String, dynamic>.from(data);
      if ((canonicalTarget == 'specific' || initialTarget == 'khusus') &&
          selectedStudents.isNotEmpty) {
        requestData['siswa_target'] = selectedStudents;
      }

      // Call appropriate API based on mode
      if (isEditMode && activityData != null) {
        await getIt<ApiClassActivityService>().updateActivity(
          activityData['id'].toString(),
          requestData,
        );
      } else {
        await getIt<ApiClassActivityService>().createActivity(requestData);
      }

      // Automatically mark material as generated (checked)
      if (data['chapter_id'] != null) {
        try {
          final List<Map<String, dynamic>> progressItems = [
            {
              'bab_id': data['chapter_id'],
              'sub_bab_id': data['sub_chapter_id'],
              'is_checked': true,
              'is_generated': true,
            },
          ];

          // Add explicitly passed materials to mark as generated
          if (materialsToMarkAsGenerated != null) {
            for (final item in materialsToMarkAsGenerated!) {
              progressItems.add({
                'bab_id': item['bab_id'],
                'sub_bab_id': item['sub_bab_id'],
                'is_checked': true,
                'is_generated': true,
              });
            }
          }

          // Also add manually selected IDs from the multi-select dialog
          if (useMaterialTitle &&
              selectedSubChapterIds.isNotEmpty &&
              selectedChapterId != null) {
            for (final subId in selectedSubChapterIds) {
              final bool exists = progressItems.any(
                (p) => p['sub_bab_id'].toString() == subId,
              );
              if (!exists) {
                progressItems.add({
                  'bab_id': selectedChapterId,
                  'sub_bab_id': subId,
                  'is_checked': true,
                  'is_generated': true,
                });
              }
            }
          }

          AppLogger.debug('class_activity', '=== BATCH SAVE PROGRESS ===');
          AppLogger.debug(
            'class_activity',
            'Progress items: ${progressItems.length}',
          );
          AppLogger.debug(
            'class_activity',
            'First item: ${progressItems.first}',
          );

          await getIt<ApiSubjectService>().batchSaveMateriProgress({
            'guru_id': teacherId,
            'mata_pelajaran_id': selectedSubjectId,
            'class_id': selectedClassId,
            'progress_items': progressItems,
          });
          AppLogger.debug(
            'class_activity',
            'Auto-marked material as generated: ${data['chapter_id']}',
          );
        } catch (e) {
          AppLogger.error('class_activity', 'Error auto-marking material: $e');
        }
      }

      if (!mounted) return;

      // Notify parent to refresh the activity list
      widget.onActivityAdded();

      AppNavigator.pop(context);

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': isEditMode
              ? 'Activity updated successfully'
              : 'Activity added successfully',
          'id': isEditMode
              ? 'Kegiatan berhasil diperbarui'
              : 'Kegiatan berhasil ditambahkan',
        }),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackBarUtils.showError(context, message);
  }

  /// Map a possibly-legacy class_activities.type to the canonical
  /// English value the backend now expects.
  /// Canonical: assignment / test / quiz / activity / exam / material.
  String _toCanonicalActivityType(String raw) {
    switch (raw.toLowerCase()) {
      case 'tugas':
      case 'assignment':
        return 'assignment';
      case 'ulangan':
      case 'test':
        return 'test';
      case 'kuis':
      case 'quiz':
        return 'quiz';
      case 'kegiatan':
      case 'activity':
        return 'activity';
      case 'ujian':
      case 'exam':
        return 'exam';
      case 'materi':
      case 'material':
        return 'material';
      default:
        return raw.toLowerCase();
    }
  }

  /// Map a possibly-legacy class_activities.target_role to the
  /// canonical English value (student / all / specific).
  String _toCanonicalTargetRole(String raw) {
    switch (raw.toLowerCase()) {
      case 'siswa':
      case 'student':
        return 'student';
      case 'umum':
      case 'all':
        return 'all';
      case 'khusus':
      case 'specific':
        return 'specific';
      default:
        return raw.toLowerCase();
    }
  }

  /// Map an Indonesian day name to its English lowercase counterpart.
  String? _toCanonicalDay(String? raw) {
    if (raw == null) return null;
    switch (raw.toLowerCase()) {
      case 'senin':
        return 'monday';
      case 'selasa':
        return 'tuesday';
      case 'rabu':
        return 'wednesday';
      case 'kamis':
        return 'thursday';
      case 'jumat':
      case "jum'at":
        return 'friday';
      case 'sabtu':
        return 'saturday';
      case 'minggu':
      case 'ahad':
        return 'sunday';
      default:
        return raw.toLowerCase();
    }
  }
}
