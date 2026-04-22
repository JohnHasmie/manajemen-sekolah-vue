// Teacher detail view screen - shows full profile info for a single teacher.
//
// Like `pages/admin/teachers/{id}.vue` - displays all teacher information
// (personal data, subjects taught, classes, schedule).
// Calls `GET /api/teachers/{id}` (TeacherController@show).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_detail_card_builders_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_detail_data_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_detail_ui_builders_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_detail_ui_helpers_mixin.dart';

/// Teacher detail screen - displays full profile for a single teacher.
///
/// Takes a [teacher] map (basic data) and fetches full details from API.
/// Like a Vue route page with `props: true` receiving the teacher object.
class TeacherDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  TeacherDetailScreenState createState() => TeacherDetailScreenState();
}

/// Mutable state for [TeacherDetailScreen].
///
/// Manages teacher profile data fetching and UI rendering.
/// State properties:
/// - [_teacherDetail] - full teacher data from API (null until loaded)
/// - [_subjects] - all subjects for reference/mapping
/// - [_isLoading] / [_errorMessage] - loading and error states
class TeacherDetailScreenState extends ConsumerState<TeacherDetailScreen>
    with
        TeacherDetailDataMixin,
        TeacherDetailUIHelpersMixin,
        TeacherDetailUIBuildersMixin,
        TeacherDetailCardBuildersMixin {
  Map<String, dynamic>? _teacherDetail;
  List<dynamic> _subjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  Map<String, dynamic>? get teacherDetail => _teacherDetail;
  @override
  set teacherDetail(Map<String, dynamic>? value) => _teacherDetail = value;

  @override
  List<dynamic> get subjects => _subjects;
  @override
  set subjects(List<dynamic> value) => _subjects = value;

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  String? get errorMessage => _errorMessage;
  @override
  set errorMessage(String? value) => _errorMessage = value;

  @override
  Map<String, dynamic> get widgetTeacher => widget.teacher;

  /// Like Vue's `mounted()` - fetches full teacher details from API.
  @override
  void initState() {
    super.initState();
    loadTeacherDetail();
  }

  @override
  Widget build(BuildContext context) {
    final teacher = _teacherDetail ?? widget.teacher;
    final effectiveTeacher = _teacherDetail ?? widget.teacher;

    final displaySubjectNames = getNamesList(
      effectiveTeacher['subjects'],
      effectiveTeacher['subject_ids'] ?? Teacher.fromJson(widget.teacher).subjectIds,
      _subjects,
    );

    final teachingClassNames = extractTeachingClassNames(effectiveTeacher);
    final homeroomStatus = getHomeroomStatus(effectiveTeacher);

    final teacherModel = Teacher.fromJson(teacher);
    final nameStr = teacherModel.name;
    final nameHash = nameStr.codeUnits.fold(0, (sum, c) => sum + c);
    final avatarColor = ColorUtils.getColorForIndex(nameHash);
    final initial = teacherModel.initials;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildGradientHeader(context, nameStr),
          Expanded(
            child: buildBody(
              context,
              teacher,
              teachingClassNames,
              displaySubjectNames,
              homeroomStatus,
              avatarColor,
              initial,
            ),
          ),
        ],
      ),
    );
  }
}
