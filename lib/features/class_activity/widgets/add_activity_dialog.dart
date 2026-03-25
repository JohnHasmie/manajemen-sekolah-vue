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
import 'package:provider/provider.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

class AddActivityDialog extends StatefulWidget {
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
  final String? initialBabId;
  final String? initialSubBabId;
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
    this.initialBabId,
    this.initialSubBabId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.isEditMode = false,
    this.activityData,
  });

  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
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
  bool _isLoadingBab = false;
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  String? _selectedBabId;
  String? _selectedSubBabId; // Primary selection (kept for backward compat)
  final List<String> _selectedSubBabIds = []; // Multi-selection support
  bool _useMateriTitle = false; // Toggle: use bab/sub bab or manual input

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
    _selectedBabId = widget.initialBabId;
    _selectedSubBabId = widget.initialSubBabId;

    // Initialize multi-select list
    if (_selectedSubBabId != null) {
      _selectedSubBabIds.add(_selectedSubBabId!);
    }
    if (widget.initialAdditionalMaterials != null) {
      for (var item in widget.initialAdditionalMaterials!) {
        final subId = item['sub_chapter_id']?.toString();
        if (subId != null && !_selectedSubBabIds.contains(subId)) {
          _selectedSubBabIds.add(subId);
        }
      }
    }

    // If in edit mode, populate form with existing data
    if (widget.isEditMode && widget.activityData != null) {
      _judulController.text = widget.activityData['judul']?.toString() ?? '';
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
        final siswaTarget = widget.activityData['siswa_target'];
        if (siswaTarget is List) {
          _selectedStudents.addAll(siswaTarget.map((s) => s.toString()));
        }
      }
    }

    // If initial bab is provided, enable material title mode
    if (_selectedBabId != null || _selectedSubBabId != null) {
      _useMateriTitle = true;
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
    //   print('Initial bab ID: $_selectedBabId');
    //   print('Initial sub bab ID: $_selectedSubBabId');
    //   print('Use materi title: $_useMateriTitle');
    //   print('Initial date: $_selectedDate');
    // }

    // If initial subject is provided, load its data
    if (_selectedSubjectId != null) {
      Future.delayed(Duration.zero, () {
        AppLogger.debug('class_activity', 'Loading initial data for subject: $_selectedSubjectId');

        widget.onSubjectSelected(_selectedSubjectId!);
        // Load bab materi for the initial subject
        _loadBabMateri(_selectedSubjectId!).then((_) {
          // After bab list loaded, load sub bab if initial bab is provided
          if (_selectedBabId != null) {
            AppLogger.debug('class_activity', 'Loading sub bab for bab: $_selectedBabId');
            _loadSubBabMateri(_selectedBabId!).then((_) {
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
    _judulController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadBabMateri(String subjectId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING BAB MATERI =====');
      AppLogger.debug('class_activity', 'Subject ID: $subjectId');

      setState(() {
        _isLoadingBab = true;
        _babMateriList = []; // Clear previous list while loading
      });

      // Find Master Subject ID from the selected School Subject ID
      final subject = widget.subjectList.firstWhere(
        (s) => s['id']?.toString() == subjectId,
        orElse: () => <String, dynamic>{},
      );
      final masterSubjectId = subject.isEmpty
          ? null
          : subject['subject_id']?.toString();

      if (masterSubjectId == null) {
        AppLogger.error('class_activity', 'Error: Master Subject ID not found for subject $subjectId');
        return;
      }

      final babList = await getIt<ApiSubjectService>().getBabMateri(
        subjectId: masterSubjectId,
      );

      if (kDebugMode) {
        AppLogger.debug('class_activity', 'API Response - Bab count: ${babList.length}');
        if (babList.isNotEmpty) {
          AppLogger.debug('class_activity', 'First item structure: ${babList[0]}');
          AppLogger.debug('class_activity', 'Available fields: ${babList[0].keys}');
          AppLogger.debug('class_activity', 'Judul Bab: ${babList[0]['judul_bab']}');
        }
      }

      setState(() {
        _babMateriList = babList;
        // Only reset if no initial values were provided
        if (widget.initialBabId == null) {
          _selectedBabId = null;
        }
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
        // Only clear sub bab list if no initial sub bab
        if (widget.initialSubBabId == null) {
          _subBabMateriList = [];
        }
        _isLoadingBab = false;
      });

      AppLogger.debug('class_activity', 'State updated - _babMateriList.length: ${_babMateriList.length}',);
      AppLogger.debug('class_activity', 'Current _selectedBabId: $_selectedBabId');
      AppLogger.debug('class_activity', 'Current _selectedSubBabId: $_selectedSubBabId');
      AppLogger.debug('class_activity', '=============================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoadingBab = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadSubBabMateri(String babId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING SUB BAB MATERI =====');
      AppLogger.debug('class_activity', 'Bab ID: $babId');

      final subBabList = await getIt<ApiSubjectService>().getSubBabMateri(babId: babId);

      if (kDebugMode) {
        AppLogger.debug('class_activity', 'API Response - Sub Bab count: ${subBabList.length}');
        if (subBabList.isNotEmpty) {
          AppLogger.debug('class_activity', 'First item structure: ${subBabList[0]}');
          AppLogger.debug('class_activity', 'Available fields: ${subBabList[0].keys}');
          AppLogger.debug('class_activity', 'Judul Sub Bab: ${subBabList[0]['judul_sub_bab']}');
        }
      }

      setState(() {
        _subBabMateriList = subBabList;
        // Only reset if no initial value was provided
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
      });

      AppLogger.debug('class_activity', 'State updated - _subBabMateriList.length: ${_subBabMateriList.length}',);
      AppLogger.debug('class_activity', 'Current _selectedSubBabId: $_selectedSubBabId');
      AppLogger.debug('class_activity', '==================================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading sub bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  String _getBabName(dynamic bab) {
    // Try multiple possible field names (backend returns 'chapter_title')
    return bab['chapter_title']?.toString() ??
        bab['judul_bab']?.toString() ??
        bab['nama']?.toString() ??
        bab['judul']?.toString() ??
        bab['title']?.toString() ??
        bab['name']?.toString() ??
        'Unknown';
  }

  String _getSubBabName(dynamic subBab) {
    // Try multiple possible field names (backend returns 'sub_chapter_title')
    return subBab['sub_chapter_title']?.toString() ??
        subBab['judul_sub_bab']?.toString() ??
        subBab['nama']?.toString() ??
        subBab['judul']?.toString() ??
        subBab['title']?.toString() ??
        subBab['name']?.toString() ??
        'Unknown';
  }

  void _updateTitleFromMateri() {
    String babName = '';
    String subBabName = '';

    // Get bab name if selected
    if (_selectedBabId != null && _babMateriList.isNotEmpty) {
      final bab = _babMateriList.firstWhere(
        (b) => b['id']?.toString() == _selectedBabId,
        orElse: () => <String, dynamic>{},
      );
      if (bab.isNotEmpty) {
        // Check if the map is not empty
        babName = _getBabName(bab);
      }
    }

    // Get sub bab name if selected
    if (_selectedSubBabId != null && _subBabMateriList.isNotEmpty) {
      final subBab = _subBabMateriList.firstWhere(
        (item) => item['id']?.toString() == _selectedSubBabId,
        orElse: () => <String, dynamic>{},
      );
      if (subBab.isNotEmpty) {
        subBabName = _getSubBabName(subBab);
      }
    }

    // Build title based on what's selected
    String title = '';
    if (babName.isNotEmpty && subBabName.isNotEmpty) {
      // Both selected: "Bab - Sub Bab"
      title = '$babName - $subBabName';
    } else if (babName.isNotEmpty) {
      // Only bab selected
      title = babName;
    } else if (subBabName.isNotEmpty) {
      // Only sub bab selected (edge case)
      title = subBabName;
    }

    if (title.isNotEmpty && title != 'Unknown') {
      _judulController.text = title;
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

        // Untuk target KHUSUS: tidak ada filter waktu, semua jadwal bisa dipilih
        if (widget.initialTarget == 'khusus') {
          if (!uniqueClasses.containsKey(classId)) {
            uniqueClasses[classId] = {
              'id': classId,
              'nama': schedule['kelas_nama'] ?? 'Unknown',
            };
          }
        }
        // Untuk target UMUM
        else {
          // Jika ada initialClassId (dari teaching schedule), selalu include kelas tersebut
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
          // Filter berdasarkan waktu untuk kelas lainnya
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
      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );

      final Map<String, dynamic> data = {
        'teacher_id': widget.teacherId,
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'title': _judulController.text,
        'deskripsi': _deskripsiController.text,
        'jenis': widget.activityType,
        'target': widget.initialTarget,
        'date': _selectedDate!.toIso8601String().split('T')[0],
        'day': _selectedDay,
      };

      // Save chapter_id and sub_chapter_id if selected from materi
      if (_useMateriTitle && _selectedBabId != null) {
        data['chapter_id'] = _selectedBabId;
      } else if (_selectedChapterId != null) {
        // Fallback to old chapter props if exists
        data['chapter_id'] = _selectedChapterId;
      }

      if (_useMateriTitle && _selectedSubBabId != null) {
        data['sub_chapter_id'] = _selectedSubBabId;
      } else if (_selectedSubChapterId != null) {
        // Fallback to old sub chapter props if exists
        data['sub_chapter_id'] = _selectedSubChapterId;
      }

      // Handle Additional Material (from LIVE selection)
      if (_selectedSubBabIds.isNotEmpty) {
        final List<Map<String, dynamic>> extraMaterials = [];
        final primarySubId = data['sub_chapter_id']?.toString();

        for (var subId in _selectedSubBabIds) {
          // Skip if this is the primary sub chapter
          if (subId == primarySubId) continue;

          // Try to find full details for this sub chapter
          // 1. Check in loaded sub bab list
          var subBabData = _subBabMateriList.firstWhere(
            (s) => s['id']?.toString() == subId,
            orElse: () => <String, dynamic>{},
          );

          String? chapterIdForSub = _selectedBabId;

          // 2. If not found (maybe from initial params but not loaded in current list?), check initialAdditionalMaterials
          if (subBabData == null && widget.initialAdditionalMaterials != null) {
            final found = widget.initialAdditionalMaterials!.firstWhere(
              (m) => m['sub_chapter_id'].toString() == subId,
              orElse: () => {},
            );
            if (found.isNotEmpty) {
              // Construct a temporary object if found in initial params
              subBabData = {
                'id': subId,
                // We might not have titles here if not standard format, but we do our best
              };
              chapterIdForSub =
                  found['chapter_id']?.toString() ?? _selectedBabId;
            }
          }

          if (subBabData.isNotEmpty || chapterIdForSub != null) {
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

      // Tambahkan siswa target untuk kegiatan khusus
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
          if (_useMateriTitle &&
              _selectedSubBabIds.isNotEmpty &&
              _selectedBabId != null) {
            for (var subId in _selectedSubBabIds) {
              // Avoid duplicates
              bool exists = progressItems.any(
                (p) => p['sub_bab_id'].toString() == subId,
              );
              if (!exists) {
                progressItems.add({
                  'bab_id': _selectedBabId,
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
      Navigator.pop(context);
      widget.onActivityAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? languageProvider.getTranslatedText({
                    'en': 'Activity updated successfully',
                    'id': 'Kegiatan berhasil diperbarui',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Activity added successfully',
                    'id': 'Kegiatan berhasil ditambahkan',
                  }),
          ),
          backgroundColor: ColorUtils.success600,
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ColorUtils.error600),
    );
  }

  void _openMultiSelectSubBabDialog(LanguageProvider languageProvider) {
    if (_subBabMateriList.isEmpty) return;

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
                  children: _subBabMateriList.map((subBab) {
                    final subId = subBab['id'].toString();
                    final isSelected = _selectedSubBabIds.contains(subId);
                    return CheckboxListTile(
                      title: Text(_getSubBabName(subBab)),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            if (!_selectedSubBabIds.contains(subId)) {
                              _selectedSubBabIds.add(subId);
                            }
                          } else {
                            _selectedSubBabIds.remove(subId);
                          }
                          // Update primary selection for backward compatibility
                          _selectedSubBabId = _selectedSubBabIds.isNotEmpty
                              ? _selectedSubBabIds.first
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
                  onPressed: () => Navigator.pop(context),
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
    final languageProvider = Provider.of<LanguageProvider>(context);
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
                    SizedBox(width: 12),
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
                        padding: EdgeInsets.all(4),
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Box
                    Container(
                      padding: EdgeInsets.all(12),
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
                          SizedBox(width: 8),
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
                                    _loadBabMateri(value);
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
                    SizedBox(height: 12),

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
                    SizedBox(height: 12),

                    // Toggle: Pilih dari Materi atau Tulis Manual
                    Row(
                      children: [
                        Icon(Icons.title, size: 20, color: ColorUtils.slate600),
                        SizedBox(width: 8),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Choose from material',
                            'id': 'Pilih dari materi',
                          }),
                          style: TextStyle(fontSize: 14),
                        ),
                        Spacer(),
                        Switch(
                          value: _useMateriTitle,
                          onChanged: _selectedSubjectId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _useMateriTitle = value;
                                    if (!value) {
                                      // Reset when switching to manual
                                      _selectedBabId = null;
                                      _selectedSubBabId = null;
                                    }
                                  });
                                },
                          activeThumbColor: primaryColor,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),

                    // Dropdown Bab Materi (if useMateriTitle = true)
                    if (_useMateriTitle) ...[
                      Builder(
                        builder: (context) {
                          final Map<String, DropdownMenuItem<String>>
                          uniqueBabItems = {};
                          for (var bab in _babMateriList) {
                            final id = bab['id']?.toString();
                            if (id != null && !uniqueBabItems.containsKey(id)) {
                              uniqueBabItems[id] = DropdownMenuItem<String>(
                                value: id,
                                child: Text(_getBabName(bab)),
                              );
                            }
                          }
                          final List<DropdownMenuItem<String>> babItems =
                              uniqueBabItems.values.toList();

                          return DropdownButtonFormField<String>(
                            key: ValueKey(
                              'bab_${_selectedBabId}_${babItems.length}',
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
                                  (item) => item.value == _selectedBabId,
                                ))
                                ? _selectedBabId
                                : null,
                            isExpanded: true,
                            items: babItems.isEmpty ? null : babItems,
                            onChanged: babItems.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedBabId = value;
                                      _selectedSubBabId = null;
                                    });
                                    if (value != null) {
                                      _loadSubBabMateri(value);
                                      _updateTitleFromMateri();
                                    }
                                  },
                            hint: Text(
                              languageProvider.getTranslatedText({
                                'en': _isLoadingBab
                                    ? 'Loading chapters...'
                                    : (babItems.isEmpty
                                          ? 'No chapters found'
                                          : 'Select Chapter'),
                                'id': _isLoadingBab
                                    ? 'Memuat bab...'
                                    : (babItems.isEmpty
                                          ? 'Tidak ada bab'
                                          : 'Pilih Bab'),
                              }),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12),
                    ],

                    // Multi-Select Sub Bab (if bab is selected) - Custom UI
                    if (_useMateriTitle && _selectedBabId != null) ...[
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
                            _selectedSubBabIds.isEmpty
                                ? languageProvider.getTranslatedText({
                                    'en': 'Select Sub Chapters (optional)',
                                    'id': 'Pilih Sub Bab (opsional)',
                                  })
                                : _selectedSubBabIds.length == 1
                                ? _getSubBabName(
                                    _subBabMateriList.firstWhere(
                                      (s) =>
                                          s['id'].toString() ==
                                          _selectedSubBabIds.first,
                                      orElse: () => {},
                                    ),
                                  )
                                : '${_selectedSubBabIds.length} ${languageProvider.getTranslatedText({'en': 'selected', 'id': 'dipilih'})}',
                            style: TextStyle(
                              color: _selectedSubBabIds.isEmpty
                                  ? ColorUtils.slate600
                                  : ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],

                    // Judul Field
                    TextFormField(
                      controller: _judulController,
                      decoration: InputDecoration(
                        labelText:
                            '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                        helperText: _useMateriTitle
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
                          _useMateriTitle &&
                          (_selectedBabId != null || _selectedSubBabId != null),
                      validator: (value) => value == null || value.isEmpty
                          ? languageProvider.getTranslatedText({
                              'en': 'Required',
                              'id': 'Wajib diisi',
                            })
                          : null,
                    ),
                    SizedBox(height: 12),

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
                    SizedBox(height: 12),

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

                    // Batas Waktu (hanya untuk Tugas)
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

                    // Pilih Siswa (hanya untuk target khusus)
                    if (widget.initialTarget == 'khusus' &&
                        _selectedClassId != null) ...[
                      SizedBox(height: 12),
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
                      SizedBox(height: 8),
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
            padding: EdgeInsets.all(20),
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
                          : () => Navigator.pop(context),
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
                  SizedBox(width: 12),
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
