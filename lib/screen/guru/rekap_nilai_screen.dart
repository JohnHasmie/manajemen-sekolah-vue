import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_grade_recap_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
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
  List<dynamic> _students = [];
  List<dynamic> _recaps = [];

  // Computed Table Data
  List<Map<String, dynamic>> _tableData = [];
  List<dynamic> _rawGrades = [];

  // Selected Data
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Controllers for editable fields
  final Map<String, TextEditingController> _predikatControllers = {};
  final Map<String, TextEditingController> _deskripsiControllers = {};

  // Loading & Pagination
  bool _isLoading = false;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          '${ApiService.baseUrl}/class/${_selectedClass!['id']}/subjects',
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

      setState(() {
        _rawGrades = rawGrades;
        _students = students;
        _recaps = recaps;
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

      double? utsScore = utsGrade != null
          ? double.tryParse(
              (utsGrade['score'] ?? utsGrade['nilai'] ?? '0').toString(),
            )
          : null;
      double? uasScore = uasGrade != null
          ? double.tryParse(
              (uasGrade['score'] ?? uasGrade['nilai'] ?? '0').toString(),
            )
          : null;

      // Calculate Final Score
      double finalScore = 0;
      int componentCount = 0;

      for (var score in babScores) {
        if (score != null) {
          finalScore += score;
          componentCount++;
        }
      }
      if (utsScore != null) {
        finalScore += utsScore;
        componentCount++;
      }
      if (uasScore != null) {
        finalScore += uasScore;
        componentCount++;
      }

      double finalAverage = componentCount > 0
          ? (finalScore / componentCount)
          : 0;

      // Check existing Recap
      var existingRecap = recaps.firstWhere(
        (r) => r['student_class_id']?.toString() == studentClassId,
        orElse: () => null,
      );

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

      tableData.add({
        'student_class_id': studentClassId,
        'nis': (student['student_number'] ?? student['nis'] ?? '-').toString(),
        'nama': (student['name'] ?? student['nama'] ?? '-').toString(),
        'bab_scores': babScores,
        'uts': utsScore,
        'uas': uasScore,
        'final_score': finalAverage,
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
        if (type == 'bab' && babIndex != null) {
          row['bab_scores'][babIndex] = newValue;
        } else if (type == 'uts') {
          row['uts'] = newValue;
        } else if (type == 'uas') {
          row['uas'] = newValue;
        }

        // Recalculate Final Score
        double sum = 0;
        int count = 0;
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
        row['final_score'] = count > 0 ? sum / count : 0.0;
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
                              ListView.builder(
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
                                      _processTableData(
                                        _students,
                                        _chapters,
                                        _rawGrades,
                                        _recaps,
                                      );
                                      Navigator.pop(context);
                                    },
                                  );
                                },
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
          if (type == 'bab') {
            row['bab_scores'][babIndex!] = finalBulkScore;
          } else if (type == 'uts') {
            row['uts'] = finalBulkScore;
          } else if (type == 'uas') {
            row['uas'] = finalBulkScore;
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
    row['final_score'] = count > 0 ? sum / count : 0.0;
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
          'final_score': row['final_score'],
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

  // ==================== BUILDERS ====================

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      appBar: AppBar(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Grade Recap',
            'id': 'Rekap Nilai',
          }),
          style: TextStyle(
            color: ColorUtils.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorUtils.slate900),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
                _searchController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_currentStep == 2)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecaps,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.save, size: 18),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Save',
                    'id': 'Simpan',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb / Header info
          if (_currentStep > 0)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedClass != null)
                    Text(
                      'Kelas: ${_selectedClass!['nama'] ?? _selectedClass!['name']}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (_selectedSubject != null)
                    Text(
                      'Mata Pelajaran: ${_selectedSubject!['nama'] ?? _selectedSubject!['name']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: ColorUtils.slate500,
                      ),
                    ),
                ],
              ),
            ),

          Expanded(child: _buildBody(languageProvider)),
        ],
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

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _classList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _classList.length)
          return Center(child: CircularProgressIndicator());

        final item = _classList[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ColorUtils.slate200),
          ),
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: ColorUtils.primary.withValues(alpha: 0.1),
              child: Icon(Icons.class_, color: ColorUtils.primary),
            ),
            title: Text(item['nama'] ?? item['name'] ?? '-'),
            subtitle: Text('${item['grade_level'] ?? ''}'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedClass = item;
                _currentStep = 1;
              });
              _loadSubjects();
            },
          ),
        );
      },
    );
  }

  Widget _buildSubjectList(LanguageProvider languageProvider) {
    if (_isLoading) return SkeletonListLoading();

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _subjectList.length,
      itemBuilder: (context, index) {
        final item = _subjectList[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ColorUtils.slate200),
          ),
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: ColorUtils.warningLight,
              child: Icon(Icons.book, color: ColorUtils.warning600),
            ),
            title: Text(item['nama'] ?? item['name'] ?? '-'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedSubject = item;
                _currentStep = 2;
              });
              _loadRecapData();
            },
          ),
        );
      },
    );
  }

  Widget _buildRecapTable(LanguageProvider languageProvider) {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    int numChapters = _chapters.isNotEmpty ? _chapters.length : 1;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.resolveWith(
            (states) => ColorUtils.slate50,
          ),
          dataRowMinHeight: 60,
          dataRowMaxHeight: 60,
          columns: [
            DataColumn(
              label: Text('NIS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataColumn(
              label: Text(
                'Nama Siswa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // Dynamic Bab Columns
            for (int i = 0; i < numChapters; i++)
              DataColumn(
                label: InkWell(
                  onTap: () => _showBulkSelectionDialog('bab', i),
                  child: Row(
                    children: [
                      Text(
                        _chapters.length > i
                            ? (_chapters[i]['judul_bab'] ??
                                  _chapters[i]['judul'] ??
                                  _chapters[i]['title'] ??
                                  'Bab ${i + 1}')
                            : 'Bab ${i + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.edit, size: 12, color: ColorUtils.slate400),
                    ],
                  ),
                ),
              ),

            DataColumn(
              label: InkWell(
                onTap: () => _showBulkSelectionDialog('uts'),
                child: Row(
                  children: [
                    Text('UTS', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.edit, size: 12, color: ColorUtils.slate400),
                  ],
                ),
              ),
            ),
            DataColumn(
              label: InkWell(
                onTap: () => _showBulkSelectionDialog('uas'),
                child: Row(
                  children: [
                    Text('UAS', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.edit, size: 12, color: ColorUtils.slate400),
                  ],
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Nilai Akhir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Predikat',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Deskripsi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _tableData.map((row) {
            String studentClassId = row['student_class_id'];
            return DataRow(
              cells: [
                DataCell(Text(row['nis'])),
                DataCell(Text(row['nama'])),

                // Bab cells
                for (int i = 0; i < numChapters; i++)
                  DataCell(
                    Text(row['bab_scores'][i]?.toStringAsFixed(1) ?? '-'),
                    onTap: () =>
                        _showGradeSelectionDialog(studentClassId, 'bab', i),
                  ),

                DataCell(
                  Text(row['uts']?.toStringAsFixed(1) ?? '-'),
                  onTap: () =>
                      _showGradeSelectionDialog(studentClassId, 'uts', null),
                ),
                DataCell(
                  Text(row['uas']?.toStringAsFixed(1) ?? '-'),
                  onTap: () =>
                      _showGradeSelectionDialog(studentClassId, 'uas', null),
                ),
                DataCell(Text(row['final_score']?.toStringAsFixed(1) ?? '0.0')),

                DataCell(
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _predikatControllers[studentClassId],
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _deskripsiControllers[studentClassId],
                      maxLines: 2,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
