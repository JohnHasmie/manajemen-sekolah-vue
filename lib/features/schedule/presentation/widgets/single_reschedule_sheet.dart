import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_teaching_hour_dropdown.dart';

Future<String?> showSingleRescheduleSheet({
  required BuildContext context,
  required Map<String, dynamic> schedule,
  required List<dynamic> days,
  required List<dynamic> lessonHours,
  required String semesterId,
  required String academicYearId,
  required LanguageProvider languageProvider,
}) {
  return AppBottomSheet.show<String>(
    context: context,
    title: languageProvider.getTranslatedText({
      'en': 'Move Schedule',
      'id': 'Pindah Jadwal',
    }),
    subtitle: languageProvider.getTranslatedText({
      'en': 'Select target day and hour',
      'id': 'Pilih target hari dan jam pelajaran',
    }),
    icon: Icons.swap_horiz_rounded,
    primaryColor: ColorUtils.getRoleColor('admin'),
    content: _SingleRescheduleContent(
      schedule: schedule,
      days: days,
      lessonHours: lessonHours,
      semesterId: semesterId,
      academicYearId: academicYearId,
      languageProvider: languageProvider,
    ),
  );
}

class _SingleRescheduleContent extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final List<dynamic> days;
  final List<dynamic> lessonHours;
  final String semesterId;
  final String academicYearId;
  final LanguageProvider languageProvider;

  const _SingleRescheduleContent({
    required this.schedule,
    required this.days,
    required this.lessonHours,
    required this.semesterId,
    required this.academicYearId,
    required this.languageProvider,
  });

  @override
  State<_SingleRescheduleContent> createState() =>
      _SingleRescheduleContentState();
}

class _SingleRescheduleContentState extends State<_SingleRescheduleContent> {
  String _selectedDayId = '';
  String _selectedLessonHourId = '';

  List<dynamic> _availableLessonHours = [];
  List<dynamic> _occupiedSlots = [];

  bool _isLoadingHours = false;
  final bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to the schedule's current day
    final currentDayId = widget.schedule['day_id']?.toString() ?? '';
    if (widget.days.any((d) => d['id'].toString() == currentDayId)) {
      _selectedDayId = currentDayId;
      _filterLessonHours();
    }
  }

  void _filterLessonHours() {
    if (_selectedDayId.isEmpty) {
      setState(() {
        _availableLessonHours = [];
        _selectedLessonHourId = '';
      });
      return;
    }

    final filtered = widget.lessonHours.where((jam) {
      final jamDayId = jam['day_id']?.toString() ?? jam['hari_id']?.toString();
      return jamDayId == _selectedDayId;
    }).toList();

    filtered.sort((a, b) {
      final hA = int.tryParse(a['hour_number'].toString()) ?? 0;
      final hB = int.tryParse(b['hour_number'].toString()) ?? 0;
      return hA.compareTo(hB);
    });

    setState(() {
      _availableLessonHours = filtered;
      // Reset selected hour if it's not in the new day's hours
      if (_selectedLessonHourId.isNotEmpty &&
          !filtered.any(
            (jam) => jam['id'].toString() == _selectedLessonHourId,
          )) {
        _selectedLessonHourId = '';
      }
    });

    _fetchOccupiedSlots();
  }

  Future<void> _fetchOccupiedSlots() async {
    setState(() => _isLoadingHours = true);

    try {
      final api = getIt<ApiScheduleService>();
      final classId = widget.schedule['class_id']?.toString() ?? '';
      final teacherId = widget.schedule['teacher_id']?.toString() ?? '';

      List<dynamic> classOccupied = [];
      List<dynamic> teacherOccupied = [];

      // Check class conflicts
      if (classId.isNotEmpty) {
        final classResp = await api.getSchedulesPaginated(
          classId: classId,
          dayId: _selectedDayId,
          semesterId: widget.semesterId,
          academicYearId: widget.academicYearId,
          limit: 100,
        );
        if (classResp['data'] is List) {
          classOccupied = classResp['data'];
        }
      }

      // Check teacher conflicts
      if (teacherId.isNotEmpty) {
        final teacherResp = await api.getSchedulesPaginated(
          teacherId: teacherId,
          dayId: _selectedDayId,
          semesterId: widget.semesterId,
          academicYearId: widget.academicYearId,
          limit: 100,
        );
        if (teacherResp['data'] is List) {
          teacherOccupied = teacherResp['data'];
        }
      }

      if (!mounted) return;

      final allOccupied = [...classOccupied, ...teacherOccupied];
      // Exclude the current schedule from occupied slots so it doesn't block
      // its own move
      final currentScheduleId = widget.schedule['id']?.toString();
      if (currentScheduleId != null) {
        allOccupied.removeWhere(
          (s) => s['id']?.toString() == currentScheduleId,
        );
      }

      setState(() {
        _occupiedSlots = allOccupied;
        _isLoadingHours = false;

        // Auto-clear if the selected hour became occupied
        if (_selectedLessonHourId.isNotEmpty) {
          final isOccupied = _occupiedSlots.any((occ) {
            final occId =
                occ['lesson_hour_days_id']?.toString() ??
                occ['lesson_hour_id']?.toString() ??
                (occ['lesson_hour'] != null
                    ? occ['lesson_hour']['id']?.toString()
                    : null);
            return occId == _selectedLessonHourId;
          });
          if (isOccupied) {
            _selectedLessonHourId = '';
          }
        }
      });
    } catch (e) {
      AppLogger.error(
        'single_reschedule_sheet',
        'Error fetching occupied slots: $e',
      );
      if (mounted) {
        setState(() => _isLoadingHours = false);
      }
    }
  }

  void _onDayChanged(String? val) {
    if (val != null && val != _selectedDayId) {
      setState(() {
        _selectedDayId = val;
      });
      _filterLessonHours();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isId = widget.languageProvider.currentLanguage == 'id';
    final daysItems = widget.days.map((d) {
      String name = (d['name'] ?? d['nama'] ?? '').toString();
      if (isId) {
        name = dayNameToIndonesian(name);
      }
      return DropdownMenuItem<String>(
        value: d['id'].toString(),
        child: Text(name),
      );
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormDropdownField<String>(
          label: widget.languageProvider.getTranslatedText({
            'en': 'Target Day',
            'id': 'Pilih Hari Target',
          }),
          isRequired: true,
          value: _selectedDayId.isEmpty ? null : _selectedDayId,
          items: daysItems,
          onChanged: _onDayChanged,
          hintText: widget.languageProvider.getTranslatedText({
            'en': 'Select Day',
            'id': 'Pilih Hari',
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleTeachingHourDropdown(
          teachingHours: _availableLessonHours,
          occupiedSlots: _occupiedSlots,
          selectedValue: _selectedLessonHourId,
          onChanged: (v) => setState(() => _selectedLessonHourId = v),
          languageProvider: widget.languageProvider,
          primaryColor: ColorUtils.getRoleColor('admin'),
          isLoading: _isLoadingHours,
        ),
        const SizedBox(height: AppSpacing.lg),
        BottomSheetFooter(
          primaryLabel: widget.languageProvider.getTranslatedText({
            'en': 'Save',
            'id': 'Simpan',
          }),
          primaryColor: ColorUtils.getRoleColor('admin'),
          primaryEnabled:
              _selectedDayId.isNotEmpty &&
              _selectedLessonHourId.isNotEmpty &&
              !_isSaving,
          onPrimary: () {
            AppNavigator.pop(context, _selectedLessonHourId);
          },
          onSecondary: () => AppNavigator.pop(context),
        ),
      ],
    );
  }
}
