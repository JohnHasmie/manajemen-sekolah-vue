import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_action_bar.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_material_selector.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_student_selector.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_target_info_box.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

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
  final _descriptionController = TextEditingController();
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

  // Chapter & Sub-chapter materials
  bool _isLoadingChapters = false;
  List<dynamic> _chapterMaterialList = [];
  List<dynamic> _subChapterMaterialList = [];
  final List<String> _selectedSubChapterIds = []; // Multi-selection support
  bool _useMaterialTitle = false; // Toggle: use bab/sub bab or manual input

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
      _descriptionController.text =
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

    // If initial subject is provided, load its data
    if (_selectedSubjectId != null) {
      Future.delayed(Duration.zero, () {
        AppLogger.debug(
          'class_activity',
          'Loading initial data for subject: $_selectedSubjectId',
        );

        widget.onSubjectSelected(_selectedSubjectId!);
        // Load bab materi for the initial subject
        _loadChapterContent(_selectedSubjectId!).then((_) {
          // After bab list loaded, load sub bab if initial bab is provided
          if (_selectedChapterId != null) {
            AppLogger.debug(
              'class_activity',
              'Loading sub bab for bab: $_selectedChapterId',
            );
            _loadSubChapterContent(_selectedChapterId!).then((_) {
              // After sub bab loaded, update title
              _updateTitleFromMaterial();
            });
          } else {
            // Only bab selected, update title
            _updateTitleFromMaterial();
          }
        });

        // If initial class is provided and target is 'khusus', load students
        if (_selectedClassId != null && widget.initialTarget == 'khusus') {
          AppLogger.debug(
            'class_activity',
            'Loading students for class: $_selectedClassId',
          );
          _loadStudents();
        }
      });
    } else {
      AppLogger.debug(
        'class_activity',
        'No initial subject ID - waiting for user selection',
      );
    }

    AppLogger.debug('class_activity', '=====================================');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;

    setState(() {
      _isLoadingStudents = true;
      _studentList = []; // Clear previous list
    });

    AppLogger.debug(
      'class_activity',
      '[_loadStudents] Starting load for class: $_selectedClassId',
    );

    try {
      final students = await getIt<ApiClassActivityService>().getStudentsByClass(
        _selectedClassId!,
      );

      if (!mounted) {
        AppLogger.debug(
          'class_activity',
          '[_loadStudents] Widget unmounted, skipping setState',
        );
        return;
      }

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

  Future<void> _loadChapterContent(String subjectId) async {
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
          ? (subject['subject_id']?.toString() ??
                subject['id']?.toString() ??
                subjectId)
          : subjectId;

      final chapterList = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: masterSubjectId,
      );

      if (kDebugMode) {
        AppLogger.debug(
          'class_activity',
          'API Response - Bab count: ${chapterList.length}',
        );
        if (chapterList.isNotEmpty) {
          AppLogger.debug(
            'class_activity',
            'First item structure: ${chapterList[0]}',
          );
          AppLogger.debug(
            'class_activity',
            'Available fields: ${chapterList[0].keys}',
          );
          AppLogger.debug(
            'class_activity',
            'Judul Bab: ${chapterList[0]['judul_bab']}',
          );
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

      AppLogger.debug(
        'class_activity',
        'State updated - _chapterMaterialList.length: ${_chapterMaterialList.length}',
      );
      AppLogger.debug(
        'class_activity',
        'Current _selectedChapterId: $_selectedChapterId',
      );
      AppLogger.debug(
        'class_activity',
        'Current _selectedSubChapterId: $_selectedSubChapterId',
      );
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

  Future<void> _loadSubChapterContent(String chapterId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING SUB BAB MATERI =====');
      AppLogger.debug('class_activity', 'Bab ID: $chapterId');

      final subChapterList = await getIt<ApiSubjectService>()
          .getSubChapterMaterials(chapterId: chapterId);

      if (kDebugMode) {
        AppLogger.debug(
          'class_activity',
          'API Response - Sub Bab count: ${subChapterList.length}',
        );
        if (subChapterList.isNotEmpty) {
          AppLogger.debug(
            'class_activity',
            'First item structure: ${subChapterList[0]}',
          );
          AppLogger.debug(
            'class_activity',
            'Available fields: ${subChapterList[0].keys}',
          );
          AppLogger.debug(
            'class_activity',
            'Judul Sub Bab: ${subChapterList[0]['judul_sub_bab']}',
          );
        }
      }

      setState(() {
        _subChapterMaterialList = subChapterList;
        // Only reset if no initial value was provided
        if (widget.initialSubChapterId == null) {
          _selectedSubChapterId = null;
        }
      });

      AppLogger.debug(
        'class_activity',
        'State updated - _subChapterMaterialList.length: ${_subChapterMaterialList.length}',
      );
      AppLogger.debug(
        'class_activity',
        'Current _selectedSubChapterId: $_selectedSubChapterId',
      );
      AppLogger.debug('class_activity', '==================================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading sub bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  String _getChapterName(dynamic chapter) {
    // Try multiple possible field names (backend returns 'chapter_title')
    return chapter['chapter_title']?.toString() ??
        chapter['judul_bab']?.toString() ??
        chapter['nama']?.toString() ??
        chapter['judul']?.toString() ??
        chapter['title']?.toString() ??
        chapter['name']?.toString() ??
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

  void _updateTitleFromMaterial() {
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

    // Filter schedules by selected subject and deduplicate by class_id
    for (var schedule in widget.scheduleList) {
      final scheduleSubjectId =
          (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();

      AppLogger.debug(
        'class_activity',
        'Checking schedule: ${schedule['id']} - Subject: $scheduleSubjectId vs Selected: $_selectedSubjectId',
      );

      if (scheduleSubjectId == _selectedSubjectId) {
        final classId = (schedule['class_id'] ?? schedule['kelas_id'])
            .toString();

        // For SPECIFIC target: no time filter, all schedules can be selected
        if (widget.initialTarget == 'khusus') {
          if (!uniqueClasses.containsKey(classId)) {
            uniqueClasses[classId] = {
              'id': classId,
              'name': schedule['kelas_nama'] ?? 'Unknown',
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
                'name': schedule['kelas_nama'] ?? 'Unknown',
              };
              AppLogger.debug(
                'class_activity',
                'Added class from initialClassId: ${schedule['kelas_nama']}',
              );
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

            AppLogger.debug(
              'class_activity',
              'Schedule: ${schedule['kelas_nama']}, Day: $scheduleDay vs Target: $targetDay',
            );

            // Check if schedule is on the selected day
            if (scheduleDay == targetDay) {
              // Time validation removed to ensure classes always appear for the day
              // Original logic checked start_time + 23h, but this was too strict/buggy
              if (!uniqueClasses.containsKey(classId)) {
                uniqueClasses[classId] = {
                  'id': classId,
                  'name': schedule['kelas_nama'] ?? 'Unknown',
                };
              } else {
                AppLogger.debug(
                  'class_activity',
                  'Class already added: $classId',
                );
              }
            } else {
              AppLogger.debug(
                'class_activity',
                'Day mismatch: $scheduleDay != $targetDay',
              );
            }
          }
        }
      }
    }

    // Convert to dropdown items safely
    try {
      return uniqueClasses.values.map((classItem) {
        return DropdownMenuItem<String>(
          value: classItem['id'].toString(),
          child: Text(classItem['name'] ?? 'Unknown'),
        );
      }).toList();
    } catch (e) {
      AppLogger.error(
        'class_activity',
        'Error generating class dropdown items: $e',
      );
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
        'deskripsi': _descriptionController.text,
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
          if (subChapterData == null &&
              widget.initialAdditionalMaterials != null) {
            final found = widget.initialAdditionalMaterials!.firstWhere(
              (m) => m['sub_chapter_id'].toString() == subId,
              orElse: () => {},
            );
            if (found.isNotEmpty) {
              // Construct a temporary object if found in initial params
              subChapterData = {
                'id': subId,
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
        await getIt<ApiClassActivityService>().updateActivity(
          widget.activityData['id'].toString(),
          requestData,
        );
      } else {
        // Create new activity
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
              final bool exists = progressItems.any(
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
          AppLogger.debug(
            'class_activity',
            'Progress items: ${progressItems.length}',
          );
          AppLogger.debug(
            'class_activity',
            'First item: ${progressItems.first}',
          );

          await getIt<ApiSubjectService>().batchSaveMateriProgress({
            'guru_id': widget.teacherId,
            'mata_pelajaran_id': _selectedSubjectId,
            'class_id': _selectedClassId,
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
      AppNavigator.pop(context);
      widget.onActivityAdded();

      SnackBarUtils.showSuccess(
        context,
        widget.isEditMode
            ? languageProvider.getTranslatedText({
                'en': 'Activity updated successfully',
                'id': 'Kegiatan berhasil diperbarui',
              })
            : languageProvider.getTranslatedText({
                'en': 'Activity added successfully',
                'id': 'Kegiatan berhasil ditambahkan',
              }),
      );
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
                          _selectedSubChapterId =
                              _selectedSubChapterIds.isNotEmpty
                              ? _selectedSubChapterIds.first
                              : null;
                        });
                        // Trigger main widget rebuild to update UI text
                        setState(() {});
                        _updateTitleFromMaterial();
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
          AddActivityHeader(
            activityType: widget.activityType,
            isEditMode: widget.isEditMode,
            primaryColor: primaryColor,
            languageProvider: languageProvider,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Box
                    AddActivityTargetInfoBox(
                      initialTarget: widget.initialTarget,
                      primaryColor: primaryColor,
                      languageProvider: languageProvider,
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
                                    _loadChapterContent(value);
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
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          AppLocalizations.noTeachingSubjects.tr,
                          style: TextStyle(
                            color: ColorUtils.error600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),

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
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          widget.initialTarget == 'khusus'
                              ? AppLocalizations.noClassesForSubject.tr
                              : AppLocalizations.noActiveClasses.tr,
                          style: TextStyle(
                            color: ColorUtils.warning600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),

                    // Toggle + Chapter + Sub-chapter selector
                    AddActivityMaterialSelector(
                      useMaterialTitle: _useMaterialTitle,
                      isLoadingChapters: _isLoadingChapters,
                      selectedSubjectId: _selectedSubjectId,
                      selectedChapterId: _selectedChapterId,
                      selectedSubChapterIds: _selectedSubChapterIds,
                      chapterMaterialList: _chapterMaterialList,
                      subChapterMaterialList: _subChapterMaterialList,
                      primaryColor: primaryColor,
                      languageProvider: languageProvider,
                      onToggleMaterialTitle: (value) {
                        setState(() {
                          _useMaterialTitle = value;
                          if (!value) {
                            _selectedChapterId = null;
                            _selectedSubChapterId = null;
                          }
                        });
                      },
                      onChapterChanged: (value) {
                        setState(() {
                          _selectedChapterId = value;
                          _selectedSubChapterId = null;
                        });
                        if (value != null) {
                          _loadSubChapterContent(value);
                          _updateTitleFromMaterial();
                        }
                      },
                      onSubChapterTap: () =>
                          _openMultiSelectSubBabDialog(languageProvider),
                      getChapterName: _getChapterName,
                      getSubChapterName: _getSubChapterName,
                    ),

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
                          (_selectedChapterId != null ||
                              _selectedSubChapterId != null),
                      validator: (value) => value == null || value.isEmpty
                          ? languageProvider.getTranslatedText({
                              'en': 'Required',
                              'id': 'Wajib diisi',
                            })
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Deskripsi
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.getTranslatedText({
                          'en': 'Description',
                          'id': 'Deskripsi',
                        }),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),

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
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
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
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _deadline ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            if (!mounted) return;
                            final time = await showTimePicker(
                              // ignore: use_build_context_synchronously
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
                        _selectedClassId != null)
                      AddActivityStudentSelector(
                        studentList: _studentList,
                        selectedStudents: _selectedStudents,
                        isLoading: _isLoadingStudents,
                        initialTarget: widget.initialTarget,
                        onRefresh: _loadStudents,
                        onToggleStudent: (studentId, selected) {
                          setState(() {
                            if (selected) {
                              _selectedStudents.add(studentId);
                            } else {
                              _selectedStudents.remove(studentId);
                            }
                          });
                        },
                        languageProvider: languageProvider,
                      ),
                  ],
                ),
              ),
            ),
          ),
          AddActivityActionBar(
            isSubmitting: _isSubmitting,
            isEditMode: widget.isEditMode,
            primaryColor: primaryColor,
            languageProvider: languageProvider,
            onSubmit: _submitForm,
          ),
        ],
      ),
    );
  }
}
