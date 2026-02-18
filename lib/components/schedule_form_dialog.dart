import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class ScheduleFormDialog extends StatefulWidget {
  final List<dynamic> teacherList;
  final List<dynamic> subjectList;
  final List<dynamic> classList;
  final List<dynamic> hariList;
  final List<dynamic> semesterList;
  final List<dynamic> jamPelajaranList;
  final List<dynamic> academicYearList; // New: List of AC
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
    required this.hariList,
    required this.semesterList,
    required this.jamPelajaranList,
    required this.semester,
    required this.academicYear,
    this.academicYearList =
        const [], // Default to empty if not passed (migration safety)
    this.schedule,
    required this.apiService,
    required this.apiTeacherService,
  });

  @override
  ScheduleFormDialogState createState() => ScheduleFormDialogState();
}

class ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedTeacher;
  late String _selectedSubject;
  late String _selectedClass;
  late String _selectedDay;
  List<String> _selectedDayIds = [];
  late String _selectedSemester;
  late String _selectedAcademicYear; // New: Local state for AC
  late String _selectedJamPelajaran;

  List<dynamic> _filteredSubjectList = [];
  List<dynamic> _availableJamPelajaranList = [];
  List<dynamic> _lessonHourSettings = [];
  List<dynamic> _occupiedSlots = [];
  bool _isLoadingSubjects = false;
  bool _isLoadingJamPelajaran = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiSettingsService.getLessonHourSettings();
      if (mounted) {
        setState(() {
          _lessonHourSettings = settings;
        });
        // Re-filter if we already have potential candidates
        if (_availableJamPelajaranList.isNotEmpty &&
            _selectedDayIds.isNotEmpty) {
          _filterAvailableJamPelajaran();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading settings: $e');
    }
  }

  Color _getPrimaryColor() {
    return Color(0xFF4361EE); // Blue untuk admin
  }

  void _initializeForm() {
    _selectedTeacher = '';
    _selectedSubject = '';
    _selectedClass = '';
    _selectedDay = '';
    _selectedDayIds = [];
    _selectedSemester = widget.semester;
    _selectedAcademicYear = widget.academicYear;
    _selectedJamPelajaran = '';

    _filteredSubjectList = widget.subjectList;
    _availableJamPelajaranList = [];

    if (widget.schedule != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setEditFormValues();
      });
    }

    if (widget.hariList.isNotEmpty && _selectedDayIds.isEmpty) {
      // Default to first day if none selected (optional, or leave empty)
      // _selectedDayIds = [widget.hariList.first['id']?.toString() ?? ''];
    }
  }

  void _setEditFormValues() {
    setState(() {
      _selectedTeacher =
          widget.schedule['guru_id']?.toString() ??
          widget.schedule['teacher_id']?.toString() ??
          '';
      _selectedSubject =
          widget.schedule['mata_pelajaran_id']?.toString() ??
          widget.schedule['subject_id']?.toString() ??
          '';
      _selectedClass =
          widget.schedule['kelas_id']?.toString() ??
          widget.schedule['class_id']?.toString() ??
          '';
      _selectedDayIds = [];
      if (widget.schedule['days_ids'] != null &&
          widget.schedule['days_ids'] is List) {
        _selectedDayIds = List<String>.from(
          (widget.schedule['days_ids'] as List).map((e) => e.toString()),
        );
      } else if (widget.schedule['day_id'] != null) {
        // Fallback or legacy
        _selectedDayIds = [widget.schedule['day_id'].toString()];
      } else if (widget.schedule['hari_id'] != null) {
        _selectedDayIds = [widget.schedule['hari_id'].toString()];
      }
      _selectedSemester =
          widget.schedule['semester_id']?.toString() ??
          widget.schedule['semester']?.toString() ??
          widget.semester;
      _selectedAcademicYear =
          widget.schedule['academic_year_id']?.toString() ??
          widget.schedule['academic_year']?.toString() ??
          widget.academicYear;
      _selectedJamPelajaran =
          widget.schedule['lesson_hour_days_id']?.toString() ??
          widget.schedule['lesson_hour_id']?.toString() ??
          widget.schedule['jam_pelajaran_id']?.toString() ??
          '';

      if (_selectedTeacher.isNotEmpty) {
        _filterSubjectsByTeacher(_selectedTeacher);
      }

      if (_selectedDayIds.isNotEmpty) {
        _filterAvailableJamPelajaran();
        _fetchOccupiedSlots();
      }
    });
  }

  Future<void> _fetchOccupiedSlots() async {
    if (_selectedClass.isEmpty ||
        _selectedDayIds.isEmpty ||
        _selectedSemester.isEmpty) {
      return;
    }

    try {
      final response = await ApiScheduleService.getSchedulesPaginated(
        classId: _selectedClass,
        hariId: _selectedDayIds.first,
        semesterId: _selectedSemester,
        tahunAjaran: _selectedAcademicYear,
        limit: 100, // Ensure we get all slots
      );

      final occupied = response['data'] is List ? response['data'] : [];

      setState(() {
        _occupiedSlots = occupied;

        // If editing, exclude current schedule from occupied list
        if (widget.schedule != null && widget.schedule['id'] != null) {
          _occupiedSlots.removeWhere((s) => s['id'] == widget.schedule['id']);
        }
      });

      if (kDebugMode) {
        print('DEBUG: Occupied slots count: ${_occupiedSlots.length}');
        if (_occupiedSlots.isNotEmpty) {
          print(
            'DEBUG: First occupied slot keys: ${_occupiedSlots.first.keys}',
          );
          print(
            'DEBUG: First occupied slot LHD_ID: ${_occupiedSlots.first['lesson_hour_days_id']}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching occupied slots: $e');
    }
  }

  Future<void> _filterSubjectsByTeacher(String teacherId) async {
    try {
      setState(() => _isLoadingSubjects = true);

      final teacherSubjects = await widget.apiTeacherService
          .getSubjectByTeacher(teacherId);

      final filtered = widget.subjectList.where((subject) {
        return teacherSubjects.any(
          (teacherSubject) => teacherSubject['id'] == subject['id'],
        );
      }).toList();

      setState(() {
        _filteredSubjectList = filtered;
        _isLoadingSubjects = false;

        if (_selectedSubject.isNotEmpty) {
          final currentSubjectExists = filtered.any(
            (subject) => subject['id'] == _selectedSubject,
          );
          if (!currentSubjectExists) {
            _selectedSubject = '';
          }
        }
        if (kDebugMode) {
          print(
            'DEBUG: _availableJamPelajaranList from backend: $_availableJamPelajaranList',
          );
        }

        // Removed redundant Client-Side Filter based on Settings here.
        // It is handled correctly in _filterAvailableJamPelajaran() which is called when needed.
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error filtering subjects: $e');
      }
      setState(() {
        _filteredSubjectList = widget.subjectList;
        _isLoadingSubjects = false;
      });
      _showErrorSnackBar('Failed to load teacher subjects');
    }
  }

  void _filterAvailableJamPelajaran() {
    setState(() => _isLoadingJamPelajaran = true);

    try {
      if (_selectedDayIds.isEmpty) {
        setState(() {
          _availableJamPelajaranList = widget.jamPelajaranList;
          _isLoadingJamPelajaran = false;
        });
        return;
      }

      final selectedDayId = _selectedDayIds.first;

      // Filter by day_id directly since backend now populates it
      final filtered = widget.jamPelajaranList.where((jam) {
        final jamDayId =
            jam['day_id']?.toString() ?? jam['hari_id']?.toString();
        return jamDayId == selectedDayId;
      }).toList();

      // Sort by hour_number
      filtered.sort((a, b) {
        final hA = int.tryParse(a['hour_number'].toString()) ?? 0;
        final hB = int.tryParse(b['hour_number'].toString()) ?? 0;
        return hA.compareTo(hB);
      });

      setState(() {
        _availableJamPelajaranList = filtered;
        _isLoadingJamPelajaran = false;

        // Reset selected jam if it's no longer valid
        if (_selectedJamPelajaran.isNotEmpty) {
          final exists = filtered.any(
            (jam) => jam['id'].toString() == _selectedJamPelajaran,
          );
          if (!exists) {
            _selectedJamPelajaran = '';
          }
        }
      });
      // Trigger fetch occupied slots
      _fetchOccupiedSlots();
    } catch (e) {
      if (kDebugMode) print('Error filtering jam pelajaran: $e');
      setState(() {
        _availableJamPelajaranList = widget.jamPelajaranList;
        _isLoadingJamPelajaran = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll(
                'Failed to load teacher subjects',
                'Gagal memuat mata pelajaran guru',
              ),
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> _removeDuplicates(List<dynamic> items, String idField) {
    final seen = <String>{};
    return items.where((item) {
      final id = item[idField]?.toString() ?? '';
      if (seen.contains(id)) {
        return false;
      } else {
        seen.add(id);
        return true;
      }
    }).toList();
  }

  String _formatTimeForDropdown(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '07:00';

    try {
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
      }
      return timeString;
    } catch (e) {
      return '07:00';
    }
  }

  String _translateDayName(String dayName, String languageCode) {
    if (languageCode == 'en') return dayName;
    const dayMap = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };
    return dayMap[dayName] ?? dayName;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final uniqueTeacherList = _removeDuplicates(widget.teacherList, 'id');
        final uniqueClassList = _removeDuplicates(widget.classList, 'id');
        final uniqueHariList = _removeDuplicates(widget.hariList, 'id');
        final uniqueSemesterList = _removeDuplicates(widget.semesterList, 'id');
        final uniqueJamPelajaranList = _removeDuplicates(
          _availableJamPelajaranList,
          'id',
        );
        final uniqueSubjectList = _removeDuplicates(_filteredSubjectList, 'id');

        final isEdit = widget.schedule != null;
        final title = isEdit
            ? languageProvider.getTranslatedText({
                'en': 'Edit Schedule',
                'id': 'Edit Jadwal',
              })
            : languageProvider.getTranslatedText({
                'en': 'Add Schedule',
                'id': 'Tambah Jadwal',
              });
        final subtitle = isEdit
            ? languageProvider.getTranslatedText({
                'en': 'Update schedule information',
                'id': 'Perbarui informasi jadwal',
              })
            : languageProvider.getTranslatedText({
                'en': 'Fill in the schedule information',
                'id': 'Isi informasi jadwal',
              });

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Pattern #9 Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPrimaryColor(),
                      _getPrimaryColor().withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // 44×44 icon container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_calendar_outlined : Icons.add_chart,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 32×32 circle X close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTeacherDropdown(
                          uniqueTeacherList,
                          languageProvider,
                        ),
                        const SizedBox(height: 12),
                        _buildSubjectDropdown(
                          uniqueSubjectList,
                          languageProvider,
                        ),
                        const SizedBox(height: 12),
                        _buildClassDropdown(uniqueClassList, languageProvider),
                        const SizedBox(height: 12),
                        _buildDayMultiSelect(uniqueHariList, languageProvider),
                        const SizedBox(height: 12),
                        _buildAcademicYearDropdown(
                          widget.academicYearList,
                          languageProvider,
                        ),
                        const SizedBox(height: 12),
                        _buildSemesterDropdown(
                          uniqueSemesterList,
                          languageProvider,
                        ),
                        const SizedBox(height: 12),
                        _buildTeachingHourDropdown(
                          uniqueJamPelajaranList,
                          languageProvider,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Pattern #9 Footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: ColorUtils.slate100, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Cancel',
                            'id': 'Batal',
                          }),
                          style: TextStyle(color: ColorUtils.slate600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Save',
                            'id': 'Simpan',
                          }),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeacherDropdown(
    List<dynamic> teachers,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Teacher', 'id': 'Guru'}),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedTeacher.isNotEmpty ? _selectedTeacher : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Teacher',
                    'id': 'Pilih Guru',
                  }),
                  style: TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...teachers.map<DropdownMenuItem<String>>((teacher) {
                return DropdownMenuItem<String>(
                  value: teacher['id'] as String,
                  child: Text(
                    teacher['nama'] ?? teacher['name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTeacher = value ?? '';
                _selectedSubject = '';
                _filteredSubjectList = [];
              });
              if (value != null && value.isNotEmpty) {
                _filterSubjectsByTeacher(value);
              } else {
                setState(() {
                  _filteredSubjectList = widget.subjectList;
                });
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.person,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a teacher',
                  'id': 'Harap pilih guru',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown(
    List<dynamic> subjects,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedSubject.isNotEmpty ? _selectedSubject : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Subject',
                    'id': 'Pilih Mata Pelajaran',
                  }),
                  style: TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...subjects.map<DropdownMenuItem<String>>((subject) {
                return DropdownMenuItem<String>(
                  value: subject['id'] as String,
                  child: Text(
                    subject['name'] ?? subject['nama'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }),
            ],
            onChanged: _isLoadingSubjects
                ? null
                : (value) {
                    setState(() {
                      _selectedSubject = value ?? '';
                    });
                  },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.book, color: _getPrimaryColor(), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: _isLoadingSubjects
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a subject',
                  'id': 'Harap pilih mata pelajaran',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassDropdown(
    List<dynamic> classes,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedClass.isNotEmpty ? _selectedClass : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Class',
                    'id': 'Pilih Kelas',
                  }),
                  style: TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...classes.map((classItem) {
                return DropdownMenuItem<String>(
                  value: classItem['id']?.toString() ?? '',
                  child: Text(
                    classItem['name'] ?? classItem['nama'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedClass = value ?? '';
              });
              if (_selectedDayIds.isNotEmpty) {
                _fetchOccupiedSlots();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.school,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a class',
                  'id': 'Harap pilih kelas',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayMultiSelect(
    List<dynamic> days,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Days', 'id': 'Hari'}),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: days.map((day) {
                  final dayId = day['id'].toString();
                  final isSelected = _selectedDayIds.contains(dayId);
                  return FilterChip(
                    label: Text(
                      _translateDayName(
                        day['name'] ?? day['nama'] ?? 'Unknown',
                        languageProvider.currentLanguage,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedDayIds.add(dayId);
                        } else {
                          _selectedDayIds.remove(dayId);
                        }
                      });
                      if (_selectedDayIds.isNotEmpty) {
                        _filterAvailableJamPelajaran();
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: _getPrimaryColor().withValues(alpha: 0.12),
                    checkmarkColor: _getPrimaryColor(),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: isSelected ? _getPrimaryColor() : ColorUtils.slate600,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? _getPrimaryColor() : ColorUtils.slate300,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  );
                }).toList(),
              ),
              if (_selectedDayIds.isEmpty &&
                  _filteredSubjectList.isNotEmpty) // Basic check state
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Please select at least one day',
                      'id': 'Harap pilih minimal satu hari',
                    }),
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicYearDropdown(
    List<dynamic> academicYears,
    LanguageProvider languageProvider,
  ) {
    // Determine items. If list is empty, maybe show only current?
    // Usually list is passed from parent.
    final items = academicYears.isNotEmpty
        ? academicYears
        : [
            {'id': widget.academicYear, 'year': 'Current'},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Academic Year',
            'id': 'Tahun Ajaran',
          }),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedAcademicYear.isNotEmpty
                ? _selectedAcademicYear
                : null,
            items: items.map<DropdownMenuItem<String>>((year) {
              return DropdownMenuItem<String>(
                value: year['id']?.toString() ?? '',
                child: Text(
                  year['year'] ?? year['name'] ?? 'Unknown',
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAcademicYear = value ?? '';
              });
              if (_selectedDayIds.isNotEmpty) {
                // If AC changes, maybe slots change availability?
                // Probably yes if slots are tied to schedule which is tied to year.
                // But generally occupied slots are fetched by year param.
                _fetchOccupiedSlots();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.calendar_today,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select an academic year',
                  'id': 'Harap pilih tahun ajaran',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterDropdown(
    List<dynamic> semesters,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Semester',
            'id': 'Semester',
          }),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedSemester.isNotEmpty
                ? _selectedSemester
                : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Semester',
                    'id': 'Pilih Semester',
                  }),
                  style: TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...semesters.map<DropdownMenuItem<String>>((semester) {
                return DropdownMenuItem<String>(
                  value: semester['id']?.toString() ?? '',
                  child: Text(
                    semester['name'] ?? semester['nama'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedSemester = value ?? '';
              });
              if (_selectedDayIds.isNotEmpty) {
                _fetchOccupiedSlots();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.grade,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a semester',
                  'id': 'Harap pilih semester',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeachingHourDropdown(
    List<dynamic> teachingHours,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Teaching Hour',
            'id': 'Jam Pelajaran',
          }),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Teaching Hour',
                    'id': 'Pilih Jam Pelajaran',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...() {
                final seenIds = <String>{};
                return teachingHours
                    .where((jam) {
                      final id = jam['id']?.toString() ?? '';
                      if (id.isEmpty || seenIds.contains(id)) {
                        return false;
                      }
                      seenIds.add(id);
                      return true;
                    })
                    .map<DropdownMenuItem<String>>((jam) {
                      final jamId = jam['id']?.toString() ?? '';
                      bool isAvailable =
                          jam['is_terpakai'] != 1 && jam['is_terpakai'] != true;

                      // Check overlap with occupied slots
                      final isOccupied = _occupiedSlots.any((occupied) {
                        // Use lesson_hour_id first (new backend), fallback to lesson_hour_days_id (legacy/backup)
                        // But since jamId is generic (UUID), we basically MUST match with lesson_hour_id (UUID)
                        // Use lesson_hour_days_id as primary match since it links to lesson_hours table
                        final occId =
                            occupied['lesson_hour_days_id']?.toString() ??
                            occupied['lesson_hour_id']?.toString() ??
                            (occupied['lesson_hour'] != null
                                ? occupied['lesson_hour']['id']?.toString()
                                : null);

                        // If backend doesn't return lesson_hour_id yet, we might fail to detect overlap.
                        // But we fixed backend to return it.

                        final match = occId == jamId;
                        if (kDebugMode && match) {
                          print(
                            'DEBUG: Slot $jamId is occupied by ${occupied['id']} (LHD: ${occupied['lesson_hour_days_id']})',
                          );
                        }
                        return match;
                      });

                      if (isOccupied) {
                        isAvailable = false;
                      }

                      final jamKe = jam['hour_number'] ?? jam['jam_ke'] ?? '';
                      final jamMulai = _formatTimeForDropdown(
                        jam['start_time']?.toString() ??
                            jam['jam_mulai']?.toString(),
                      );
                      final jamSelesai = _formatTimeForDropdown(
                        jam['end_time']?.toString() ??
                            jam['jam_selesai']?.toString(),
                      );

                      return DropdownMenuItem<String>(
                        value: jamId,
                        enabled: isAvailable, // Disable if occupied
                        child: Opacity(
                          opacity: isAvailable ? 1.0 : 0.5,
                          child: Text(
                            isAvailable
                                ? '$jamKe ($jamMulai - $jamSelesai)'
                                : '$jamKe ($jamMulai - $jamSelesai) - Terisi',
                            style: TextStyle(
                              fontSize: 14,
                              color: isAvailable ? Colors.black : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      );
                    });
              }(),
            ],
            onChanged: _isLoadingJamPelajaran
                ? null
                : (value) {
                    setState(() {
                      _selectedJamPelajaran = value ?? '';
                    });
                  },
            initialValue:
                _selectedJamPelajaran.isNotEmpty &&
                    teachingHours.any(
                      (jam) =>
                          (jam['id']?.toString() ?? '') ==
                          _selectedJamPelajaran,
                    )
                ? _selectedJamPelajaran
                : null,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.access_time,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: _isLoadingJamPelajaran
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a teaching hour',
                  'id': 'Harap pilih jam pelajaran',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  void _saveSchedule() {
    if (_formKey.currentState!.validate()) {
      final scheduleData = {
        'teacher_id': _selectedTeacher,
        'subject_id': _selectedSubject,
        'class_id': _selectedClass,
        'days_ids': _selectedDayIds, // Changed key & data structure
        'semester_id': _selectedSemester,
        'academic_year_id': _selectedAcademicYear,
        'lesson_hour_id': _selectedJamPelajaran,
      };

      Navigator.pop(context, scheduleData);
    }
  }
}
