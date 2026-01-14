import 'dart:async';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/separated_search_filter.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class GradePage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const GradePage({super.key, required this.teacher});

  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends State<GradePage> {
  // Services
  final ApiSubjectService apiSubjectService = ApiSubjectService();
  final ApiTeacherService apiTeacherService = ApiTeacherService();

  // State
  int _currentStep = 0; // 0: Class List, 1: Subject List, 2: Grade Book

  // Data Lists
  List<dynamic> _classList = [];
  List<dynamic> _subjectList = [];

  // Selected Data
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Filtering & Pagination
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Pagination State
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        if (_currentStep == 0) {
          _loadMoreClasses();
        } else if (_currentStep == 1) {
          _loadMoreSubjects();
        }
      }
    }
  }

  void _onSearchChanged() {
    if (_currentStep == 0) {
      setState(() {});
    } else if (_currentStep == 1) {
      setState(() {});
    }
  }

  // ==================== LOAD LOGIC ====================

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

      List<dynamic> loadedClasses = [];

      if (widget.teacher['role'] == 'guru') {
        final response = await ApiTeacherService.getTeacherClasses(
          widget.teacher['id'],
          academicYearId: academicYearId,
        );
        loadedClasses = response;
        _hasMoreData = false;
      } else {
        // Admin: Load ALL classes
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
        _showErrorSnackBar('Failed to load classes: $e');
      }
    }
  }

  Future<void> _loadMoreClasses() async {
    if (widget.teacher['role'] == 'guru') return;
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
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      List<dynamic> subjects = [];

      if (widget.teacher['role'] == 'guru') {
        // Use TeachingSchedule to find subjects this teacher teaches in this class
        final schedules = await ApiScheduleService.getSchedulesPaginated(
          limit: 100,
          guruId: widget.teacher['id'],
          classId: _selectedClass!['id'].toString(),
          tahunAjaran: academicYearId,
        );

        final data = schedules['data'] ?? [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};

        for (var item in data) {
          final subject = item['subject'] ?? item['mata_pelajaran'];
          if (subject != null) {
            uniqueSubjects[subject['id'].toString()] = subject;
          }
        }
        subjects = uniqueSubjects.values.toList();
      } else {
        // Admin: Get all subjects for this class
        final schedules = await ApiScheduleService.getSchedulesPaginated(
          limit: 100,
          classId: _selectedClass!['id'].toString(),
          tahunAjaran: academicYearId,
        );
        final data = schedules['data'] ?? [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var item in data) {
          final subject = item['subject'] ?? item['mata_pelajaran'];
          if (subject != null) {
            uniqueSubjects[subject['id'].toString()] = subject;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load subjects: $e');
      }
    }
  }

  Future<void> _loadMoreSubjects() async {}

  // ==================== HELPER METHODS ====================

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll('Failed to load', 'Gagal memuat'),
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
    );
  }

  // ==================== BUILDERS ====================

  Widget _buildStep0ClassList(LanguageProvider languageProvider) {
    // Filter locally if needed
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = _classList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final level = (item['grade_level'] ?? item['tingkat'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchTerm) || level.contains(searchTerm);
    }).toList();

    if (_isLoading) {
      return LoadingScreen(
        message: languageProvider.getTranslatedText({
          'en': 'Loading classes...',
          'id': 'Memuat kelas...',
        }),
      );
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.class_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Tidak Ada Kelas',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'Try adjusting your search filters',
          'id': 'Coba sesuaikan filter pencarian anda',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadClasses(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Center(child: CircularProgressIndicator());
          }
          final classData = filtered[index];
          final isHomeroom = classData['is_homeroom'] == true;

          return Card(
            elevation: 2,
            shadowColor: ColorUtils.slate200,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedClass = classData;
                  _currentStep = 1;
                  _searchController.clear();
                });
                _loadSubjects();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isHomeroom
                            ? ColorUtils.primary.withOpacity(0.1)
                            : _getPrimaryColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: isHomeroom
                            ? Border.all(
                                color: ColorUtils.primary.withOpacity(0.5),
                              )
                            : null,
                      ),
                      child: Icon(
                        isHomeroom
                            ? Icons.home_work_outlined
                            : Icons.class_outlined,
                        color: isHomeroom
                            ? ColorUtils.primary
                            : _getPrimaryColor(),
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
                                  classData['nama'] ?? classData['name'] ?? '-',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isHomeroom)
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Wali Kelas',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: ColorUtils.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat'})}: ${classData['grade_level'] ?? classData['tingkat'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep1SubjectList(LanguageProvider languageProvider) {
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = _subjectList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final code = (item['kode'] ?? item['code'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchTerm) || code.contains(searchTerm);
    }).toList();

    if (_isLoading) {
      return LoadingScreen(
        message: languageProvider.getTranslatedText({
          'en': 'Loading subjects...',
          'id': 'Memuat mata pelajaran...',
        }),
      );
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Tidak Ada Mata Pelajaran',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects found for this class',
          'id': 'Tidak ada mata pelajaran untuk kelas ini',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSubjects(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final subject = filtered[index];
          return Card(
            elevation: 2,
            shadowColor: ColorUtils.slate200,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedSubject = subject;
                  _currentStep = 2;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.book_outlined, color: Colors.orange),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject['nama'] ?? subject['name'] ?? '-',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            subject['kode'] ?? subject['code'] ?? '-',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep == 0) {
          _selectedClass = null;
          _selectedSubject = null;
          _searchController.clear();
        } else if (_currentStep == 1) {
          _selectedSubject = null;
        }
      });
      return false;
    }
    return true;
  }

  Widget _buildHeader(BuildContext context, LanguageProvider languageProvider) {
    String title = '';
    String subtitle = '';

    if (_currentStep == 0) {
      title = languageProvider.getTranslatedText({
        'en': 'Input Grades',
        'id': 'Input Nilai',
      });
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Class',
        'id': 'Pilih Kelas',
      });
    } else if (_currentStep == 1) {
      title = _selectedClass?['nama'] ?? _selectedClass?['name'] ?? 'Class';
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Subject',
        'id': 'Pilih Mata Pelajaran',
      });
    } else {
      return SizedBox.shrink();
    }

    return Container(
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
                onTap: () async {
                  final shouldPop = await _handleWillPop();
                  if (shouldPop && mounted) Navigator.pop(context);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        // If Step 2, we show GradeBookPage which handles its own scaffold/body
        if (_currentStep == 2) {
          return WillPopScope(
            onWillPop: _handleWillPop,
            child: GradeBookPage(
              teacher: widget.teacher,
              subject: _selectedSubject!,
              classData: _selectedClass!,
              onBack: () {
                setState(() {
                  _currentStep = 1;
                  _selectedSubject = null;
                });
              },
            ),
          );
        }

        return WillPopScope(
          onWillPop: _handleWillPop,
          child: Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Column(
              children: [
                _buildHeader(context, languageProvider),

                if (_currentStep == 0 || _currentStep == 1) ...[
                  SeparatedSearchFilter(
                    controller: _searchController,
                    onChanged: (value) => setState(() {}),
                    hintText: _currentStep == 0
                        ? languageProvider.getTranslatedText({
                            'en': 'Search class...',
                            'id': 'Cari kelas...',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'Search subject...',
                            'id': 'Cari mata pelajaran...',
                          }),
                    showFilter: false, // Simple search for now
                    searchBackgroundColor: Colors.white,
                    margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  ),
                ],

                Expanded(
                  child: _currentStep == 0
                      ? _buildStep0ClassList(languageProvider)
                      : _buildStep1SubjectList(languageProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Halaman Grade Book/Tabel Nilai
class GradeBookPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Map<String, dynamic> classData;
  final VoidCallback? onBack;

  const GradeBookPage({
    super.key,
    required this.teacher,
    required this.subject,
    required this.classData,
    this.onBack,
  });

  @override
  GradeBookPageState createState() => GradeBookPageState();
}

class GradeBookPageState extends State<GradeBookPage> {
  List<Siswa> _siswaList = [];
  List<Siswa> _filteredSiswaList = [];
  List<Map<String, dynamic>> _nilaiList = [];
  final List<String> _allJenisNilaiList = [
    'harian',
    'tugas',
    'ulangan',
    'uts',
    'uas',
  ];
  List<String> _filteredJenisNilaiList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  final Map<String, bool> _jenisNilaiFilter = {
    'harian': true,
    'tugas': true,
    'ulangan': true,
    'uts': true,
    'uas': true,
  };

  // Map to store unique assessments for each grade type
  // Key: jenis (e.g., 'harian'), Value: List of assessment headers
  // Each header: { 'id': String?, 'date': String, 'title': String?, 'is_temp': bool }
  Map<String, List<Map<String, dynamic>>> _assessmentHeaders = {};

  // Scroll controller untuk sinkronisasi scroll horizontal
  final ScrollController _horizontalScrollController = ScrollController();

  // Edit Mode State
  bool _isEditMode = false;
  String? _editJenis;
  // Map to store controllers: key = "siswaId_field" (e.g. "123_nilai", "123_deskripsi")
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFilteredJenisNilai();
    _searchController.addListener(_filterSiswa);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    for (var node in _editFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _filterSiswa() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSiswaList = List.from(_siswaList);
      } else {
        _filteredSiswaList = _siswaList
            .where(
              (siswa) =>
                  siswa.name.toLowerCase().contains(query) ||
                  siswa.nis.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      // Load siswa berdasarkan kelas
      final siswaData = await ApiStudentService.getStudentByClass(
        widget.classData['id'],
      );

      // Load nilai yang sudah ada
      final academicYearId = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).selectedAcademicYear?['id'];
      final nilaiData = await ApiService().getNilaiByMataPelajaran(
        widget.subject['id'],
        academicYearId: academicYearId?.toString(),
      );

      setState(() {
        _siswaList = siswaData.map((s) => Siswa.fromJson(s)).toList();
        _filteredSiswaList = List.from(_siswaList);

        // Map API response to legacy format expected by UI
        _nilaiList = List<Map<String, dynamic>>.from(
          nilaiData.map((item) {
            return {
              'id': item['id'],
              'siswa_id': item['student_id'] ?? item['siswa_id'],
              'guru_id': item['teacher_id'] ?? item['guru_id'],
              'mata_pelajaran_id':
                  item['subject_id'] ?? item['mata_pelajaran_id'],
              'jenis': item['type'] ?? item['jenis'],
              'nilai': item['score'] ?? item['nilai'],
              'deskripsi': item['notes'] ?? item['deskripsi'],
              'tanggal': item['date'] ?? item['tanggal'],
              'assessment_id': item['assessment_id'],
              'title': item['title'],
            };
          }),
        );

        // Process unique assessments
        _assessmentHeaders = {};

        for (var nilai in _nilaiList) {
          final jenis = nilai['jenis']?.toString().toLowerCase();
          if (jenis == null) continue;

          String? rawDate = nilai['tanggal'];
          if (rawDate != null) {
            final datePart = rawDate.split('T')[0];
            final assessmentId = nilai['assessment_id'];
            final title = nilai['title'];

            if (!_assessmentHeaders.containsKey(jenis)) {
              _assessmentHeaders[jenis] = [];
            }

            // Check if header already exists
            final existingIndex = _assessmentHeaders[jenis]!.indexWhere((h) {
              if (assessmentId != null && h['id'] != null) {
                return h['id'] == assessmentId;
              }
              // Fallback for legacy data or temp data
              // If title is present in both, compare it. If one is null, it's ambiguous.
              // Assuming legacy data has no title.
              return h['date'] == datePart && h['title'] == title;
            });

            if (existingIndex == -1) {
              _assessmentHeaders[jenis]!.add({
                'id': assessmentId,
                'date': datePart,
                'title': title,
                'is_temp': false,
              });
            }
          }
        }

        // Sort headers
        for (var key in _assessmentHeaders.keys) {
          _assessmentHeaders[key]!.sort((a, b) {
            final dateCompare = a['date'].compareTo(b['date']);
            if (dateCompare != 0) return dateCompare;
            return (a['title'] ?? '').compareTo(b['title'] ?? '');
          });
        }

        print(
          "DEBUG: _assessmentHeaders keys: ${_assessmentHeaders.keys.toList()}",
        );

        // Ensure at least one empty column (or default) if no data exists for a type
        // Actually, we don't force an empty column if there's no data,
        // but we need a way to add the first one.
        // We'll handle this in the UI by showing a "+" button even if list is empty.

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load grade data: $e');
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
                'Failed to load grade data:',
                'Gagal memuat data nilai:',
              ),
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll('successfully', 'berhasil'),
            }),
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateFilteredJenisNilai() {
    setState(() {
      _filteredJenisNilaiList = _allJenisNilaiList
          .where((jenis) => _jenisNilaiFilter[jenis] == true)
          .toList();
    });
  }

  void _showFilterDialog(LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.filter_list, color: _getPrimaryColor()),
              SizedBox(width: 8),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Filter Grade Types',
                  'id': 'Filter Jenis Nilai',
                }),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _allJenisNilaiList.map((jenis) {
                return CheckboxListTile(
                  title: Text(_getJenisNilaiLabel(jenis, languageProvider)),
                  value: _jenisNilaiFilter[jenis],
                  onChanged: (bool? value) {
                    setState(() {
                      _jenisNilaiFilter[jenis] = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Cancel',
                  'id': 'Batal',
                }),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updateFilteredJenisNilai();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
              ),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Apply',
                  'id': 'Terapkan',
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic>? _getNilaiForSiswaAndHeader(
    String siswaId,
    String jenis,
    Map<String, dynamic> header,
  ) {
    try {
      final result = _nilaiList.firstWhere((nilai) {
        final matchSiswa = nilai['siswa_id'].toString() == siswaId;

        if (!matchSiswa) return false;

        // Match by ID if available
        if (header['id'] != null && nilai['assessment_id'] != null) {
          return nilai['assessment_id'] == header['id'];
        }

        // Fallback: Match by Date + Title + Type
        final nilaiDate = nilai['tanggal']?.toString().split('T')[0];
        final nilaiJenis = nilai['jenis']?.toString().toLowerCase();

        return nilaiJenis == jenis.toLowerCase() &&
            nilaiDate == header['date'] &&
            nilai['title'] == header['title'];
      }, orElse: () => <String, dynamic>{});

      return result;
    } catch (e) {
      return null;
    }
  }

  void _openInputForm(
    Siswa siswa,
    String jenisNilai,
    LanguageProvider languageProvider, {
    Map<String, dynamic>? header,
  }) {
    final existingNilai = header != null
        ? _getNilaiForSiswaAndHeader(siswa.id, jenisNilai, header)
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputForm(
          teacher: widget.teacher,
          subject: widget.subject,
          siswa: siswa,
          jenisNilai: jenisNilai,
          existingNilai: existingNilai?.isNotEmpty == true
              ? existingNilai
              : null,
          initialDate: header != null ? DateTime.parse(header['date']) : null,
          // TODO: Pass title to GradeInputForm if supported
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _showColumnOptions(
    String jenis,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    String date = header['date'];
    String? title = header['title'];
    String displayTitle = title != null && title.isNotEmpty
        ? "$title (${_formatDateDisplay(date)})"
        : _formatDateDisplay(date);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "${_getJenisNilaiLabel(jenis, languageProvider)} - $displayTitle",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.visibility, color: Colors.blue),
                ),
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'View Details',
                    'id': 'Lihat Detail',
                  }),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAssessmentDetail(jenis, header, languageProvider);
                },
              ),
              if (widget.teacher['role'] == 'guru') ...[
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit, color: Colors.orange),
                  ),
                  title: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Edit Assessment',
                      'id': 'Edit Penilaian',
                    }),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _enterEditMode(jenis, header);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Delete Assessment',
                      'id': 'Hapus Penilaian',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Delete all grades for this assessment',
                      'id': 'Hapus semua nilai penilaian ini',
                    }),
                    style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteAssessment(jenis, header, languageProvider);
                  },
                ),
              ],
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  String _formatGradeValue(dynamic value) {
    if (value == null) return '';
    double? numVal = double.tryParse(value.toString());
    if (numVal == null) return '';

    // Check if integer
    if (numVal % 1 == 0) {
      return numVal.toInt().toString();
    }

    return numVal.toString();
  }

  Map<String, dynamic>? _editHeader;

  void _enterEditMode(String jenis, Map<String, dynamic> header) {
    setState(() {
      _isEditMode = true;
      _editJenis = jenis;
      _editHeader = header;
      _editControllers.clear();
      _editFocusNodes.clear();

      // Initialize controllers for all students
      for (var siswa in _filteredSiswaList) {
        final nilaiData = _getNilaiForSiswaAndHeader(siswa.id, jenis, header);

        final nilaiKey = "${siswa.id}_nilai";
        _editControllers[nilaiKey] = TextEditingController(
          text: _formatGradeValue(nilaiData?['nilai']),
        );
        _editFocusNodes[nilaiKey] = FocusNode();
        _editFocusNodes[nilaiKey]!.addListener(() {
          if (!_editFocusNodes[nilaiKey]!.hasFocus) {
            _saveInlineGrade(
              siswa.id,
              jenis,
              header,
              'nilai',
              _editControllers[nilaiKey]!.text,
            );
          }
        });

        // Deskripsi Controller
        final deskripsiKey = "${siswa.id}_deskripsi";
        _editControllers[deskripsiKey] = TextEditingController(
          text: nilaiData?['deskripsi']?.toString() ?? '',
        );
        _editFocusNodes[deskripsiKey] = FocusNode();
        _editFocusNodes[deskripsiKey]!.addListener(() {
          if (!_editFocusNodes[deskripsiKey]!.hasFocus) {
            _saveInlineGrade(
              siswa.id,
              jenis,
              header,
              'deskripsi',
              _editControllers[deskripsiKey]!.text,
            );
          }
        });
      }
    });
  }

  Future<void> _saveInlineGrade(
    String siswaId,
    String jenis,
    Map<String, dynamic> header,
    String field,
    String value, {
    bool reload = true,
  }) async {
    // Check if value changed
    final currentData = _getNilaiForSiswaAndHeader(siswaId, jenis, header);
    final currentValue = currentData?[field]?.toString() ?? '';

    // If value is empty and was empty, do nothing
    if (value.isEmpty && currentValue.isEmpty) return;

    // If value hasn't changed, do nothing
    if (value == currentValue) return;

    try {
      final data = {
        'student_id': siswaId,
        'teacher_id': widget.teacher['id'],
        'subject_id': widget.subject['id'],
        'type': jenis,
        'date': header['date'],
        'title': header['title'],
        'assessment_id': header['id'], // Include assessment ID if exists
        'score': field == 'nilai'
            ? (value.isEmpty ? 0 : double.tryParse(value) ?? 0)
            : (currentData?['nilai'] ?? 0),
        'notes': field == 'deskripsi'
            ? value
            : (currentData?['deskripsi'] ?? ''),
      };

      if (currentData != null && currentData['id'] != null) {
        // Update
        await ApiService().put('/grades/${currentData['id']}', data);
      } else {
        // Create new only if we have a value
        if (value.isNotEmpty) {
          await ApiService().post('/grades', data);
        }
      }

      // Update local data in background
      if (reload) {
        _loadData();
      }
    } catch (e) {
      print('Error saving inline grade: $e');
      _showErrorSnackBar('Failed to save: $e');
    }
  }

  Widget _buildEditTable(LanguageProvider languageProvider) {
    String date = _editHeader?['date'] ?? '';
    String? title = _editHeader?['title'];
    String displayTitle = title != null && title.isNotEmpty
        ? "$title (${_formatDateDisplay(date)})"
        : _formatDateDisplay(date);

    return Column(
      children: [
        // Edit Header
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Mode',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "${_getJenisNilaiLabel(_editJenis!, languageProvider)} - $displayTitle",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Show loading indicator
                  setState(() => _isLoading = true);

                  try {
                    // Iterate and save all
                    for (var siswa in _filteredSiswaList) {
                      final nilaiKey = "${siswa.id}_nilai";
                      final deskripsiKey = "${siswa.id}_deskripsi";

                      // Save Nilai
                      if (_editControllers.containsKey(nilaiKey)) {
                        await _saveInlineGrade(
                          siswa.id,
                          _editJenis!,
                          _editHeader!,
                          'nilai',
                          _editControllers[nilaiKey]!.text,
                          reload: false,
                        );
                      }

                      // Save Deskripsi
                      if (_editControllers.containsKey(deskripsiKey)) {
                        await _saveInlineGrade(
                          siswa.id,
                          _editJenis!,
                          _editHeader!,
                          'deskripsi',
                          _editControllers[deskripsiKey]!.text,
                          reload: false,
                        );
                      }
                    }

                    // Reload data once
                    await _loadData();

                    setState(() {
                      _isEditMode = false;
                      _editJenis = null;
                      _editHeader = null;
                      _isLoading = false;
                    });
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showErrorSnackBar('Failed to save changes: $e');
                  }
                },
                icon: Icon(Icons.check, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Finish',
                    'id': 'Selesai',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? MediaQuery.of(context).size.width
                    : 600,
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 150,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Name',
                                'id': 'Nama',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Grade',
                                'id': 'Nilai',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Description',
                                  'id': 'Deskripsi',
                                }),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rows
                    ..._filteredSiswaList.map((siswa) {
                      final nilaiKey = "${siswa.id}_nilai";
                      final deskripsiKey = "${siswa.id}_deskripsi";

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            // Name
                            Container(
                              width: 150,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    siswa.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    siswa.nis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Nilai Input
                            Container(
                              width: 100,
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.grey.shade200),
                                  right: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: TextFormField(
                                controller: _editControllers[nilaiKey],
                                focusNode: _editFocusNodes[nilaiKey],
                                enabled: !Provider.of<AcademicYearProvider>(
                                  context,
                                  listen: false,
                                ).isReadOnly,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '-',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                onFieldSubmitted: (value) {
                                  _saveInlineGrade(
                                    siswa.id,
                                    _editJenis!,
                                    _editHeader!,
                                    'nilai',
                                    value,
                                  );
                                },
                              ),
                            ),
                            // Deskripsi Input
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: TextFormField(
                                  controller: _editControllers[deskripsiKey],
                                  focusNode: _editFocusNodes[deskripsiKey],
                                  enabled: !Provider.of<AcademicYearProvider>(
                                    context,
                                    listen: false,
                                  ).isReadOnly,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: languageProvider
                                        .getTranslatedText({
                                          'en': 'Add description...',
                                          'id': 'Tambah deskripsi...',
                                        }),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onFieldSubmitted: (value) {
                                    _saveInlineGrade(
                                      siswa.id,
                                      _editJenis!,
                                      _editHeader!,
                                      'deskripsi',
                                      value,
                                    );
                                  },
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
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateDisplay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  void _showAssessmentDetail(
    String jenis,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    String date = header['date'];
    String? title = header['title'];
    // Calculate stats
    int totalSiswa = _siswaList.length;
    int gradedCount = 0;
    double totalNilai = 0;

    for (var siswa in _siswaList) {
      final nilai = _getNilaiForSiswaAndHeader(siswa.id, jenis, header);
      if (nilai != null && nilai.isNotEmpty) {
        gradedCount++;
        totalNilai += double.tryParse(nilai['nilai'].toString()) ?? 0.0;
      }
    }

    double average = gradedCount > 0 ? totalNilai / gradedCount : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Assessment Details',
            'id': 'Detail Penilaian',
          }),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              languageProvider.getTranslatedText({'en': 'Type', 'id': 'Jenis'}),
              _getJenisNilaiLabel(jenis, languageProvider),
            ),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Date',
                'id': 'Tanggal',
              }),
              _formatDateDisplay(date),
            ),
            if (title != null && title.isNotEmpty)
              _buildDetailRow(
                languageProvider.getTranslatedText({
                  'en': 'Title',
                  'id': 'Judul',
                }),
                title,
              ),
            Divider(),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Total Students',
                'id': 'Total Siswa',
              }),
              totalSiswa.toString(),
            ),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Graded',
                'id': 'Sudah Dinilai',
              }),
              "$gradedCount / $totalSiswa",
            ),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Average Score',
                'id': 'Rata-rata Nilai',
              }),
              average.toStringAsFixed(2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDeleteAssessment(
    String jenis,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    String date = header['date'];
    String? title = header['title'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Assessment?',
            'id': 'Hapus Penilaian?',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete all grades for ${_getJenisNilaiLabel(jenis, languageProvider)} on ${_formatDateDisplay(date)}${title != null ? " ($title)" : ""}? This action cannot be undone.',
            'id':
                'Apakah Anda yakin ingin menghapus semua nilai ${_getJenisNilaiLabel(jenis, languageProvider)} pada tanggal ${_formatDateDisplay(date)}${title != null ? " ($title)" : ""}? Tindakan ini tidak dapat dibatalkan.',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAssessment(jenis, header);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssessment(
    String jenis,
    Map<String, dynamic> header,
  ) async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();

      // If we have assessment_id, ideally we should delete by ID.
      // But keeping legacy implementation for now, using batch delete.
      // Providing title to query params if available.

      final queryParams = {
        'mata_pelajaran_id': widget.subject['id'],
        'jenis': jenis,
        'tanggal': header['date'],
      };

      if (header['title'] != null) {
        queryParams['title'] = header['title'];
      }

      // If we have assessment_id, maybe backend supports it?
      // Current backend only checks type and date in batch delete?
      // User requested Title addition, so assuming backend handles Title in batch delete.
      // If not, this might over-delete.
      // Note: Backend CreateGradeAction uses firstOrCreate.
      // If we delete, we should be specific.

      final queryString = Uri(queryParameters: queryParams).query;

      await apiService.delete('/grades/batch?$queryString');

      _showSuccessSnackBar('Assessment deleted successfully');
      _loadData(); // Reload to refresh the table
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to delete assessment: $e');
    }
  }

  Future<void> _addNewAssessment(String jenis) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      final dateStr =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

      setState(() {
        if (!_assessmentHeaders.containsKey(jenis)) {
          _assessmentHeaders[jenis] = [];
        }

        // Add a temporary header. Title is initially null.
        // It will be distinct from existing ones if they have titles.
        // But if there is an existing one with null title and same date,
        // we might just be pointing to that one.

        // Check if we already have a header with this date and (null) title
        bool exists = _assessmentHeaders[jenis]!.any(
          (h) => h['date'] == dateStr && h['title'] == null,
        );

        if (!exists) {
          _assessmentHeaders[jenis]!.add({
            'id': null,
            'date': dateStr,
            'title': null,
            'is_temp': true,
          });

          // Sort
          _assessmentHeaders[jenis]!.sort((a, b) {
            final dateCompare = a['date'].compareTo(b['date']);
            if (dateCompare != 0) return dateCompare;
            return (a['title'] ?? '').compareTo(b['title'] ?? '');
          });
        }
      });
    }
  }

  Future<void> _exportGrades(LanguageProvider languageProvider) async {
    setState(() => _isLoading = true);
    try {
      final academicYearId = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).selectedAcademicYear?['id'];
      final endpoint =
          '/grades/export?class_id=${widget.classData['id']}&subject_id=${widget.subject['id']}&teacher_id=${widget.teacher['id']}&academic_year_id=$academicYearId';

      final bytes = await ApiService.downloadFile(endpoint);

      if (kIsWeb) {
        // Handle web download
        await FileSaver.instance.saveFile(
          name: 'grades_export_${DateTime.now().millisecond}',
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      } else {
        // Handle mobile download
        final directory = await getApplicationDocumentsDirectory();
        final file = File(
          '${directory.path}/grades_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
        await file.writeAsBytes(bytes);

        await OpenFile.open(file.path);
      }

      _showSuccessSnackBar(
        languageProvider.getTranslatedText({
          'en': 'Export successful',
          'id': 'Ekspor berhasil',
        }),
      );
    } catch (e) {
      _showErrorSnackBar('Export Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openNewInputForm(LanguageProvider languageProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputFormNew(
          teacher: widget.teacher,
          subject: widget.subject,
          siswaList: _siswaList,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  Widget _buildGradeTable(LanguageProvider languageProvider) {
    // Calculate total width based on columns
    double totalWidth = 120.0; // Name column

    for (var jenis in _filteredJenisNilaiList) {
      final headers = _assessmentHeaders[jenis] ?? [];
      // Width for assessment columns + 1 for "Add" button column
      totalWidth += (headers.length * 90.0) + 50.0;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalScrollController,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          children: [
            // Header tabel
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  // Kolom Nama Siswa - Lebar tetap
                  Container(
                    width: 120,
                    padding: EdgeInsets.all(12),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Name',
                        'id': 'Nama',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Kolom jenis nilai (Dynamic)
                  ..._filteredJenisNilaiList.expand((jenis) {
                    final headers = _assessmentHeaders[jenis] ?? [];

                    List<Widget> columns = [];

                    // Existing assessment columns
                    for (var header in headers) {
                      String date = header['date'];
                      String? title = header['title'];

                      // Format date for display (e.g. 10/10)
                      final parts = date.split('-');
                      final displayDate = parts.length == 3
                          ? "${parts[2]}/${parts[1]}"
                          : date;

                      columns.add(
                        InkWell(
                          onTap: () => _showColumnOptions(
                            jenis,
                            header,
                            languageProvider,
                          ),
                          child: Container(
                            width: 90,
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  // Show Title if available, else Type label
                                  title != null && title.isNotEmpty
                                      ? title
                                      : _getJenisNilaiLabel(
                                          jenis,
                                          languageProvider,
                                        ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  displayDate,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Add button column (Only for Guru)
                    if (widget.teacher['role'] == 'guru')
                      columns.add(
                        Container(
                          width: 50,
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              size: 20,
                              color: _getPrimaryColor(),
                            ),
                            onPressed: () => _addNewAssessment(jenis),
                            tooltip: "Add $jenis",
                          ),
                        ),
                      );

                    return columns;
                  }),
                ],
              ),
            ),
            // Body tabel
            ..._filteredSiswaList.map((siswa) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    // Kolom Nama Siswa - Tetap
                    Container(
                      width: 120,
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            siswa.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${siswa.nis}',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    // Kolom Nilai (Dynamic)
                    ..._filteredJenisNilaiList.expand((jenis) {
                      final headers = _assessmentHeaders[jenis] ?? [];

                      List<Widget> columns = [];

                      // Existing columns
                      for (var header in headers) {
                        final nilai = _getNilaiForSiswaAndHeader(
                          siswa.id,
                          jenis,
                          header,
                        );
                        final nilaiText = nilai?.isNotEmpty == true
                            ? _formatGradeValue(nilai!['nilai'])
                            : '-';
                        final hasValue = nilai?.isNotEmpty == true;

                        columns.add(
                          Container(
                            width: 90,
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: GestureDetector(
                              onTap: widget.teacher['role'] == 'guru'
                                  ? () => _openInputForm(
                                      siswa,
                                      jenis,
                                      languageProvider,
                                      header: header,
                                    )
                                  : null,
                              child: Container(
                                height: 40,
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: hasValue
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: hasValue
                                        ? Colors.green.shade200
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    nilaiText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: hasValue
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: hasValue
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // Spacer for Add button column (Only for Guru)
                      if (widget.teacher['role'] == 'guru')
                        columns.add(
                          Container(
                            width: 50,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade200),
                              ),
                              color: Colors.grey.shade50.withOpacity(0.5),
                            ),
                          ),
                        );

                      return columns;
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final activeFilterCount = _jenisNilaiFilter.values
            .where((v) => v)
            .length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              '${languageProvider.getTranslatedText({'en': 'Grades', 'id': 'Nilai'})} - ${widget.subject['name']} - ${widget.classData['name']}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.download, color: Colors.black),
                onPressed: () => _exportGrades(languageProvider),
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Export to Excel',
                  'id': 'Ekspor ke Excel',
                }),
              ),
              // Tombol Filter dengan badge
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.filter_list, color: Colors.black),
                    onPressed: () => _showFilterDialog(languageProvider),
                    tooltip: languageProvider.getTranslatedText({
                      'en': 'Filter Grade Types',
                      'id': 'Filter Jenis Nilai',
                    }),
                  ),
                  if (activeFilterCount < _allJenisNilaiList.length)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${_allJenisNilaiList.length - activeFilterCount}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.black),
                onPressed: _loadData,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Refresh',
                  'id': 'Muat Ulang',
                }),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: _isLoading
              ? LoadingScreen(
                  message: languageProvider.getTranslatedText({
                    'en': 'Loading grade data...',
                    'id': 'Memuat data nilai...',
                  }),
                )
              : _isEditMode
              ? _buildEditTable(languageProvider)
              : Column(
                  children: [
                    // Header Info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.subject['name']} - ${widget.classData['name']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Grade types', 'id': 'Jenis nilai'})}: ${_filteredJenisNilaiList.map((jenis) => _getJenisNilaiLabel(jenis, languageProvider)).join(', ')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Search students...',
                              'id': 'Cari siswa...',
                            }),
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
                        ),
                      ),
                    ),

                    if (_filteredSiswaList.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${_filteredSiswaList.length} ${languageProvider.getTranslatedText({'en': 'students found', 'id': 'siswa ditemukan'})}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 8),

                    // Instruction
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Click on grade cells to input/edit',
                          'id':
                              'Klik pada kolom nilai untuk menginput/mengedit',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Tabel Nilai
                    Expanded(
                      child: _filteredSiswaList.isEmpty
                          ? EmptyState(
                              title: languageProvider.getTranslatedText({
                                'en': 'No students found',
                                'id': 'Tidak ada siswa',
                              }),
                              subtitle: _searchController.text.isEmpty
                                  ? languageProvider.getTranslatedText({
                                      'en': 'No students in this class',
                                      'id': 'Tidak ada siswa di kelas ini',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'No search results found',
                                      'id': 'Tidak ditemukan hasil pencarian',
                                    }),
                              icon: Icons.people_outline,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: _buildGradeTable(languageProvider),
                            ),
                    ),
                  ],
                ),
          floatingActionButton:
              (_isEditMode || widget.teacher['role'] != 'guru')
              ? null
              : FloatingActionButton(
                  onPressed: () => _openNewInputForm(languageProvider),
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.add),
                ),
        );
      },
    );
  }
}

