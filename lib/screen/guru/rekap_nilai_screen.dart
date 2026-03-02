import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_grade_recap_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_rekap_nilai_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class RekapNilaiPage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const RekapNilaiPage({super.key, required this.teacher});

  @override
  State<RekapNilaiPage> createState() => _RekapNilaiPageState();
}

class _RekapNilaiPageState extends State<RekapNilaiPage> {
  // Services
  final ApiSubjectService apiSubjectService = ApiSubjectService();
  final ApiTeacherService apiTeacherService = ApiTeacherService();

  // State
  int _currentStep = 0; // 0: Class List, 1: Subject List, 2: Recap Table

  // Data
  List<dynamic> _classList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _chapters = [];
  List<dynamic> _allAvailableChapters = [];
  List<dynamic> _todaySchedules = [];
  Map<String, String> _dayIdMap = {};

  // Computed Table Data
  List<Map<String, dynamic>> _tableData = [];
  List<dynamic> _rawGrades = [];

  // Selected Data
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Controllers for editable fields
  final Map<String, TextEditingController> _predikatControllers = {};
  final Map<String, TextEditingController> _deskripsiControllers = {};
  final Map<String, TextEditingController> _scoreControllers = {};

  // Loading & Pagination
  bool _isLoading = false;
  bool _isSaving = false;
  double _studentInfoWidth = 160.0; // Default width for frozen column
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodaySchedules();
      _loadClasses();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    for (var c in _predikatControllers.values) {
      c.dispose();
    }
    for (var c in _deskripsiControllers.values) {
      c.dispose();
    }
    for (var c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading && _currentStep == 0) {
        _loadMoreClasses();
      }
    }
  }

  void _onSearchChanged() {
    // Manual search triggered by button
  }

  // ==================== PRIORITY LOGIC ====================

  Future<void> _loadTodaySchedules() async {
    try {
      final days = await ApiScheduleService.getHari();
      final Map<String, String> dayIdMap = {};
      for (var day in days) {
        dayIdMap[day['nama'] ?? day['name'] ?? ''] = day['id'].toString();
      }

      final now = DateTime.now();
      final dayNamesISO = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final currentDayISO = dayNamesISO[now.weekday - 1];
      final currentDayIndo = _normalizeDayName(currentDayISO);

      String? currentDayId;
      dayIdMap.forEach((key, value) {
        if (_normalizeDayName(key) == currentDayIndo) {
          currentDayId = value;
        }
      });

      if (!mounted) return;
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final schedules = await ApiScheduleService.getSchedulesPaginated(
        limit: 100,
        guruId: widget.teacher['id'],
        tahunAjaran: academicYearId,
      );

      final List<dynamic> allSchedules = schedules['data'] ?? [];

      if (mounted) {
        setState(() {
          _dayIdMap = dayIdMap;
          _todaySchedules = allSchedules.where((s) {
            final ids = _extractDayIds(s);
            if (currentDayId != null && ids.contains(currentDayId)) return true;
            return ids.any((id) {
              final entry = _dayIdMap.entries.firstWhere(
                (e) => e.value == id,
                orElse: () => const MapEntry('', ''),
              );
              return entry.key.isNotEmpty &&
                  _normalizeDayName(entry.key) == currentDayIndo;
            });
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading today schedules: $e');
    }
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
    if (schedule == null) return [];
    final rawIds = schedule['days_ids'] ?? schedule['day_id'];
    if (rawIds == null) return [];

    if (rawIds is List) {
      return rawIds.map((e) => e.toString()).toList();
    }
    if (rawIds is String) {
      if (rawIds.contains('[')) {
        try {
          final parsed = json.decode(rawIds);
          if (parsed is List) return parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return rawIds
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [rawIds.toString()];
  }

  // ==================== HELPER METHODS ====================

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==================== LOAD DATA ====================

  Future<void> _loadClasses({bool resetPage = true}) async {
    if (resetPage) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _classList = [];
        _hasMoreData = true;
      });
    }

    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();
      final role = widget.teacher['role']?.toString().toLowerCase() ?? '';

      List<dynamic> loadedClasses = [];

      if (role.contains('guru')) {
        loadedClasses = await ApiTeacherService.getTeacherClasses(
          widget.teacher['id'],
          academicYearId: academicYearId,
        );
        _hasMoreData = false;
      } else {
        final response = await ApiClassService.getClassPaginated(
          page: _currentPage,
          limit: _perPage,
          academicYearId: academicYearId,
          search: _searchController.text,
        );
        loadedClasses = response['data'] ?? [];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      }

      if (mounted) {
        setState(() {
          if (resetPage) {
            _classList = loadedClasses;
          } else {
            _classList.addAll(loadedClasses);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadMoreClasses() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadClasses(resetPage: false);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _subjectList = [];
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/class/${_selectedClass!['id']}/subjects?teacher_id=${widget.teacher['id']}',
        ),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final allSubjects = json.decode(response.body) as List;
        setState(() {
          _subjectList = allSubjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadRecapData() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId =
          (provider.selectedAcademicYear?['id'] ??
                  provider.activeAcademicYear?['id'])
              ?.toString() ??
          '';

      if (academicYearId.isEmpty) {
        throw Exception(
          'Academic Year is required but not selected or active.',
        );
      }

      final classId = _selectedClass!['id'].toString();
      final subjectId = _selectedSubject!['id'].toString();

      // 1. Fetch Students
      final students = await ApiClassService.getStudentsByClassId(classId);

      // 2. Resolve Master Subject ID for Chapters
      final masterSubjectId = _selectedSubject?['subject_id']?.toString();
      if (masterSubjectId == null) {
        throw Exception('Master Subject ID not found for this subject.');
      }

      final chapters = await ApiSubjectService.getBabMateri(
        subjectId: masterSubjectId,
      );
      _chapters = List.from(chapters);
      _allAvailableChapters = List.from(chapters);

      // 3. Fetch Grades
      final rawGradesResponse = await ApiService().get(
        '/grades?class_id=$classId&subject_id=$subjectId&academic_year_id=$academicYearId&limit=1000',
      );
      List<dynamic> rawGrades = [];
      if (rawGradesResponse != null) {
        if (rawGradesResponse is Map && rawGradesResponse['data'] != null) {
          rawGrades = rawGradesResponse['data'];
        } else if (rawGradesResponse is List) {
          rawGrades = rawGradesResponse;
        }
      }

      // 4. Fetch existing Recaps
      final recaps = await ApiGradeRecapService.getGradeRecaps(
        classId: classId,
        subjectId: subjectId,
        academicYearId: academicYearId,
      );

      // Restore Chapters from saved Recap (Expand list if needed)
      if (recaps.isNotEmpty) {
        List<String> longestBabNames = [];
        for (var r in recaps) {
          if (r['bab_names'] != null && r['bab_names'] is List) {
            final names = List<String>.from(r['bab_names']);
            if (names.length > longestBabNames.length) {
              longestBabNames = names;
            }
          }
        }

        if (longestBabNames.isNotEmpty) {
          while (_chapters.length < longestBabNames.length) {
            _chapters.add({
              'judul_bab': 'Bab ${_chapters.length + 1}',
              'judul': 'Bab ${_chapters.length + 1}',
              'title': 'Bab ${_chapters.length + 1}',
            });
          }

          for (int i = 0; i < longestBabNames.length; i++) {
            if (i < _chapters.length) {
              _chapters[i]['judul_bab'] = longestBabNames[i];
              _chapters[i]['judul'] = longestBabNames[i];
              _chapters[i]['title'] = longestBabNames[i];
            }
          }
        }
      }

      setState(() {
        _rawGrades = rawGrades;
        _allAvailableChapters = List.from(chapters);
      });

      _processTableData(students, _chapters, rawGrades, recaps);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  void _processTableData(
    List<dynamic> students,
    List<dynamic> chapters,
    List<dynamic> rawGrades,
    List<dynamic> recaps,
  ) {
    List<Map<String, dynamic>> tableData = [];
    _predikatControllers.clear();
    _deskripsiControllers.clear();
    _scoreControllers.clear();

    String autoDeskripsi =
        "Telah memahami materi ${chapters.map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab').join(', ')} dengan cukup baik.";

    for (var studentRow in students) {
      final student = studentRow['student'] ?? studentRow;
      final studentClassId =
          (studentRow['student_class_id'] ?? studentRow['id']).toString();

      // Filter grades for this student
      final studentGrades = rawGrades.where((g) {
        final gStudentClassId = (g['student_class_id'] ?? g['siswa_kelas_id'])
            ?.toString();
        return gStudentClassId == studentClassId;
      }).toList();

      // Group Harian
      List<dynamic> harianGrades = studentGrades.where((g) {
        final typeStr =
            (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
        return [
          'harian',
          'tugas',
          'ulangan',
          'kuis',
          'praktek',
          'formatif',
          'sumatif',
        ].contains(typeStr);
      }).toList();

      // Sort by date (assuming they have date/tanggal)
      harianGrades.sort(
        (a, b) => (a['tanggal'] ?? '').compareTo(b['tanggal'] ?? ''),
      );

      List<double?> babScores = [];
      int numChapters = chapters.isNotEmpty ? chapters.length : 1;

      // Distribute harian grades into chapters evenly
      if (harianGrades.isNotEmpty && numChapters > 0) {
        int itemsPerBab = (harianGrades.length / numChapters).ceil();
        for (int i = 0; i < numChapters; i++) {
          int start = i * itemsPerBab;
          int end = (start + itemsPerBab > harianGrades.length)
              ? harianGrades.length
              : start + itemsPerBab;

          if (start < harianGrades.length) {
            var chunk = harianGrades.sublist(start, end);
            double sum = 0;
            for (var c in chunk) {
              double val =
                  double.tryParse(
                    (c['score'] ?? c['nilai'] ?? '0').toString(),
                  ) ??
                  0;
              sum += val;
            }
            babScores.add(sum / chunk.length);
          } else {
            babScores.add(null);
          }
        }
      } else {
        babScores = List.filled(numChapters, null);
      }

      // UTS & UAS
      var utsGrade = studentGrades.firstWhere(
        (g) => (g['type'] ?? g['jenis'])?.toString().toLowerCase() == 'uts',
        orElse: () => null,
      );
      var uasGrade = studentGrades.firstWhere(
        (g) => (g['type'] ?? g['jenis'])?.toString().toLowerCase() == 'uas',
        orElse: () => null,
      );

      // Check existing Recap
      var existingRecap = recaps.firstWhere(
        (r) => r['student_class_id']?.toString() == studentClassId,
        orElse: () => null,
      );

      double? utsScore;
      double? uasScore;
      List<double?> finalBabScores = [];

      if (existingRecap != null && existingRecap['bab_scores'] != null) {
        // LOAD FROM SAVED RECAP
        final savedBabScores = List<dynamic>.from(existingRecap['bab_scores']);
        finalBabScores = savedBabScores
            .map((s) => s != null ? double.tryParse(s.toString()) : null)
            .toList();
        utsScore = existingRecap['uts_score'] != null
            ? double.tryParse(existingRecap['uts_score'].toString())
            : null;
        uasScore = existingRecap['uas_score'] != null
            ? double.tryParse(existingRecap['uas_score'].toString())
            : null;
      } else {
        // CALCULATE FROM RAW GRADES
        utsScore = utsGrade != null
            ? double.tryParse(
                (utsGrade['score'] ?? utsGrade['nilai'] ?? '0').toString(),
              )
            : null;
        uasScore = uasGrade != null
            ? double.tryParse(
                (uasGrade['score'] ?? uasGrade['nilai'] ?? '0').toString(),
              )
            : null;
        finalBabScores = babScores;
      }

      // Calculate Final Score
      double finalScoreValue = 0;
      int componentCount = 0;

      for (var score in finalBabScores) {
        if (score != null) {
          finalScoreValue += score;
          componentCount++;
        }
      }
      if (utsScore != null) {
        finalScoreValue += utsScore;
        componentCount++;
      }
      if (uasScore != null) {
        finalScoreValue += uasScore;
        componentCount++;
      }

      double finalAverage = componentCount > 0
          ? (finalScoreValue / componentCount)
          : 0;

      double currentSkillScore =
          (existingRecap != null && existingRecap['skill_score'] != null)
          ? (double.tryParse(existingRecap['skill_score'].toString()) ??
                finalAverage)
          : finalAverage;

      String currentPredikat = existingRecap != null
          ? (existingRecap['predikat'] ?? '')
          : '';
      String currentDeskripsi = existingRecap != null
          ? (existingRecap['deskripsi'] ?? '')
          : (chapters.isNotEmpty ? autoDeskripsi : '');

      _predikatControllers[studentClassId] = TextEditingController(
        text: currentPredikat,
      );
      _deskripsiControllers[studentClassId] = TextEditingController(
        text: currentDeskripsi,
      );

      // Initialize Score Controllers
      for (int i = 0; i < numChapters; i++) {
        final key = '$studentClassId|bab|$i';
        _scoreControllers[key] = TextEditingController(
          text: finalBabScores[i]?.toStringAsFixed(1) ?? '',
        );
      }
      _scoreControllers['$studentClassId|uts|null'] = TextEditingController(
        text: utsScore?.toStringAsFixed(1) ?? '',
      );
      _scoreControllers['$studentClassId|uas|null'] = TextEditingController(
        text: uasScore?.toStringAsFixed(1) ?? '',
      );
      _scoreControllers['$studentClassId|skill_score|null'] =
          TextEditingController(text: currentSkillScore.toStringAsFixed(1));

      tableData.add({
        'student_class_id': studentClassId,
        'nis': (student['student_number'] ?? student['nis'] ?? '-').toString(),
        'nama': (student['name'] ?? student['nama'] ?? '-').toString(),
        'bab_scores': finalBabScores,
        'uts': utsScore,
        'uas': uasScore,
        'final_score': finalAverage,
        'skill_score': currentSkillScore,
        'predikat': currentPredikat,
        'deskripsi': currentDeskripsi,
      });
    }

    setState(() {
      _chapters = chapters;
      _tableData = tableData;
      _isLoading = false;
    });
  }

  void _showGradeSelectionDialog(
    String studentClassId,
    String type,
    int? babIndex,
  ) {
    final studentGrades = _rawGrades.where((g) {
      final gStudentClassId = (g['student_class_id'] ?? g['siswa_kelas_id'])
          ?.toString();
      return gStudentClassId == studentClassId;
    }).toList();

    List<dynamic> options = [];
    if (type == 'bab') {
      options = studentGrades.where((g) {
        final typeStr =
            (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
        return [
          'harian',
          'tugas',
          'ulangan',
          'kuis',
          'praktek',
          'formatif',
          'sumatif',
        ].contains(typeStr);
      }).toList();
    } else {
      options = studentGrades.where((g) {
        final typeStr =
            (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
        return typeStr == type.toLowerCase();
      }).toList();
    }

    showDialog(
      context: context,
      builder: (context) {
        List<dynamic> selectedItems = [];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                type == 'bab'
                    ? 'Pilih Nilai Harian'
                    : 'Pilih Nilai ${type.toUpperCase()}',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: options.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Tidak ada data nilai yang ditemukan.'),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Pilih satu atau lebih nilai untuk dirata-ratakan.',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final g = options[index];
                                final score = (g['score'] ?? g['nilai'] ?? '0')
                                    .toString();
                                final title =
                                    g['assessment']?['title'] ??
                                    g['title'] ??
                                    g['judul'] ??
                                    'Nilai';
                                final date =
                                    g['assessment']?['date'] ??
                                    g['date'] ??
                                    g['tanggal'] ??
                                    '';
                                final isSelected = selectedItems.contains(g);

                                return CheckboxListTile(
                                  title: Text('$title ($score)'),
                                  subtitle: Text(date),
                                  value: isSelected,
                                  activeColor: ColorUtils.primary,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedItems.add(g);
                                      } else {
                                        selectedItems.remove(g);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: selectedItems.isEmpty
                      ? null
                      : () {
                          double sum = 0;
                          for (var item in selectedItems) {
                            final s = (item['score'] ?? item['nilai'] ?? '0')
                                .toString();
                            sum += double.tryParse(s) ?? 0;
                          }
                          _updateTableValue(
                            studentClassId,
                            type,
                            babIndex,
                            sum / selectedItems.length,
                          );
                          Navigator.pop(context);
                        },
                  child: Text('Gunakan Rata-rata'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateTableValue(
    String studentClassId,
    String type,
    int? babIndex,
    double newValue,
  ) {
    setState(() {
      final index = _tableData.indexWhere(
        (row) => row['student_class_id'] == studentClassId,
      );
      if (index != -1) {
        final row = _tableData[index];

        // Update Controller
        final key = '$studentClassId|$type|${babIndex ?? 'null'}';
        if (_scoreControllers.containsKey(key)) {
          _scoreControllers[key]!.text = newValue.toStringAsFixed(1);
        }

        if (type == 'bab' && babIndex != null) {
          row['bab_scores'][babIndex] = newValue;
        } else if (type == 'uts') {
          row['uts'] = newValue;
        } else if (type == 'uas') {
          row['uas'] = newValue;
        } else if (type == 'skill_score') {
          row['skill_score'] = newValue;
        }
        _recalculateRow(row);
      }
    });
  }

  void _showBulkSelectionDialog(String type, [int? babIndex]) {
    // 1. Get unique assessments for bulk filling
    final assessmentMap = <String, Map<String, dynamic>>{};
    for (var g in _rawGrades) {
      final typeStr = (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';

      // Filter by requested type (harian types for bab, or specific uts/uas)
      bool match = false;
      if (type == 'bab') {
        match = [
          'harian',
          'tugas',
          'ulangan',
          'kuis',
          'praktek',
          'formatif',
          'sumatif',
        ].contains(typeStr);
      } else {
        match = typeStr == type.toLowerCase();
      }

      if (match) {
        final title =
            g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? 'Nilai';
        final date =
            g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '';
        final key = '$title|$date';
        if (!assessmentMap.containsKey(key)) {
          assessmentMap[key] = {'title': title, 'date': date};
        }
      }
    }
    final assessments = assessmentMap.values.toList();

    showDialog(
      context: context,
      builder: (context) {
        List<Map<String, dynamic>> selectedBulk = [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                title: Text(
                  type == 'bab'
                      ? 'Pengaturan Kolom Bab ${babIndex! + 1}'
                      : 'Pengaturan Kolom ${type.toUpperCase()}',
                ),
                contentPadding: EdgeInsets.zero,
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: ColorUtils.primary,
                        unselectedLabelColor: ColorUtils.slate500,
                        indicatorColor: ColorUtils.primary,
                        tabs: [
                          if (type == 'bab') Tab(text: 'Nama Materi'),
                          Tab(text: 'Isi Otomatis'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Material Selection (Only for Bab)
                            if (type == 'bab')
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Nama Materi Manual',
                                        hintText:
                                            'Ketik nama materi di sini...',
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.edit),
                                      ),
                                      onSubmitted: (val) {
                                        if (val.isNotEmpty) {
                                          setState(() {
                                            _chapters[babIndex!] = {
                                              'judul_bab': val,
                                              'judul': val,
                                              'title': val,
                                            };
                                          });
                                          _updateAllDescriptions();
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                  ),
                                  Divider(),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: EdgeInsets.all(8.0),
                                      itemCount: _allAvailableChapters.length,
                                      itemBuilder: (context, i) {
                                        final c = _allAvailableChapters[i];
                                        final title =
                                            c['judul_bab'] ??
                                            c['judul'] ??
                                            c['title'] ??
                                            'Bab';
                                        return ListTile(
                                          title: Text(title),
                                          onTap: () {
                                            setState(() {
                                              _chapters[babIndex!] = c;
                                            });
                                            _updateAllDescriptions();
                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            // Tab 2: Bulk Fill from History (Multi-select)
                            Column(
                              children: [
                                if (assessments.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Pilih satu atau lebih nilai untuk dirata-ratakan ke seluruh murid.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ColorUtils.slate500,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: assessments.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Tidak ada riwayat nilai.',
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          itemCount: assessments.length,
                                          itemBuilder: (context, i) {
                                            final a = assessments[i];
                                            final isSelected = selectedBulk
                                                .contains(a);
                                            return CheckboxListTile(
                                              title: Text(a['title']),
                                              subtitle: Text(a['date']),
                                              value: isSelected,
                                              activeColor: ColorUtils.primary,
                                              onChanged: (val) {
                                                setDialogState(() {
                                                  if (val == true) {
                                                    selectedBulk.add(a);
                                                  } else {
                                                    selectedBulk.remove(a);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                ),
                                if (selectedBulk.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ColorUtils.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          _applyBulkGrades(
                                            type,
                                            selectedBulk,
                                            babIndex,
                                          );
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Gunakan Rata-rata (${selectedBulk.length})',
                                        ),
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
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Batal'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditableGradeCell(
    String studentClassId,
    String type,
    int? babIndex,
  ) {
    final key = '$studentClassId|$type|${babIndex ?? 'null'}';
    final controller = _scoreControllers[key];

    if (controller == null) return Text('-');

    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          border: OutlineInputBorder(),
          suffixIcon: InkWell(
            onTap: () =>
                _showGradeSelectionDialog(studentClassId, type, babIndex),
            child: Icon(Icons.history, size: 14, color: ColorUtils.slate400),
          ),
          suffixIconConstraints: BoxConstraints(minWidth: 24, minHeight: 24),
        ),
        onChanged: (val) {
          final newValue = double.tryParse(val) ?? 0.0;
          _updateTableValueSilently(studentClassId, type, babIndex, newValue);
        },
      ),
    );
  }

  void _updateTableValueSilently(
    String studentClassId,
    String type,
    int? babIndex,
    double newValue,
  ) {
    setState(() {
      final index = _tableData.indexWhere(
        (row) => row['student_class_id'] == studentClassId,
      );
      if (index != -1) {
        final row = _tableData[index];
        if (type == 'bab' && babIndex != null) {
          row['bab_scores'][babIndex] = newValue;
        } else if (type == 'uts') {
          row['uts'] = newValue;
        } else if (type == 'uas') {
          row['uas'] = newValue;
        } else if (type == 'skill_score') {
          row['skill_score'] = newValue;
        }
        _recalculateRow(row);
      }
    });
  }

  void _addChapter() {
    setState(() {
      final newIndex = _chapters.length;
      final newChapterName = 'Bab ${newIndex + 1}';

      // Create a fresh map for the new chapter and add it
      _chapters.add({
        'judul_bab': newChapterName,
        'judul': newChapterName,
        'title': newChapterName,
      });

      // Keep _allAvailableChapters in sync if needed
      _allAvailableChapters.add({
        'judul_bab': newChapterName,
        'judul': newChapterName,
        'title': newChapterName,
      });

      for (var row in _tableData) {
        final studentClassId = row['student_class_id'];

        // Expand score list safely
        if (row['bab_scores'] is List) {
          row['bab_scores'] = List<dynamic>.from(row['bab_scores'])..add(null);
        }

        // Initialize Controller for the new Bab
        final key = '$studentClassId|bab|$newIndex';
        _scoreControllers[key] = TextEditingController(text: '');

        _recalculateRow(row);
      }
    });

    _updateAllDescriptions();
  }

  void _applyBulkGrades(
    String type,
    List<Map<String, dynamic>> selectedAssessments, [
    int? babIndex,
  ]) {
    setState(() {
      for (var row in _tableData) {
        final studentClassId = row['student_class_id'];

        double totalScore = 0;
        int count = 0;

        for (var a in selectedAssessments) {
          final title = a['title'];
          final date = a['date'];

          final grades = _rawGrades.where((g) {
            final gStudentClassId =
                (g['student_class_id'] ?? g['siswa_kelas_id'])?.toString();
            if (gStudentClassId != studentClassId) return false;

            final gTitle =
                g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? '';
            final gDate =
                g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '';
            final gType =
                (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';

            // For bab, we match by title/date only as types vary.
            // For uts/uas we also ensure type matches for safety.
            if (type != 'bab' && gType != type) return false;

            return gTitle == title && gDate == date;
          }).toList();

          if (grades.isNotEmpty) {
            final s =
                double.tryParse(
                  (grades[0]['score'] ?? grades[0]['nilai'] ?? '0').toString(),
                ) ??
                0;
            totalScore += s;
            count++;
          }
        }

        if (count > 0) {
          final finalBulkScore = totalScore / count;

          // Update Controller
          final key = '$studentClassId|$type|${babIndex ?? 'null'}';
          if (_scoreControllers.containsKey(key)) {
            _scoreControllers[key]!.text = finalBulkScore.toStringAsFixed(1);
          }

          if (type == 'bab') {
            row['bab_scores'][babIndex!] = finalBulkScore;
          } else if (type == 'uts') {
            row['uts'] = finalBulkScore;
          } else if (type == 'uas') {
            row['uas'] = finalBulkScore;
          } else if (type == 'skill_score') {
            row['skill_score'] = finalBulkScore;
          }
          _recalculateRow(row);
        }
      }
    });

    if (type == 'bab') _updateAllDescriptions();
  }

  void _recalculateRow(Map<String, dynamic> row) {
    double sum = 0;
    int count = 0;
    double oldFinalScore = row['final_score'] ?? 0.0;

    for (var s in row['bab_scores']) {
      if (s != null) {
        sum += s;
        count++;
      }
    }
    if (row['uts'] != null) {
      sum += row['uts'];
      count++;
    }
    if (row['uas'] != null) {
      sum += row['uas'];
      count++;
    }

    double newFinalScore = count > 0 ? sum / count : 0.0;
    row['final_score'] = newFinalScore;

    // Auto-update skill_score if it was matching previous final_score or is 0
    double currentSkill = row['skill_score'] ?? 0.0;
    if (currentSkill == oldFinalScore || currentSkill == 0.0) {
      row['skill_score'] = newFinalScore;
      final studentClassId = row['student_class_id'];
      final key = '$studentClassId|skill_score|null';
      if (_scoreControllers.containsKey(key)) {
        _scoreControllers[key]!.text = newFinalScore.toStringAsFixed(1);
      }
    }
  }

  void _updateAllDescriptions() {
    String autoDeskripsiTemplate =
        "Telah memahami materi ${_chapters.map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab').join(', ')} dengan cukup baik.";

    setState(() {
      for (var row in _tableData) {
        final studentClassId = row['student_class_id'];
        // Only update if it was using the automatic description (or is empty)
        // For simplicity, we can update it if the user hasn't modified it markedly,
        // but here we just update if it's currently empty or previously auto-generated.
        // Or simply provide a button to "Reset Descriptions".
        // Let's just update the controllers.
        if (_deskripsiControllers[studentClassId]?.text.isEmpty ?? true) {
          _deskripsiControllers[studentClassId]?.text = autoDeskripsiTemplate;
          row['deskripsi'] = autoDeskripsiTemplate;
        }
      }
    });
  }

  Future<void> _saveRecaps() async {
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId =
          (provider.selectedAcademicYear?['id'] ??
                  provider.activeAcademicYear?['id'])
              ?.toString() ??
          '';

      if (academicYearId.isEmpty) {
        throw Exception(
          'Academic Year is required but not selected or active.',
        );
      }

      List<Map<String, dynamic>> payload = [];

      for (var row in _tableData) {
        String studentClassId = row['student_class_id'];
        payload.add({
          'student_class_id': studentClassId,
          'subject_id': _selectedSubject!['id'].toString(),
          'academic_year_id': academicYearId,
          'predikat': _predikatControllers[studentClassId]?.text,
          'deskripsi': _deskripsiControllers[studentClassId]?.text,
          'bab_scores': row['bab_scores'],
          'bab_names': _chapters
              .map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab')
              .toList(),
          'uts_score': row['uts'],
          'uas_score': row['uas'],
          'final_score': row['final_score'],
          'skill_score': row['skill_score'],
        });
      }

      await ApiGradeRecapService.batchSaveGradeRecap(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rekap Nilai berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      final className =
          _selectedClass?['nama'] ?? _selectedClass?['name'] ?? 'Kelas';
      final subjectName =
          _selectedSubject?['nama'] ??
          _selectedSubject?['name'] ??
          'Mata_Pelajaran';

      await ExcelRekapNilaiService.exportRekapNilaiToExcel(
        tableData: _tableData,
        chapters: _chapters,
        className: className,
        subjectName: subjectName,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ==================== BUILDERS ====================

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              // Pattern #7 Gradient Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPrimaryColor(),
                      _getPrimaryColor().withValues(alpha: 0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_currentStep > 0) {
                          setState(() {
                            _currentStep--;
                            _searchController.clear();
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
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
                              'en': 'Grade Recap',
                              'id': 'Rekap Nilai',
                            }),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _currentStep == 0
                                ? languageProvider.getTranslatedText({
                                    'en': 'Select Class',
                                    'id': 'Pilih Kelas',
                                  })
                                : _currentStep == 1
                                ? (_selectedClass?['nama'] ??
                                      _selectedClass?['name'] ??
                                      '')
                                : (_selectedSubject?['nama'] ??
                                      _selectedSubject?['name'] ??
                                      ''),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_currentStep == 2)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _isExporting ? null : _exportToExcel,
                            child: Container(
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isExporting
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Icon(
                                          Icons.table_view,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Excel',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _isSaving ? null : _saveRecaps,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isSaving
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Icon(
                                          Icons.save,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Save',
                                            'id': 'Simpan',
                                          }),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Step indicator or search bar
              if (_currentStep < 2) _buildTopControls(languageProvider),

              Expanded(child: _buildBody(languageProvider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopControls(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: ColorUtils.slate900),
          decoration: InputDecoration(
            hintText: languageProvider.getTranslatedText({
              'en': _currentStep == 0
                  ? 'Search classes...'
                  : 'Search subjects...',
              'id': _currentStep == 0
                  ? 'Cari kelas...'
                  : 'Cari mata pelajaran...',
            }),
            hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 14),
            prefixIcon: Icon(
              Icons.search,
              color: ColorUtils.slate400,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: ColorUtils.slate400,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LanguageProvider languageProvider) {
    if (_currentStep == 0) return _buildClassList(languageProvider);
    if (_currentStep == 1) return _buildSubjectList(languageProvider);
    return _buildRecapTable(languageProvider);
  }

  Widget _buildClassList(LanguageProvider languageProvider) {
    if (_isLoading) return SkeletonListLoading();

    final query = _searchController.text.toLowerCase();
    final filteredList = _classList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final level = (item['grade_level'] ?? '').toString().toLowerCase();
      return name.contains(query) || level.contains(query);
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: ColorUtils.slate300),
            SizedBox(height: 16),
            Text(
              languageProvider.getTranslatedText({
                'en': 'No classes found',
                'id': 'Kelas tidak ditemukan',
              }),
              style: TextStyle(color: ColorUtils.slate500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: filteredList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredList.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final item = filteredList[index];
        return _buildClassCard(item, languageProvider);
      },
    );
  }

  Widget _buildClassCard(dynamic item, LanguageProvider languageProvider) {
    final classId = item['id']?.toString();
    final isToday = _todaySchedules.any(
      (s) => s['class_id']?.toString() == classId,
    );
    final ht = item['homeroom_teacher'];
    final wk = item['wali_kelas'];

    String waliKelas = '-';
    if (ht is Map) {
      waliKelas = ht['name']?.toString() ?? '-';
    } else if (ht is List && ht.isNotEmpty && ht[0] is Map) {
      waliKelas = ht[0]['name']?.toString() ?? '-';
    } else if (wk is Map) {
      waliKelas = wk['nama']?.toString() ?? wk['name']?.toString() ?? '-';
    } else if (wk is List && wk.isNotEmpty && wk[0] is Map) {
      waliKelas = wk[0]['nama']?.toString() ?? wk[0]['name']?.toString() ?? '-';
    } else {
      waliKelas =
          item['wali_kelas_name']?.toString() ??
          item['homeroom_teacher_name']?.toString() ??
          '-';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedClass = item;
          _currentStep = 1;
          _searchController.clear();
        });
        _loadSubjects();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ColorUtils.corporateShadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getPrimaryColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.class_outlined,
                    color: _getPrimaryColor(),
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['nama'] ?? item['name'] ?? '-',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.success600.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'TODAY',
                                'id': 'HARI INI',
                              }),
                              style: TextStyle(
                                color: ColorUtils.success600,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoTag(
                          Icons.layers_outlined,
                          '${item['grade_level'] ?? '-'}',
                        ),
                        _buildInfoTag(Icons.person_outline, waliKelas),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ColorUtils.slate300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectList(LanguageProvider languageProvider) {
    if (_isLoading) return SkeletonListLoading();

    final query = _searchController.text.toLowerCase();
    final filteredList = _subjectList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query);
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: ColorUtils.slate300),
            SizedBox(height: 16),
            Text(
              languageProvider.getTranslatedText({
                'en': 'No subjects found',
                'id': 'Mata pelajaran tidak ditemukan',
              }),
              style: TextStyle(color: ColorUtils.slate500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        return _buildSubjectCard(item, languageProvider);
      },
    );
  }

  Widget _buildSubjectCard(dynamic item, LanguageProvider languageProvider) {
    // Highlighting current class/subject combo is usually overkill for rekap,
    // but we can check if it's the same category.

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubject = item;
          _currentStep = 2;
          _searchController.clear();
        });
        _loadRecapData();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ColorUtils.corporateShadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.book_outlined,
                    color: ColorUtils.warning600,
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nama'] ?? item['name'] ?? '-',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildInfoTag(
                      Icons.history_edu_outlined,
                      item['subject_code'] ?? 'Mata Pelajaran',
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ColorUtils.slate300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecapTable(LanguageProvider languageProvider) {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    int numChapters = _chapters.isNotEmpty ? _chapters.length : 1;

    // Frozen column width (Combined Name & NIS) using dynamic state
    final double leftWidth = _studentInfoWidth;

    const double gradeCellWidth = 110; // Bab, UTS, UAS
    const double finalScoreWidth = 80;
    const double predikatWidth = 80;
    const double deskripsiWidth = 280;

    double rightSideWidth =
        (numChapters * gradeCellWidth) +
        (gradeCellWidth * 2) + // UTS + UAS
        (finalScoreWidth * 2) + // Final + Skill
        predikatWidth +
        deskripsiWidth +
        60; // Extra horizontal margin for safety

    // Left Side: Frozen column (Combined Name & NIS)
    final leftSide = Container(
      width: leftWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: ColorUtils.slate200, width: 2)),
      ),
      child: Column(
        children: [
          // Header with Resize Handle
          Stack(
            children: [
              Container(
                height: 60,
                width: leftWidth,
                padding: EdgeInsets.only(left: 16, right: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'STUDENT INFO',
                    'id': 'INFO SISWA',
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Resize Handle
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _studentInfoWidth += details.delta.dx;
                      // Constraints: min 100, max 350
                      if (_studentInfoWidth < 100) _studentInfoWidth = 100;
                      if (_studentInfoWidth > 350) _studentInfoWidth = 350;
                    });
                  },
                  child: Container(
                    width: 10,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 20,
                        decoration: BoxDecoration(
                          color: ColorUtils.slate300,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Student Rows
          ..._tableData.map((row) {
            return Container(
              height: 75,
              width: leftWidth,
              padding: EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    row['nama'] ?? '-',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'NIS: ${row['nis'] ?? '-'}',
                    style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    // Right Side: Scrollable columns
    final rightSide = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: rightSideWidth,
        child: Column(
          children: [
            // Header Row
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
              ),
              child: Row(
                children: [
                  // Dynamic Bab Columns
                  for (int i = 0; i < numChapters; i++)
                    Container(
                      width: gradeCellWidth,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: InkWell(
                        onTap: () => _showBulkSelectionDialog('bab', i),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _chapters.length > i
                                    ? (_chapters[i]['judul_bab'] ??
                                          _chapters[i]['judul'] ??
                                          _chapters[i]['title'] ??
                                          'Bab ${i + 1}')
                                    : 'Bab ${i + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ColorUtils.slate700,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 12,
                              color: ColorUtils.slate400,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // UTS Header
                  Container(
                    width: gradeCellWidth,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: () => _showBulkSelectionDialog('uts'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'UTS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: ColorUtils.slate400,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // UAS Header
                  Container(
                    width: gradeCellWidth,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: () => _showBulkSelectionDialog('uas'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'UAS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: ColorUtils.slate400,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Final Header
                  Container(
                    width: finalScoreWidth,
                    alignment: Alignment.center,
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Final',
                        'id': 'Akhir',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Skill Header
                  Container(
                    width: finalScoreWidth,
                    alignment: Alignment.center,
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Skill',
                        'id': 'Keterampilan',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Pred Header
                  Container(
                    width: predikatWidth,
                    alignment: Alignment.center,
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Grade',
                        'id': 'Pred',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Deskripsi Header
                  Container(
                    width: deskripsiWidth,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Description',
                        'id': 'Deskripsi',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Data Rows
            ..._tableData.map((row) {
              String studentClassId = row['student_class_id'];
              return Container(
                height: 75,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Row(
                  children: [
                    // Bab cells
                    for (int i = 0; i < numChapters; i++)
                      Container(
                        width: gradeCellWidth,
                        alignment: Alignment.center,
                        child: _buildEditableGradeCell(
                          studentClassId,
                          'bab',
                          i,
                        ),
                      ),

                    // UTS cell
                    Container(
                      width: gradeCellWidth,
                      alignment: Alignment.center,
                      child: _buildEditableGradeCell(
                        studentClassId,
                        'uts',
                        null,
                      ),
                    ),

                    // UAS cell
                    Container(
                      width: gradeCellWidth,
                      alignment: Alignment.center,
                      child: _buildEditableGradeCell(
                        studentClassId,
                        'uas',
                        null,
                      ),
                    ),

                    // Final Score
                    Container(
                      width: finalScoreWidth,
                      alignment: Alignment.center,
                      child: Text(
                        row['final_score']?.toStringAsFixed(1) ?? '0.0',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getPrimaryColor(),
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // Skill Score Editable
                    Container(
                      width: finalScoreWidth,
                      alignment: Alignment.center,
                      child: _buildEditableGradeCell(
                        studentClassId,
                        'skill_score',
                        null,
                      ),
                    ),

                    // Predikat
                    Container(
                      width: predikatWidth,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _predikatControllers[studentClassId],
                          style: TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: ColorUtils.slate200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: ColorUtils.slate200,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Deskripsi
                    Container(
                      width: deskripsiWidth,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _deskripsiControllers[studentClassId],
                        maxLines: 2,
                        style: TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.all(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          fillColor: ColorUtils.slate50,
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );

    return Column(
      children: [
        // Action Bar for Table
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Grade Data',
                  'id': 'Data Nilai',
                }),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate700,
                ),
              ),
              Spacer(),
              OutlinedButton.icon(
                onPressed: _addChapter,
                icon: Icon(Icons.add, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Add Bab',
                    'id': 'Tambah Bab',
                  }),
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _getPrimaryColor(),
                  side: BorderSide(color: _getPrimaryColor()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ColorUtils.corporateShadow(),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftSide,
                      Expanded(child: rightSide),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
