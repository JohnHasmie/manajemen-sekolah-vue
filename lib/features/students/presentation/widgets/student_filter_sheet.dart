// Student filter bottom sheet — extracted from
// admin_student_management_screen.dart.
//
// Like a Vue modal component that owns its own local (temp) filter state,
// then calls [onApply] with the committed values when user taps
// "Apply Filter". The parent screen is responsible for storing the final
// filter state and triggering a data reload.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet_content.dart';

/// Shows a modal bottom sheet with status, class, gender
/// and guardian filters.
///
/// [classList]             - available classes fetched from API.
/// [primaryColor]          - role accent color.
/// [initialStatus]         - currently active status filter.
/// [initialClassIds]       - currently active class filter IDs.
/// [initialGender]         - currently active gender filter.
/// [initialGuardian]       - currently active guardian name filter.
/// [onApply]               - called when user taps "Apply Filter";
///                           receives the four new filter values.
void showStudentFilterSheet({
  required BuildContext context,
  required List<dynamic> classList,
  required Color primaryColor,
  required String? initialStatus,
  required List<String> initialClassIds,
  required String? initialGender,
  required String? initialGuardian,
  required void Function({
    required String? status,
    required List<String> classIds,
    required String? gender,
    required String? guardian,
  })
  onApply,
  required String Function(Map<String, String> translations) translate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StudentFilterSheetWrapper(
      classList: classList,
      primaryColor: primaryColor,
      initialStatus: initialStatus,
      initialClassIds: initialClassIds,
      initialGender: initialGender,
      initialGuardian: initialGuardian,
      onApply: onApply,
      translate: translate,
    ),
  );
}

/// Internal stateful wrapper that orchestrates the filter sheet UI.
///
/// Owns the "temp" filter state while the sheet is open.
class _StudentFilterSheetWrapper extends StatefulWidget {
  final List<dynamic> classList;
  final Color primaryColor;
  final String? initialStatus;
  final List<String> initialClassIds;
  final String? initialGender;
  final String? initialGuardian;
  final void Function({
    required String? status,
    required List<String> classIds,
    required String? gender,
    required String? guardian,
  })
  onApply;
  final String Function(Map<String, String> translations) translate;

  const _StudentFilterSheetWrapper({
    required this.classList,
    required this.primaryColor,
    required this.initialStatus,
    required this.initialClassIds,
    required this.initialGender,
    required this.initialGuardian,
    required this.onApply,
    required this.translate,
  });

  @override
  State<_StudentFilterSheetWrapper> createState() =>
      _StudentFilterSheetWrapperState();
}

class _StudentFilterSheetWrapperState
    extends State<_StudentFilterSheetWrapper> {
  late GlobalKey<StudentFilterSheetContentState> _contentKey;

  @override
  void initState() {
    super.initState();
    _contentKey = GlobalKey<StudentFilterSheetContentState>();
  }

  void _handleReset() {
    _contentKey.currentState?.resetFilters();
  }

  void _handleApply() {
    final contentState = _contentKey.currentState;
    if (contentState == null) return;

    widget.onApply(
      status: contentState.status,
      classIds: contentState.classIds,
      gender: contentState.gender,
      guardian: contentState.guardian,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: widget.translate({'en': 'Filter', 'id': 'Filter'}),
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      content: StudentFilterSheetContent(
        key: _contentKey,
        classList: widget.classList,
        primaryColor: widget.primaryColor,
        initialStatus: widget.initialStatus,
        initialClassIds: widget.initialClassIds,
        initialGender: widget.initialGender,
        initialGuardian: widget.initialGuardian,
        translate: widget.translate,
      ),
      onApply: _handleApply,
      onReset: _handleReset,
    );
  }
}