// Form Input Nilai Individual
class GradeInputForm extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Siswa siswa;
  final String jenisNilai;
  final Map<String, dynamic>? existingNilai;
  final DateTime? initialDate;
  final String? initialTitle;

  const GradeInputForm({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswa,
    required this.jenisNilai,
    this.existingNilai,
    this.initialDate,
    this.initialTitle,
  });

  @override
  GradeInputFormState createState() => GradeInputFormState();
}

class GradeInputFormState extends State<GradeInputForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nilaiController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-fill data jika edit
    if (widget.existingNilai != null) {
      _nilaiController.text = widget.existingNilai!['nilai'].toString();
      _deskripsiController.text =
          widget.existingNilai!['deskripsi']?.toString() ?? '';
      _titleController.text = widget.existingNilai!['title']?.toString() ?? '';

      if (widget.existingNilai!['tanggal'] != null) {
        _selectedDate = DateTime.parse(widget.existingNilai!['tanggal']);
      }
    } else {
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      }
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
    }
  }

  @override
  void dispose() {
    _nilaiController.dispose();
    _deskripsiController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitNilai() async {
    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    if (academicYearProvider.isReadOnly) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).getTranslatedText({
              'en': 'Cannot submit grades for inactive academic year',
              'id':
                  'Tidak dapat menyimpan nilai untuk tahun ajaran yang tidak aktif',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'student_id': widget.siswa.id,
          'teacher_id': widget.teacher['id'],
          'subject_id': widget.subject['id'],
          'type': widget.jenisNilai,
          'score': double.parse(_nilaiController.text),
          'notes': _deskripsiController.text,
          'title': _titleController.text.isNotEmpty
              ? _titleController.text
              : null,
          'date':
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        };

        if (widget.existingNilai != null) {
          // Update nilai yang sudah ada
          await ApiService().put(
            '/grades/${widget.existingNilai!['id']}',
            data,
          );
        } else {
          // Tambah nilai baru
          await ApiService().post('/grades', data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().getTranslatedText({
                'en': widget.existingNilai != null
                    ? 'Grade successfully updated'
                    : 'Grade successfully saved',
                'id': widget.existingNilai != null
                    ? 'Nilai berhasil diupdate'
                    : 'Nilai berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.read<LanguageProvider>().getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'Input Grade',
                'id': 'Input Nilai',
              }),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Info Siswa dan Mata Pelajaran
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'Student', 'id': 'Siswa'})}: ${widget.siswa.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getPrimaryColor(),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.badge, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${widget.siswa.nis}',
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.menu_book, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${widget.subject['nama']}',
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.assignment, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'Type', 'id': 'Jenis'})}: ${_getJenisNilaiLabel(widget.jenisNilai, languageProvider)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Input Title
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: languageProvider.getTranslatedText({
                        'en': 'Assessment Title (Optional)',
                        'id': 'Judul Penilaian (Opsional)',
                      }),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title, color: _getPrimaryColor()),
                      helperText: languageProvider.getTranslatedText({
                        'en': 'E.g., Quiz 1, Project A',
                        'id': 'Contoh: Kuis 1, Proyek A',
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Input Nilai
                  TextFormField(
                    controller: _nilaiController,
                    decoration: InputDecoration(
                      labelText: languageProvider.getTranslatedText({
                        'en': 'Grade',
                        'id': 'Nilai',
                      }),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.score, color: _getPrimaryColor()),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.getTranslatedText({
                          'en': 'Please enter grade',
                          'id': 'Masukkan nilai',
                        });
                      }
                      if (double.tryParse(value) == null) {
                        return languageProvider.getTranslatedText({
                          'en': 'Please enter valid number',
                          'id': 'Masukkan angka yang valid',
                        });
                      }
                      final nilai = double.parse(value);
                      if (nilai < 0 || nilai > 100) {
                        return languageProvider.getTranslatedText({
                          'en': 'Grade must be between 0-100',
                          'id': 'Nilai harus antara 0-100',
                        });
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Input Deskripsi
                  TextFormField(
                    controller: _deskripsiController,
                    decoration: InputDecoration(
                      labelText: languageProvider.getTranslatedText({
                        'en': 'Description',
                        'id': 'Deskripsi',
                      }),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.description,
                        color: _getPrimaryColor(),
                      ),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // Pilih Tanggal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: _getPrimaryColor()),
                        SizedBox(width: 12),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Date:',
                            'id': 'Tanggal:',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () => _selectDate(context),
                          child: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tombol Simpan
                  ElevatedButton(
                    onPressed: _submitNilai,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryColor(),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.existingNilai != null
                          ? languageProvider.getTranslatedText({
                              'en': 'Update Grade',
                              'id': 'Update Nilai',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Save Grade',
                              'id': 'Simpan Nilai',
                            }),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Form Input Nilai Baru untuk Multiple Siswa
class GradeInputFormNew extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Siswa> siswaList;

  const GradeInputFormNew({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswaList,
  });

  @override
  GradeInputFormNewState createState() => GradeInputFormNewState();
}

class GradeInputFormNewState extends State<GradeInputFormNew> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  // Variabel untuk state
  String? _selectedJenisNilai;
  final List<String> _jenisNilaiList = [
    'harian',
    'tugas',
    'ulangan',
    'uts',
    'uas',
  ];

  // Map untuk menyimpan nilai per siswa
  final Map<String, Map<String, dynamic>> _nilaiSiswaMap = {};

  // Text controllers untuk tabel input
  final Map<String, TextEditingController> _tableControllers = {};
  final Map<String, FocusNode> _tableFocusNodes = {};

  // State untuk tracking apakah jenis nilai dan tanggal sudah di-set
  bool _isConfigurationSet = false;
  String? _confirmedJenisNilai;
  DateTime? _confirmedDate;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize map dengan nilai default untuk setiap siswa
    for (var siswa in widget.siswaList) {
      _nilaiSiswaMap[siswa.id] = {'nilai': '', 'deskripsi': ''};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _tableControllers.values) {
      controller.dispose();
    }
    for (var node in _tableFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitNilai() async {
    final languageProvider = context.read<LanguageProvider>();

    if (_formKey.currentState!.validate()) {
      if (_selectedJenisNilai == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Please select grade type first',
                'id': 'Pilih jenis nilai terlebih dahulu',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Cek apakah ada setidaknya satu siswa yang memiliki nilai
      bool hasData = false;
      for (var siswa in widget.siswaList) {
        final nilaiData = _nilaiSiswaMap[siswa.id];
        if (nilaiData?['nilai']?.isNotEmpty == true) {
          hasData = true;
          break;
        }
      }

      if (!hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Enter grade for at least one student',
                'id': 'Masukkan nilai untuk setidaknya satu siswa',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      try {
        int successCount = 0;

        for (var siswa in widget.siswaList) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          final nilai = nilaiData?['nilai']?.toString().trim();

          // Skip jika tidak ada nilai yang diinput
          if (nilai == null || nilai.isEmpty) {
            continue;
          }

          // Perbaikan: Kirim Student Class ID jika ada, fallback ke ID siswa (untuk kompatibilitas)
          final studentIdToSend = siswa.studentClassId ?? siswa.id;

          // ... (inside _submitNilai)
          final data = {
            'student_id': siswa.id, // For legacy/history
            'student_class_id':
                studentIdToSend, // New field required by backend
            'teacher_id': widget.teacher['id'],
            'subject_id': widget.subject['id'],
            'type': _selectedJenisNilai,
            'score': double.parse(nilaiData!['nilai']),
            'notes': nilaiData['deskripsi'] ?? '',
            'date':
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            'title': _titleController.text.isNotEmpty
                ? _titleController.text
                : null,
          };

          // Tambah nilai baru
          await ApiService().post('/grades', data);
          successCount++;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': '$successCount grades successfully saved',
                'id': '$successCount nilai berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Validation failed - show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en':
                  'Please check your input. Grades must be numbers between 0-100.',
              'id':
                  'Periksa input Anda. Nilai harus berupa angka antara 0-100.',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  Widget _buildInputTable(LanguageProvider languageProvider) {
    // Calculate width
    double tableWidth = 150.0; // Name column
    tableWidth += 100.0; // Nilai column
    tableWidth += 200.0; // Deskripsi column

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width
              : tableWidth,
          child: Column(
            children: [
              // Header (Sticky-like appearance)
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 150,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Name',
                          'id': 'Nama',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      width: 100,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Grade',
                          'id': 'Nilai',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Description',
                            'id': 'Deskripsi',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Rows - scrollable
              ...widget.siswaList.map((siswa) {
                final nilaiKey = "${siswa.id}_nilai";
                final deskripsiKey = "${siswa.id}_deskripsi";

                // Initialize controllers if not exists
                if (!_tableControllers.containsKey(nilaiKey)) {
                  _tableControllers[nilaiKey] = TextEditingController();
                  _tableFocusNodes[nilaiKey] = FocusNode();
                }
                if (!_tableControllers.containsKey(deskripsiKey)) {
                  _tableControllers[deskripsiKey] = TextEditingController();
                  _tableFocusNodes[deskripsiKey] = FocusNode();
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      // Name
                      Container(
                        width: 150,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              siswa.name,
                              style: TextStyle(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              siswa.nis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Nilai Input
                      Container(
                        width: 100,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade200),
                            right: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: TextFormField(
                          controller: _tableControllers[nilaiKey],
                          focusNode: _tableFocusNodes[nilaiKey],
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '-',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            errorStyle: TextStyle(fontSize: 10),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final numValue = double.tryParse(value);
                              if (numValue == null) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Numbers only',
                                  'id': 'Hanya angka',
                                });
                              }
                              if (numValue < 0 || numValue > 100) {
                                return languageProvider.getTranslatedText({
                                  'en': '0-100',
                                  'id': '0-100',
                                });
                              }
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _nilaiSiswaMap[siswa.id]?['nilai'] = value;
                            });
                          },
                        ),
                      ),
                      // Deskripsi Input
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: TextFormField(
                            controller: _tableControllers[deskripsiKey],
                            focusNode: _tableFocusNodes[deskripsiKey],
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Add description...',
                                'id': 'Tambah deskripsi...',
                              }),
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            onChanged: (value) {
                              _nilaiSiswaMap[siswa.id]?['deskripsi'] = value;
                            },
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
      ),
    );
  }

  // Build header untuk mode add setelah di-set (mirip dengan edit mode)
  Widget _buildAddHeader(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Jenis Nilai with edit icon
          GestureDetector(
            onTap: () {
              setState(() {
                _isConfigurationSet = false;
              });
            },
            child: Row(
              children: [
                Text(
                  _getJenisNilaiLabel(
                    _confirmedJenisNilai ?? '',
                    languageProvider,
                  ),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(width: 8),
                Icon(Icons.edit, size: 16, color: _getPrimaryColor()),
              ],
            ),
          ),
          // Right side: Date in Indonesian format
          Text(
            _formatDateIndonesian(_confirmedDate!),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Format date to Indonesian format (e.g., "05 Januari 2025")
  String _formatDateIndonesian(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString();

    return '$day $month $year';
  }

  // Build configuration panel (selection stage)
  Widget _buildConfigurationPanel(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Subject Info
          Row(
            children: [
              Icon(Icons.menu_book, color: _getPrimaryColor(), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${widget.subject['nama']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _getPrimaryColor(),
                      ),
                    ),
                    if (widget.subject['code'] != null ||
                        widget.subject['kode'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${widget.subject['code'] ?? widget.subject['kode']}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pilih Jenis Nilai
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedJenisNilai,
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.assignment, color: _getPrimaryColor()),
                hintText: languageProvider.getTranslatedText({
                  'en': 'Select grade type',
                  'id': 'Pilih jenis nilai',
                }),
              ),
              items: _jenisNilaiList.map((String jenis) {
                return DropdownMenuItem<String>(
                  value: jenis,
                  child: Text(_getJenisNilaiLabel(jenis, languageProvider)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedJenisNilai = newValue;
                });
              },
              validator: (value) {
                if (value == null) {
                  return languageProvider.getTranslatedText({
                    'en': 'Please select grade type',
                    'id': 'Pilih jenis nilai terlebih dahulu',
                  });
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          // Pilih Tanggal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _getPrimaryColor()),
                const SizedBox(width: 12),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Date:',
                    'id': 'Tanggal:',
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(fontSize: 16, color: _getPrimaryColor()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.title, color: _getPrimaryColor()),
                hintText: languageProvider.getTranslatedText({
                  'en': 'Assessment Title (Optional)',
                  'id': 'Judul Penilaian (Opsional)',
                }),
                helperText: languageProvider.getTranslatedText({
                  'en': 'E.g., Quiz 1, Chapter 5 Test',
                  'id': 'Contoh: Kuis 1, Ulangan Bab 5',
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Tombol Set
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_selectedJenisNilai != null &&
                      !Provider.of<AcademicYearProvider>(context).isReadOnly)
                  ? () {
                      setState(() {
                        _isConfigurationSet = true;
                        _confirmedJenisNilai = _selectedJenisNilai;
                        _confirmedDate = _selectedDate;
                      });
                    }
                  : null,
              icon: Icon(Icons.check),
              label: Text(
                languageProvider.getTranslatedText({
                  'en': 'Set',
                  'id': 'Tetapkan',
                }),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final siswaWithNilaiCount = widget.siswaList.where((siswa) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          return nilaiData?['nilai']?.isNotEmpty == true;
        }).length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'New Grade Input',
                'id': 'Input Nilai Baru',
              }),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                // Conditional header based on state
                if (!_isConfigurationSet)
                  _buildConfigurationPanel(languageProvider)
                else
                  _buildAddHeader(languageProvider),

                // Student List Section - only show after configuration is set
                if (_isConfigurationSet) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Student List',
                            'id': 'Daftar Siswa',
                          }),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: siswaWithNilaiCount > 0
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: siswaWithNilaiCount > 0
                                  ? Colors.green.shade200
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            '$siswaWithNilaiCount/${widget.siswaList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                            style: TextStyle(
                              color: siswaWithNilaiCount > 0
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Edit grade and description for each student',
                        'id': 'Edit nilai dan deskripsi untuk setiap siswa',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildInputTable(languageProvider)),
                ] else ...[
                  const Expanded(
                    child: EmptyState(
                      title: 'Select grade type and date',
                      subtitle:
                          'Please select grade type and date first then click Set',
                      icon: Icons.assignment,
                    ),
                  ),
                ],

                // Tombol Finish - only show after configuration is set
                if (_isConfigurationSet) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _submitNilai,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPrimaryColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Finish',
                          'id': 'Selesai',
                        }),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
