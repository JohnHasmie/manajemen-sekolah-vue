import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart'
    as sched;
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_form_mixin.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_footer.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_teacher_dropdown.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_subject_dropdown.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_class_dropdown.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_day_multi_select.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_academic_year_dropdown.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_term_dropdown.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/live_conflict_preview_card.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_teaching_hour_dropdown.dart';

/// A bottom sheet form for creating or editing a schedule entry.
///
/// Implements cascading dropdown logic with form validation and data submission.
/// Returns the schedule data map via `Navigator.pop(context, scheduleData)`.
class ScheduleFormDialog extends ConsumerStatefulWidget {
  final List<dynamic> teacherList;
  final List<dynamic> subjectList;
  final List<dynamic> classList;
  final List<dynamic> dayList;
  final List<dynamic> semesterList;
  final List<dynamic> lessonHourList;
  final List<dynamic> academicYearList;
  final String semester;
  final String academicYear;
  final dynamic schedule;
  final dynamic apiService;
  final ApiTeacherService apiTeacherService;

  const ScheduleFormDialog({
    super.key,
    required this.teacherList,
    required this.subjectList,
    required this.classList,
    required this.dayList,
    required this.semesterList,
    required this.lessonHourList,
    required this.semester,
    required this.academicYear,
    this.academicYearList = const [],
    this.schedule,
    required this.apiService,
    required this.apiTeacherService,
  });

  @override
  ScheduleFormDialogState createState() => ScheduleFormDialogState();
}

