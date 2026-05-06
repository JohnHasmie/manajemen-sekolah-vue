// Teacher filter bottom sheet widget.
//
// Extracted from TeacherAdminScreenState._showFilterSheet() to keep the
// management screen under the line-count budget.
//
// Like a Vue modal component — receives initial filter values as props and
// emits the confirmed selection via [onApply].
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_filter_sections.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_show_all_toggle.dart';

/// Bottom-sheet widget for filtering the teacher list.
///
/// Receives the current filter state as constructor parameters and returns
/// the confirmed selection through [onApply].  The parent is responsible for
/// calling [showModalBottomSheet] and passing in the reference data lists.
class TeacherFilterSheet extends StatefulWidget {
  const TeacherFilterSheet({
    super.key,
    required this.initialHomeroom,
    required this.initialGender,
    required this.initialEmploymentStatus,
    required this.initialTeachingClass,
    required this.initialShowAll,
    required this.availableGenders,
    required this.availableEmploymentStatus,
    required this.availableClass,
    required this.languageProvider,
    required this.onApply,
  });

  /// Current homeroom filter value passed from the parent screen.
  final String? initialHomeroom;

  /// Current gender filter value passed from the parent screen.
  final String? initialGender;

  /// Current employment-status filter value passed from the parent screen.
  final String? initialEmploymentStatus;

  /// Current teaching-class filter value passed from the parent screen.
  final String? initialTeachingClass;

  /// Whether "Show All Teachers" toggle is currently on.
  final bool initialShowAll;

  /// Gender options loaded from the backend (list of {label, value} maps).
  final List<dynamic> availableGenders;

  /// Employment-status options loaded from the backend.
  final List<dynamic> availableEmploymentStatus;

  /// Class options loaded from the backend.
  final List<dynamic> availableClass;

  /// Language/translation provider — read once from parent so the sheet does
  /// not need its own Riverpod ref.
  final dynamic languageProvider;

  /// Called when the user taps "Apply Filter".
  ///
  /// Parameters (in order): homeroom, gender, employmentStatus,
  /// teachingClassId, showAll.
  final void Function(
    String? homeroom,
    String? gender,
    String? employmentStatus,
    String? teachingClassId,
    bool showAll,
  )
  onApply;

  @override
  TeacherFilterSheetState createState() => TeacherFilterSheetState();
}

/// Mutable state for [TeacherFilterSheet].
///
/// Like Vue's `data()` inside the modal component — holds temporary
/// selections that are only committed to the parent when the user
/// confirms.
class TeacherFilterSheetState extends State<TeacherFilterSheet> {
  // Temporary (uncommitted) filter selections — like v-model bindings
  // inside a modal that are only emitted on "Save".
  late String? _tempSelectedHomeroom;
  late String? _tempSelectedGender;
  late String? _tempSelectedEmploymentStatus;
  late String? _tempSelectedTeachingClass;
  late bool _showAllTeachers;

  @override
  void initState() {
    super.initState();
    _tempSelectedHomeroom = widget.initialHomeroom;
    _tempSelectedGender = widget.initialGender;
    _tempSelectedEmploymentStatus = widget.initialEmploymentStatus;
    _tempSelectedTeachingClass = widget.initialTeachingClass;
    _showAllTeachers = widget.initialShowAll;
  }

  void _resetFilters() {
    setState(() {
      _tempSelectedHomeroom = null;
      _tempSelectedGender = null;
      _tempSelectedEmploymentStatus = null;
      _tempSelectedTeachingClass = null;
      _showAllTeachers = false;
    });
  }

  void _updateHomeroom(String? value) {
    setState(() {
      _tempSelectedHomeroom = value;
    });
  }

  void _updateGender(String? value) {
    setState(() {
      _tempSelectedGender = value;
    });
  }

  void _updateEmploymentStatus(String? value) {
    setState(() {
      _tempSelectedEmploymentStatus = value;
    });
  }

  void _updateTeachingClass(String? value) {
    setState(() {
      _tempSelectedTeachingClass = value;
    });
  }

  void _updateShowAll(bool value) {
    setState(() {
      _showAllTeachers = value;
    });
  }

  void _handleApply() {
    widget.onApply(
      _tempSelectedHomeroom,
      _tempSelectedGender,
      _tempSelectedEmploymentStatus,
      _tempSelectedTeachingClass,
      _showAllTeachers,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = widget.languageProvider;
    final color = ColorUtils.getRoleColor('admin');

    return AppFilterBottomSheet(
      title: languageProvider.getTranslatedText({
        'en': 'Filter Teachers',
        'id': 'Filter Guru',
      }),
      icon: Icons.tune_rounded,
      primaryColor: color,
      maxHeightFactor: 0.75,
      onApply: _handleApply,
      onReset: _resetFilters,
      content: TeacherFilterContent(
        sections: [
          TeacherShowAllToggle(
            value: _showAllTeachers,
            onChanged: _updateShowAll,
            languageProvider: languageProvider,
          ),
          TeacherGenderSection(
            selectedValue: _tempSelectedGender,
            availableGenders: widget.availableGenders,
            onSelected: _updateGender,
            languageProvider: languageProvider,
            primaryColor: color,
          ),
          TeacherEmploymentStatusSection(
            selectedValue: _tempSelectedEmploymentStatus,
            availableEmploymentStatus: widget.availableEmploymentStatus,
            onSelected: _updateEmploymentStatus,
            languageProvider: languageProvider,
            primaryColor: color,
          ),
          TeacherClassSection(
            selectedValue: _tempSelectedTeachingClass,
            availableClass: widget.availableClass,
            onChanged: _updateTeachingClass,
            languageProvider: languageProvider,
            primaryColor: color,
          ),
          TeacherHomeroomSection(
            selectedValue: _tempSelectedHomeroom,
            onSelected: _updateHomeroom,
            languageProvider: languageProvider,
            primaryColor: color,
          ),
        ],
      ),
    );
  }
}
