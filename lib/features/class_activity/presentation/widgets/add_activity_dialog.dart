import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/activity_data_loading_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/activity_date_picker_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/activity_name_helper_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/activity_submission_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_form_content.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_material_selector.dart';

class AddActivityDialog extends ConsumerStatefulWidget {
  final String teacherId, teacherName;
  final List<dynamic> scheduleList, subjectList, chapterList, subChapterList;
  final Function(String) onSubjectSelected, onChapterSelected;
  final VoidCallback onActivityAdded;
  final String initialTarget, activityType;
  final DateTime? initialDate;
  final String? initialSubjectId,
      initialSubjectName,
      initialClassId,
      initialClassName;
  final String? initialChapterId, initialSubChapterId;
  final bool isEditMode;
  final dynamic activityData;
  final List<Map<String, dynamic>>? initialAdditionalMaterials,
      materialsToMarkAsGenerated;
  final String? lessonHourId;

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
    this.lessonHourId,
  });

  @override
  ConsumerState<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends ConsumerState<AddActivityDialog>
    with
        ActivityDataLoadingMixin,
        ActivitySubmissionMixin,
        ActivityNameHelperMixin,
        ActivityDatePickerMixin {
  late final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController();
  late final _descriptionController = TextEditingController();
  final _selectedStudents = <String>[];
  final _selectedSubChapterIds = <String>[];

  String? _selectedSubjectId,
      _selectedClassId,
      _selectedChapterId,
      _selectedSubChapterId;
  DateTime? _selectedDate, _deadline;
  String? _selectedDay;
  bool _isSubmitting = false,
      _isLoadingStudents = false,
      _isLoadingChapters = false;
  bool _useMaterialTitle = false;
  List<dynamic> _studentList = [],
      _chapterMaterialList = [],
      _subChapterMaterialList = [];

  // Mixin getters/setters
  @override
  GlobalKey<FormState> get formKey => _formKey;
  @override
  TextEditingController get titleController => _titleController;
  @override
  TextEditingController get descriptionController => _descriptionController;
  @override
  bool get isSubmitting => _isSubmitting;
  @override
  set isSubmitting(bool v) => _isSubmitting = v;
  @override
  String? get selectedSubjectId => _selectedSubjectId;
  @override
  String? get selectedClassId => _selectedClassId;
  @override
  String? get selectedChapterId => _selectedChapterId;
  @override
  String? get selectedSubChapterId => _selectedSubChapterId;
  @override
  DateTime? get selectedDate => _selectedDate;
  @override
  DateTime? get deadline => _deadline;
  @override
  String? get selectedDay => _selectedDay;
  @override
  bool get useMaterialTitle => _useMaterialTitle;
  @override
  List<String> get selectedSubChapterIds => _selectedSubChapterIds;
  @override
  List<String> get selectedStudents => _selectedStudents;
  @override
  String get teacherId => widget.teacherId;
  @override
  String get activityType => widget.activityType;
  @override
  String get initialTarget => widget.initialTarget;
  @override
  bool get isEditMode => widget.isEditMode;
  @override
  dynamic get activityData => widget.activityData;
  @override
  List<Map<String, dynamic>>? get initialAdditionalMaterials =>
      widget.initialAdditionalMaterials;
  @override
  List<Map<String, dynamic>>? get materialsToMarkAsGenerated =>
      widget.materialsToMarkAsGenerated;
  @override
  bool get isLoadingStudents => _isLoadingStudents;
  @override
  set isLoadingStudents(bool v) => _isLoadingStudents = v;
  @override
  List<dynamic> get studentList => _studentList;
  @override
  set studentList(List<dynamic> v) => _studentList = v;
  @override
  bool get isLoadingChapters => _isLoadingChapters;
  @override
  set isLoadingChapters(bool v) => _isLoadingChapters = v;
  @override
  List<dynamic> get chapterMaterialList => _chapterMaterialList;
  @override
  set chapterMaterialList(List<dynamic> v) => _chapterMaterialList = v;
  @override
  List<dynamic> get subChapterMaterialList => _subChapterMaterialList;
  @override
  set subChapterMaterialList(List<dynamic> v) => _subChapterMaterialList = v;
  @override
  String? get initialChapterId => widget.initialChapterId;
  @override
  String? get initialSubChapterId => widget.initialSubChapterId;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _loadInitialData();
  }

  void _initializeFormData() {
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedDay = getDayName(_selectedDate!);
    _selectedSubjectId = widget.initialSubjectId;
    _selectedClassId = widget.initialClassId;
    _selectedChapterId = widget.initialChapterId;
    _selectedSubChapterId = widget.initialSubChapterId;

    if (_selectedSubChapterId != null) {
      _selectedSubChapterIds.add(_selectedSubChapterId!);
    }
    if (widget.initialAdditionalMaterials != null) {
      for (final item in widget.initialAdditionalMaterials!) {
        final subId = item['sub_chapter_id']?.toString();
        if (subId != null && !_selectedSubChapterIds.contains(subId)) {
          _selectedSubChapterIds.add(subId);
        }
      }
    }

    if (widget.isEditMode && widget.activityData != null) {
      _titleController.text = widget.activityData['judul']?.toString() ?? '';
      _descriptionController.text =
          widget.activityData['deskripsi']?.toString() ?? '';
      if (widget.activityData['batas_waktu'] != null) {
        _deadline = DateTime.tryParse(
          widget.activityData['batas_waktu'].toString(),
        );
      }
      if (widget.initialTarget == 'khusus' &&
          widget.activityData['siswa_target'] != null) {
        final studentTarget = widget.activityData['siswa_target'];
        if (studentTarget is List) {
          _selectedStudents.addAll(studentTarget.map((s) => s.toString()));
        }
      }
    }

    if (_selectedChapterId != null || _selectedSubChapterId != null) {
      _useMaterialTitle = true;
    }
  }

  void _loadInitialData() {
    if (_selectedSubjectId == null) return;
    Future.delayed(Duration.zero, () {
      AppLogger.debug(
        'class_activity',
        'Loading initial data for subject: $_selectedSubjectId',
      );
      widget.onSubjectSelected(_selectedSubjectId!);
      loadChapterContent(_selectedSubjectId!, widget.subjectList).then((_) {
        if (_selectedChapterId != null) {
          loadSubChapterContent(
            _selectedChapterId!,
          ).then((_) => _updateTitleFromMaterial());
        } else {
          _updateTitleFromMaterial();
        }
      });
      if (_selectedClassId != null && widget.initialTarget == 'khusus') {
        loadStudents(_selectedClassId!);
      }
    });
    AppLogger.debug('class_activity', '=====================================');
  }

  void _updateTitleFromMaterial() {
    updateTitleFromMaterial(
      selectedChapterId: _selectedChapterId,
      selectedSubChapterId: _selectedSubChapterId,
      chapterMaterialList: _chapterMaterialList,
      subChapterMaterialList: _subChapterMaterialList,
      onTitleUpdated: (title) {
        _titleController.text = title;
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Combines `initialClassName` + `initialSubjectName` into the single
  /// subtitle slot that `AppBottomSheet`'s gradient header exposes. Mirrors
  /// the old hand-rolled "Class · Subject" row inside `ActivityDialogShell`.
  String? _buildSubtitle() {
    final c = widget.initialClassName;
    final s = widget.initialSubjectName;
    if (c == null && s == null) return null;
    if (c != null && s != null) return '$c · $s';
    return c ?? s;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final isAssignment = widget.activityType == 'tugas';
    final p = ColorUtils.getRoleColor('guru');

    final Map<String, dynamic> uniqueChapters = {};
    for (final ch in _chapterMaterialList) {
      final id = ch['id']?.toString();
      if (id != null && !uniqueChapters.containsKey(id)) {
        uniqueChapters[id] = ch;
      }
    }
    final chapters = uniqueChapters.values.toList();

    final title = widget.isEditMode
        ? (isAssignment ? 'Edit Tugas' : 'Edit Materi')
        : (isAssignment ? 'Tambah Tugas' : 'Tambah Materi');
    final submitLabel = _isSubmitting
        ? 'Menyimpan...'
        : (widget.isEditMode
              ? 'Simpan Perubahan'
              : (isAssignment ? 'Tambah Tugas' : 'Tambah Materi'));

    return AppBottomSheet(
      title: title,
      subtitle: _buildSubtitle(),
      icon: isAssignment ? Icons.assignment_rounded : Icons.menu_book_rounded,
      primaryColor: p,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      content: ActivityFormContent(
        formKey: _formKey,
        titleController: _titleController,
        descriptionController: _descriptionController,
        accentColor: p,
        isAssignment: isAssignment,
        useMaterialTitle: _useMaterialTitle,
        selectedSubjectId: _selectedSubjectId,
        selectedChapterId: _selectedChapterId,
        isLoadingChapters: _isLoadingChapters,
        chapters: chapters,
        subChapters: _subChapterMaterialList,
        selectedSubChapterIds: _selectedSubChapterIds,
        selectedDate: _selectedDate,
        deadline: _deadline,
        selectedClassId: _selectedClassId,
        initialTarget: widget.initialTarget,
        studentList: _studentList,
        selectedStudents: _selectedStudents,
        isLoadingStudents: _isLoadingStudents,
        languageProvider: languageProvider,
        getChapterName: getChapterName,
        getSubChapterName: getSubChapterName,
        onMaterialModeChanged: (val) {
          setState(() {
            _useMaterialTitle = val;
            if (!_useMaterialTitle) {
              _selectedChapterId = null;
              _selectedSubChapterId = null;
              _selectedSubChapterIds.clear();
            }
          });
        },
        onChapterSelected: (id) {
          setState(() {
            _selectedChapterId = id;
            _selectedSubChapterId = null;
            _selectedSubChapterIds.clear();
          });
          loadSubChapterContent(id).then((_) => _updateTitleFromMaterial());
        },
        onSubChapterToggled: (subId, isSelected) {
          setState(() {
            if (isSelected) {
              if (!_selectedSubChapterIds.contains(subId)) {
                _selectedSubChapterIds.add(subId);
              }
            } else {
              _selectedSubChapterIds.remove(subId);
            }
            _selectedSubChapterId = _selectedSubChapterIds.isNotEmpty
                ? _selectedSubChapterIds.first
                : null;
          });
          _updateTitleFromMaterial();
        },
        onShowDatePicker: () => showActivityDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
              _selectedDay = getDayName(date);
            });
          },
        ),
        onShowDateTimePicker: () => showDeadlinePicker(
          context: context,
          initialDateTime: _deadline ?? DateTime.now(),
          onDateTimeSelected: (dateTime) =>
              setState(() => _deadline = dateTime),
        ),
        onClearDeadline: () => setState(() => _deadline = null),
        onViewAllSubChapters: () {
          showMultiSelectSubBabDialog(
            context: context,
            languageProvider: languageProvider,
            subChapters: _subChapterMaterialList,
            selectedSubChapterIds: _selectedSubChapterIds,
            getSubChapterName: getSubChapterName,
            onSubChapterToggled: (subId, isSelected) {
              setState(() {
                if (isSelected) {
                  if (!_selectedSubChapterIds.contains(subId)) {
                    _selectedSubChapterIds.add(subId);
                  }
                } else {
                  _selectedSubChapterIds.remove(subId);
                }
                _selectedSubChapterId = _selectedSubChapterIds.isNotEmpty
                    ? _selectedSubChapterIds.first
                    : null;
              });
              _updateTitleFromMaterial();
            },
          );
        },
        onRefreshStudents: () => loadStudents(_selectedClassId!),
        onToggleStudent: (id, sel) {
          setState(() {
            if (sel) {
              _selectedStudents.add(id);
            } else {
              _selectedStudents.remove(id);
            }
          });
        },
      ),
      footer: BottomSheetFooter(
        primaryLabel: submitLabel,
        primaryColor: p,
        primaryEnabled: !_isSubmitting,
        onPrimary: submitForm,
        onSecondary: _isSubmitting ? () {} : () => AppNavigator.pop(context),
      ),
    );
  }
}