/// State for [ScheduleFormDialog]. Manages form field values, filtered
/// dropdown lists, and occupied slot tracking via [ScheduleFormMixin].
class ScheduleFormDialogState extends ConsumerState<ScheduleFormDialog>
    with ScheduleFormMixin {
  final _formKey = GlobalKey<FormState>();
  late String _selectedTeacher;
  late String _selectedSubject;
  late String _selectedClass;
  late List<String> _selectedDayIds;
  late String _selectedTerm;
  late String _selectedAcademicYear;
  late String _selectedLessonHour;
  late List<dynamic> _filteredSubjectList;
  late List<dynamic> _availableLessonHourList;
  late List<dynamic> _occupiedSlots;
  late bool _isLoadingSubjects;
  late bool _isLoadingLessonHour;

  /// Count of conflicting sessions returned by the live probe inside
  /// [LiveConflictPreviewCard]. Drives the Simpan footer's enabled
  /// state — admin can still tap once to confirm via the existing
  /// post-save ConflictResolutionDialog flow, so this is informational
  /// rather than a hard block.
  int _liveConflictCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    loadSettings();
  }

  void _initializeForm() {
    _selectedTeacher = '';
    _selectedSubject = '';
    _selectedClass = '';
    _selectedDayIds = [];
    _selectedTerm = widget.semester;
    _selectedAcademicYear = widget.academicYear;
    _selectedLessonHour = '';
    _filteredSubjectList = widget.subjectList;
    _availableLessonHourList = [];
    _occupiedSlots = [];
    _isLoadingSubjects = false;
    _isLoadingLessonHour = false;

    if (widget.schedule != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setEditFormValues();
      });
    }
  }

  void _setEditFormValues() {
    final model = sched.Schedule.fromJson(widget.schedule!);
    setState(() {
      _selectedTeacher = model.teacherId ?? '';
      _selectedSubject = model.subjectId ?? '';
      _selectedClass = model.classId ?? '';
      _selectedDayIds = [];
      if (widget.schedule!['days_ids'] != null &&
          widget.schedule!['days_ids'] is List) {
        _selectedDayIds = List<String>.from(
          (widget.schedule!['days_ids'] as List).map((e) => e.toString()),
        );
      } else if (model.dayId != null && model.dayId!.isNotEmpty) {
        _selectedDayIds = [model.dayId!];
      }
      _selectedTerm =
          widget.schedule!['semester_id']?.toString() ??
          widget.schedule!['semester']?.toString() ??
          widget.semester;
      _selectedAcademicYear =
          widget.schedule!['academic_year_id']?.toString() ??
          widget.schedule!['academic_year']?.toString() ??
          widget.academicYear;
      _selectedLessonHour =
          widget.schedule!['lesson_hour_days_id']?.toString() ??
          model.lessonHourId ??
          '';

      if (_selectedTeacher.isNotEmpty) {
        filterSubjectsByTeacher(_selectedTeacher);
      }
      if (_selectedDayIds.isNotEmpty) {
        filterAvailableJamPelajaran();
        fetchOccupiedSlots();
      }
    });
  }

  // Getters/setters for ScheduleFormMixin
  @override
  dynamic get schedule => widget.schedule;
  @override
  String get selectedTeacher => _selectedTeacher;
  @override
  set selectedTeacher(String value) => _selectedTeacher = value;
  @override
  String get selectedSubject => _selectedSubject;
  @override
  set selectedSubject(String value) => _selectedSubject = value;
  @override
  String get selectedClass => _selectedClass;
  @override
  set selectedClass(String value) => _selectedClass = value;
  @override
  List<String> get selectedDayIds => _selectedDayIds;
  @override
  set selectedDayIds(List<String> value) => _selectedDayIds = value;
  @override
  String get selectedTerm => _selectedTerm;
  @override
  set selectedTerm(String value) => _selectedTerm = value;
  @override
  String get selectedAcademicYear => _selectedAcademicYear;
  @override
  set selectedAcademicYear(String value) => _selectedAcademicYear = value;
  @override
  String get selectedLessonHour => _selectedLessonHour;
  @override
  set selectedLessonHour(String value) => _selectedLessonHour = value;
  @override
  List<dynamic> get filteredSubjectList => _filteredSubjectList;
  @override
  set filteredSubjectList(List<dynamic> value) => _filteredSubjectList = value;
  @override
  List<dynamic> get availableLessonHourList => _availableLessonHourList;
  @override
  set availableLessonHourList(List<dynamic> value) =>
      _availableLessonHourList = value;
  @override
  List<dynamic> get occupiedSlots => _occupiedSlots;
  @override
  set occupiedSlots(List<dynamic> value) => _occupiedSlots = value;
  @override
  bool get isLoadingSubjects => _isLoadingSubjects;
  @override
  set isLoadingSubjects(bool value) => _isLoadingSubjects = value;
  @override
  bool get isLoadingLessonHour => _isLoadingLessonHour;
  @override
  set isLoadingLessonHour(bool value) => _isLoadingLessonHour = value;
  @override
  List<dynamic> get subjectList => widget.subjectList;
  @override
  List<dynamic> get lessonHourList => widget.lessonHourList;
  @override
  List<dynamic> get classList => widget.classList;
  @override
  ApiTeacherService get apiTeacherService => widget.apiTeacherService;

  // Use the admin brand navy (Color(0xFF143068)) so the Edit/Tambah
  // Jadwal sheet header matches the rest of the admin chrome. The
  // previous ColorUtils.blue600 was a brighter cobalt-violet that read
  // as a different role's surface — out of place against the navy
  // BrandPageHeader the sheet is opened from.
  Color _getPrimaryColor() => ColorUtils.getRoleColor('admin');

  List<dynamic> _removeDuplicates(List<dynamic> items, String idField) {
    final seen = <String>{};
    return items.where((item) {
      final id = item[idField]?.toString() ?? '';
      if (!seen.contains(id)) {
        seen.add(id);
        return true;
      }
      return false;
    }).toList();
  }

  void _saveSchedule() {
    if (!_formKey.currentState!.validate()) return;
    final scheduleData = {
      'teacher_id': _selectedTeacher,
      'subject_id': _selectedSubject,
      'class_id': _selectedClass,
      'days_ids': _selectedDayIds,
      'semester_id': _selectedTerm,
      'academic_year_id': _selectedAcademicYear,
      'lesson_hour_days_id': _selectedLessonHour,
    };
    AppLogger.debug('schedule_form', 'Saving schedule data');
    AppNavigator.pop(context, scheduleData);
  }

  Widget _buildFormFields(LanguageProvider lang) {
    final unique = {
      'teachers': _removeDuplicates(widget.teacherList, 'id'),
      'classes': _removeDuplicates(widget.classList, 'id'),
      'days': _removeDuplicates(widget.dayList, 'id'),
      'semesters': _removeDuplicates(widget.semesterList, 'id'),
      'hours': _removeDuplicates(_availableLessonHourList, 'id'),
      'subjects': _removeDuplicates(_filteredSubjectList, 'id'),
    };
    final color = _getPrimaryColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScheduleTeacherDropdown(
          teachers: unique['teachers']!,
          selectedValue: _selectedTeacher,
          onChanged: _onTeacherChanged,
          languageProvider: lang,
          primaryColor: color,
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleSubjectDropdown(
          subjects: unique['subjects']!,
          selectedValue: _selectedSubject,
          onChanged: (v) => setState(() => _selectedSubject = v),
          languageProvider: lang,
          primaryColor: color,
          isLoading: _isLoadingSubjects,
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleClassDropdown(
          classes: unique['classes']!,
          selectedValue: _selectedClass,
          onChanged: _onClassChanged,
          languageProvider: lang,
          primaryColor: color,
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleDayMultiSelect(
          days: unique['days']!,
          selectedDayIds: _selectedDayIds,
          onChanged: _onDaysChanged,
          languageProvider: lang,
          primaryColor: color,
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleAcademicYearDropdown(
          academicYears: widget.academicYearList,
          selectedValue: _selectedAcademicYear,
          defaultYear: widget.academicYear,
          onChanged: _onYearChanged,
          languageProvider: lang,
          primaryColor: color,
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleTermDropdown(
          semesters: unique['semesters']!,
          selectedValue: _selectedTerm,
          onChanged: _onTermChanged,
          languageProvider: lang,
          primaryColor: color,
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleTeachingHourDropdown(
          teachingHours: unique['hours']!,
          occupiedSlots: _occupiedSlots,
          selectedValue: _selectedLessonHour,
          onChanged: (v) => setState(() => _selectedLessonHour = v),
          languageProvider: lang,
          primaryColor: color,
          isLoading: _isLoadingLessonHour,
        ),
        // ── Live conflict preview (Frame D) ─────────────────────────
        //
        // Re-probes /teaching-schedule/conflicts whenever the form's
        // teacher / class / day / lesson_hour state settles, and
        // renders a red preview block when the picked slot collides.
        // Stays SizedBox.shrink until all six required fields are set.
        LiveConflictPreviewCard(
          teacherId: _selectedTeacher,
          classId: _selectedClass,
          semesterId: _selectedTerm,
          academicYearId: _selectedAcademicYear,
          daysIds: _selectedDayIds,
          lessonHourId: _selectedLessonHour,
          excludeScheduleId: widget.schedule?['id']?.toString(),
          onConflictCountChanged: (n) {
            // Cache the count so [_saveSchedule] / footer can read it
            // before allowing submit. The setState is cheap — no
            // rebuild churn because we only flip a bool.
            if ((_liveConflictCount > 0) != (n > 0)) {
              setState(() => _liveConflictCount = n);
            } else {
              _liveConflictCount = n;
            }
          },
        ),
      ],
    );
  }

  void _onTeacherChanged(String v) {
    setState(() {
      _selectedTeacher = v;
      _selectedSubject = '';
      _filteredSubjectList = [];
    });
    if (v.isNotEmpty) {
      filterSubjectsByTeacher(v);
    } else {
      setState(() => _filteredSubjectList = widget.subjectList);
    }
  }

  void _onClassChanged(String v) {
    setState(() => _selectedClass = v);
    if (_selectedDayIds.isNotEmpty) fetchOccupiedSlots();
  }

  void _onDaysChanged(List<String> v) {
    setState(() => _selectedDayIds = v);
    if (v.isNotEmpty) filterAvailableJamPelajaran();
  }

  void _onYearChanged(String v) {
    setState(() => _selectedAcademicYear = v);
    if (_selectedDayIds.isNotEmpty) fetchOccupiedSlots();
  }

  void _onTermChanged(String v) {
    setState(() => _selectedTerm = v);
    if (_selectedDayIds.isNotEmpty) fetchOccupiedSlots();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final isEdit = widget.schedule != null;
    final title = isEdit
        ? lang.getTranslatedText(const {
            'en': 'Edit Schedule',
            'id': 'Edit Jadwal',
          })
        : lang.getTranslatedText(const {
            'en': 'Add Schedule',
            'id': 'Tambah Jadwal',
          });

    return AppBottomSheet(
      title: title,
      subtitle: isEdit ? 'EDIT DATA' : 'TAMBAH BARU',
      icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
      primaryColor: _getPrimaryColor(),
      maxHeightFactor: 0.85,
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        4,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      content: Form(key: _formKey, child: _buildFormFields(lang)),
      footer: ScheduleFormFooter(
        onSave: _saveSchedule,
        primaryColor: _getPrimaryColor(),
        languageProvider: lang,
      ),
    );
  }
}
