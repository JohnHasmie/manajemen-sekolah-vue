import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';

import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_student_selector.dart';

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
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
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
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
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
    final p = ColorUtils.getRoleColor('guru');

    // Build unique chapter map for material section
    final Map<String, dynamic> uniqueChapters = {};
    for (var ch in _chapterMaterialList) {
      final id = ch['id']?.toString();
      if (id != null && !uniqueChapters.containsKey(id)) uniqueChapters[id] = ch;
    }
    final chapters = uniqueChapters.values.toList();

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(children: [
        // ── Header ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.85)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(isAssignment ? Icons.assignment_rounded : Icons.menu_book_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    widget.isEditMode
                        ? (isAssignment ? 'Edit Tugas' : 'Edit Materi')
                        : (isAssignment ? 'Tambah Tugas' : 'Tambah Materi'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (widget.initialClassName != null || widget.initialSubjectName != null)
                    Row(children: [
                      if (widget.initialClassName != null) Text('${widget.initialClassName}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                      if (widget.initialClassName != null && widget.initialSubjectName != null) Text(' · ', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                      if (widget.initialSubjectName != null) Flexible(child: Text(widget.initialSubjectName!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                ])),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
          ]),
        ),

        // ── Form body ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 4),

                // ═══ SECTION 1: Material Source ═══
                _buildSectionLabel(icon: Icons.auto_stories_rounded, label: 'Sumber Judul', color: p),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: const Text('Tulis Manual'),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: const Text('Dari Materi'),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        enabled: _selectedSubjectId != null,
                      ),
                    ],
                    selected: {_useMaterialTitle},
                    onSelectionChanged: (sel) => setState(() {
                      _useMaterialTitle = sel.first;
                      if (!_useMaterialTitle) {
                        _selectedChapterId = null;
                        _selectedSubChapterId = null;
                        _selectedSubChapterIds.clear();
                      }
                    }),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: p.withValues(alpha: 0.1),
                      selectedForegroundColor: p,
                      foregroundColor: ColorUtils.slate500,
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: ColorUtils.slate200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                // Chapter chips (when "Dari Materi" active)
                if (_useMaterialTitle) ...[
                  const SizedBox(height: 14),
                  _buildSectionLabel(icon: Icons.menu_book_rounded, label: 'Bab Materi', color: p),
                  const SizedBox(height: 8),
                  if (_isLoadingChapters)
                    Row(children: List.generate(3, (_) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 72, height: 32,
                      decoration: BoxDecoration(color: ColorUtils.slate100, borderRadius: BorderRadius.circular(16)),
                    )))
                  else if (chapters.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: ColorUtils.slate400),
                        const SizedBox(width: 8),
                        Text('Tidak ada bab tersedia', style: TextStyle(fontSize: 13, color: ColorUtils.slate500)),
                      ]),
                    )
                  else
                    Wrap(spacing: 6, runSpacing: 6, children: chapters.map((ch) {
                      final id = ch['id'].toString();
                      final isSelected = id == _selectedChapterId;
                      return ChoiceChip(
                        label: Text(_getChapterName(ch)),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedChapterId = id;
                            _selectedSubChapterId = null;
                            _selectedSubChapterIds.clear();
                          });
                          _loadSubChapterContent(id);
                          _updateTitleFromMaterial();
                        },
                        showCheckmark: false,
                        selectedColor: p.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? p : ColorUtils.slate600,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        side: BorderSide(color: isSelected ? p.withValues(alpha: 0.3) : ColorUtils.slate200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      );
                    }).toList()),

                  // Sub-chapter filter chips
                  if (_selectedChapterId != null && _subChapterMaterialList.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildSectionLabel(
                      icon: Icons.article_outlined, label: 'Sub Bab', color: p,
                      trailing: _subChapterMaterialList.length > 7
                          ? GestureDetector(
                              onTap: () => _openMultiSelectSubBabDialog(languageProvider),
                              child: Text('Lihat Semua', style: TextStyle(fontSize: 12, color: p, fontWeight: FontWeight.w600)),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: _subChapterMaterialList.take(7).map((sub) {
                      final subId = sub['id'].toString();
                      final isSelected = _selectedSubChapterIds.contains(subId);
                      return FilterChip(
                        label: Text(_getSubChapterName(sub)),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) { _selectedSubChapterIds.add(subId); }
                            else { _selectedSubChapterIds.remove(subId); }
                            _selectedSubChapterId = _selectedSubChapterIds.isNotEmpty ? _selectedSubChapterIds.first : null;
                          });
                          _updateTitleFromMaterial();
                        },
                        selectedColor: p.withValues(alpha: 0.08),
                        checkmarkColor: p,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          color: isSelected ? p : ColorUtils.slate600,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                        ),
                        side: BorderSide(color: isSelected ? p.withValues(alpha: 0.25) : ColorUtils.slate200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList()),
                  ],
                ],

                // ═══ DIVIDER ═══
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: ColorUtils.slate100, height: 1),
                ),

                // ═══ SECTION 2: Title ═══
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: isAssignment ? 'Judul tugas...' : 'Judul materi...',
                    hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 14, fontWeight: FontWeight.w400),
                    filled: true, fillColor: ColorUtils.slate50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: _useMaterialTitle && _selectedChapterId != null
                        ? Padding(padding: const EdgeInsets.only(right: 10), child: Icon(Icons.lock_outline_rounded, size: 16, color: ColorUtils.slate400))
                        : null,
                  ),
                  readOnly: _useMaterialTitle && (_selectedChapterId != null || _selectedSubChapterId != null),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 10),

                // ═══ SECTION 3: Description ═══
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tambahkan catatan atau instruksi...',
                    hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
                    filled: true, fillColor: ColorUtils.slate50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3, minLines: 2,
                ),

                // ═══ DIVIDER ═══
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: ColorUtils.slate100, height: 1),
                ),

                // ═══ SECTION 4: Date & Deadline ═══
                _buildDateCard(
                  icon: Icons.calendar_today_rounded,
                  iconColor: p,
                  label: 'Tanggal Kegiatan',
                  value: _selectedDate != null ? _formatDate(_selectedDate!) : null,
                  placeholder: 'Pilih tanggal',
                  onTap: () {
                    _showModernDatePicker(
                      initialDate: _selectedDate ?? DateTime.now(),
                      title: 'Pilih Tanggal Kegiatan',
                      onDateSelected: (date) {
                        setState(() {
                          _selectedDate = date;
                          _selectedDay = _days[date.weekday - 1];
                        });
                      },
                    );
                  },
                ),
                if (isAssignment) ...[
                  const SizedBox(height: 10),
                  _buildDateCard(
                    icon: Icons.access_time_rounded,
                    iconColor: ColorUtils.warning600,
                    label: 'Batas Waktu',
                    value: _deadline != null ? _formatDateTime(_deadline!) : null,
                    placeholder: 'Belum ditentukan (opsional)',
                    onTap: () {
                      _showModernDateTimePicker(
                        initialDateTime: _deadline ?? DateTime.now(),
                        title: 'Pilih Batas Waktu',
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _deadline = dateTime;
                          });
                        },
                      );
                    },
                    onClear: _deadline != null ? () => setState(() => _deadline = null) : null,
                  ),
                ],

                // ═══ SECTION 5: Students (specific target only) ═══
                if (widget.initialTarget == 'khusus' && _selectedClassId != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: ColorUtils.slate200, height: 1),
                  ),
                  AddActivityStudentSelector(
                    studentList: _studentList, selectedStudents: _selectedStudents,
                    isLoading: _isLoadingStudents, initialTarget: widget.initialTarget,
                    onRefresh: _loadStudents,
                    onToggleStudent: (id, sel) { setState(() { if (sel) { _selectedStudents.add(id); } else { _selectedStudents.remove(id); } }); },
                    languageProvider: languageProvider,
                  ),
                ],

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),

        // ── Bottom bar ──
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, elevation: 0, disabledBackgroundColor: ColorUtils.slate300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEditMode ? 'Simpan Perubahan' : (isAssignment ? 'Tambah Tugas' : 'Tambah Materi'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helper: Section label with icon ──
  Widget _buildSectionLabel({required IconData icon, required String label, required Color color, Widget? trailing}) {
    return Row(children: [
      Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorUtils.slate600)),
      if (trailing != null) ...[const Spacer(), trailing],
    ]);
  }

  // ── Helper: Full-width date card ──
  Widget _buildDateCard({required IconData icon, required Color iconColor, required String label, String? value, String? placeholder, required VoidCallback onTap, VoidCallback? onClear}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 1),
            Text(value ?? placeholder ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: value != null ? ColorUtils.slate800 : ColorUtils.slate400)),
          ])),
          if (onClear != null)
            GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 16, color: ColorUtils.slate400))
          else
            Icon(Icons.chevron_right_rounded, size: 18, color: ColorUtils.slate300),
        ]),
      ),
    );
  }

  // ── Helper: Format date ──
  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ── Helper: Format date+time ──
  String _formatDateTime(DateTime d) {
    return '${_formatDate(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Helper: Modern Date Picker Sheet ──
  void _showModernDatePicker({
    required DateTime initialDate,
    required String title,
    required Function(DateTime) onDateSelected,
  }) {
    final p = ColorUtils.getRoleColor('guru');
    DateTime tempDate = initialDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p, p.withValues(alpha: 0.85)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            // Calendar
            SizedBox(
              height: 340,
              child: Theme(
                data: ThemeData(
                  useMaterial3: true,
                  primaryColor: p,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: p,
                    primary: p,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: ColorUtils.slate800,
                    secondary: p,
                  ),
                  datePickerTheme: DatePickerThemeData(
                    headerBackgroundColor: p,
                    headerForegroundColor: Colors.white,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.any((s) => s == WidgetState.selected || s == WidgetState.pressed)) return Colors.white;
                      return ColorUtils.slate800;
                    }),
                    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.any((s) => s == WidgetState.selected || s == WidgetState.pressed)) return p;
                      return Colors.transparent;
                    }),
                    todayForegroundColor: WidgetStateProperty.all(p),
                    todayBackgroundColor: WidgetStateProperty.all(p.withValues(alpha: 0.1)),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onDateChanged: (date) {
                      tempDate = date;
                    },
                  ),
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    onDateSelected(tempDate);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Pilih Tanggal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: Modern Date Time Picker Sheet (For Assignments) ──
  void _showModernDateTimePicker({
    required DateTime initialDateTime,
    required String title,
    required Function(DateTime) onDateTimeSelected,
  }) {
    final p = ColorUtils.getRoleColor('guru');
    DateTime tempDate = initialDateTime;
    TimeOfDay tempTime = TimeOfDay.fromDateTime(initialDateTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p, p.withValues(alpha: 0.85)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 330,
                        child: Theme(
                          data: ThemeData(
                            useMaterial3: true,
                            primaryColor: p,
                            colorScheme: ColorScheme.fromSeed(
                              seedColor: p,
                              primary: p,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: ColorUtils.slate800,
                              secondary: p,
                            ),
                            datePickerTheme: DatePickerThemeData(
                              headerBackgroundColor: p,
                              headerForegroundColor: Colors.white,
                              backgroundColor: Colors.white,
                              elevation: 0,
                              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.any((s) => s == WidgetState.selected || s == WidgetState.pressed)) return Colors.white;
                                return ColorUtils.slate800;
                              }),
                              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.any((s) => s == WidgetState.selected || s == WidgetState.pressed)) return p;
                                return Colors.transparent;
                              }),
                              todayForegroundColor: WidgetStateProperty.all(p),
                              todayBackgroundColor: WidgetStateProperty.all(p.withValues(alpha: 0.1)),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: CalendarDatePicker(
                              initialDate: tempDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                              onDateChanged: (date) {
                                tempDate = date;
                              },
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time_rounded, size: 18, color: ColorUtils.slate400),
                                const SizedBox(width: 8),
                                Text(
                                  'Set Waktu (Jam : Menit)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColorUtils.slate700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 120,
                              margin: const EdgeInsets.symmetric(horizontal: 40),
                              decoration: BoxDecoration(
                                color: ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ColorUtils.slate200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Hours
                                  Expanded(
                                    child: CupertinoPicker(
                                      scrollController: FixedExtentScrollController(initialItem: tempTime.hour),
                                      itemExtent: 40,
                                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(capStartEdge: true, capEndEdge: false),
                                      onSelectedItemChanged: (int value) {
                                        setSheetState(() => tempTime = TimeOfDay(hour: value, minute: tempTime.minute));
                                      },
                                      children: List.generate(24, (index) => Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: p),
                                        ),
                                      )),
                                    ),
                                  ),
                                  Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ColorUtils.slate400)),
                                  // Minutes
                                  Expanded(
                                    child: CupertinoPicker(
                                      scrollController: FixedExtentScrollController(initialItem: tempTime.minute),
                                      itemExtent: 40,
                                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(capStartEdge: false, capEndEdge: true),
                                      onSelectedItemChanged: (int value) {
                                        setSheetState(() => tempTime = TimeOfDay(hour: tempTime.hour, minute: value));
                                      },
                                      children: List.generate(60, (index) => Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: p),
                                        ),
                                      )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final finalDateTime = DateTime(
                        tempDate.year,
                        tempDate.month,
                        tempDate.day,
                        tempTime.hour,
                        tempTime.minute,
                      );
                      onDateTimeSelected(finalDateTime);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Batas Waktu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
