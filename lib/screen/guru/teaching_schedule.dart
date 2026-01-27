import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/screen/guru/materi_screen.dart';
import 'package:manajemensekolah/screen/guru/presence_teacher.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeachingScheduleScreen extends StatefulWidget {
  const TeachingScheduleScreen({super.key});

  @override
  TeachingScheduleScreenState createState() => TeachingScheduleScreenState();
}

class TeachingScheduleScreenState extends State<TeachingScheduleScreen> {
  List<dynamic> _jadwalList = [];
  List<dynamic> _semesterList = [];
  bool _isLoading = true;
  String _teacherId = '';
  String _teacherNama = '';
  List<dynamic> _academicYearList = [];
  String _selectedSemester = '1'; // Will be set by _setDefaultAcademicPeriod()
  String _selectedAcademicYear =
      '2024/2025'; // Will be set by _setDefaultAcademicPeriod()
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  List<String> _selectedDayIds = [];
  String? _selectedFilterSemester;
  String? _selectedClassId;
  bool _hasActiveFilter = false;
  List<Map<String, String>> _availableClasses = [];

  // Homeroom State
  Map<String, dynamic>? _homeroomData; // Legacy/Primary support
  List<dynamic> _homeroomClassesList = []; // Support multiple classes
  Map<String, dynamic>?
  _selectedHomeroomClass; // Current selected homeroom class
  bool _isHomeroomView = false;

  // DITAMBAHKAN KEMBALI: Toggle antara card dan table view
  bool _isTableView = false;

