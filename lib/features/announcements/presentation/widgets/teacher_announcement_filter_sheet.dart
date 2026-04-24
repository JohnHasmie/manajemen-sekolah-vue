// Filter bottom sheet for the teacher announcement screen.
//
// Mirrors the teacher_schedule_filter_sheet pattern (shared
// AppFilterBottomSheet + FilterSectionHeader + FilterChipGrid) so all
// teacher-side filter sheets share the same look.
//
// Scoped to the fields that are actually meaningful when a teacher views
// their own feed: priority + status. Target is intentionally omitted —
// the teacher feed only ever surfaces announcements targeted at "Guru"
// or "Semua", and filtering between them isn't useful day-to-day.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// Shows the teacher announcement filter bottom sheet.
///
/// `onApply` is invoked with the new `(priority, status)` selections when
/// the user taps "Apply". Values of `null` mean "all".
void showTeacherAnnouncementFilterSheet({
  required BuildContext context,
  required Color primaryColor,
  required LanguageProvider languageProvider,
  required String? currentPriority,
  required String? currentStatus,
  required void Function(String? priority, String? status) onApply,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TeacherAnnouncementFilterSheet(
      primaryColor: primaryColor,
      languageProvider: languageProvider,
      initialPriority: currentPriority,
      initialStatus: currentStatus,
      onApply: onApply,
    ),
  );
}

class _TeacherAnnouncementFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String? initialPriority;
  final String? initialStatus;
  final void Function(String? priority, String? status) onApply;

  const _TeacherAnnouncementFilterSheet({
    required this.primaryColor,
    required this.languageProvider,
    required this.initialPriority,
    required this.initialStatus,
    required this.onApply,
  });

  @override
  State<_TeacherAnnouncementFilterSheet> createState() =>
      _TeacherAnnouncementFilterSheetState();
}

class _TeacherAnnouncementFilterSheetState
    extends State<_TeacherAnnouncementFilterSheet> {
  String? _tempPriority;
  String? _tempStatus;

  @override
  void initState() {
    super.initState();
    _tempPriority = widget.initialPriority;
    _tempStatus = widget.initialStatus;
  }

  LanguageProvider get _lp => widget.languageProvider;

  @override
  Widget build(BuildContext context) {
    final priorityOptions = [
      FilterOption<String>(
        value: 'Penting',
        label: _lp.getTranslatedText({'en': 'Important', 'id': 'Penting'}),
      ),
      FilterOption<String>(
        value: 'Biasa',
        label: _lp.getTranslatedText({'en': 'Normal', 'id': 'Biasa'}),
      ),
    ];

    final statusOptions = [
      FilterOption<String>(
        value: 'Aktif',
        label: _lp.getTranslatedText({'en': 'Active', 'id': 'Aktif'}),
      ),
      FilterOption<String>(
        value: 'Terjadwal',
        label: _lp.getTranslatedText({'en': 'Scheduled', 'id': 'Terjadwal'}),
      ),
      FilterOption<String>(
        value: 'Kedaluwarsa',
        label: _lp.getTranslatedText({'en': 'Expired', 'id': 'Kedaluwarsa'}),
      ),
    ];

    return AppFilterBottomSheet(
      title: _lp.getTranslatedText({
        'en': 'Filter Announcements',
        'id': 'Filter Pengumuman',
      }),
      icon: Icons.tune_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: _lp.getTranslatedText({
                  'en': 'Priority',
                  'id': 'Prioritas',
                }),
                icon: Icons.priority_high_rounded,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: priorityOptions,
                selectedValue: _tempPriority,
                onSelected: (v) => setState(() => _tempPriority = v),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: _lp.getTranslatedText({'en': 'Status', 'id': 'Status'}),
                icon: Icons.info_outline_rounded,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: statusOptions,
                selectedValue: _tempStatus,
                onSelected: (v) => setState(() => _tempStatus = v),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
        ],
      ),
      onApply: () {
        Navigator.pop(context);
        widget.onApply(_tempPriority, _tempStatus);
      },
      onReset: () => setState(() {
        _tempPriority = null;
        _tempStatus = null;
      }),
    );
  }
}
