// Bottom sheet widget for filtering attendance results by date, subject, day, and lesson hour.
// Extracted from TeacherAttendanceScreen._showFilterSheet.
//
// Like a Vue <AttendanceFilter> component that holds temporary filter state
// and emits the final selections back to the parent on "Apply".
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Data class that bundles all filter selections so the parent can apply them.
class AttendanceFilterResult {
  final String? dateFilter;
  final List<String> subjectIds;
  final List<String> dayIds;
  final List<String> lessonHourIds;

  const AttendanceFilterResult({
    required this.dateFilter,
    required this.subjectIds,
    required this.dayIds,
    required this.lessonHourIds,
  });
}

/// Content widget shown inside a scrollable modal bottom sheet.
/// Manages its own temporary filter state and returns an [AttendanceFilterResult]
/// via [onApply] when the user taps "Apply Filter".
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => AttendanceFilterSheet(
///     languageProvider: languageProvider,
///     primaryColor: primaryColor,
///     initialDateFilter: _selectedDateFilter,
///     initialSubjectIds: _selectedSubjectIds,
///     initialDayIds: _selectedDayIds,
///     initialLessonHourIds: _selectedLessonHourIds,
///     subjects: _subjectTeacher,
///     lessonHours: _lessonHours,
///     onApply: (result) { ... },
///   ),
/// );
/// ```
class AttendanceFilterSheet extends StatefulWidget {
  final LanguageProvider languageProvider;
  final Color primaryColor;

  /// Current filter values so the sheet opens with the right chips pre-selected.
  final String? initialDateFilter;
  final List<String> initialSubjectIds;
  final List<String> initialDayIds;
  final List<String> initialLessonHourIds;

  /// Available subjects and lesson hours to show as filter chips.
  final List<dynamic> subjects;
  final List<dynamic> lessonHours;

  /// Called when the user taps "Apply Filter".
  final ValueChanged<AttendanceFilterResult> onApply;

  const AttendanceFilterSheet({
    super.key,
    required this.languageProvider,
    required this.primaryColor,
    required this.initialDateFilter,
    required this.initialSubjectIds,
    required this.initialDayIds,
    required this.initialLessonHourIds,
    required this.subjects,
    required this.lessonHours,
    required this.onApply,
  });

  @override
  State<AttendanceFilterSheet> createState() => _AttendanceFilterSheetState();
}

class _AttendanceFilterSheetState extends State<AttendanceFilterSheet> {
  late String? _tempDateFilter;
  late List<String> _tempSubjectIds;
  late List<String> _tempDayIds;
  late List<String> _tempLessonHourIds;

  // Static day data -- same order as the original.
  static const List<Map<String, String>> _days = [
    {'en': 'Monday', 'id': 'Senin', 'val': '1'},
    {'en': 'Tuesday', 'id': 'Selasa', 'val': '2'},
    {'en': 'Wednesday', 'id': 'Rabu', 'val': '3'},
    {'en': 'Thursday', 'id': 'Kamis', 'val': '4'},
    {'en': 'Friday', 'id': 'Jumat', 'val': '5'},
    {'en': 'Saturday', 'id': 'Sabtu', 'val': '6'},
    {'en': 'Sunday', 'id': 'Minggu', 'val': '7'},
  ];

  @override
  void initState() {
    super.initState();
    _tempDateFilter = widget.initialDateFilter;
    _tempSubjectIds = List.from(widget.initialSubjectIds);
    _tempDayIds = List.from(widget.initialDayIds);
    _tempLessonHourIds = List.from(widget.initialLessonHourIds);
  }

  LanguageProvider get _lang => widget.languageProvider;
  Color get _primary => widget.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildGradientHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range section
                  _buildSectionHeader(
                    _lang.getTranslatedText({'en': 'Time Range', 'id': 'Rentang Waktu'}),
                    Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildDateRangeChips(),

                  // Subject section
                  if (widget.subjects.isNotEmpty) ...[
                    _buildSectionHeader(
                      _lang.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'}),
                      Icons.book_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSubjectChips(),
                  ],

                  // Day section
                  _buildSectionHeader(
                    _lang.getTranslatedText({'en': 'Day', 'id': 'Hari'}),
                    Icons.today_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildDayChips(),

                  // Lesson Hour section
                  if (widget.lessonHours.isNotEmpty) ...[
                    _buildSectionHeader(
                      _lang.getTranslatedText({'en': 'Lesson Hour', 'id': 'Jam Pelajaran'}),
                      Icons.access_time_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildLessonHourChips(),
                  ],
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ======================= Header =======================

  Widget _buildGradientHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primary,
            _primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 20),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(Icons.filter_list, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _lang.getTranslatedText({'en': 'Filter Attendance', 'id': 'Filter Absensi'}),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tempDateFilter = null;
                    _tempSubjectIds.clear();
                    _tempDayIds.clear();
                    _tempLessonHourIds.clear();
                  });
                },
                child: Text(
                  _lang.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================= Section header =======================

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate700),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  // ======================= Chip sections =======================

  Widget _buildDateRangeChips() {
    final items = [
      {'label': _lang.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}), 'val': 'today'},
      {'label': _lang.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'}), 'val': 'week'},
      {'label': _lang.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'}), 'val': 'month'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = _tempDateFilter == item['val'];
        return FilterChip(
          label: Text(item['label']!),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _tempDateFilter = selected ? item['val'] : null;
            });
          },
          backgroundColor: Colors.white,
          selectedColor: _primary.withValues(alpha: 0.2),
          checkmarkColor: _primary,
          labelStyle: TextStyle(
            color: isSelected ? _primary : ColorUtils.slate600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubjectChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.subjects.map((subject) {
        final subjectId = subject['id'].toString();
        final isSelected = _tempSubjectIds.contains(subjectId);
        final label =
            subject['name'] ?? subject['nama'] ?? subject['mata_pelajaran_nama'] ?? 'Subject';
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _tempSubjectIds.add(subjectId);
              } else {
                _tempSubjectIds.remove(subjectId);
              }
            });
          },
          backgroundColor: Colors.white,
          selectedColor: _primary.withValues(alpha: 0.2),
          checkmarkColor: _primary,
          labelStyle: TextStyle(
            color: isSelected ? _primary : ColorUtils.slate600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _days.map((d) {
        final val = d['val']!;
        final isSelected = _tempDayIds.contains(val);
        final label = _lang.getTranslatedText({'en': d['en']!, 'id': d['id']!});
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _tempDayIds.add(val);
              } else {
                _tempDayIds.remove(val);
              }
            });
          },
          backgroundColor: Colors.white,
          selectedColor: _primary.withValues(alpha: 0.2),
          checkmarkColor: _primary,
          labelStyle: TextStyle(
            color: isSelected ? _primary : ColorUtils.slate600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLessonHourChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.lessonHours.map((lh) {
        final lhId = lh['id'].toString();
        final isSelected = _tempLessonHourIds.contains(lhId);
        return FilterChip(
          label: Text(lh['name'] ?? 'Jam'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _tempLessonHourIds.add(lhId);
              } else {
                _tempLessonHourIds.remove(lhId);
              }
            });
          },
          backgroundColor: Colors.white,
          selectedColor: _primary.withValues(alpha: 0.2),
          checkmarkColor: _primary,
          labelStyle: TextStyle(
            color: isSelected ? _primary : ColorUtils.slate600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  // ======================= Footer =======================

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => AppNavigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: ColorUtils.slate300),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
              child: Text(
                _lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(AttendanceFilterResult(
                  dateFilter: _tempDateFilter,
                  subjectIds: _tempSubjectIds,
                  dayIds: _tempDayIds,
                  lessonHourIds: _tempLessonHourIds,
                ));
                AppNavigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
              child: Text(
                _lang.getTranslatedText({'en': 'Apply Filter', 'id': 'Terapkan Filter'}),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