  List<String> _dayOptions = [
    'Semua Hari',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  Map<String, String> _dayIdMap = {
    'Senin': '1',
    'Selasa': '2',
    'Rabu': '3',
    'Kamis': '4',
    'Jumat': '5',
    'Sabtu': '6',
  };

  final Map<String, Color> _dayColorMap = {
    'Senin': Color(0xFF6366F1),
    'Selasa': Color(0xFF10B981),
    'Rabu': Color(0xFFF59E0B),
    'Kamis': Color(0xFFEF4444),
    'Jumat': Color(0xFF8B5CF6),
    'Sabtu': Color(0xFF06B6D4),
  };

  @override
  void initState() {
    super.initState();
    _setDefaultAcademicPeriod();
    _loadUserData();
  }

  /// Calculate current academic year based on current date
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Academic year runs from July to June
    // If current month is July or later, academic year is currentYear/nextYear
    // Otherwise, academic year is previousYear/currentYear
    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  /// Set default academic year and semester based on current date
  void _setDefaultAcademicPeriod() {
    setState(() {
      _selectedAcademicYear = _getCurrentAcademicYear();
      // Semester will be set by _loadSemesterData called from _loadUserData
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (kDebugMode) {
      print('===== TeachingScheduleScreen: _loadUserData STARTED =====');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user');
      if (kDebugMode) {
        print('Raw User Data from Prefs: $userDataStr');
      }

      final userData = json.decode(userDataStr ?? '{}');
      final userId = userData['id']?.toString() ?? '';

      setState(() {
        _teacherId = userId; // Fallback to userId
        _teacherNama = userData['nama']?.toString() ?? 'Guru';
      });

      if (kDebugMode) {
        print('User ID: $userId');
      }

      if (userId.isNotEmpty) {
        // Resolve Teacher ID from User ID
        try {
          // Import ApiTeacherService if not already (it's in the same package usually)
          // Get Academic Year context
          String? academicYearId;
          try {
            if (mounted) {
              final academicYearProvider = Provider.of<AcademicYearProvider>(
                context,
                listen: false,
              );
              academicYearId = academicYearProvider.selectedAcademicYear?['id']
                  ?.toString();
            }
          } catch (e) {
            // ignore
          }

          final teacherData = await ApiTeacherService.getGuruByUserId(
            userId,
            academicYearId: academicYearId,
          );

          if (kDebugMode) {
            print('🔍 TeachingSchedule - Loading User Data');
            print('🔍 Context Year ID: $academicYearId');
            print(
              '🔍 API Response Homeroom: ${teacherData?['homeroom_class']}',
            );
          }

          if (teacherData != null && teacherData['id'] != null) {
            final resolvedId = teacherData['id'].toString();
            if (kDebugMode) {
              print('✅ Resolved Teacher ID: $resolvedId');
            }
            setState(() {
              _teacherId = resolvedId;

              _homeroomClassesList = [];

              // 1. Add classes from 'teacher_classes' pivot (User Request: "sesuai dengan table teacher_classes")
              if (teacherData['classes'] != null &&
                  teacherData['classes'] is List) {
                final classesList = List.from(teacherData['classes']);
                for (var cls in classesList) {
                  if (!_homeroomClassesList.any(
                    (c) => c['id'].toString() == cls['id'].toString(),
                  )) {
                    _homeroomClassesList.add(cls);
                  }
                }
              }

              // 2. Add classes from 'homeroom_classes' relation (Standard Homeroom definition)
              if (teacherData['homeroom_classes'] != null &&
                  teacherData['homeroom_classes'] is List) {
                final homeroomList = List.from(teacherData['homeroom_classes']);
                for (var cls in homeroomList) {
                  if (!_homeroomClassesList.any(
                    (c) => c['id'].toString() == cls['id'].toString(),
                  )) {
                    _homeroomClassesList.add(cls);
                  }
                }
              }
              // Check singular (legacy or primary) and add if not in list
              if (teacherData['homeroom_class'] != null) {
                _homeroomData = teacherData['homeroom_class'];
                final exists = _homeroomClassesList.any(
                  (c) => c['id'].toString() == _homeroomData!['id'].toString(),
                );
                if (!exists) {
                  _homeroomClassesList.add(_homeroomData);
                }
              }

              // Default selection if available
              if (_homeroomClassesList.isNotEmpty &&
                  _selectedHomeroomClass == null) {
                _selectedHomeroomClass = _homeroomClassesList.first;
              }

              if (kDebugMode) {
                print('✅ Homeroom Data List: $_homeroomClassesList');
              }
            });
          } else {
            if (kDebugMode) {
              print(
                '⚠️ Failed to resolve Teacher ID, using User ID as fallback',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error resolving teacher ID: $e');
          }
        }

        await _loadDayData();
        await _loadSemesterData();
        await _loadAcademicYearData();
        _loadJadwal();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _loadUserData: $e');
      }
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadDayData() async {
    try {
      final dayData = await ApiScheduleService.getHari();
      if (dayData.isNotEmpty) {
        final Map<String, String> newDayIdMap = {};
        final List<String> newDayOptions = ['Semua Hari'];

        for (var day in dayData) {
          final name =
              day['name_id']?.toString() ?? day['name']?.toString() ?? '';
          final id = day['id']?.toString() ?? '';
          if (name.isNotEmpty && id.isNotEmpty) {
            newDayIdMap[name] = id;
            newDayOptions.add(name);
          }
        }

        if (newDayIdMap.isNotEmpty) {
          setState(() {
            _dayIdMap = newDayIdMap;
            _dayOptions = newDayOptions;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading day data: $e');
      }
    }
  }

  Future<void> _loadSemesterData() async {
    try {
      final semesterData = await ApiScheduleService.getSemester();

      setState(() {
        _semesterList = semesterData;
      });

      String? semesterId;

      // 1. Fetch from Backend API (Sync with Dashboard)
      try {
        final result = await ApiScheduleService.getDateBasedSemester();
        if (result.isNotEmpty && result.containsKey('semester')) {
          final targetSemesterName = result['semester'].toString();

          final dateBasedSemester = semesterData.firstWhere((s) {
            final name = (s['name'] ?? s['nama'] ?? '').toString();
            return name.contains(targetSemesterName);
          }, orElse: () => null);

          if (dateBasedSemester != null) {
            semesterId = dateBasedSemester['id'].toString();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching date based semester: $e');
        }
      }

      // 2. Fallback to backend 'current' flag
      if (semesterId == null) {
        final currentSem = semesterData.firstWhere(
          (s) =>
              s['current'] == true ||
              s['current'] == 1 ||
              s['current'].toString() == '1',
          orElse: () => null,
        );

        if (currentSem != null) {
          semesterId = currentSem['id'].toString();
        }
      }

      // 3. Last fallback
      if (semesterId == null && semesterData.isNotEmpty) {
        semesterId = semesterData.first['id'].toString();
      }

      if (semesterId != null && mounted) {
        setState(() {
          _selectedSemester = semesterId!;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading semester data: $e');
      }
    }
  }

  Future<void> _loadAcademicYearData() async {
    try {
      final academicYears = await ApiScheduleService.getAcademicYear();

      // Get global selected year from provider
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final globalSelectedYear = academicYearProvider.selectedAcademicYear;

      setState(() {
        _academicYearList = academicYears
            .where(
              (ay) => (ay['year'] ?? '').toString() != 'Status Kepegawaian',
            )
            .toList();

        // 1. Prioritize Global Provider Selection
        if (globalSelectedYear != null) {
          _selectedAcademicYear = globalSelectedYear['year'].toString();
        } else {
          // 2. Fallback to existing logic if provider is empty
          final currentAY = _academicYearList.firstWhere(
            (ay) =>
                ay['current'] == true ||
                ay['current'] == 1 ||
                ay['current'].toString() == '1',
            orElse: () => null,
          );

          if (currentAY != null) {
            _selectedAcademicYear = currentAY['year'].toString();
          } else if (academicYears.isNotEmpty) {
            _selectedAcademicYear = academicYears.last['year'].toString();
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading academic year data: $e');
      }
    }
  }

  Future<void> _loadJadwal() async {
    if (_teacherId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Use filter semester/year if set, otherwise use selected
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse = _selectedAcademicYear;

      if (kDebugMode) {
        print('FETCHING SCHEDULE WITH:');
        print('- Teacher ID: $_teacherId');
        print('- Semester: $semesterToUse');
        print('- Academic Year: $academicYearToUse');
      }

      dynamic jadwalData;

      if (_isHomeroomView && _selectedHomeroomClass != null) {
        // Fetch schedule for the homeroom class
        final classId = _selectedHomeroomClass!['id'].toString();
        final result = await ApiScheduleService.getSchedulesPaginated(
          classId: classId,
          semesterId: semesterToUse,
          tahunAjaran: academicYearToUse,
          limit: 100, // Fetch all for now
        );
        jadwalData = result['data'] ?? [];
      } else {
        // Fetch teaching schedule for the teacher
        jadwalData = await ApiScheduleService.getFilteredSchedule(
          teacherId: _teacherId,
          semester: semesterToUse,
          academicYear: academicYearToUse,
        );
      }

      final jadwal = jadwalData is List ? jadwalData : [];

      if (kDebugMode) {
        print('Total schedule items loaded: ${jadwal.length}');
      }

      setState(() {
        _jadwalList = jadwal;
        _isLoading = false;

        // Extract unique classes for filter
        final uniqueClasses = <String, String>{};
        for (var item in jadwal) {
          final id =
              item['class_id']?.toString() ??
              item['kelas_id']?.toString() ??
              '';
          final name =
              item['class_name']?.toString() ??
              item['kelas_nama']?.toString() ??
              '';
          if (id.isNotEmpty && name.isNotEmpty) {
            uniqueClasses[id] = name;
          }
        }
        _availableClasses =
            uniqueClasses.entries
                .map((e) => {'id': e.key, 'name': e.value})
                .toList()
              ..sort((a, b) => a['name']!.compareTo(b['name']!));
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load jadwal: $e');
      }
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
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
                'Failed to load schedule data:',
                'Gagal memuat data jadwal:',
              ),
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDayIds.isNotEmpty ||
          _selectedClassId != null ||
          (_selectedFilterSemester != null &&
              _selectedFilterSemester != _selectedSemester);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDayIds.clear();
      _selectedFilterSemester = null;
      _selectedClassId = null;
      _checkActiveFilter();
    });
    // Reload data to ensure semester and other contexts are correct
    _loadSemesterData().then((_) => _loadJadwal());
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    // Hari chips
    for (var dayId in _selectedDayIds) {
      final dayNameRaw = _dayOptions.firstWhere(
        (h) => _dayIdMap[h] == dayId,
        orElse: () => 'Hari',
      );

      // Localization helper for days
      final dayMap = {
        'senin': {'en': 'Monday', 'id': 'Senin'},
        'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'jumat': {'en': 'Friday', 'id': 'Jumat'},
        'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
        'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'minggu': {'en': 'Sunday', 'id': 'Minggu'},
      };

      final normalizedKey = dayNameRaw.toLowerCase();
      final label = dayMap[normalizedKey] != null
          ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
          : dayNameRaw;

      filterChips.add({
        'label': label,
        'onRemove': () {
          setState(() {
            _selectedDayIds.remove(dayId);
            _checkActiveFilter();
          });
        },
      });
    }

    // Class Chip
    if (_selectedClassId != null) {
      final cls = _availableClasses.firstWhere(
        (c) => c['id'] == _selectedClassId,
        orElse: () => {'name': 'Class'},
      );
      filterChips.add({
        'label': cls['name'],
        'onRemove': () {
          setState(() {
            _selectedClassId = null;
            _checkActiveFilter();
          });
        },
      });
    }

    // Semester chip
    if (_selectedFilterSemester != null &&
        _selectedFilterSemester != _selectedSemester) {
      final semester = _semesterList.firstWhere(
        (s) => s['id'].toString() == _selectedFilterSemester,
        orElse: () => {'nama': 'Semester $_selectedFilterSemester'},
      );
      filterChips.add({
        'label': semester['nama'] ?? 'Semester',
        'onRemove': () {
          setState(() {
            _selectedFilterSemester = null;
            _checkActiveFilter();
          });
          _loadJadwal();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    // Temporary values for filter
    String? tempSelectedSemester = _selectedFilterSemester;
    String? tempSelectedClassId = _selectedClassId;

    // Helper for localized day display
    String getLocalizedDay(String dayRaw) {
      final dayMap = {
        'senin': {'en': 'Monday', 'id': 'Senin'},
        'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'jumat': {'en': 'Friday', 'id': 'Jumat'},
        'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
        'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'minggu': {'en': 'Sunday', 'id': 'Minggu'},
      };
      final key = dayRaw.toLowerCase();
      return dayMap[key] != null
          ? languageProvider.getTranslatedText(dayMap[key]!)
          : dayRaw;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        primaryColor: _getPrimaryColor(),
        config: FilterConfig(
          sections: [
            FilterSection(
              key: 'dayIds',
              title: languageProvider.getTranslatedText({
                'en': 'Day',
                'id': 'Hari',
              }),
              options: _dayOptions.where((day) => day != 'Semua Hari').map((
                day,
              ) {
                return FilterOption(
                  label: getLocalizedDay(day),
                  value: _dayIdMap[day] ?? '',
                );
              }).toList(),
              multiSelect: true,
            ),
            FilterSection(
              key: 'classId',
              title: languageProvider.getTranslatedText({
                'en': 'Class',
                'id': 'Kelas',
              }),
              options: _availableClasses.map((cls) {
                return FilterOption(label: cls['name']!, value: cls['id']!);
              }).toList(),
              multiSelect: false,
            ),
            FilterSection(
              key: 'semester',
              title: languageProvider.getTranslatedText({
                'en': 'Semester',
                'id': 'Semester',
              }),
              options: _semesterList.map((semester) {
                return FilterOption(
                  label: semester['name'] ?? semester['nama'] ?? 'Semester',
                  value: semester['id'].toString(),
                );
              }).toList(),
              multiSelect: false,
            ),
          ],
        ),
        initialFilters: {
          'dayIds': _selectedDayIds,
          'classId': tempSelectedClassId,
          'semester': tempSelectedSemester ?? _selectedSemester,
        },
        onApplyFilters: (filters) {
          // Check if semester changed - need to reload data
          bool needsReload = false;

          final newSemester = filters['semester'];

          if (newSemester != null && newSemester != _selectedSemester) {
            needsReload = true;
          }

          setState(() {
            _selectedDayIds = List<String>.from(filters['dayIds'] ?? []);
            _selectedClassId = filters['classId'];
            _selectedFilterSemester = newSemester;

            // Update main semester if filtered
            if (newSemester != null) {
              _selectedSemester = newSemester;
            }

            _checkActiveFilter();
          });

          // Reload data if semester changed
          if (needsReload) {
            _loadJadwal();
          }
        },
      ),
    );
  }

  // DITAMBAHKAN KEMBALI: Method untuk toggle view
  void _toggleView() {
    setState(() {
      _isTableView = !_isTableView;
    });
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
    );
  }

  Color _getDayColor(String day) {
    return _dayColorMap[day] ?? Color(0xFF6B7280);
  }

  String _normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return name;
  }

  List<String> _extractDayIds(dynamic schedule) {
    final List<String> ids = [];
    final rawDaysIds = schedule['days_ids'];

    if (rawDaysIds != null) {
      if (rawDaysIds is List) {
        ids.addAll(rawDaysIds.map((id) => id.toString()));
      } else if (rawDaysIds is String) {
        try {
          final clean = rawDaysIds
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
          if (clean.isNotEmpty) {
            ids.addAll(
              clean
                  .split(',')
                  .map((id) => id.trim())
                  .where((id) => id.isNotEmpty),
            );
          }
        } catch (e) {}
      }
    }

    // Fallback
    if (ids.isEmpty) {
      final fallbackId = schedule['day_id'] ?? schedule['hari_id'];
      if (fallbackId != null) {
        ids.add(fallbackId.toString());
      }
    }
    return ids;
  }

  List<dynamic> _getFilteredSchedules() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();

    // Standard mappings for maximum stability
    final dayNamesISO = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayOrder = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final weekdayToIndo = {
      1: 'Senin',
      2: 'Selasa',
      3: 'Rabu',
      4: 'Kamis',
      5: 'Jumat',
      6: 'Sabtu',
      7: 'Minggu',
    };

    final currentDayISO =
        dayNamesISO[now.weekday - 1]; // 1-based (Mon=1, ..., Sun=7)
    final currentDayIndo = _normalizeDayName(currentDayISO);

    // Find the current day ID from the dynamic map with robust normalized matching
    String? currentDayId;
    _dayIdMap.forEach((key, value) {
      if (_normalizeDayName(key) == currentDayIndo) {
        currentDayId = value.toString();
      }
    });

    final filtered = _jadwalList.where((schedule) {
      final subjectName =
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
      final className = schedule['kelas_nama']?.toString().toLowerCase() ?? '';

      final daysIds = _extractDayIds(schedule);

      final dayNamesStr = daysIds
          .map((id) {
            final entry = _dayIdMap.entries.firstWhere(
              (e) => e.value.toString() == id,
              orElse: () => MapEntry('', ''),
            );
            return entry.key.isNotEmpty
                ? entry.key
                : (weekdayToIndo[int.tryParse(id) ?? 0] ?? '');
          })
          .where((k) => k.isNotEmpty)
          .join(' ')
          .toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayNamesStr.contains(searchTerm);

      // Filter by hari
      final matchesDay =
          _selectedDayIds.isEmpty ||
          _selectedDayIds.any((selectedId) {
            return daysIds.any(
              (dId) => dId.toString() == selectedId.toString(),
            );
          });

      // Filter by class
      final matchesClass =
          _selectedClassId == null ||
          _selectedClassId!.isEmpty ||
          (schedule['class_id']?.toString() == _selectedClassId ||
              schedule['kelas_id']?.toString() == _selectedClassId);

      return matchesSearch && matchesDay && matchesClass;
    }).toList();

    // Sort with multiple fallback layers for "Today" prioritization
    filtered.sort((a, b) {
      final dayIdA = _extractDayIds(a);
      final dayIdB = _extractDayIds(b);

      // Robust "Today" detection
      bool belongsToToday(Map<String, dynamic> item, List<String> ids) {
        // Tier 1: Direct name field check (hari_nama)
        final hariNama = (item['hari_nama'] ?? item['day_name'] ?? '')
            .toString();
        if (hariNama.isNotEmpty &&
            _normalizeDayName(hariNama) == currentDayIndo) {
          return true;
        }

        // Tier 2: ID match using dynamically loaded map
        if (currentDayId != null && ids.any((id) => id == currentDayId)) {
          return true;
        }

        // Tier 3: Direct ISO weekday number match (the ultimate fallback)
        if (ids.any((id) => id == now.weekday.toString())) {
          return true;
        }

        // Tier 4: Map key normalized match
        return ids.any((id) {
          final entry = _dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('', ''),
          );
          return entry.key.isNotEmpty &&
              _normalizeDayName(entry.key) == currentDayIndo;
        });
      }

      final isTodayA = belongsToToday(a, dayIdA);
      final isTodayB = belongsToToday(b, dayIdB);

      // 1. Priority: Today First
      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;

      // 2. Secondary: Sequential Day-of-Week (Mon -> Sun)
      int getMinDayRank(List<String> ids) {
        if (ids.isEmpty) return 99;
        int minIdx = 99;
        for (var id in ids) {
          String name = '';
          final entry = _dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('', ''),
          );
          if (entry.key.isNotEmpty) {
            name = _normalizeDayName(entry.key);
          } else {
            // Mapping failed, try standard ISO assumption
            name = weekdayToIndo[int.tryParse(id) ?? 0] ?? '';
          }

          int idx = dayOrder.indexOf(name);
          if (idx != -1 && idx < minIdx) minIdx = idx;
        }
        return minIdx;
      }

      final rankA = getMinDayRank(dayIdA);
      final rankB = getMinDayRank(dayIdB);
      if (rankA != rankB) return rankA.compareTo(rankB);

      // 3. Tertiary: Item Density (Fewer days first)
      if (dayIdA.length != dayIdB.length) {
        return dayIdA.length.compareTo(dayIdB.length);
      }

      // 4. Quaternary: Chronological (Start Time)
      final timeA = (a['jam_mulai'] ?? a['start_time'] ?? '00:00').toString();
      final timeB = (b['jam_mulai'] ?? b['start_time'] ?? '00:00').toString();
      return timeA.compareTo(timeB);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredSchedules = _getFilteredSchedules();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header dengan gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Teaching Schedule',
                                  'id': 'Jadwal Mengajar',
                                }),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en':
                                      _isHomeroomView &&
                                          _selectedHomeroomClass != null
                                      ? 'Viewing Homeroom Schedule'
                                      : 'View your teaching schedule',
                                  'id':
                                      _isHomeroomView &&
                                          _selectedHomeroomClass != null
                                      ? 'Melihat Jadwal Wali Kelas'
                                      : 'Lihat jadwal mengajar Anda',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // DITAMBAHKAN KEMBALI: Tombol toggle view
                        GestureDetector(
                          onTap: _toggleView,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isTableView ? Icons.grid_view : Icons.list,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Info Guru
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teacherNama,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_homeroomClassesList.isEmpty)
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Teacher',
                                      'id': 'Guru',
                                    }),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTapDown: (TapDownDetails details) {
                                      showMenu(
                                        context: context,
                                        position: RelativeRect.fromLTRB(
                                          details.globalPosition.dx,
                                          details.globalPosition.dy,
                                          details.globalPosition.dx,
                                          details.globalPosition.dy,
                                        ),
                                        items: [
                                          PopupMenuItem(
                                            value: 'guru',
                                            child: Text(
                                              'Guru (Lihat Jadwal Mengajar)',
                                            ),
                                          ),
                                          ..._homeroomClassesList.map(
                                            (c) => PopupMenuItem(
                                              value: c,
                                              child: Text(
                                                'Wali Kelas - ${c['name'] ?? c['nama']}',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ).then((value) {
                                        if (value != null) {
                                          setState(() {
                                            if (value == 'guru') {
                                              _isHomeroomView = false;
                                            } else {
                                              _isHomeroomView = true;
                                              _selectedHomeroomClass =
                                                  value as Map<String, dynamic>;
                                            }
                                          });
                                          _loadJadwal();
                                        }
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          _isHomeroomView &&
                                                  _selectedHomeroomClass != null
                                              ? 'Wali Kelas - ${(_selectedHomeroomClass!['name'] ?? _selectedHomeroomClass!['nama'] ?? '').toString()}'
                                              : 'Guru',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.white
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Icon(
                                          Icons
                                              .arrow_drop_down, // Changed icon to indicate list
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Search Bar with Filter using SeparatedSearchFilter
                    // Search Bar with Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(color: Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: languageProvider
                                          .getTranslatedText({
                                            'en': 'Search schedules...',
                                            'id': 'Cari jadwal...',
                                          }),
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.grey.shade600,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    onSubmitted: (_) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.search,
                                      color: _getPrimaryColor(),
                                    ),
                                    onPressed: () {
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Filter Button
                        Container(
                          decoration: BoxDecoration(
                            color: _hasActiveFilter
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                onPressed: _showFilterSheet,
                                icon: Icon(
                                  Icons.tune,
                                  color: _hasActiveFilter
                                      ? _getPrimaryColor()
                                      : Colors.white,
                                ),
                                tooltip: languageProvider.getTranslatedText({
                                  'en': 'Filter',
                                  'id': 'Filter',
                                }),
                              ),
                              if (_hasActiveFilter)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 8,
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Filter Chips
                    if (_hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ..._buildFilterChips(languageProvider).map((
                                    filter,
                                  ) {
                                    return Container(
                                      margin: EdgeInsets.only(right: 6),
                                      child: Chip(
                                        label: Text(
                                          filter['label'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: Colors.white
                                            .withOpacity(0.2),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        labelPadding: EdgeInsets.only(left: 4),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: _clearAllFilters,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Clear All',
                                    'id': 'Hapus Semua',
                                  }),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading schedule data...',
                          'id': 'Memuat data jadwal...',
                        }),
                      )
                    : Column(
                        children: [
                          // View Toggle Info
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  '${filteredSchedules.length} ${languageProvider.getTranslatedText({'en': 'schedules found', 'id': 'jadwal ditemukan'})}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  _isTableView
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Table View',
                                          'id': 'Tampilan Tabel',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Card View',
                                          'id': 'Tampilan Kartu',
                                        }),
                                  style: TextStyle(
                                    color: _getPrimaryColor(),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),

                          Expanded(
                            child: filteredSchedules.isEmpty
                                ? EmptyState(
                                    icon: Icons.schedule_outlined,
                                    title: languageProvider.getTranslatedText({
                                      'en': 'No Teaching Schedules',
                                      'id': 'Tidak Ada Jadwal Mengajar',
                                    }),
                                    subtitle: languageProvider.getTranslatedText({
                                      'en':
                                          _searchController.text.isNotEmpty ||
                                              _hasActiveFilter
                                          ? 'No schedules found for your search and filters'
                                          : 'There are no teaching schedules available',
                                      'id':
                                          _searchController.text.isNotEmpty ||
                                              _hasActiveFilter
                                          ? 'Tidak ada jadwal yang sesuai dengan pencarian dan filter'
                                          : 'Tidak ada jadwal mengajar yang tersedia',
                                    }),
                                    buttonText: languageProvider
                                        .getTranslatedText({
                                          'en': 'Refresh',
                                          'id': 'Muat Ulang',
                                        }),
                                    onPressed: _loadJadwal,
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadJadwal,
                                    color: _getPrimaryColor(),
                                    backgroundColor: Colors.white,
                                    child: _isTableView
                                        ? _buildTableView(
                                            languageProvider,
                                            filteredSchedules,
                                          )
                                        : _buildCardView(
                                            languageProvider,
                                            filteredSchedules,
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

  // DITAMBAHKAN KEMBALI: Method untuk table view dengan format seperti Excel
  Widget _buildTableView(
    LanguageProvider languageProvider,
    List<dynamic> schedules,
  ) {
    // Group schedules by day and class
    final Map<String, Map<String, List<dynamic>>> scheduleMap = {};

    for (var schedule in schedules) {
      final daysIds = [];
      if (schedule['days_ids'] != null) {
        if (schedule['days_ids'] is List)
          daysIds.addAll(schedule['days_ids']);
        else if (schedule['days_ids'] is String) {
          try {
            final parsed = (schedule['days_ids'] as String)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',');
            daysIds.addAll(parsed);
          } catch (e) {}
        }
      }
      if (daysIds.isEmpty) {
        if (schedule['day_id'] != null)
          daysIds.add(schedule['day_id']);
        else if (schedule['hari_id'] != null)
          daysIds.add(schedule['hari_id']);
      }

      for (var rawDayId in daysIds) {
        final entry = _dayIdMap.entries.firstWhere(
          (e) => e.value.toString() == rawDayId.toString(),
          orElse: () => MapEntry('Unknown', ''),
        );
        final hari = entry.key;
        if (hari == 'Unknown') continue;

        final kelas = schedule['kelas_nama']?.toString() ?? 'Unknown';

        if (!scheduleMap.containsKey(hari)) {
          scheduleMap[hari] = {};
        }
        if (!scheduleMap[hari]!.containsKey(kelas)) {
          scheduleMap[hari]![kelas] = [];
        }

        scheduleMap[hari]![kelas]!.add(schedule);
      }
    }

    // Get unique classes and days
    final classes =
        scheduleMap.values.expand((dayMap) => dayMap.keys).toSet().toList()
          ..sort();

    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final availableDays = days
        .where((day) => scheduleMap.containsKey(day))
        .toList();

    // Get all unique session numbers
    final allSessions =
        schedules
            .map((s) => int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0)
            .toSet()
            .toList()
          ..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'JADWAL PELAJARAN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getPrimaryColor(),
                ),
              ),
              SizedBox(height: 16),

              // Table
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Header Row 1 - Hari
                    Container(
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells for time and session
                          Container(
                            width: 80,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                            child: Text(
                              'Jam Ke-',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                            child: Text(
                              'Waktu',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          // Hari headers
                          ...availableDays.expand((day) {
                            return [
                              Container(
                                width: 200 * classes.length.toDouble(),
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: availableDays.last == day
                                          ? Colors.transparent
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getDayColor(day),
                                  ),
                                ),
                              ),
                            ];
                          }),
                        ],
                      ),
                    ),

                    // Header Row 2 - Kelas
                    Container(
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells for time and session
                          Container(
                            width: 80,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),

                          // Kelas headers for each day
                          ...availableDays.expand((day) {
                            return classes.asMap().entries.map((classEntry) {
                              final isLastInDay =
                                  classEntry.key == classes.length - 1;
                              final isLastDay = availableDays.last == day;

                              return Container(
                                width: 200,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: (isLastInDay && !isLastDay)
                                          ? Colors.grey.shade400
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  classEntry.value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              );
                            }).toList();
                          }),
                        ],
                      ),
                    ),

                    // Data Rows
                    ...allSessions.map((session) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: session == allSessions.last
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Session Number
                            Container(
                              width: 80,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              child: Text(
                                session.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            // Time
                            Container(
                              width: 100,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              child: _buildTimeForSession(session, schedules),
                            ),

                            // Schedule Data for each day and class
                            ...availableDays.expand((day) {
                              return classes.map((kelas) {
                                final scheduleForCell =
                                    _getScheduleForSessionAndDayAndClass(
                                      session,
                                      day,
                                      kelas,
                                      schedules,
                                    );

                                return Container(
                                  width: 200,
                                  height: 60,
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color:
                                            classes.last == kelas &&
                                                availableDays.last != day
                                            ? Colors.grey.shade400
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: scheduleForCell != null
                                      ? Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _getDayColor(
                                              day,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: _getDayColor(
                                                day,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                scheduleForCell['mata_pelajaran_nama'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getDayColor(day),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (scheduleForCell['guru_nama'] !=
                                                  null)
                                                Text(
                                                  scheduleForCell['guru_nama']!,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        )
                                      : Container(),
                                );
                              }).toList();
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Legend
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keterangan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      children: availableDays.map((day) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getDayColor(day),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(day, style: TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get time for session
  Widget _buildTimeForSession(int session, List<dynamic> schedules) {
    final scheduleForSession = schedules.firstWhere(
      (s) => (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session,
      orElse: () => <String, dynamic>{},
    );

    if (scheduleForSession.isNotEmpty) {
      final startTime = _formatTime(scheduleForSession['jam_mulai']);
      final endTime = _formatTime(scheduleForSession['jam_selesai']);
      return Text(
        '$startTime\n$endTime',
        style: TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      '--:--\n--:--',
      style: TextStyle(fontSize: 10, color: Colors.grey),
      textAlign: TextAlign.center,
    );
  }

  // Helper method to find schedule for specific session, day, and class
  Map<String, dynamic>? _getScheduleForSessionAndDayAndClass(
    int session,
    String day,
    String kelas,
    List<dynamic> schedules,
  ) {
    try {
      return schedules.firstWhere(
        (s) =>
            (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session &&
            s['hari_nama']?.toString() == day &&
            s['kelas_nama']?.toString() == kelas,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  // DIPINDAH: Method untuk card view (sebelumnya _buildJadwalCard)
  Widget _buildCardView(
    LanguageProvider languageProvider,
    List<dynamic> schedules,
  ) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        return _buildJadwalCard(schedules[index], languageProvider, index);
      },
    );
  }

  Widget _buildJadwalCard(
    Map<String, dynamic> jadwal,
    LanguageProvider languageProvider,
    int index,
  ) {
    final daysIds = _extractDayIds(jadwal);

    String dayNames = daysIds
        .map((id) {
          final entry = _dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('Unknown', ''),
          );
          return entry.key;
        })
        .where((n) => n != 'Unknown' && n.isNotEmpty)
        .join(', ');

    // Fallback display if ID mapping failed
    if (dayNames.isEmpty) {
      final rawDayName = (jadwal['hari_nama'] ?? jadwal['day_name'] ?? '')
          .toString();
      if (rawDayName.isNotEmpty) {
        dayNames = _normalizeDayName(rawDayName);
      }
    }

    final day = dayNames.isNotEmpty ? dayNames : 'Unknown';
    // Use first day color for simplicity, or mixing colors? First day is fine.
    final firstDayName = daysIds.isNotEmpty
        ? _dayIdMap.entries
              .firstWhere(
                (e) => e.value.toString() == daysIds.first.toString(),
                orElse: () => MapEntry('Senin', ''),
              )
              .key
        : 'Senin';
    final dayColor = _getDayColor(firstDayName);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to Presence Page with schedule data
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresencePage(
                  teacher: {'id': _teacherId, 'nama': _teacherNama},
                  initialDate: DateTime.now(),
                  initialSubjectId:
                      (jadwal['subject_id'] ??
                              jadwal['mata_pelajaran_id'] ??
                              jadwal['mata_pelajaran']?['id'])
                          ?.toString(),
                  initialSubjectName:
                      (jadwal['subject_name'] ??
                              jadwal['mata_pelajaran_nama'] ??
                              jadwal['mata_pelajaran']?['name'])
                          ?.toString(),
                  initialclassId:
                      (jadwal['class_id'] ??
                              jadwal['kelas_id'] ??
                              jadwal['class']?['id'])
                          ?.toString(),
                  initialClassName:
                      (jadwal['class_name'] ??
                              jadwal['kelas_nama'] ??
                              jadwal['class']?['name'])
                          ?.toString(),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Strip berwarna di pinggir kiri sesuai hari
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: dayColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),

                // Background pattern effect
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header dengan mata pelajaran dan tahun ajaran - DIUBAH
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  jadwal['mata_pelajaran_nama'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'Subject',
                                        'id': 'Mata Pelajaran',
                                      }),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                // DIUBAH: Tahun ajaran di bawah mata pelajaran dengan ukuran kecil
                                Text(
                                  jadwal['tahun_ajaran_nama'] ??
                                      _selectedAcademicYear,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // DIUBAH: Hari diperbesar
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: dayColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: dayColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              day,
                              style: TextStyle(
                                color: dayColor,
                                fontSize: 14, // DIUBAH: diperbesar dari 12
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Informasi waktu
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.access_time,
                              color: _getPrimaryColor(),
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Time',
                                    'id': 'Waktu',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${_formatTime(jadwal['jam_mulai'])} - ${_formatTime(jadwal['jam_selesai'])}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.format_list_numbered,
                              color: _getPrimaryColor(),
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Session',
                                    'id': 'Sesi',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${languageProvider.getTranslatedText({'en': 'Hour', 'id': 'Jam'})} ${jadwal['jam_ke'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Informasi kelas dan semester - DIUBAH: menghapus tahun ajaran dari sini
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.school,
                              color: _getPrimaryColor(),
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Class & Semester',
                                    'id': 'Kelas & Semester',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${jadwal['kelas_nama'] ?? '-'} • ${jadwal['semester_nama'] ?? 'Semester'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MateriPage(
                                      teacher: {
                                        'id': _teacherId,
                                        'nama': _teacherNama,
                                      },
                                      initialSubjectId:
                                          (jadwal['subject_id'] ??
                                                  jadwal['mata_pelajaran_id'])
                                              ?.toString(),
                                      initialSubjectName:
                                          (jadwal['subject_name'] ??
                                                  jadwal['mata_pelajaran_nama'])
                                              ?.toString(),
                                      initialClassId:
                                          (jadwal['class_id'] ??
                                                  jadwal['kelas_id'])
                                              ?.toString(),
                                      initialClassName:
                                          (jadwal['class_name'] ??
                                                  jadwal['kelas_nama'])
                                              ?.toString(),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.library_books, size: 16),
                              label: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Material',
                                  'id': 'Materi',
                                }),
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _getPrimaryColor(),
                                side: BorderSide(color: _getPrimaryColor()),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Calculate next occurrence date for this schedule
                                final now = DateTime.now();
                                final scheduleDay = _dayIdMap.entries
                                    .firstWhere(
                                      (entry) =>
                                          entry.value.toString() ==
                                          (jadwal['day_id'] ??
                                                  jadwal['hari_id'])
                                              ?.toString(),
                                      orElse: () => MapEntry('Senin', '1'),
                                    )
                                    .key;
                                final scheduleDayIndex = _dayOptions.indexOf(
                                  scheduleDay,
                                );
                                final todayIndex = now.weekday;
                                int daysUntilSchedule =
                                    scheduleDayIndex - todayIndex;
                                if (daysUntilSchedule < 0) {
                                  daysUntilSchedule += 7;
                                }
                                final scheduleDate = now.add(
                                  Duration(days: daysUntilSchedule),
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassActifityScreen(
                                      initialDate: scheduleDate,
                                      initialSubjectId:
                                          (jadwal['subject_id'] ??
                                                  jadwal['mata_pelajaran_id'])
                                              ?.toString(),
                                      initialSubjectName:
                                          (jadwal['subject_name'] ??
                                                  jadwal['mata_pelajaran_nama'])
                                              ?.toString(),
                                      initialClassId:
                                          (jadwal['class_id'] ??
                                                  jadwal['kelas_id'])
                                              ?.toString(),
                                      initialClassName:
                                          (jadwal['class_name'] ??
                                                  jadwal['kelas_nama'])
                                              ?.toString(),
                                      autoShowActivityDialog: true,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.assignment, size: 16),
                              label: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Activity',
                                  'id': 'Aktivitas',
                                }),
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getPrimaryColor(),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';

    // Handle various time formats
    final cleanedTime = time.replaceAll('.', ':');
    final timeParts = cleanedTime.split(':');

    if (timeParts.length >= 2) {
      final hour = timeParts[0].padLeft(2, '0');
      final minute = timeParts[1].padLeft(2, '0');
      return '$hour:$minute';
    }

    return time.length >= 5 ? time.substring(0, 5) : time;
  }
}
