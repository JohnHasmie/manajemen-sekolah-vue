// class_activity.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/tab_switcher.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassActifityScreen extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialBabId;
  final String? initialSubBabId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  const ClassActifityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialBabId,
    this.initialSubBabId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
  });

  @override
  ClassActifityScreenState createState() => ClassActifityScreenState();
}

class ClassActifityScreenState extends State<ClassActifityScreen>
    with TickerProviderStateMixin {
  final List<dynamic> _scheduleList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _chapterList = [];
  List<dynamic> _subChapterList = [];
  List<dynamic> _activityList = [];
  bool _isLoading = true;
  String _teacherId = '';
  String _teacherName = '';

  // New Navigation State
  // 0: Class List, 1: Subject List, 2: Activity List
  int _currentStep = 0;
  String? _selectedClassId;
  String? _selectedClassName;
  // Map<String, dynamic>? _selectedClassData; // If full object needed
  String? _selectedSubjectId;
  String? _selectedSubjectName;

  // Data Lists
  List<dynamic> _classList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;

  bool _hasActiveFilter = false;

  // Pagination
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Scroll controller for infinite scroll
  final ScrollController _scrollController = ScrollController();

  // Search debouncing

  late TabController _tabController;
  String _currentTarget = 'umum';

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_onScroll);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {
      _currentTarget = _tabController.index == 0 ? 'umum' : 'khusus';
    });
    // Reset pagination when switching tabs
    _resetAndLoadActivities();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreActivities();
      }
    }
  }

  void _resetAndLoadActivities() {
    setState(() {
      _currentPage = 1;
      _activityList.clear();
      _hasMoreData = true;
      _isLoading = true;
    });
    _loadActivities();
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _currentPage++;
      _isLoadingMore = true;
    });

    await _loadActivities();
  }

  // ========== VIEW BUILDERS ==========

  Widget _buildClassList(LanguageProvider languageProvider) {
    if (_isLoading) {
      return LoadingScreen(
        message: languageProvider.getTranslatedText({
          'en': 'Loading classes...',
          'id': 'Memuat kelas...',
        }),
      );
    }

    if (_classList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Kelas Tidak Ditemukan',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'You do not have any assigned classes for this academic year.',
          'id':
              'Anda tidak memiliki kelas yang ditugaskan untuk tahun ajaran ini.',
        }),
        icon: Icons.class_outlined,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _classList.length,
      itemBuilder: (context, index) {
        final classData = _classList[index];
        final isHomeroom = classData['is_homeroom'] == true;

        return Card(
          elevation: 2,
          shadowColor: ColorUtils.slate200,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              setState(() {
                _selectedClassId = classData['id'].toString();
                _selectedClassName = classData['name'] ?? classData['nama'];
                _currentStep = 1;
              });
              await _loadSubjectsForClass();
            },
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
                          : ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isHomeroom
                          ? Icons.home_work_rounded
                          : Icons.class_rounded,
                      color: isHomeroom
                          ? ColorUtils.primary
                          : ColorUtils.slate500,
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
                                classData['name'] ?? classData['nama'] ?? '-',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ColorUtils.slate900,
                                ),
                              ),
                            ),
                            if (isHomeroom)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorUtils.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Wali Kelas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${classData['tingkat'] ?? ''} • ${classData['jurusan'] ?? ''}',
                          style: TextStyle(
                            color: ColorUtils.slate500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: ColorUtils.slate400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectList(LanguageProvider languageProvider) {
    if (_isLoading) {
      return LoadingScreen(
        message: languageProvider.getTranslatedText({
          'en': 'Loading subjects...',
          'id': 'Memuat mata pelajaran...',
        }),
      );
    }

    if (_subjectList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Mata Pelajaran Tidak Ditemukan',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects suitable for this class found.',
          'id': 'Tidak ditemukan mata pelajaran yang sesuai untuk kelas ini.',
        }),
        icon: Icons.menu_book_outlined,
      );
    }

    return Column(
      children: [
        // Selection Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: ColorUtils.slate50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Selected Class:',
                  'id': 'Kelas Terpilih:',
                }),
                style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
              ),
              SizedBox(height: 4),
              Text(
                _selectedClassName ?? '-',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _subjectList.length,
            itemBuilder: (context, index) {
              final subject = _subjectList[index];
              final subjectName = subject['name'] ?? subject['nama'] ?? '-';
              // Check backend response for code/description
              final subjectCode = subject['code'] ?? subject['kode'] ?? '';

              return Card(
                elevation: 2,
                shadowColor: ColorUtils.slate200,
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    setState(() {
                      _selectedSubjectId = subject['id'].toString();
                      _selectedSubjectName = subjectName;
                      _currentStep = 2; // Go to Activity List
                    });
                    await _loadActivities();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ColorUtils.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: ColorUtils.primary,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subjectName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ColorUtils.slate900,
                                ),
                              ),
                              if (subjectCode.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    subjectCode,
                                    style: TextStyle(
                                      color: ColorUtils.slate500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: ColorUtils.slate400,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadUserData() async {
    if (kDebugMode) {
      print('===== _loadUserData STARTED =====');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      final userId = userData['id']?.toString() ?? '';

      setState(() {
        _teacherId = userId; // Initially set to userId
        _teacherName = userData['nama']?.toString() ?? 'Guru';
      });

      if (kDebugMode) {
        print('User ID from prefs: $userId');
      }

      if (userId.isNotEmpty) {
        // 1. Resolve Teacher ID first (needed for both Schedule and Activities)
        try {
          final teacherData = await ApiTeacherService.getGuruByUserId(userId);
          if (teacherData != null && teacherData['id'] != null) {
            final teacherId = teacherData['id'].toString();

            if (kDebugMode) {
              print('Resolved Teacher ID: $teacherId');
            }

            setState(() {
              _teacherId = teacherId; // Update to Teacher ID for activities
            });

            // 2. Load Classes using TEACHER ID
            await _loadClasses(teacherId);

            // If initial params provided, try to navigate deep
            if (widget.initialClassId != null) {
              _selectedClassId = widget.initialClassId;
              _selectedClassName = widget.initialClassName;
              _currentStep = 1; // Go to Subject List

              if (widget.initialSubjectId != null) {
                _selectedSubjectId = widget.initialSubjectId;
                // Need to find subject name? Or rely on initialSubjectName
                _selectedSubjectName =
                    widget.initialSubjectName; // Assuming passed
                _currentStep = 2; // Go to Activity List
                await _loadActivities();
              } else {
                await _loadSubjectsForClass();
              }
            }
          } else {
            if (kDebugMode) {
              print('❌ Failed to resolve Teacher ID from User ID');
              print('Cannot load classes without Teacher ID');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error during teacher resolution: $e');
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _loadUserData: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClasses(String teacherId) async {
    try {
      final academicYearId = context
          .read<AcademicYearProvider>()
          .selectedAcademicYear?['id']
          ?.toString();

      final classes = await ApiTeacherService.getTeacherClasses(
        teacherId,
        academicYearId: academicYearId,
      );

      setState(() {
        _classList = classes;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading classes: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubjectsForClass() async {
    if (_selectedClassId == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Get All Subjects for Teacher
      final allSubjects = await ApiTeacherService().getSubjectByTeacher(
        _teacherId,
      );

      // 2. Get Selected Class Data to check Grade Level
      final selectedClass = _classList.firstWhere(
        (c) => c['id'].toString() == _selectedClassId,
        orElse: () => <String, dynamic>{}, // Return empty map if not found
      );

      // Normalize grade level (e.g., "10", "X", "1")
      String? classGrade;
      if (selectedClass.isNotEmpty) {
        // Try different fields: 'tingkat', 'grade_level', 'level'
        classGrade =
            selectedClass['tingkat']?.toString() ??
            selectedClass['grade_level']?.toString();
      }

      // 3. Filter Subjects
      final filteredSubjects = allSubjects.where((subject) {
        // If subject has specific grade assigned in master subject
        final masterSubject = subject['master_subject'];
        // Note: backend response structure for 'getSubjectByTeacher' needs verification
        // It returns list of subject_schools (Subject model).
        // We added eager load 'masterSubject'.

        final subjectGrade = masterSubject?['grade']?.toString();

        // Logic:
        // - If subject has NO grade, show for all classes? Or show only if explicitly linked?
        // - If subject HAS grade, show only if matches class grade.
        // - Also check 'subject_schools' might have 'grade' if copied? No, strictly master.

        if (subjectGrade != null &&
            subjectGrade.isNotEmpty &&
            classGrade != null) {
          // Simple string match for now. Might need "X" vs "10" mapping later.
          return subjectGrade == classGrade;
        }

        // If no grade restrictions, allow it.
        return true;
      }).toList();

      setState(() {
        _subjectList = filteredSubjects;
        // _subjectList = allSubjects; // Fallback if filtering is too strict
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading subjects: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  // Helper to handle back button
  Future<bool> _handleWillPop() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep == 1) {
          _selectedSubjectId = null;
          _selectedSubjectName = null;
        } else if (_currentStep == 0) {
          _selectedClassId = null;
          _selectedClassName = null;
        }
      });
      return false; // Don't pop route
    }
    return true; // Pop route
  }

  void _showActivityTypeDialog() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),

            // Title
            Text(
              languageProvider.getTranslatedText({
                'en': 'Select Activity Type',
                'id': 'Pilih Jenis Kegiatan',
              }),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Choose what you want to create',
                'id': 'Pilih apa yang ingin Anda buat',
              }),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),

            // Tugas Option
            _buildActivityTypeOption(
              icon: Icons.assignment,
              title: languageProvider.getTranslatedText({
                'en': 'Assignment',
                'id': 'Tugas',
              }),
              description: languageProvider.getTranslatedText({
                'en': 'Create an assignment for students',
                'id': 'Buat tugas untuk siswa',
              }),
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showAddActivityDialog('tugas');
              },
            ),
            SizedBox(height: 12),

            // Materi Option
            _buildActivityTypeOption(
              icon: Icons.book,
              title: languageProvider.getTranslatedText({
                'en': 'Material',
                'id': 'Materi',
              }),
              description: languageProvider.getTranslatedText({
                'en': 'Share learning materials',
                'id': 'Bagikan materi pembelajaran',
              }),
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showAddActivityDialog('materi');
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTypeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(String activityType) {
    showDialog(
      context: context,
      builder: (context) => AddActivityDialog(
        teacherId: _teacherId,
        teacherName: _teacherName,
        scheduleList: _scheduleList,
        subjectList: _subjectList,
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterMaterials,
        onActivityAdded: _loadActivities,
        initialTarget: _currentTarget,
        activityType: activityType,
        initialDate: widget.initialDate,
        initialSubjectId: widget.initialSubjectId,
        initialClassId: widget.initialClassId,
        initialBabId: widget.initialBabId,
        initialSubBabId: widget.initialSubBabId,
        initialAdditionalMaterials: widget.initialAdditionalMaterials,
        materialsToMarkAsGenerated: widget.materialsToMarkAsGenerated,
      ),
    );
  }

  void _showEditActivityDialog(dynamic activity) {
    showDialog(
      context: context,
      builder: (context) => AddActivityDialog(
        teacherId: _teacherId,
        teacherName: _teacherName,
        scheduleList: _scheduleList,
        subjectList: _subjectList,
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterMaterials,
        onActivityAdded: _loadActivities,
        initialTarget: activity['target_role'] ?? 'umum',
        activityType: activity['jenis'] ?? 'tugas',
        isEditMode: true,
        activityData: activity,
        initialDate: activity['date'] != null
            ? DateTime.tryParse(activity['date'].toString())
            : null,
        initialSubjectId: activity['subject_id']?.toString(),
        initialClassId: activity['class_id']?.toString(),
        initialBabId: activity['chapter_id']?.toString(),
        initialSubBabId: activity['sub_chapter_id']?.toString(),
        initialAdditionalMaterials: activity['additional_material'] is List
            ? (activity['additional_material'] as List)
                  .map((e) => e as Map<String, dynamic>)
                  .toList()
            : [],
      ),
    );
  }

  Future<void> _deleteActivity(
    dynamic activity,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Activity',
            'id': 'Hapus Kegiatan',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete "${activity['title']}"? This action cannot be undone.',
            'id':
                'Apakah Anda yakin ingin menghapus "${activity['title']}"? Tindakan ini tidak dapat dibatalkan.',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClassActivityService.deleteKegiatan(activity['id'].toString());

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Activity deleted successfully',
                'id': 'Kegiatan berhasil dihapus',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh list
        _loadActivities();

        // Auto-uncheck material logic
        // 1. Uncheck primary material
        final List<Map<String, dynamic>> progressItems = [];

        // Helper function to check if a specific material is used by other activities
        Future<bool> isMaterialUsed(
          String chapterId,
          String? subChapterId,
        ) async {
          try {
            final response =
                await ApiClassActivityService.getClassActivityPaginated(
                  page: 1,
                  limit: 1,
                  guruId: _teacherId,
                  mataPelajaranId:
                      activity['subject_id'] ?? activity['mata_pelajaran_id'],
                  chapterId: chapterId,
                  subChapterId: subChapterId,
                );
            final totalItems = response['pagination']?['total_items'] ?? 0;
            return totalItems > 0;
          } catch (e) {
            if (kDebugMode) print('Error checking material usage: $e');
            return true;
          }
        }

        if (activity['chapter_id'] != null) {
          try {
            // 1. Check Sub-Chapter ID (Specific)
            // If the deleted activity had a specific sub-chapter, we check if any others use it.
            if (activity['sub_chapter_id'] != null) {
              final inUse = await isMaterialUsed(
                activity['chapter_id'].toString(),
                activity['sub_chapter_id'].toString(),
              );
              if (!inUse) {
                progressItems.add({
                  'bab_id': activity['chapter_id'],
                  'sub_bab_id': activity['sub_chapter_id'],
                  'is_checked': false,
                });
              }
            }
            // 2. Check Whole Chapter (Implicitly all sub-chapters)
            // If the deleted activity covered the whole chapter (sub_chapter_id == null),
            // we need to check EACH sub-chapter in that chapter.
            else {
              // Get all sub-chapters for this chapter
              final subChapters = await ApiSubjectService.getSubBabMateri(
                babId: activity['chapter_id'].toString(),
              );

              for (var sub in subChapters) {
                final subId = sub['id'].toString();

                // Check if this specific sub-chapter is used by any activity
                final isSpecificUsed = await isMaterialUsed(
                  activity['chapter_id'].toString(),
                  subId,
                );

                // Check if there is any activity covering the WHOLE chapter (implicitly covering this sub too)
                // We pass 'null' string to trigger IS NULL check in backend
                final isGenericUsed = await isMaterialUsed(
                  activity['chapter_id'].toString(),
                  'null',
                );

                if (!isSpecificUsed && !isGenericUsed) {
                  progressItems.add({
                    'bab_id': activity['chapter_id'],
                    'sub_bab_id': subId,
                    'is_checked': false,
                  });
                }
              }
            }

            if (kDebugMode) {
              print(
                'Activities check complete. Unchecking ${progressItems.length} items.',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching sub-chapters for uncheck: $e');
            }
          }
        }

        // 2. Uncheck additional materials
        if (activity['additional_material'] != null) {
          try {
            List<dynamic> additionalMaterials = [];
            if (activity['additional_material'] is String) {
              additionalMaterials = json.decode(
                activity['additional_material'],
              );
            } else if (activity['additional_material'] is List) {
              additionalMaterials = activity['additional_material'];
            }

            for (var item in additionalMaterials) {
              if (item['chapter_id'] != null &&
                  item['sub_chapter_id'] != null) {
                final subId = item['sub_chapter_id'].toString();
                final chapId = item['chapter_id'].toString();

                final isSpecificUsed = await isMaterialUsed(chapId, subId);
                // We don't necessarily check generic (whole chapter) usage for specific additional items?
                // Or we should?
                // If Activity B covers Whole Chapter, then Sub 1 (additional in Activity A) IS covered.
                // So we must check generic too.
                final isGenericUsed = await isMaterialUsed(chapId, 'null');

                if (!isSpecificUsed && !isGenericUsed) {
                  progressItems.add({
                    'bab_id': chapId,
                    'sub_bab_id': subId,
                    'is_checked': false,
                  });
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing additional materials: $e');
            }
          }
        }

        if (progressItems.isNotEmpty) {
          try {
            await ApiSubjectService.batchSaveMateriProgress({
              'guru_id': _teacherId,
              'mata_pelajaran_id':
                  activity['subject_id'] ?? activity['mata_pelajaran_id'],
              'progress_items': progressItems,
            });
            if (kDebugMode) {
              print('Auto-unchecked ${progressItems.length} materials.');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error auto-unchecking materials: $e');
            }
          }
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Failed to delete activity: $e',
                'id': 'Gagal menghapus kegiatan: $e',
              }),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed _getFilteredActivities - now using backend filtering

  // ========== TAB SWITCHER MENGGUNAKAN KOMPONEN ==========
  Widget _buildTabSwitcher(LanguageProvider languageProvider) {
    final tabs = [
      TabItem(
        label: languageProvider.getTranslatedText({
          'en': 'All Students',
          'id': 'Semua Siswa',
        }),
        icon: Icons.group,
      ),
      TabItem(
        label: languageProvider.getTranslatedText({
          'en': 'Specific Student',
          'id': 'Khusus Siswa',
        }),
        icon: Icons.person,
      ),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: TabSwitcher(
        tabController: _tabController,
        tabs: tabs,
        primaryColor: _getPrimaryColor(),
      ),
    );
  }

  // ========== SEARCH AND FILTER MENGGUNAKAN KOMPONEN ==========
  Widget _buildSearchAndFilter(LanguageProvider languageProvider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: languageProvider.getTranslatedText({
                          'en': 'Search activities...',
                          'id': 'Cari kegiatan...',
                        }),
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) {
                        _resetAndLoadActivities();
                      },
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.search, color: _getPrimaryColor()),
                      onPressed: () {
                        _resetAndLoadActivities();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _hasActiveFilter ? _getPrimaryColor() : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasActiveFilter
                    ? _getPrimaryColor()
                    : Colors.grey.shade300,
              ),
            ),
            child: IconButton(
              onPressed: _showFilterSheet,
              icon: Icon(
                Icons.tune,
                color: _hasActiveFilter ? Colors.white : Colors.grey.shade700,
              ),
              tooltip: languageProvider.getTranslatedText({
                'en': 'Filter',
                'id': 'Filter',
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ========== FILTER SHEET MENGGUNAKAN KOMPONEN ==========
  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    final filterConfig = FilterConfig(
      sections: [
        FilterSection(
          key: 'date',
          title: languageProvider.getTranslatedText({
            'en': 'Date Range',
            'id': 'Rentang Tanggal',
          }),
          options: [
            FilterOption(
              label: languageProvider.getTranslatedText({
                'en': 'Today',
                'id': 'Hari Ini',
              }),
              value: 'today',
            ),
            FilterOption(
              label: languageProvider.getTranslatedText({
                'en': 'This Week',
                'id': 'Minggu Ini',
              }),
              value: 'week',
            ),
            FilterOption(
              label: languageProvider.getTranslatedText({
                'en': 'This Month',
                'id': 'Bulan Ini',
              }),
              value: 'month',
            ),
          ],
        ),
      ],
    );

    final initialFilters = <String, dynamic>{'date': _selectedDateFilter};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        config: filterConfig,
        initialFilters: initialFilters,
        onApplyFilters: (Map<String, dynamic> filters) {
          setState(() {
            _selectedDateFilter = filters['date'];
            _hasActiveFilter = _selectedDateFilter != null;
          });
          _resetAndLoadActivities();
        },
      ),
    );
  }

  // ========== FILTER CHIPS ==========
  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedDateFilter != null) {
      final label = _selectedDateFilter == 'today'
          ? languageProvider.getTranslatedText({
              'en': 'Today',
              'id': 'Hari Ini',
            })
          : _selectedDateFilter == 'week'
          ? languageProvider.getTranslatedText({
              'en': 'This Week',
              'id': 'Minggu Ini',
            })
          : languageProvider.getTranslatedText({
              'en': 'This Month',
              'id': 'Bulan Ini',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDateFilter = null;
            _hasActiveFilter = false;
          });
          _resetAndLoadActivities();
        },
      });
    }

    return filterChips;
  }

  Widget _buildActivityList() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading && _activityList.isEmpty) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading activities...',
              'id': 'Memuat kegiatan...',
            }),
          );
        }

        return Column(
          children: [
            // Header removed

            // Search dan Filter Bar
            _buildSearchAndFilter(languageProvider),

            // Filter Chips
            if (_hasActiveFilter) ...[
              SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  children: _buildFilterChips(languageProvider).map((filter) {
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
                        backgroundColor: _getPrimaryColor().withOpacity(0.7),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        labelPadding: EdgeInsets.only(left: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 8),
            ],

            Expanded(
              child: _activityList.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No Activities',
                        'id': 'Belum ada kegiatan',
                      }),
                      subtitle:
                          _searchController.text.isEmpty && !_hasActiveFilter
                          ? languageProvider.getTranslatedText({
                              'en': 'No activities found for this subject.',
                              'id':
                                  'Tidak ada kegiatan untuk mata pelajaran ini.',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'No search results found',
                              'id': 'Tidak ditemukan hasil pencarian',
                            }),
                      icon: Icons.event_note,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount:
                          _activityList.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _activityList.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: _getPrimaryColor(),
                              ),
                            ),
                          );
                        }
                        final activity = _activityList[index];
                        return _buildActivityCard(activity, context);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ========== CARD SEPERTI PENGUMUMAN ==========
  Widget _buildActivityCard(dynamic activity, BuildContext context) {
    final day = activity['day']?.toString() ?? 'Unknown';
    final cardColor = _getDayColor(day);
    final isAssignment =
        activity['jenis'] == 'tugas' ||
        activity['jenis'] == 'assignment' ||
        activity['type'] == 'assignment';
    final isSpecificTarget = activity['target_role'] == 'khusus';
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    return GestureDetector(
      onTap: () {
        _showActivityDetail(activity);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
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
                  // Strip berwarna di pinggir kiri
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // Activity type badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAssignment ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAssignment
                            ? languageProvider.getTranslatedText({
                                'en': 'ASSIGNMENT',
                                'id': 'TUGAS',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'MATERIAL',
                                'id': 'MATERI',
                              }),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan judul kegiatan
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity['title'] ?? 'Judul Kegiatan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${activity['subject_name'] ?? _selectedSubjectName ?? ''} • ${activity['class_name'] ?? _selectedClassName ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Tanggal dan Hari
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: cardColor,
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
                                      'en': 'Schedule',
                                      'id': 'Jadwal',
                                    }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    '${activity['day']} • ${_formatDate(activity['date'])}',
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

                        // Deskripsi
                        if (activity['deskripsi'] != null &&
                            activity['deskripsi'].isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: cardColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.description,
                                      color: cardColor,
                                      size: 16,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Description',
                                            'id': 'Deskripsi',
                                          }),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          activity['deskripsi'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                            ],
                          ),

                        // Materi/Bab
                        if (activity['bab_judul'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: cardColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.menu_book,
                                      color: cardColor,
                                      size: 16,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Learning Material',
                                            'id': 'Materi Pembelajaran',
                                          }),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          '${activity['bab_judul']}${activity['sub_bab_judul'] != null ? ' • ${activity['sub_bab_judul']}' : ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // Display Additional Materials if any
                                        if (activity['additional_material'] !=
                                                null &&
                                            activity['additional_material']
                                                is List &&
                                            (activity['additional_material']
                                                    as List)
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children:
                                                  (activity['additional_material']
                                                          as List)
                                                      .map<Widget>((item) {
                                                        final title =
                                                            item['sub_chapter_title'] ??
                                                            'Materi Tambahan';
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 2.0,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .add_circle_outline,
                                                                size: 12,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                              SizedBox(
                                                                width: 4,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  title,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade700,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      })
                                                      .toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                        SizedBox(height: 12),

                        // Target dan Deadline
                        Row(
                          children: [
                            // Target
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSpecificTarget
                                    ? Colors.purple.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSpecificTarget
                                      ? Colors.purple
                                      : Colors.green,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSpecificTarget
                                        ? Icons.person
                                        : Icons.group,
                                    size: 12,
                                    color: isSpecificTarget
                                        ? Colors.purple
                                        : Colors.green,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isSpecificTarget
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Specific Student',
                                            'id': 'Khusus Siswa',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'All Students',
                                            'id': 'Semua Siswa',
                                          }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSpecificTarget
                                          ? Colors.purple
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Spacer(),

                            // Deadline untuk tugas
                            if (isAssignment && activity['batas_waktu'] != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      _formatDate(activity['batas_waktu']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        // Action Buttons
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionButton(
                              icon: Icons.edit,
                              label: languageProvider.getTranslatedText({
                                'en': 'Edit',
                                'id': 'Edit',
                              }),
                              color: cardColor,
                              onPressed: () =>
                                  _showEditActivityDialog(activity),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete,
                              label: languageProvider.getTranslatedText({
                                'en': 'Delete',
                                'id': 'Hapus',
                              }),
                              color: Colors.red,
                              onPressed: () =>
                                  _deleteActivity(activity, languageProvider),
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
      ),
    );
  }

  void _showActivityDetail(dynamic activity) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                activity['title'] ?? '',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                activity['deskripsi'] ??
                    languageProvider.getTranslatedText({
                      'en': 'No description',
                      'id': 'Tidak ada deskripsi',
                    }),
              ),
              SizedBox(height: 16),
              if (activity['additional_material'] != null) ...[
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Materials:',
                    'id': 'Materi:',
                  }),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                // Rendering additional material list logic could go here
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            _buildHeader(languageProvider),
            Expanded(child: _buildBodyContent(languageProvider)),
          ],
        ),
        // TAB SWITCHER: Only show in Activity List (Step 2)
        // CHECK: Previous code had tab switcher inside body of step 2.
        // We can keep it there.

        // FAB: Only show in Step 2
        floatingActionButton: _currentStep == 2
            ? FloatingActionButton(
                onPressed: _showActivityTypeDialog,
                backgroundColor: _getPrimaryColor(),
                child: Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildBodyContent(LanguageProvider languageProvider) {
    switch (_currentStep) {
      case 0:
        return _buildClassList(languageProvider);
      case 1:
        return _buildSubjectList(languageProvider);
      case 2:
        // TabSwitcher is now in the Header
        return _buildActivityList();
      default:
        return Container();
    }
  }

  // ========== HELPER METHODS ==========
  Color _getDayColor(String day) {
    return _dayColorMap[day] ?? Colors.grey;
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.8)],
    );
  }

  // ========== HEADER BARU SEPERTI PRESENCE TEACHER ==========
  Widget _buildHeader(LanguageProvider languageProvider) {
    String title = languageProvider.getTranslatedText({
      'en': 'Class Activity',
      'id': 'Kegiatan Kelas',
    });

    String subtitle = '';
    if (_currentStep == 0) {
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select a class to manage activities',
        'id': 'Pilih kelas untuk mengelola kegiatan',
      });
    } else if (_currentStep == 1) {
      subtitle = _selectedClassName ?? '-';
    } else if (_currentStep == 2) {
      subtitle =
          '${_selectedClassName ?? '-'} • ${_selectedSubjectName ?? '-'}';
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
                  if (shouldPop && mounted) {
                    Navigator.pop(context);
                  }
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  // Implement actions if needed
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'help',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Help'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_currentStep == 2) ...[
            SizedBox(height: 16),
            _buildTabSwitcher(languageProvider),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime? dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      dateTime = DateTime.tryParse(date);
    }
    if (dateTime == null) return '-';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  // Method helpers for API to avoid errors if they were deleted
  Future<void> _loadMaterials(String subjectId) async {
    try {
      final materials = await ApiSubjectService.getMateri();
      setState(() {
        _chapterList = materials;
        _subChapterList = [];
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load materials: $e');
      }
    }
  }

  Future<void> _loadSubChapterMaterials(String chapterId) async {
    try {
      final subMaterials = await ApiSubjectService.getSubBabMateri(
        babId: chapterId,
      );
      setState(() {
        _subChapterList = subMaterials;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load sub chapter materials: $e');
      }
    }
  }

  Future<void> _loadActivities() async {
    if (_isLoadingMore) return;

    try {
      setState(() {
        if (_currentPage == 1) {
          _isLoading = true;
        }
      });

      final academicYearId = context
          .read<AcademicYearProvider>()
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiClassActivityService.getClassActivityPaginated(
        page: _currentPage,
        limit: _perPage,
        guruId: _teacherId,
        classId: _selectedClassId,
        mataPelajaranId: _selectedSubjectId,
        target: _currentTarget,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        tanggal: _selectedDateFilter,
        academicYearId: academicYearId,
      );

      // if (kDebugMode) {
      //   print(
      //     'Loaded activities page $_currentPage: ${response['data']?.length ?? 0} items',
      //   );
      // }

      setState(() {
        if (_currentPage == 1) {
          _activityList = response['data'] ?? [];
        } else {
          _activityList.addAll(response['data'] ?? []);
        }
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // Auto show activity dialog if specified
      if (widget.autoShowActivityDialog && _currentPage == 1) {
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            _showActivityTypeDialog();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasMoreData = false;
      });
      if (kDebugMode) {
        print('Error load activities: $e');
      }
    }
  }
}

class AddActivityDialog extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<dynamic> scheduleList;
  final List<dynamic> subjectList;
  final List<dynamic> chapterList;
  final List<dynamic> subChapterList;
  final Function(String) onSubjectSelected;
  final Function(String) onChapterSelected;
  final VoidCallback onActivityAdded;
  final String initialTarget;
  final String activityType;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialClassId;
  final String? initialBabId;
  final String? initialSubBabId;
  final bool isEditMode;
  final dynamic activityData;

  const AddActivityDialog({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.scheduleList,
    required this.subjectList,
    required this.chapterList,
    required this.subChapterList,
    required this.onSubjectSelected,
    required this.onChapterSelected,
    required this.onActivityAdded,
    required this.initialTarget,
    required this.activityType,
    this.initialDate,
    this.initialSubjectId,
    this.initialClassId,
    this.initialBabId,
    this.initialSubBabId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.isEditMode = false,
    this.activityData,
  });

  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final List<String> _selectedStudents = [];

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedChapterId;
  String? _selectedSubChapterId;
  DateTime? _selectedDate;
  DateTime? _deadline;
  String? _selectedDay;
  bool _isSubmitting = false;
  bool _isLoadingStudents = false;
  List<dynamic> _studentList = [];

  // Bab & Sub Bab Materi
  bool _isLoadingBab = false;
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  String? _selectedBabId;
  String? _selectedSubBabId; // Primary selection (kept for backward compat)
  final List<String> _selectedSubBabIds = []; // Multi-selection support
  bool _useMateriTitle = false; // Toggle: use bab/sub bab or manual input

  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  void initState() {
    super.initState();

    // Set initial values from widget parameters or use defaults
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedDay = _days[_selectedDate!.weekday - 1];
    _selectedSubjectId = widget.initialSubjectId;
    _selectedClassId = widget.initialClassId;
    _selectedBabId = widget.initialBabId;
    _selectedSubBabId = widget.initialSubBabId;

    // Initialize multi-select list
    if (_selectedSubBabId != null) {
      _selectedSubBabIds.add(_selectedSubBabId!);
    }
    if (widget.initialAdditionalMaterials != null) {
      for (var item in widget.initialAdditionalMaterials!) {
        final subId = item['sub_chapter_id']?.toString();
        if (subId != null && !_selectedSubBabIds.contains(subId)) {
          _selectedSubBabIds.add(subId);
        }
      }
    }

    // If in edit mode, populate form with existing data
    if (widget.isEditMode && widget.activityData != null) {
      _judulController.text = widget.activityData['judul']?.toString() ?? '';
      _deskripsiController.text =
          widget.activityData['deskripsi']?.toString() ?? '';

      // Parse deadline if exists
      if (widget.activityData['batas_waktu'] != null) {
        _deadline = DateTime.tryParse(
          widget.activityData['batas_waktu'].toString(),
        );
      }

      // Load selected students if target is khusus
      if (widget.initialTarget == 'khusus' &&
          widget.activityData['siswa_target'] != null) {
        final siswaTarget = widget.activityData['siswa_target'];
        if (siswaTarget is List) {
          _selectedStudents.addAll(siswaTarget.map((s) => s.toString()));
        }
      }
    }

    // If initial bab is provided, enable material title mode
    if (_selectedBabId != null || _selectedSubBabId != null) {
      _useMateriTitle = true;
    }

    // Debug logging
    // if (kDebugMode) {
    //   print('===== AddActivityDialog INIT =====');
    //   print('Subject list count: ${widget.subjectList.length}');
    //   print('Schedule list count: ${widget.scheduleList.length}');
    //   print('Activity type: ${widget.activityType}');
    //   print('Initial target: ${widget.initialTarget}');
    //   print('Initial subject ID: $_selectedSubjectId');
    //   print('Initial class ID: $_selectedClassId');
    //   print('Initial bab ID: $_selectedBabId');
    //   print('Initial sub bab ID: $_selectedSubBabId');
    //   print('Use materi title: $_useMateriTitle');
    //   print('Initial date: $_selectedDate');
    // }

    // If initial subject is provided, load its data
    if (_selectedSubjectId != null) {
      Future.delayed(Duration.zero, () {
        if (kDebugMode) {
          print('Loading initial data for subject: $_selectedSubjectId');
        }

        widget.onSubjectSelected(_selectedSubjectId!);
        // Load bab materi for the initial subject
        _loadBabMateri(_selectedSubjectId!).then((_) {
          // After bab list loaded, load sub bab if initial bab is provided
          if (_selectedBabId != null) {
            if (kDebugMode) {
              print('Loading sub bab for bab: $_selectedBabId');
            }
            _loadSubBabMateri(_selectedBabId!).then((_) {
              // After sub bab loaded, update title
              _updateTitleFromMateri();
            });
          } else {
            // Only bab selected, update title
            _updateTitleFromMateri();
          }
        });

        // If initial class is provided and target is 'khusus', load students
        if (_selectedClassId != null && widget.initialTarget == 'khusus') {
          if (kDebugMode) {
            print('Loading students for class: $_selectedClassId');
          }
          _loadStudents();
        }
      });
    } else {
      if (kDebugMode) {
        print('No initial subject ID - waiting for user selection');
      }
    }

    if (kDebugMode) {
      print('=====================================');
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;

    setState(() {
      _isLoadingStudents = true;
      _studentList = []; // Clear previous list
    });

    if (kDebugMode) {
      print('[_loadStudents] Starting load for class: $_selectedClassId');
    }

    try {
      final students = await ApiClassActivityService.getSiswaByKelas(
        _selectedClassId!,
      );

      if (!mounted) {
        if (kDebugMode) {
          print('[_loadStudents] Widget unmounted, skipping setState');
        }
        return;
      }

      // if (kDebugMode) {
      //   print('[_loadStudents] Loaded ${students.length} students');
      // }

      setState(() {
        _studentList = students;
        _isLoadingStudents = false;
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error loading students: $e');
        print(stackTrace);
      }
      if (mounted) {
        setState(() {
          _studentList = [];
          _isLoadingStudents = false;
        });
      }
    }
  }

  Future<void> _loadBabMateri(String subjectId) async {
    try {
      if (kDebugMode) {
        print('===== LOADING BAB MATERI =====');
        print('Subject ID: $subjectId');
      }

      setState(() {
        _isLoadingBab = true;
        _babMateriList = []; // Clear previous list while loading
      });

      // Find Master Subject ID from the selected School Subject ID
      final subject = widget.subjectList.firstWhere(
        (s) => s['id'] == subjectId,
        orElse: () => null,
      );
      final masterSubjectId = subject?['subject_id']?.toString();

      if (masterSubjectId == null) {
        if (kDebugMode) {
          print('Error: Master Subject ID not found for subject $subjectId');
        }
        return;
      }

      final babList = await ApiSubjectService.getBabMateri(
        subjectId: masterSubjectId,
      );

      if (kDebugMode) {
        print('API Response - Bab count: ${babList.length}');
        if (babList.isNotEmpty) {
          print('First item structure: ${babList[0]}');
          print('Available fields: ${babList[0].keys}');
          print('Judul Bab: ${babList[0]['judul_bab']}');
        }
      }

      setState(() {
        _babMateriList = babList;
        // Only reset if no initial values were provided
        if (widget.initialBabId == null) {
          _selectedBabId = null;
        }
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
        // Only clear sub bab list if no initial sub bab
        if (widget.initialSubBabId == null) {
          _subBabMateriList = [];
        }
        _isLoadingBab = false;
      });

      if (kDebugMode) {
        print(
          'State updated - _babMateriList.length: ${_babMateriList.length}',
        );
        print('Current _selectedBabId: $_selectedBabId');
        print('Current _selectedSubBabId: $_selectedSubBabId');
        print('=============================');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading bab materi: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      setState(() {
        _isLoadingBab = false;
      });
    }
  }

  Future<void> _loadSubBabMateri(String babId) async {
    try {
      if (kDebugMode) {
        print('===== LOADING SUB BAB MATERI =====');
        print('Bab ID: $babId');
      }

      final subBabList = await ApiSubjectService.getSubBabMateri(babId: babId);

      if (kDebugMode) {
        print('API Response - Sub Bab count: ${subBabList.length}');
        if (subBabList.isNotEmpty) {
          print('First item structure: ${subBabList[0]}');
          print('Available fields: ${subBabList[0].keys}');
          print('Judul Sub Bab: ${subBabList[0]['judul_sub_bab']}');
        }
      }

      setState(() {
        _subBabMateriList = subBabList;
        // Only reset if no initial value was provided
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
      });

      if (kDebugMode) {
        print(
          'State updated - _subBabMateriList.length: ${_subBabMateriList.length}',
        );
        print('Current _selectedSubBabId: $_selectedSubBabId');
        print('==================================');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading sub bab materi: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    }
  }

  String _getBabName(dynamic bab) {
    // Try multiple possible field names (backend returns 'chapter_title')
    return bab['chapter_title']?.toString() ??
        bab['judul_bab']?.toString() ??
        bab['nama']?.toString() ??
        bab['judul']?.toString() ??
        bab['title']?.toString() ??
        bab['name']?.toString() ??
        'Unknown';
  }

  String _getSubBabName(dynamic subBab) {
    // Try multiple possible field names (backend returns 'sub_chapter_title')
    return subBab['sub_chapter_title']?.toString() ??
        subBab['judul_sub_bab']?.toString() ??
        subBab['nama']?.toString() ??
        subBab['judul']?.toString() ??
        subBab['title']?.toString() ??
        subBab['name']?.toString() ??
        'Unknown';
  }

  void _updateTitleFromMateri() {
    String babName = '';
    String subBabName = '';

    // Get bab name if selected
    if (_selectedBabId != null && _babMateriList.isNotEmpty) {
      final bab = _babMateriList.firstWhere(
        (item) => item['id'].toString() == _selectedBabId,
        orElse: () => null,
      );
      if (bab != null) {
        babName = _getBabName(bab);
      }
    }

    // Get sub bab name if selected
    if (_selectedSubBabId != null && _subBabMateriList.isNotEmpty) {
      final subBab = _subBabMateriList.firstWhere(
        (item) => item['id'].toString() == _selectedSubBabId,
        orElse: () => null,
      );
      if (subBab != null) {
        subBabName = _getSubBabName(subBab);
      }
    }

    // Build title based on what's selected
    String title = '';
    if (babName.isNotEmpty && subBabName.isNotEmpty) {
      // Both selected: "Bab - Sub Bab"
      title = '$babName - $subBabName';
    } else if (babName.isNotEmpty) {
      // Only bab selected
      title = babName;
    } else if (subBabName.isNotEmpty) {
      // Only sub bab selected (edge case)
      title = subBabName;
    }

    if (title.isNotEmpty && title != 'Unknown') {
      _judulController.text = title;
    }
  }

  List<DropdownMenuItem<String>> _getUniqueClassItems() {
    final Map<String, Map<String, dynamic>> uniqueClasses = {};
    final now = DateTime.now();
    // Use _selectedDay if available, otherwise fallback to current day
    final String targetDay =
        _selectedDay ??
        [
          'Senin',
          'Selasa',
          'Rabu',
          'Kamis',
          'Jumat',
          'Sabtu',
          'Minggu',
        ][now.weekday - 1];

    // if (kDebugMode) {
    //   print('Getting unique classes for subject: $_selectedSubjectId');
    //   print(
    //     'Current day: $currentDay, Current time: ${now.hour}:${now.minute}',
    //   );
    //   print('Target: ${widget.initialTarget}');
    //   print('Initial class ID from widget: ${widget.initialClassId}');
    // }

    // Filter schedules by selected subject and deduplicate by class_id
    for (var schedule in widget.scheduleList) {
      final scheduleSubjectId =
          (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();

      if (scheduleSubjectId == _selectedSubjectId) {
        final classId = (schedule['class_id'] ?? schedule['kelas_id'])
            .toString();

        // Untuk target KHUSUS: tidak ada filter waktu, semua jadwal bisa dipilih
        if (widget.initialTarget == 'khusus') {
          if (!uniqueClasses.containsKey(classId)) {
            uniqueClasses[classId] = {
              'id': classId,
              'nama': schedule['kelas_nama'] ?? 'Unknown',
            };
          }
        }
        // Untuk target UMUM
        else {
          // Jika ada initialClassId (dari teaching schedule), selalu include kelas tersebut
          if (widget.initialClassId != null &&
              classId == widget.initialClassId) {
            if (!uniqueClasses.containsKey(classId)) {
              uniqueClasses[classId] = {
                'id': classId,
                'nama': schedule['kelas_nama'] ?? 'Unknown',
              };
              if (kDebugMode) {
                print(
                  'Added class from initialClassId: ${schedule['kelas_nama']}',
                );
              }
            }
          }
          // Filter berdasarkan waktu untuk kelas lainnya
          else {
            var scheduleDay =
                schedule['hari_nama']?.toString() ??
                schedule['day_name']?.toString() ??
                '';

            // Map English days to Indonesian if needed
            final dayMap = {
              'Monday': 'Senin',
              'Tuesday': 'Selasa',
              'Wednesday': 'Rabu',
              'Thursday': 'Kamis',
              'Friday': 'Jumat',
              'Saturday': 'Sabtu',
              'Sunday': 'Minggu',
            };

            if (dayMap.containsKey(scheduleDay)) {
              scheduleDay = dayMap[scheduleDay]!;
            }

            // if (kDebugMode) {
            //   print(
            //     'Schedule: ${schedule['kelas_nama']}, Day: $scheduleDay, Start: $jamMulai',
            //   );
            //   print('Checking against Current Day: $currentDay');
            // }

            // Check if schedule is on the selected day
            if (scheduleDay == targetDay) {
              // Time validation removed to ensure classes always appear for the day
              // Original logic checked start_time + 23h, but this was too strict/buggy
              if (!uniqueClasses.containsKey(classId)) {
                uniqueClasses[classId] = {
                  'id': classId,
                  'nama': schedule['kelas_nama'] ?? 'Unknown',
                };
              }
            }
          }
        }
      }
    }

    // if (kDebugMode) {
    //   print('Unique classes found: ${uniqueClasses.length}');
    // }

    // Convert to dropdown items safely
    try {
      return uniqueClasses.values.map((classItem) {
        return DropdownMenuItem<String>(
          value: classItem['id'].toString(),
          child: Text(classItem['nama'] ?? 'Unknown'),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error generating class dropdown items: $e');
      return [];
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null || _selectedClassId == null) {
      _showError('Pilih mata pelajaran dan kelas terlebih dahulu');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );

      final Map<String, dynamic> data = {
        'teacher_id': widget.teacherId,
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'title': _judulController.text,
        'deskripsi': _deskripsiController.text,
        'jenis': widget.activityType,
        'target': widget.initialTarget,
        'date': _selectedDate!.toIso8601String().split('T')[0],
        'day': _selectedDay,
      };

      // Save chapter_id and sub_chapter_id if selected from materi
      if (_useMateriTitle && _selectedBabId != null) {
        data['chapter_id'] = _selectedBabId;
      } else if (_selectedChapterId != null) {
        // Fallback to old chapter props if exists
        data['chapter_id'] = _selectedChapterId;
      }

      if (_useMateriTitle && _selectedSubBabId != null) {
        data['sub_chapter_id'] = _selectedSubBabId;
      } else if (_selectedSubChapterId != null) {
        // Fallback to old sub chapter props if exists
        data['sub_chapter_id'] = _selectedSubChapterId;
      }

      // Handle Additional Material (from LIVE selection)
      if (_selectedSubBabIds.isNotEmpty) {
        final List<Map<String, dynamic>> extraMaterials = [];
        final primarySubId = data['sub_chapter_id']?.toString();

        for (var subId in _selectedSubBabIds) {
          // Skip if this is the primary sub chapter
          if (subId == primarySubId) continue;

          // Try to find full details for this sub chapter
          // 1. Check in loaded sub bab list
          var subBabData = _subBabMateriList.firstWhere(
            (s) => s['id'].toString() == subId,
            orElse: () => null,
          );

          String? chapterIdForSub = _selectedBabId;

          // 2. If not found (maybe from initial params but not loaded in current list?), check initialAdditionalMaterials
          if (subBabData == null && widget.initialAdditionalMaterials != null) {
            final found = widget.initialAdditionalMaterials!.firstWhere(
              (m) => m['sub_chapter_id'].toString() == subId,
              orElse: () => {},
            );
            if (found.isNotEmpty) {
              // Construct a temporary object if found in initial params
              subBabData = {
                'id': subId,
                // We might not have titles here if not standard format, but we do our best
              };
              chapterIdForSub =
                  found['chapter_id']?.toString() ?? _selectedBabId;
            }
          }

          if (subBabData != null || chapterIdForSub != null) {
            extraMaterials.add({
              'chapter_id':
                  chapterIdForSub, // Fallback to currently selected bab
              'sub_chapter_id': subId,
            });
          } else {
            // Fallback minimal
            extraMaterials.add({'sub_chapter_id': subId});
          }
        }

        if (extraMaterials.isNotEmpty) {
          data['additional_material'] = extraMaterials;
        }
      }

      if (_deadline != null && widget.activityType == 'tugas') {
        data['batas_waktu'] = _deadline!.toIso8601String();
      }

      // Tambahkan siswa target untuk kegiatan khusus
      final Map<String, dynamic> requestData = Map<String, dynamic>.from(data);
      if (widget.initialTarget == 'khusus' && _selectedStudents.isNotEmpty) {
        requestData['siswa_target'] = _selectedStudents;
      }

      // Call appropriate API based on mode
      if (widget.isEditMode && widget.activityData != null) {
        // Update existing activity
        await ApiClassActivityService.updateKegiatan(
          widget.activityData['id'].toString(),
          requestData,
        );
      } else {
        // Create new activity
        await ApiClassActivityService.tambahKegiatan(requestData);
      }

      // Automatically mark material as generated (checked)
      if (data['chapter_id'] != null) {
        try {
          // Construct items list for batchSaveMateriProgress
          // Auto-mark as checked (is_checked: true)
          // Note: batchSaveMateriProgress expects different key structure ('progress_items')
          // but ApiSubjectService.batchSaveMateriProgress helper handles the mapping from our app structure
          // We just need to match what the internal helper expects or call the API endpoint params directly?
          // Let's check ApiSubjectService.batchSaveMateriProgress implementation again.
          // It takes {guru_id, mata_pelajaran_id, progress_items: [{bab_id, sub_bab_id, is_checked}]}

          final List<Map<String, dynamic>> progressItems = [
            {
              'bab_id': data['chapter_id'],
              'sub_bab_id': data['sub_chapter_id'],
              'is_checked': true,
              'is_generated': true,
            },
          ];

          // Add explicitly passed materials to mark as generated
          if (widget.materialsToMarkAsGenerated != null) {
            for (var item in widget.materialsToMarkAsGenerated!) {
              progressItems.add({
                'bab_id': item['bab_id'],
                'sub_bab_id': item['sub_bab_id'],
                'is_checked': true,
                'is_generated': true,
              });
            }
          }

          // Also Add manually selected IDs from the multi-select dialog
          if (_useMateriTitle &&
              _selectedSubBabIds.isNotEmpty &&
              _selectedBabId != null) {
            for (var subId in _selectedSubBabIds) {
              // Avoid duplicates
              bool exists = progressItems.any(
                (p) => p['sub_bab_id'].toString() == subId,
              );
              if (!exists) {
                progressItems.add({
                  'bab_id': _selectedBabId,
                  'sub_bab_id': subId,
                  'is_checked': true,
                  'is_generated': true,
                });
              }
            }
          }

          if (kDebugMode) {
            print('=== BATCH SAVE PROGRESS ===');
            print('Progress items: ${progressItems.length}');
            print('First item: ${progressItems.first}');
          }

          await ApiSubjectService.batchSaveMateriProgress({
            'guru_id': widget.teacherId,
            'mata_pelajaran_id': _selectedSubjectId,
            'progress_items': progressItems,
          });
          if (kDebugMode) {
            print('Auto-marked material as generated: ${data['chapter_id']}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error auto-marking material: $e');
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onActivityAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? languageProvider.getTranslatedText({
                    'en': 'Activity updated successfully',
                    'id': 'Kegiatan berhasil diperbarui',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Activity added successfully',
                    'id': 'Kegiatan berhasil ditambahkan',
                  }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _openMultiSelectSubBabDialog(LanguageProvider languageProvider) {
    if (_subBabMateriList.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        // Local state for the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                languageProvider.getTranslatedText({
                  'en': 'Select Sub Chapters',
                  'id': 'Pilih Sub Bab',
                }),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _subBabMateriList.map((subBab) {
                    final subId = subBab['id'].toString();
                    final isSelected = _selectedSubBabIds.contains(subId);
                    return CheckboxListTile(
                      title: Text(_getSubBabName(subBab)),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            if (!_selectedSubBabIds.contains(subId)) {
                              _selectedSubBabIds.add(subId);
                            }
                          } else {
                            _selectedSubBabIds.remove(subId);
                          }
                          // Update primary selection for backward compatibility
                          _selectedSubBabId = _selectedSubBabIds.isNotEmpty
                              ? _selectedSubBabIds.first
                              : null;
                        });
                        // Trigger main widget rebuild to update UI text
                        setState(() {});
                        _updateTitleFromMateri();
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Done',
                      'id': 'Selesai',
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isAssignment = widget.activityType == 'tugas';
    final primaryColor = isAssignment ? Colors.orange : Colors.blue;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAssignment ? Icons.assignment : Icons.book,
              color: primaryColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEditMode
                  ? (isAssignment
                        ? languageProvider.getTranslatedText({
                            'en': 'Edit Assignment',
                            'id': 'Edit Tugas',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'Edit Material',
                            'id': 'Edit Materi',
                          }))
                  : (isAssignment
                        ? languageProvider.getTranslatedText({
                            'en': 'Add Assignment',
                            'id': 'Tambah Tugas',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'Add Material',
                            'id': 'Tambah Materi',
                          })),
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Box
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.initialTarget == 'khusus'
                          ? Icons.people
                          : Icons.schedule,
                      color: primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.initialTarget == 'khusus'
                            ? languageProvider.getTranslatedText({
                                'en':
                                    'SPECIFIC: You can select any class anytime.',
                                'id':
                                    'KHUSUS: Anda dapat memilih kelas kapan saja.',
                              })
                            : languageProvider.getTranslatedText({
                                'en':
                                    'GENERAL: Only classes from start time to +23 hours are available.',
                                'id':
                                    'UMUM: Hanya kelas dari jam mulai sampai +23 jam yang tersedia.',
                              }),
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mata Pelajaran
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText:
                      '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})} *',
                  prefixIcon: Icon(Icons.book),
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedSubjectId,
                isExpanded: true,
                items: widget.subjectList.isEmpty
                    ? null
                    : widget.subjectList.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject['id'].toString(),
                          child: Text(
                            subject['name'] ?? subject['nama'] ?? 'Unknown',
                          ),
                        );
                      }).toList(),
                onChanged: widget.subjectList.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedSubjectId = value;
                          _selectedClassId = null;
                        });
                        if (value != null) {
                          widget.onSubjectSelected(value);
                          _loadBabMateri(
                            value,
                          ); // Load bab materi for selected subject
                        }
                      },
                validator: (value) => value == null
                    ? languageProvider.getTranslatedText({
                        'en': 'Required',
                        'id': 'Wajib diisi',
                      })
                    : null,
                hint: Text(
                  widget.subjectList.isEmpty
                      ? languageProvider.getTranslatedText({
                          'en': 'No subjects available',
                          'id': 'Tidak ada mata pelajaran',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Select Subject',
                          'id': 'Pilih Mata Pelajaran',
                        }),
                ),
              ),
              if (widget.subjectList.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en':
                          'No teaching subjects found. Please check your schedule.',
                      'id':
                          'Tidak ada mata pelajaran mengajar. Silakan periksa jadwal Anda.',
                    }),
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              SizedBox(height: 12),

              // Kelas
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText:
                      '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})} *',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
                initialValue:
                    (_selectedClassId != null &&
                        _getUniqueClassItems().any(
                          (item) => item.value == _selectedClassId,
                        ))
                    ? _selectedClassId
                    : null,
                isExpanded: true,
                items: _selectedSubjectId == null
                    ? null
                    : _getUniqueClassItems(),
                onChanged: _selectedSubjectId == null
                    ? null
                    : (value) {
                        // if (kDebugMode) {
                        //   print(
                        //     'Class Dropdown onChanged: $value, target: ${widget.initialTarget}',
                        //   );
                        // }
                        setState(() {
                          _selectedClassId = value;
                        });

                        // Defer loading students to let the dropdown update complete
                        if (widget.initialTarget == 'khusus') {
                          Future.delayed(Duration(milliseconds: 100), () {
                            if (mounted) _loadStudents();
                          });
                        }
                      },
                validator: (value) => value == null
                    ? languageProvider.getTranslatedText({
                        'en': 'Required',
                        'id': 'Wajib diisi',
                      })
                    : null,
                hint: Text(
                  _selectedSubjectId == null
                      ? languageProvider.getTranslatedText({
                          'en': 'Select subject first',
                          'id': 'Pilih mata pelajaran dulu',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Select Class',
                          'id': 'Pilih Kelas',
                        }),
                ),
              ),
              if (_selectedSubjectId != null && _getUniqueClassItems().isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    widget.initialTarget == 'khusus'
                        ? languageProvider.getTranslatedText({
                            'en': 'No classes found for this subject.',
                            'id': 'Tidak ada kelas untuk mata pelajaran ini.',
                          })
                        : languageProvider.getTranslatedText({
                            'en':
                                'No active classes now. You can fill from class start time until +23 hours.',
                            'id':
                                'Tidak ada kelas aktif saat ini. Anda dapat mengisi dari jam pelajaran mulai sampai +23 jam.',
                          }),
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              SizedBox(height: 12),

              // Toggle: Pilih dari Materi atau Tulis Manual
              Row(
                children: [
                  Icon(Icons.title, size: 20, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Choose from material',
                      'id': 'Pilih dari materi',
                    }),
                    style: TextStyle(fontSize: 14),
                  ),
                  Spacer(),
                  Switch(
                    value: _useMateriTitle,
                    onChanged: _selectedSubjectId == null
                        ? null
                        : (value) {
                            setState(() {
                              _useMateriTitle = value;
                              if (!value) {
                                // Reset when switching to manual
                                _selectedBabId = null;
                                _selectedSubBabId = null;
                              }
                            });
                          },
                    activeThumbColor: primaryColor,
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Dropdown Bab Materi (if useMateriTitle = true)
              if (_useMateriTitle) ...[
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: languageProvider.getTranslatedText({
                      'en': 'Chapter',
                      'id': 'Bab Materi',
                    }),
                    prefixIcon: Icon(Icons.menu_book),
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _babMateriList.isEmpty
                      ? null
                      : (_babMateriList.any(
                              (bab) => bab['id'].toString() == _selectedBabId,
                            )
                            ? _selectedBabId
                            : null),
                  isExpanded: true,
                  items: _babMateriList.isEmpty
                      ? null
                      : _babMateriList.map((bab) {
                          return DropdownMenuItem<String>(
                            value: bab['id'].toString(),
                            child: Text(_getBabName(bab)),
                          );
                        }).toList(),
                  onChanged: _babMateriList.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedBabId = value;
                            _selectedSubBabId = null;
                          });
                          if (value != null) {
                            _loadSubBabMateri(value);
                            _updateTitleFromMateri();
                          }
                        },
                  hint: Text(
                    languageProvider.getTranslatedText({
                      'en': _isLoadingBab
                          ? 'Loading chapters...'
                          : (_babMateriList.isEmpty
                                ? 'No chapters found'
                                : 'Select Chapter'),
                      'id': _isLoadingBab
                          ? 'Memuat bab...'
                          : (_babMateriList.isEmpty
                                ? 'Tidak ada bab'
                                : 'Pilih Bab'),
                    }),
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Multi-Select Sub Bab (if bab is selected) - Custom UI
              if (_useMateriTitle && _selectedBabId != null) ...[
                InkWell(
                  onTap: () => _openMultiSelectSubBabDialog(languageProvider),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: languageProvider.getTranslatedText({
                        'en': 'Sub Chapters',
                        'id': 'Sub Bab Materi',
                      }),
                      prefixIcon: Icon(Icons.article),
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _selectedSubBabIds.isEmpty
                          ? languageProvider.getTranslatedText({
                              'en': 'Select Sub Chapters (optional)',
                              'id': 'Pilih Sub Bab (opsional)',
                            })
                          : _selectedSubBabIds.length == 1
                          ? _getSubBabName(
                              _subBabMateriList.firstWhere(
                                (s) =>
                                    s['id'].toString() ==
                                    _selectedSubBabIds.first,
                                orElse: () => {},
                              ),
                            )
                          : '${_selectedSubBabIds.length} ${languageProvider.getTranslatedText({'en': 'selected', 'id': 'dipilih'})}',
                      style: TextStyle(
                        color: _selectedSubBabIds.isEmpty
                            ? Colors.grey.shade600
                            : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Judul Field
              TextFormField(
                controller: _judulController,
                decoration: InputDecoration(
                  labelText:
                      '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                  helperText: _useMateriTitle
                      ? languageProvider.getTranslatedText({
                          'en': 'Auto-filled from chapter/sub-chapter',
                          'id': 'Otomatis dari bab/sub bab',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Enter title manually',
                          'id': 'Tulis judul manual',
                        }),
                ),
                readOnly:
                    _useMateriTitle &&
                    (_selectedBabId != null || _selectedSubBabId != null),
                validator: (value) => value == null || value.isEmpty
                    ? languageProvider.getTranslatedText({
                        'en': 'Required',
                        'id': 'Wajib diisi',
                      })
                    : null,
              ),
              SizedBox(height: 12),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                decoration: InputDecoration(
                  labelText: languageProvider.getTranslatedText({
                    'en': 'Description',
                    'id': 'Deskripsi',
                  }),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 12),

              // Tanggal
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today),
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Date',
                    'id': 'Tanggal',
                  }),
                ),
                subtitle: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Pilih tanggal',
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _selectedDay = _days[date.weekday - 1];
                    });
                  }
                },
              ),

              // Batas Waktu (hanya untuk Tugas)
              if (isAssignment) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.alarm),
                  title: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Deadline',
                      'id': 'Batas Waktu',
                    }),
                  ),
                  subtitle: Text(
                    _deadline != null
                        ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year} ${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                        : 'Pilih batas waktu (opsional)',
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _deadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],

              // Pilih Siswa (hanya untuk target khusus)
              if (widget.initialTarget == 'khusus' &&
                  _selectedClassId != null) ...[
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Select Students',
                              'id': 'Pilih Siswa',
                            }),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (kDebugMode)
                            Text(
                              'Debug: Target=${widget.initialTarget}, Count=${_studentList.length}, Loading=$_isLoadingStudents',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 20),
                      onPressed: _loadStudents,
                      tooltip: 'Refresh Students',
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  height: 200, // Increased height for better visibility
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoadingStudents
                      ? Center(child: CircularProgressIndicator())
                      : _studentList.isEmpty
                      ? Center(child: Text('Tidak ada siswa'))
                      : SingleChildScrollView(
                          child: Column(
                            children: _studentList.map((student) {
                              final studentId = student['id'].toString();
                              final isSelected = _selectedStudents.contains(
                                studentId,
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                dense: true,
                                title: Text(
                                  student['name']?.toString() ??
                                      student['nama']?.toString() ??
                                      'Unknown',
                                  style: TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  student['student_number']?.toString() ??
                                      student['nis']?.toString() ??
                                      '',
                                  style: TextStyle(fontSize: 11),
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (bool? checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedStudents.add(studentId);
                                      } else {
                                        _selectedStudents.remove(studentId);
                                      }
                                    });
                                  },
                                ),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedStudents.remove(studentId);
                                    } else {
                                      _selectedStudents.add(studentId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(
            languageProvider.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.isEditMode
                      ? languageProvider.getTranslatedText({
                          'en': 'Update',
                          'id': 'Simpan Perubahan',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Add',
                          'id': 'Tambah',
                        }),
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
