// Add/Edit activity dialog — extracted from teacher_class_activity_screen.dart.
// A bottom-sheet wizard for creating or editing class activities (materi/tugas).
// Like a Vue modal component with form state, API calls, and multi-step logic.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/class_activity/services/class_activity_service.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

class AddActivityDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<dynamic> scheduleList;
  final List<dynamic> subjectList;
  final List<dynamic> chapterList;
  final List<dynamic> subChapterList;
  final Function(String) onSubjectSelected;
  final Function(String) onChapterSelected;
  final VoidCallback onActivityAdded;
  final String initialTarget;
  final String activityType;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialClassId;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final bool isEditMode;
  final dynamic activityData;

  const AddActivityDialog({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.scheduleList,
    required this.subjectList,
    required this.chapterList,
    required this.subChapterList,
    required this.onSubjectSelected,
    required this.onChapterSelected,
    required this.onActivityAdded,
    required this.initialTarget,
    required this.activityType,
    this.initialDate,
    this.initialSubjectId,
    this.initialClassId,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.isEditMode = false,
    this.activityData,
  });

  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;

  @override
  ConsumerState<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends ConsumerState<AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final List<String> _selectedStudents = [];

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedChapterId;
  String? _selectedSubChapterId;
  DateTime? _selectedDate;
  DateTime? _deadline;
  String? _selectedDay;
  bool _isSubmitting = false;
  bool _isLoadingStudents = false;
  List<dynamic> _studentList = [];

  // Bab & Sub Bab Materi
  bool _isLoadingChapters = false;
  List<dynamic> _chapterMaterialList = [];
  List<dynamic> _subChapterMaterialList = [];
  final List<String> _selectedSubChapterIds = []; // Multi-selection support
  bool _useMaterialTitle = false; // Toggle: use chapter/sub-chapter or manual input

  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  void initState() {
    super.initState();

    // Set initial values from widget parameters or use defaults
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedDay = _days[_selectedDate!.weekday - 1];
    _selectedSubjectId = widget.initialSubjectId;
    _selectedClassId = widget.initialClassId;
    _selectedChapterId = widget.initialChapterId;
    _selectedSubChapterId = widget.initialSubChapterId;

    // Initialize multi-select list
    if (_selectedSubChapterId != null) {
      _selectedSubChapterIds.add(_selectedSubChapterId!);
    }
    if (widget.initialAdditionalMaterials != null) {
      for (var item in widget.initialAdditionalMaterials!) {
        final subId = item['sub_chapter_id']?.toString();
        if (subId != null && !_selectedSubChapterIds.contains(subId)) {
          _selectedSubChapterIds.add(subId);
        }
      }
    }

    // If in edit mode, populate form with existing data
    if (widget.isEditMode && widget.activityData != null) {
      _titleController.text = widget.activityData['judul']?.toString() ?? '';
      _deskripsiController.text =
          widget.activityData['deskripsi']?.toString() ?? '';

      // Parse deadline if exists
      if (widget.activityData['batas_waktu'] != null) {
        _deadline = DateTime.tryParse(
          widget.activityData['batas_waktu'].toString(),
        );
      }

      // Load selected students if target is khusus
      if (widget.initialTarget == 'khusus' &&
          widget.activityData['siswa_target'] != null) {
        final studentTarget = widget.activityData['siswa_target'];
        if (studentTarget is List) {
          _selectedStudents.addAll(studentTarget.map((s) => s.toString()));
        }
      }
    }

    // If initial bab is provided, enable material title mode
    if (_selectedChapterId != null || _selectedSubChapterId != null) {
      _useMaterialTitle = true;
    }

    // Debug logging
    // if (kDebugMode) {
    //   print('===== AddActivityDialog INIT =====');
    //   print('Subject list count: ${widget.subjectList.length}');
    //   print('Schedule list count: ${widget.scheduleList.length}');
    //   print('Activity type: ${widget.activityType}');
    //   print('Initial target: ${widget.initialTarget}');
    //   print('Initial subject ID: $_selectedSubjectId');
    //   print('Initial class ID: $_selectedClassId');
    //   print('Initial bab ID: $_selectedChapterId');
    //   print('Initial sub bab ID: $_selectedSubChapterId');
    //   print('Use materi title: $_useMaterialTitle');
    //   print('Initial date: $_selectedDate');
    // }

    // If initial subject is provided, load its data
    if (_selectedSubjectId != null) {
      Future.delayed(Duration.zero, () {
        AppLogger.debug('class_activity', 'Loading initial data for subject: $_selectedSubjectId');

        widget.onSubjectSelected(_selectedSubjectId!);
        // Load bab materi for the initial subject
        _loadChapterMaterials(_selectedSubjectId!).then((_) {
          // After bab list loaded, load sub bab if initial bab is provided
          if (_selectedChapterId != null) {
            AppLogger.debug('class_activity', 'Loading sub bab for bab: $_selectedChapterId');
            _loadSubBabMateri(_selectedChapterId!).then((_) {
              // After sub bab loaded, update title
              _updateTitleFromMateri();
            });
          } else {
            // Only bab selected, update title
            _updateTitleFromMateri();
          }
        });

        // If initial class is provided and target is 'khusus', load students
        if (_selectedClassId != null && widget.initialTarget == 'khusus') {
          AppLogger.debug('class_activity', 'Loading students for class: $_selectedClassId');
          _loadStudents();
        }
      });
    } else {
      AppLogger.debug('class_activity', 'No initial subject ID - waiting for user selection');
    }

    AppLogger.debug('class_activity', '=====================================');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;

    setState(() {
      _isLoadingStudents = true;
      _studentList = []; // Clear previous list
    });

    AppLogger.debug('class_activity', '[_loadStudents] Starting load for class: $_selectedClassId');

    try {
      final students = await getIt<ApiClassActivityService>().getSiswaByKelas(
        _selectedClassId!,
      );

      if (!mounted) {
        AppLogger.debug('class_activity', '[_loadStudents] Widget unmounted, skipping setState');
        return;
      }

      // if (kDebugMode) {
      //   print('[_loadStudents] Loaded ${students.length} students');
      // }

      setState(() {
        _studentList = students;
        _isLoadingStudents = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('class_activity', 'Error loading students: $e');
      AppLogger.error('class_activity', stackTrace);
      if (mounted) {
        setState(() {
          _studentList = [];
          _isLoadingStudents = false;
        });
        // Non-critical in a dialog, but better to show something
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadChapterMaterials(String subjectId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING BAB MATERI =====');
      AppLogger.debug('class_activity', 'Subject ID: $subjectId');

      setState(() {
        _isLoadingChapters = true;
        _chapterMaterialList = []; // Clear previous list while loading
      });

      // Find Master Subject ID from the selected School Subject ID
      final subject = widget.subjectList.firstWhere(
        (s) => s['id']?.toString() == subjectId,
        orElse: () => <String, dynamic>{},
      );
      final masterSubjectId = subject.isNotEmpty
          ? (subject['subject_id']?.toString() ?? subject['id']?.toString() ?? subjectId)
          : subjectId;

      final chapterList = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: masterSubjectId,
      );

      if (kDebugMode) {
        AppLogger.debug('class_activity', 'API Response - Bab count: ${chapterList.length}');
        if (chapterList.isNotEmpty) {
          AppLogger.debug('class_activity', 'First item structure: ${chapterList[0]}');
          AppLogger.debug('class_activity', 'Available fields: ${chapterList[0].keys}');
          AppLogger.debug('class_activity', 'Judul Bab: ${chapterList[0]['judul_bab']}');
        }
      }

      setState(() {
        _chapterMaterialList = chapterList;
        // Only reset if no initial values were provided
        if (widget.initialChapterId == null) {
          _selectedChapterId = null;
        }
        if (widget.initialSubChapterId == null) {
          _selectedSubChapterId = null;
        }
        // Only clear sub bab list if no initial sub bab
        if (widget.initialSubChapterId == null) {
          _subChapterMaterialList = [];
        }
        _isLoadingChapters = false;
      });

      AppLogger.debug('class_activity', 'State updated - _chapterMaterialList.length: ${_chapterMaterialList.length}',);
      AppLogger.debug('class_activity', 'Current _selectedChapterId: $_selectedChapterId');
      AppLogger.debug('class_activity', 'Current _selectedSubChapterId: $_selectedSubChapterId');
      AppLogger.debug('class_activity', '=============================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadSubBabMateri(String babId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING SUB BAB MATERI =====');
      AppLogger.debug('class_activity', 'Bab ID: $babId');

      final subChapterList = await getIt<ApiSubjectService>().getSubChapterMaterials(chapterId: babId);

      if (kDebugMode) {
        AppLogger.debug('class_activity', 'API Response - Sub Bab count: ${subChapterList.length}');
        if (subChapterList.isNotEmpty) {
          AppLogger.debug('class_activity', 'First item structure: ${subChapterList[0]}');
          AppLogger.debug('class_activity', 'Available fields: ${subChapterList[0].keys}');
          AppLogger.debug('class_activity', 'Judul Sub Bab: ${subChapterList[0]['judul_sub_bab']}');
        }
      }

      setState(() {
        _subChapterMaterialList = subChapterList;
        // Only reset if no initial value was provided
        if (widget.initialSubChapterId == null) {
          _selectedSubChapterId = null;
        }
      });

      AppLogger.debug('class_activity', 'State updated - _subChapterMaterialList.length: ${_subChapterMaterialList.length}',);
      AppLogger.debug('class_activity', 'Current _selectedSubChapterId: $_selectedSubChapterId');
      AppLogger.debug('class_activity', '==================================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading sub bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  String _getChapterName(dynamic bab) {
    // Try multiple possible field names (backend returns 'chapter_title')
    return bab['chapter_title']?.toString() ??
        bab['judul_bab']?.toString() ??
        bab['nama']?.toString() ??
        bab['judul']?.toString() ??
        bab['title']?.toString() ??
        bab['name']?.toString() ??
        'Unknown';
  }

  String _getSubChapterName(dynamic subChapter) {
    // Try multiple possible field names (backend returns 'sub_chapter_title')
    return subChapter['sub_chapter_title']?.toString() ??
        subChapter['judul_sub_bab']?.toString() ??
        subChapter['nama']?.toString() ??
        subChapter['judul']?.toString() ??
        subChapter['title']?.toString() ??
        subChapter['name']?.toString() ??
        'Unknown';
  }

  void _updateTitleFromMateri() {
    String chapterName = '';
    String subChapterName = '';

    // Get bab name if selected
    if (_selectedChapterId != null && _chapterMaterialList.isNotEmpty) {
      final chapter = _chapterMaterialList.firstWhere(
        (b) => b['id']?.toString() == _selectedChapterId,
        orElse: () => <String, dynamic>{},
      );
      if (chapter.isNotEmpty) {
        // Check if the map is not empty
        chapterName = _getChapterName(chapter);
      }
    }

    // Get sub bab name if selected
    if (_selectedSubChapterId != null && _subChapterMaterialList.isNotEmpty) {
      final subChapter = _subChapterMaterialList.firstWhere(
        (item) => item['id']?.toString() == _selectedSubChapterId,
        orElse: () => <String, dynamic>{},
      );
      if (subChapter.isNotEmpty) {
        subChapterName = _getSubChapterName(subChapter);
      }
    }

    // Build title based on what's selected
    String title = '';
    if (chapterName.isNotEmpty && subChapterName.isNotEmpty) {
      // Both selected: "Bab - Sub Bab"
      title = '$chapterName - $subChapterName';
    } else if (chapterName.isNotEmpty) {
      // Only bab selected
      title = chapterName;
    } else if (subChapterName.isNotEmpty) {
      // Only sub bab selected (edge case)
      title = subChapterName;
    }

    if (title.isNotEmpty && title != 'Unknown') {
      _titleController.text = title;
    }
  }

  List<DropdownMenuItem<String>> _getUniqueClassItems() {
    final Map<String, Map<String, dynamic>> uniqueClasses = {};
    final now = DateTime.now();
    // Use _selectedDay if available, otherwise fallback to current day
    final String targetDay =
        _selectedDay ??
        [
          'Senin',
          'Selasa',
          'Rabu',
          'Kamis',
          'Jumat',
          'Sabtu',
          'Minggu',
        ][now.weekday - 1];

    // if (kDebugMode) {
    //   print('Getting unique classes for subject: $_selectedSubjectId');
    //   print(
    //     'Current day: $currentDay, Current time: ${now.hour}:${now.minute}',
    //   );
    //   print('Target: ${widget.initialTarget}');
    //   print('Initial class ID from widget: ${widget.initialClassId}');
    // }

    // Filter schedules by selected subject and deduplicate by class_id
    for (var schedule in widget.scheduleList) {
      final scheduleSubjectId =
          (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();

      AppLogger.debug('class_activity', 'Checking schedule: ${schedule['id']} - Subject: $scheduleSubjectId vs Selected: $_selectedSubjectId',);

      if (scheduleSubjectId == _selectedSubjectId) {
        final classId = (schedule['class_id'] ?? schedule['kelas_id'])
            .toString();

        // For SPECIFIC target: no time filter, all schedules can be selected
        if (widget.initialTarget == 'khusus') {
          if (!uniqueClasses.containsKey(classId)) {
            uniqueClasses[classId] = {
              'id': classId,
              'nama': schedule['kelas_nama'] ?? 'Unknown',
            };
          }
        }
        // For GENERAL target
        else {
          // If initialClassId exists (from teaching schedule), always include that class
          if (widget.initialClassId != null &&
              classId == widget.initialClassId) {
            if (!uniqueClasses.containsKey(classId)) {
              uniqueClasses[classId] = {
                'id': classId,
                'nama': schedule['kelas_nama'] ?? 'Unknown',
              };
              AppLogger.debug('class_activity', 'Added class from initialClassId: ${schedule['kelas_nama']}',);
            }
          }
          // Filter by time for other classes
          else {
            var scheduleDay =
                schedule['hari_nama']?.toString() ??
                schedule['day_name']?.toString() ??
                '';

            // Map English days to Indonesian if needed
            final dayMap = {
              'Monday': 'Senin',
              'Tuesday': 'Selasa',
              'Wednesday': 'Rabu',
              'Thursday': 'Kamis',
              'Friday': 'Jumat',
              'Saturday': 'Sabtu',
              'Sunday': 'Minggu',
            };

            if (dayMap.containsKey(scheduleDay)) {
              scheduleDay = dayMap[scheduleDay]!;
            }

            AppLogger.debug('class_activity', 'Schedule: ${schedule['kelas_nama']}, Day: $scheduleDay vs Target: $targetDay',);

            // Check if schedule is on the selected day
            if (scheduleDay == targetDay) {
              // Time validation removed to ensure classes always appear for the day
              // Original logic checked start_time + 23h, but this was too strict/buggy
              if (!uniqueClasses.containsKey(classId)) {
                uniqueClasses[classId] = {
                  'id': classId,
                  'nama': schedule['kelas_nama'] ?? 'Unknown',
                };
              } else {
                AppLogger.debug('class_activity', 'Class already added: $classId');
              }
            } else {
              AppLogger.debug('class_activity', 'Day mismatch: $scheduleDay != $targetDay');
            }
          }
        }
      }
    }

    // if (kDebugMode) {
    //   print('Unique classes found: ${uniqueClasses.length}');
    // }

    // Convert to dropdown items safely
    try {
      return uniqueClasses.values.map((classItem) {
        return DropdownMenuItem<String>(
          value: classItem['id'].toString(),
          child: Text(classItem['nama'] ?? 'Unknown'),
        );
      }).toList();
    } catch (e) {
      AppLogger.error('class_activity', 'Error generating class dropdown items: $e');
      return [];
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null || _selectedClassId == null) {
      _showError('Pilih mata pelajaran dan kelas terlebih dahulu');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final languageProvider = ref.read(languageRiverpod);

      final Map<String, dynamic> data = {
        'teacher_id': widget.teacherId,
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'title': _titleController.text,
        'deskripsi': _deskripsiController.text,
        'jenis': widget.activityType,
        'target': widget.initialTarget,
        'date': _selectedDate!.toIso8601String().split('T')[0],
        'day': _selectedDay,
      };

      // Save chapter_id and sub_chapter_id if selected from materi
      if (_useMaterialTitle && _selectedChapterId != null) {
        data['chapter_id'] = _selectedChapterId;
      } else if (_selectedChapterId != null) {
        // Fallback to old chapter props if exists
        data['chapter_id'] = _selectedChapterId;
      }

      if (_useMaterialTitle && _selectedSubChapterId != null) {
        data['sub_chapter_id'] = _selectedSubChapterId;
      } else if (_selectedSubChapterId != null) {
        // Fallback to old sub chapter props if exists
        data['sub_chapter_id'] = _selectedSubChapterId;
      }

      // Handle Additional Material (from LIVE selection)
      if (_selectedSubChapterIds.isNotEmpty) {
        final List<Map<String, dynamic>> extraMaterials = [];
        final primarySubId = data['sub_chapter_id']?.toString();

        for (var subId in _selectedSubChapterIds) {
          // Skip if this is the primary sub chapter
          if (subId == primarySubId) continue;

          // Try to find full details for this sub chapter
          // 1. Check in loaded sub bab list
          var subChapterData = _subChapterMaterialList.firstWhere(
            (s) => s['id']?.toString() == subId,
            orElse: () => <String, dynamic>{},
          );

          String? chapterIdForSub = _selectedChapterId;

          // 2. If not found (maybe from initial params but not loaded in current list?), check initialAdditionalMaterials
          if (subChapterData == null && widget.initialAdditionalMaterials != null) {
            final found = widget.initialAdditionalMaterials!.firstWhere(
              (m) => m['sub_chapter_id'].toString() == subId,
              orElse: () => {},
            );
            if (found.isNotEmpty) {
              // Construct a temporary object if found in initial params
              subChapterData = {
                'id': subId,
                // We might not have titles here if not standard format, but we do our best
              };
              chapterIdForSub =
                  found['chapter_id']?.toString() ?? _selectedChapterId;
            }
          }

          if (subChapterData.isNotEmpty || chapterIdForSub != null) {
            extraMaterials.add({
              'chapter_id':
                  chapterIdForSub, // Fallback to currently selected bab
              'sub_chapter_id': subId,
            });
          } else {
            // Fallback minimal
            extraMaterials.add({'sub_chapter_id': subId});
          }
        }

        if (extraMaterials.isNotEmpty) {
          data['additional_material'] = extraMaterials;
        }
      }

      if (_deadline != null && widget.activityType == 'tugas') {
        data['batas_waktu'] = _deadline!.toIso8601String();
      }

      // Add target students for specific activities
      final Map<String, dynamic> requestData = Map<String, dynamic>.from(data);
      if (widget.initialTarget == 'khusus' && _selectedStudents.isNotEmpty) {
        requestData['siswa_target'] = _selectedStudents;
      }

      // Call appropriate API based on mode
      if (widget.isEditMode && widget.activityData != null) {
        // Update existing activity
        await getIt<ApiClassActivityService>().updateKegiatan(
          widget.activityData['id'].toString(),
          requestData,
        );
      } else {
        // Create new activity
        await getIt<ApiClassActivityService>().tambahKegiatan(requestData);
      }

      // Automatically mark material as generated (checked)
      if (data['chapter_id'] != null) {
        try {
          // Construct items list for batchSaveMateriProgress
          // Auto-mark as checked (is_checked: true)
          // Note: batchSaveMateriProgress expects different key structure ('progress_items')
          // but getIt<ApiSubjectService>().batchSaveMateriProgress helper handles the mapping from our app structure
          // We just need to match what the internal helper expects or call the API endpoint params directly?
          // Let's check getIt<ApiSubjectService>().batchSaveMateriProgress implementation again.
          // It takes {guru_id, mata_pelajaran_id, progress_items: [{bab_id, sub_bab_id, is_checked}]}

          final List<Map<String, dynamic>> progressItems = [
            {
              'bab_id': data['chapter_id'],
              'sub_bab_id': data['sub_chapter_id'],
              'is_checked': true,
              'is_generated': true,
            },
          ];

          // Add explicitly passed materials to mark as generated
          if (widget.materialsToMarkAsGenerated != null) {
            for (var item in widget.materialsToMarkAsGenerated!) {
              progressItems.add({
                'bab_id': item['bab_id'],
                'sub_bab_id': item['sub_bab_id'],
                'is_checked': true,
                'is_generated': true,
              });
            }
          }

          // Also Add manually selected IDs from the multi-select dialog
          if (_useMaterialTitle &&
              _selectedSubChapterIds.isNotEmpty &&
              _selectedChapterId != null) {
            for (var subId in _selectedSubChapterIds) {
              // Avoid duplicates
              bool exists = progressItems.any(
                (p) => p['sub_bab_id'].toString() == subId,
              );
              if (!exists) {
                progressItems.add({
                  'bab_id': _selectedChapterId,
                  'sub_bab_id': subId,
                  'is_checked': true,
                  'is_generated': true,
                });
              }
            }
          }

          AppLogger.debug('class_activity', '=== BATCH SAVE PROGRESS ===');
          AppLogger.debug('class_activity', 'Progress items: ${progressItems.length}');
          AppLogger.debug('class_activity', 'First item: ${progressItems.first}');

          await getIt<ApiSubjectService>().batchSaveMateriProgress({
            'guru_id': widget.teacherId,
            'mata_pelajaran_id': _selectedSubjectId,
            'class_id': _selectedClassId,
            'progress_items': progressItems,
          });
          AppLogger.debug('class_activity', 'Auto-marked material as generated: ${data['chapter_id']}');
        } catch (e) {
          AppLogger.error('class_activity', 'Error auto-marking material: $e');
        }
      }

      if (!mounted) return;
      AppNavigator.pop(context);
      widget.onActivityAdded();

            SnackBarUtils.showSuccess(context, widget.isEditMode
                ? languageProvider.getTranslatedText({
                    'en': 'Activity updated successfully',
                    'id': 'Kegiatan berhasil diperbarui',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Activity added successfully',
                    'id': 'Kegiatan berhasil ditambahkan',
                  }));
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
        SnackBarUtils.showError(context, message);
  }

  void _openMultiSelectSubBabDialog(LanguageProvider languageProvider) {
    if (_subChapterMaterialList.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        // Local state for the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                languageProvider.getTranslatedText({
                  'en': 'Select Sub Chapters',
                  'id': 'Pilih Sub Bab',
                }),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _subChapterMaterialList.map((subChapter) {
                    final subId = subChapter['id'].toString();
                    final isSelected = _selectedSubChapterIds.contains(subId);
                    return CheckboxListTile(
                      title: Text(_getSubChapterName(subChapter)),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            if (!_selectedSubChapterIds.contains(subId)) {
                              _selectedSubChapterIds.add(subId);
                            }
                          } else {
                            _selectedSubChapterIds.remove(subId);
                          }
                          // Update primary selection for backward compatibility
                          _selectedSubChapterId = _selectedSubChapterIds.isNotEmpty
                              ? _selectedSubChapterIds.first
                              : null;
                        });
                        // Trigger main widget rebuild to update UI text
                        setState(() {});
                        _updateTitleFromMateri();
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => AppNavigator.pop(context),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Done',
                      'id': 'Selesai',
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final isAssignment = widget.activityType == 'tugas';
    final primaryColor = isAssignment
        ? ColorUtils.warning600
        : ColorUtils.corporateBlue600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Gradient Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isAssignment
                            ? Icons.assignment_rounded
                            : Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.isEditMode
                            ? (isAssignment
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Edit Assignment',
                                      'id': 'Edit Tugas',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Edit Material',
                                      'id': 'Edit Materi',
                                    }))
                            : (isAssignment
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Add Assignment',
                                      'id': 'Tambah Tugas',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Add Material',
                                      'id': 'Tambah Materi',
                                    })),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () => AppNavigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Box
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.initialTarget == 'khusus'
                                ? Icons.people
                                : Icons.schedule,
                            color: primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.initialTarget == 'khusus'
                                  ? languageProvider.getTranslatedText({
                                      'en':
                                          'SPECIFIC: You can select any class anytime.',
                                      'id':
                                          'KHUSUS: Anda dapat memilih kelas kapan saja.',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en':
                                          'GENERAL: Only classes from start time to +23 hours are available.',
                                      'id':
                                          'UMUM: Hanya kelas dari jam mulai sampai +23 jam yang tersedia.',
                                    }),
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mata Pelajaran
                    Builder(
                      builder: (context) {
                        final Map<String, DropdownMenuItem<String>>
                        uniqueSubjectItems = {};
                        for (var subject in widget.subjectList) {
                          final id = subject['id']?.toString();
                          if (id != null &&
                              !uniqueSubjectItems.containsKey(id)) {
                            uniqueSubjectItems[id] = DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                subject['name'] ?? subject['nama'] ?? 'Unknown',
                              ),
                            );
                          }
                        }
                        final List<DropdownMenuItem<String>> subjectItems =
                            uniqueSubjectItems.values.toList();

                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'subject_${_selectedSubjectId}_${subjectItems.length}',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})} *',
                            prefixIcon: Icon(Icons.book),
                            border: OutlineInputBorder(),
                          ),
                          initialValue:
                              (subjectItems.any(
                                (item) => item.value == _selectedSubjectId,
                              ))
                              ? _selectedSubjectId
                              : null,
                          isExpanded: true,
                          items: subjectItems.isEmpty ? null : subjectItems,
                          onChanged: subjectItems.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedSubjectId = value;
                                    _selectedClassId = null;
                                  });
                                  if (value != null) {
                                    widget.onSubjectSelected(value);
                                    _loadChapterMaterials(value);
                                  }
                                },
                          validator: (value) => value == null
                              ? languageProvider.getTranslatedText({
                                  'en': 'Required',
                                  'id': 'Wajib diisi',
                                })
                              : null,
                          hint: Text(
                            subjectItems.isEmpty
                                ? languageProvider.getTranslatedText({
                                    'en': 'No subjects available',
                                    'id': 'Tidak ada mata pelajaran',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Select Subject',
                                    'id': 'Pilih Mata Pelajaran',
                                  }),
                          ),
                        );
                      },
                    ),
                    if (widget.subjectList.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en':
                                'No teaching subjects found. Please check your schedule.',
                            'id':
                                'Tidak ada mata pelajaran mengajar. Silakan periksa jadwal Anda.',
                          }),
                          style: TextStyle(
                            color: ColorUtils.error600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.md),

                    // Kelas
                    Builder(
                      builder: (context) {
                        final List<DropdownMenuItem<String>> classItems =
                            _selectedSubjectId == null
                            ? []
                            : _getUniqueClassItems();

                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'class_${_selectedClassId}_${classItems.length}',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})} *',
                            prefixIcon: Icon(Icons.class_),
                            border: OutlineInputBorder(),
                          ),
                          initialValue:
                              (_selectedClassId != null &&
                                  classItems.any(
                                    (item) => item.value == _selectedClassId,
                                  ))
                              ? _selectedClassId
                              : null,
                          isExpanded: true,
                          items: classItems.isEmpty ? null : classItems,
                          onChanged: _selectedSubjectId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedClassId = value;
                                  });

                                  // Defer loading students to let the dropdown update complete
                                  if (widget.initialTarget == 'khusus') {
                                    Future.delayed(
                                      Duration(milliseconds: 100),
                                      () {
                                        if (mounted) _loadStudents();
                                      },
                                    );
                                  }
                                },
                          validator: (value) => value == null
                              ? languageProvider.getTranslatedText({
                                  'en': 'Required',
                                  'id': 'Wajib diisi',
                                })
                              : null,
                          hint: Text(
                            _selectedSubjectId == null
                                ? languageProvider.getTranslatedText({
                                    'en': 'Select subject first',
                                    'id': 'Pilih mata pelajaran dulu',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Select Class',
                                    'id': 'Pilih Kelas',
                                  }),
                          ),
                        );
                      },
                    ),
                    if (_selectedSubjectId != null &&
                        _getUniqueClassItems().isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          widget.initialTarget == 'khusus'
                              ? languageProvider.getTranslatedText({
                                  'en': 'No classes found for this subject.',
                                  'id':
                                      'Tidak ada kelas untuk mata pelajaran ini.',
                                })
                              : languageProvider.getTranslatedText({
                                  'en':
                                      'No active classes now. You can fill from class start time until +23 hours.',
                                  'id':
                                      'Tidak ada kelas aktif saat ini. Anda dapat mengisi dari jam pelajaran mulai sampai +23 jam.',
                                }),
                          style: TextStyle(
                            color: ColorUtils.warning600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.md),

                    // Toggle: Select from Material or Write Manually
                    Row(
                      children: [
                        Icon(Icons.title, size: 20, color: ColorUtils.slate600),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Choose from material',
                            'id': 'Pilih dari materi',
                          }),
                          style: TextStyle(fontSize: 14),
                        ),
                        Spacer(),
                        Switch(
                          value: _useMaterialTitle,
                          onChanged: _selectedSubjectId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _useMaterialTitle = value;
                                    if (!value) {
                                      // Reset when switching to manual
                                      _selectedChapterId = null;
                                      _selectedSubChapterId = null;
                                    }
                                  });
                                },
                          activeThumbColor: primaryColor,
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),

                    // Dropdown Chapter Materials (if useMaterialTitle = true)
                    if (_useMaterialTitle) ...[
                      Builder(
                        builder: (context) {
                          final Map<String, DropdownMenuItem<String>>
                          uniqueChapterItems = {};
                          for (var chapter in _chapterMaterialList) {
                            final id = chapter['id']?.toString();
                            if (id != null && !uniqueChapterItems.containsKey(id)) {
                              uniqueChapterItems[id] = DropdownMenuItem<String>(
                                value: id,
                                child: Text(_getChapterName(chapter)),
                              );
                            }
                          }
                          final List<DropdownMenuItem<String>> babItems =
                              uniqueChapterItems.values.toList();

                          return DropdownButtonFormField<String>(
                            key: ValueKey(
                              'bab_${_selectedChapterId}_${babItems.length}',
                            ),
                            decoration: InputDecoration(
                              labelText: languageProvider.getTranslatedText({
                                'en': 'Chapter',
                                'id': 'Bab Materi',
                              }),
                              prefixIcon: Icon(Icons.menu_book),
                              border: OutlineInputBorder(),
                            ),
                            initialValue:
                                (babItems.any(
                                  (item) => item.value == _selectedChapterId,
                                ))
                                ? _selectedChapterId
                                : null,
                            isExpanded: true,
                            items: babItems.isEmpty ? null : babItems,
                            onChanged: babItems.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedChapterId = value;
                                      _selectedSubChapterId = null;
                                    });
                                    if (value != null) {
                                      _loadSubBabMateri(value);
                                      _updateTitleFromMateri();
                                    }
                                  },
                            hint: Text(
                              languageProvider.getTranslatedText({
                                'en': _isLoadingChapters
                                    ? 'Loading chapters...'
                                    : (babItems.isEmpty
                                          ? 'No chapters found'
                                          : 'Select Chapter'),
                                'id': _isLoadingChapters
                                    ? 'Memuat bab...'
                                    : (babItems.isEmpty
                                          ? 'Tidak ada bab'
                                          : 'Pilih Bab'),
                              }),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],

                    // Multi-Select Sub Bab (if bab is selected) - Custom UI
                    if (_useMaterialTitle && _selectedChapterId != null) ...[
                      InkWell(
                        onTap: () =>
                            _openMultiSelectSubBabDialog(languageProvider),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: languageProvider.getTranslatedText({
                              'en': 'Sub Chapters',
                              'id': 'Sub Bab Materi',
                            }),
                            prefixIcon: Icon(Icons.article),
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _selectedSubChapterIds.isEmpty
                                ? languageProvider.getTranslatedText({
                                    'en': 'Select Sub Chapters (optional)',
                                    'id': 'Pilih Sub Bab (opsional)',
                                  })
                                : _selectedSubChapterIds.length == 1
                                ? _getSubChapterName(
                                    _subChapterMaterialList.firstWhere(
                                      (s) =>
                                          s['id'].toString() ==
                                          _selectedSubChapterIds.first,
                                      orElse: () => {},
                                    ),
                                  )
                                : '${_selectedSubChapterIds.length} ${languageProvider.getTranslatedText({'en': 'selected', 'id': 'dipilih'})}',
                            style: TextStyle(
                              color: _selectedSubChapterIds.isEmpty
                                  ? ColorUtils.slate600
                                  : ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],

                    // Judul Field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText:
                            '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                        helperText: _useMaterialTitle
                            ? languageProvider.getTranslatedText({
                                'en': 'Auto-filled from chapter/sub-chapter',
                                'id': 'Otomatis dari bab/sub bab',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'Enter title manually',
                                'id': 'Tulis judul manual',
                              }),
                      ),
                      readOnly:
                          _useMaterialTitle &&
                          (_selectedChapterId != null || _selectedSubChapterId != null),
                      validator: (value) => value == null || value.isEmpty
                          ? languageProvider.getTranslatedText({
                              'en': 'Required',
                              'id': 'Wajib diisi',
                            })
                          : null,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Deskripsi
                    TextFormField(
                      controller: _deskripsiController,
                      decoration: InputDecoration(
                        labelText: languageProvider.getTranslatedText({
                          'en': 'Description',
                          'id': 'Deskripsi',
                        }),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Tanggal
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today),
                      title: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Date',
                          'id': 'Tanggal',
                        }),
                      ),
                      subtitle: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Pilih tanggal',
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        // Allow selecting dates within the current semester
                        final now = DateTime.now();
                        final isGenap = now.month >= 1 && now.month <= 6;
                        final semesterStart = isGenap
                            ? DateTime(now.year, 1, 1)
                            : DateTime(now.year, 7, 1);
                        final semesterEnd = isGenap
                            ? DateTime(now.year, 6, 30)
                            : DateTime(now.year, 12, 31);

                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: semesterStart,
                          lastDate: semesterEnd,
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _selectedDay = _days[date.weekday - 1];
                          });
                        }
                      },
                    ),

                    // Deadline (only for Assignments)
                    if (isAssignment) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.alarm),
                        title: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Deadline',
                            'id': 'Batas Waktu',
                          }),
                        ),
                        subtitle: Text(
                          _deadline != null
                              ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year} ${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                              : 'Pilih batas waktu (opsional)',
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _deadline ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() {
                                _deadline = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ],

                    // Select Students (only for specific target)
                    if (widget.initialTarget == 'khusus' &&
                        _selectedClassId != null) ...[
                      SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Select Students',
                                    'id': 'Pilih Siswa',
                                  }),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (kDebugMode)
                                  Text(
                                    'Debug: Target=${widget.initialTarget}, Count=${_studentList.length}, Loading=$_isLoadingStudents',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ColorUtils.slate400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, size: 20),
                            onPressed: _loadStudents,
                            tooltip: 'Refresh Students',
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Container(
                        height: 200, // Increased height for better visibility
                        decoration: BoxDecoration(
                          border: Border.all(color: ColorUtils.slate400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoadingStudents
                            ? Center(child: CircularProgressIndicator())
                            : _studentList.isEmpty
                            ? Center(child: Text('Tidak ada siswa'))
                            : SingleChildScrollView(
                                child: Column(
                                  children: _studentList.map((student) {
                                    final studentId = student['id'].toString();
                                    final isSelected = _selectedStudents
                                        .contains(studentId);
                                    return ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                      dense: true,
                                      title: Text(
                                        student['name']?.toString() ??
                                            student['nama']?.toString() ??
                                            'Unknown',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        student['student_number']?.toString() ??
                                            student['nis']?.toString() ??
                                            '',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        onChanged: (bool? checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedStudents.add(studentId);
                                            } else {
                                              _selectedStudents.remove(
                                                studentId,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedStudents.remove(studentId);
                                          } else {
                                            _selectedStudents.add(studentId);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.isEditMode
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Update',
                                      'id': 'Simpan Perubahan',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Add',
                                      'id': 'Tambah',
                                    }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
