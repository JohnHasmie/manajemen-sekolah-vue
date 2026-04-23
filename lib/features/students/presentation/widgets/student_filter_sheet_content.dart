import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet_filters_mixin.dart';

/// Scrollable filter content with guardian, status, class,
/// and gender filters.
///
/// Organized into four filter sections using reusable widgets.
class StudentFilterSheetContent extends StatefulWidget {
  final List<dynamic> classList;
  final Color primaryColor;
  final String? initialStatus;
  final List<String> initialClassIds;
  final String? initialGender;
  final String? initialGuardian;
  final String Function(Map<String, String> translations) translate;

  const StudentFilterSheetContent({
    required this.classList,
    required this.primaryColor,
    required this.initialStatus,
    required this.initialClassIds,
    required this.initialGender,
    required this.initialGuardian,
    required this.translate,
    super.key,
  });

  @override
  State<StudentFilterSheetContent> createState() =>
      StudentFilterSheetContentState();
}

class StudentFilterSheetContentState extends State<StudentFilterSheetContent>
    with StudentFilterSheetFiltersMixin {
  @override
  late String? tempStatus;
  @override
  late List<String> tempClassIds;
  @override
  late String? tempGender;
  @override
  late String? tempGuardian;

  @override
  void initState() {
    super.initState();
    tempStatus = widget.initialStatus;
    tempClassIds = List.from(widget.initialClassIds);
    tempGender = widget.initialGender;
    tempGuardian = widget.initialGuardian;
  }

  void resetFilters() {
    setState(() {
      tempStatus = null;
      tempClassIds.clear();
      tempGender = null;
      tempGuardian = null;
    });
  }

  @override
  void updateStatus(String? value) {
    setState(() => tempStatus = value);
  }

  @override
  void updateGender(String? value) {
    setState(() => tempGender = value);
  }

  @override
  void updateGuardian(String? value) {
    setState(() => tempGuardian = value);
  }

  @override
  void toggleClassId(String classId) {
    setState(() {
      if (tempClassIds.contains(classId)) {
        tempClassIds.remove(classId);
      } else {
        tempClassIds.add(classId);
      }
    });
  }

  @override
  void updateClassIds(List<String> values) {
    setState(() => tempClassIds = values);
  }

  String? get status => tempStatus;
  List<String> get classIds => tempClassIds;
  String? get gender => tempGender;
  String? get guardian => tempGuardian;

  @override
  Widget build(BuildContext context) {
    final t = widget.translate;

    return TeacherFilterContent(
      sections: [
        buildGuardianFilter(context, t),
        buildStatusFilter(context, t),
        buildClassFilter(context, t),
        buildGenderFilter(context, t),
      ],
    );
  }
}
