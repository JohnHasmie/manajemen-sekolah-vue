import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/admin/class_promotion_wizard.dart';
import 'package:manajemensekolah/screen/admin/student_management.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_class_service.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class AdminClassManagementScreen extends StatefulWidget {
  const AdminClassManagementScreen({super.key});

  @override
  AdminClassManagementScreenState createState() =>
      AdminClassManagementScreenState();
}

class AdminClassManagementScreenState extends State<AdminClassManagementScreen>
    with TickerProviderStateMixin {
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // FAB Animation
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;
  late Animation<double> _fabScaleAnimation;
  bool _isFabOpen = false;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States (Backend filtering)
  String? _selectedGradeFilter; // '1' to '12', or null for all
  String? _selectedHomeroomFilter; // 'true', 'false', or null
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  final List<String> _availableGradeLevels = [];
  String? _schoolJenjang; // SD, SMP, or SMA

  // Search debounce removed

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // FAB Init
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _fabRotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to search changes with debounce - Removed to match StudentManagement
    // _searchController.addListener(_onSearchChanged);

    // Listen to sync triggers from FCM
    FCMService().syncTrigger.addListener(_onSyncTriggered);

    _loadSchoolSettings(); // Load dynamic grade levels
    _fetchTeachers();
    _loadData();
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _animationController.dispose();
    _fabAnimationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    // _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_classes' ||
            trigger['type'] == 'refresh_teachers')) {
      if (kDebugMode) {
        print(
          '🔄 Real-time sync triggered (${trigger['type']}): Reloading classes',
        );
      }
      _loadData(resetPage: true, useCache: false);
    }
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // 200px before bottom
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadSchoolSettings() async {
    try {
      final settings = await ApiSettingsService.getSchoolSettings();
      if (!mounted) return;

      setState(() {
        _schoolJenjang = settings['jenjang'];
        _generateGradeLevels();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading school settings: $e');
      }
      // Fallback if failed
      setState(() {
        _generateGradeLevels();
      });
    }
  }

  void _generateGradeLevels() {
    _availableGradeLevels.clear();
    int start = 1;
    int end = 12;

    if (_schoolJenjang != null) {
      final jenjang = _schoolJenjang!.toUpperCase();
      if (jenjang == 'SD') {
        start = 1;
        end = 6;
      } else if (jenjang == 'SMP') {
        start = 7;
        end = 9;
      } else if (jenjang == 'SMA' || jenjang == 'SMK') {
        start = 10;
        end = 12;
      }
    }

    for (int i = start; i <= end; i++) {
      _availableGradeLevels.add(i.toString());
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      // Fetch all teachers (limit 1000) to ensure we have the homeroom teacher in the list
      final response = await ApiTeacherService.getTeachersPaginated(
        limit: 1000,
      );
      if (!mounted) return;

      setState(() {
        _teachers = response['data'] ?? [];
      });
      if (kDebugMode) {
        print('✅ Loaded ${_teachers.length} teachers for wali kelas selection');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading teachers: $e');
      }
      // Continue with empty list - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedGradeFilter != null || _selectedHomeroomFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedGradeFilter = null;
      _selectedHomeroomFilter = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedGradeFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})}: $_selectedGradeFilter',
        'onRemove': () {
          setState(() {
            _selectedGradeFilter = null;
          });
          _checkActiveFilter();
          _loadData(); // Reload data setelah remove filter
        },
      });
    }

    if (_selectedHomeroomFilter != null) {
      String label;
      if (_selectedHomeroomFilter == 'true') {
        label = languageProvider.getTranslatedText({
          'en': 'Has Homeroom Teacher',
          'id': 'Sudah Ada Wali Kelas',
        });
      } else {
        label = languageProvider.getTranslatedText({
          'en': 'No Homeroom Teacher',
          'id': 'Belum Ada Wali Kelas',
        });
      }

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedHomeroomFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedClass = _selectedGradeFilter;
    String? tempSelectedHomeroom = _selectedHomeroomFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Gradient header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorUtils.corporateBlue600,
                      ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.filter_list_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        languageProvider.getTranslatedText({'en': 'Filter Classes', 'id': 'Filter Kelas'}),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ]),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelectedClass = null;
                          tempSelectedHomeroom = null;
                        });
                      },
                      child: Text(
                        languageProvider.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grade filter section
                      Row(children: [
                        Icon(Icons.layers_outlined, size: 16, color: ColorUtils.slate600),
                        SizedBox(width: 8),
                        Text(
                          languageProvider.getTranslatedText({'en': 'Grade Level', 'id': 'Tingkat Kelas'}),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate800),
                        ),
                      ]),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableGradeLevels.map((gradeLevel) {
                          final isSelected = tempSelectedClass == gradeLevel;
                          return FilterChip(
                            label: Text(gradeLevel),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedClass = selected ? gradeLevel : null;
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
                            checkmarkColor: ColorUtils.corporateBlue600,
                            labelStyle: TextStyle(
                              color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 24),

                      // Homeroom teacher status section
                      Row(children: [
                        Icon(Icons.person_outline, size: 16, color: ColorUtils.slate600),
                        SizedBox(width: 8),
                        Text(
                          languageProvider.getTranslatedText({'en': 'Homeroom Teacher', 'id': 'Status Wali Kelas'}),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate800),
                        ),
                      ]),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          {'value': null, 'label': languageProvider.getTranslatedText({'en': 'All', 'id': 'Semua'})},
                          {'value': 'true', 'label': languageProvider.getTranslatedText({'en': 'Assigned', 'id': 'Sudah Ada'})},
                          {'value': 'false', 'label': languageProvider.getTranslatedText({'en': 'Unassigned', 'id': 'Belum Ada'})},
                        ].map((item) {
                          final isSelected = tempSelectedHomeroom == item['value'];
                          return FilterChip(
                            label: Text(item['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedHomeroom = item['value'];
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
                            checkmarkColor: ColorUtils.corporateBlue600,
                            labelStyle: TextStyle(
                              color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer buttons
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
                        style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedGradeFilter = tempSelectedClass;
                          _selectedHomeroomFilter = tempSelectedHomeroom;
                        });
                        _checkActiveFilter();
                        Navigator.pop(context);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.corporateBlue600,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({'en': 'Apply Filter', 'id': 'Terapkan Filter'}),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _currentPage = 1;
          _hasMoreData = true;
          _classes = []; // Reset list
        });
      }

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiClassService.getClassPaginated(
        page: _currentPage,
        limit: _perPage,
        gradeLevel: _selectedGradeFilter,
        hasHomeroomTeacher: _selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        useCache: useCache,
      );

      if (!mounted) return;

      setState(() {
        _classes = response['data'] ?? [];
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(e);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.read<LanguageProvider>().getTranslatedText({'en': 'Gagal memuat data kelas', 'id': 'Gagal memuat data kelas'})}: $_errorMessage',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiClassService.getClassPaginated(
        page: _currentPage,
        limit: _perPage,
        gradeLevel: _selectedGradeFilter,
        hasHomeroomTeacher: _selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _classes.addAll(response['data'] ?? []);
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      if (kDebugMode) {
        print(
          '✅ Loaded more data: Page $_currentPage, Total items: ${_classes.length}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      if (kDebugMode) {
        print('Error loading more data: $e');
      }
    }
  }

  // Export classes to Excel
  Future<void> _exportToExcel() async {
    await ExcelClassService.exportClassesToExcel(
      classes: _classes,
      context: context,
    );
  }

  // Import classes from Excel
  Future<void> _importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await ApiClassService.importClassesFromExcel(
          File(result.files.single.path!),
        );

        // Refresh data setelah import
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.getTranslatedText({'en': 'Gagal mengimpor file', 'id': 'Gagal mengimpor file'})}: ${ErrorUtils.getFriendlyMessage(e)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Download template
  Future<void> _downloadTemplate() async {
    await ExcelClassService.downloadTemplate(context);
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? classData}) async {
    // Refresh teacher list to avoid stale data (e.g. deleted teachers)
    await _fetchTeachers();

    // Fetch fresh data if editing to ensure we have all fields (especially IDs)
    if (classData != null) {
      try {
        // Show loading indicator if needed, or just await (fast usually)
        final freshData = await ApiClassService.getClassById(
          classData['id'].toString(),
        );
        if (freshData != null && freshData is Map<String, dynamic>) {
          classData = freshData;

          // Ensure the current homeroom teacher is in the _teachers list
          // This handles cases where the teacher might be missing from the paginated list
          // or soft-deleted but still assigned
          String? homeroomId = classData['homeroom_teacher_id']?.toString();
          String? homeroomName = classData['homeroom_teacher_name']?.toString();

          // Handle Pivot/List structure
          if (homeroomId == null &&
              classData['homeroom_teacher'] is List &&
              (classData['homeroom_teacher'] as List).isNotEmpty) {
            homeroomId = classData['homeroom_teacher'][0]['id']?.toString();
            homeroomName = classData['homeroom_teacher'][0]['name']?.toString();
          } else if (homeroomId == null &&
              classData['homeroom_teacher'] is Map) {
            homeroomId = classData['homeroom_teacher']['id']?.toString();
            homeroomName = classData['homeroom_teacher']['name']?.toString();
          }

          if (homeroomId != null && homeroomName != null) {
            final exists = _teachers.any(
              (t) => t['id'].toString() == homeroomId,
            );
            if (!exists) {
              setState(() {
                _teachers.add({'id': homeroomId, 'name': homeroomName});
                // Sort teachers by name for better UX
                _teachers.sort(
                  (a, b) =>
                      (a['name'] ?? '').toString().compareTo(b['name'] ?? ''),
                );
              });
            }
          }
        }
      } catch (e) {
        print('Error fetching fresh class data: $e');
        // Fallback to existing classData
      }
    }

    if (!mounted) return;

    final nameController = TextEditingController(
      text: classData?['name'] ?? classData?['nama'] ?? '',
    );

    final isEdit = classData != null;

    // Initialize state variables outside builder to preserve state across rebuilds
    String? selectedGradeLevel = classData != null
        ? classData['grade_level']?.toString()
        : null;
    String? selectedHomeroomTeacherId;
    if (classData != null) {
      // Try flat keys
      selectedHomeroomTeacherId =
          classData['homeroom_teacher_id']?.toString() ??
          classData['wali_kelas_id']?.toString();

      // Try nested objects if flat key failed
      if (selectedHomeroomTeacherId == null) {
        if (classData['homeroom_teacher'] is List &&
            (classData['homeroom_teacher'] as List).isNotEmpty) {
          selectedHomeroomTeacherId = classData['homeroom_teacher'][0]['id']
              ?.toString();
        } else if (classData['homeroom_teacher'] is Map) {
          selectedHomeroomTeacherId = classData['homeroom_teacher']['id']
              ?.toString();
        } else if (classData['wali_kelas'] is Map) {
          selectedHomeroomTeacherId = classData['wali_kelas']['id']?.toString();
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header gradient (Pattern #9)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ColorUtils.corporateBlue600,
                              ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Icon(
                                isEdit ? Icons.edit_rounded : Icons.add_rounded,
                                color: Colors.white, size: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit
                                        ? languageProvider.getTranslatedText({'en': 'Edit Class', 'id': 'Edit Kelas'})
                                        : languageProvider.getTranslatedText({'en': 'Add Class', 'id': 'Tambah Kelas'}),
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    isEdit
                                        ? languageProvider.getTranslatedText({'en': 'Update class information', 'id': 'Perbarui informasi kelas'})
                                        : languageProvider.getTranslatedText({'en': 'Fill in class information', 'id': 'Isi informasi kelas'}),
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            _buildDialogTextField(
                              controller: nameController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Class Name',
                                'id': 'Nama Kelas',
                              }),
                              icon: Icons.school,
                            ),
                            SizedBox(height: 12),
                            _buildGradeLevelDropdown(
                              value: selectedGradeLevel,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedGradeLevel = value;
                                });
                              },
                              languageProvider: languageProvider,
                            ),
                            SizedBox(height: 12),
                            _buildHomeroomTeacherDropdown(
                              value: selectedHomeroomTeacherId,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedHomeroomTeacherId = value;
                                });
                              },
                              languageProvider: languageProvider,
                            ),
                            ],
                          ),
                        ),
                      ),

                      // Footer buttons (Pattern #9)
                      Container(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: ColorUtils.slate100)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  side: BorderSide(color: ColorUtils.slate300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.cancel.tr,
                                  style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final nama = nameController.text.trim();

                                  if (nama.isEmpty ||
                                      selectedGradeLevel == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.getTranslatedText({
                                            'en':
                                                'Class name and grade level must be filled',
                                            'id':
                                                'Nama kelas dan grade level harus diisi',
                                          }),
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final academicYearProvider =
                                        Provider.of<AcademicYearProvider>(
                                          context,
                                          listen: false,
                                        );
                                    final selectedYearId = academicYearProvider
                                        .selectedAcademicYear?['id']
                                        ?.toString();

                                    if (isEdit) {
                                      await ApiClassService.updateClass(
                                        classData!['id'].toString(),
                                        {
                                          'name': nameController.text,
                                          'grade_level': selectedGradeLevel,
                                          'homeroom_teacher_id':
                                              selectedHomeroomTeacherId,
                                          'academic_year_id': selectedYearId,
                                        },
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Class successfully updated',
                                                'id':
                                                    'Kelas berhasil diperbarui',
                                              }),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    } else {
                                      await ApiClassService.addClass({
                                        'name': nameController.text,
                                        'grade_level': selectedGradeLevel,
                                        'homeroom_teacher_id':
                                            selectedHomeroomTeacherId,
                                        'academic_year_id': selectedYearId,
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Class successfully added',
                                                'id':
                                                    'Kelas berhasil ditambahkan',
                                              }),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    }
                                    _loadData();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            languageProvider.getTranslatedText({
                                              'en':
                                                  'Failed to save class: ${ErrorUtils.getFriendlyMessage(e)}',
                                              'id':
                                                  'Gagal menyimpan kelas: ${ErrorUtils.getFriendlyMessage(e)}',
                                            }),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorUtils.corporateBlue600,
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  elevation: 2,
                                  shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isEdit
                                      ? languageProvider.getTranslatedText({'en': 'Update', 'id': 'Perbarui'})
                                      : AppLocalizations.save.tr,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  Widget _buildGradeLevelDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({'en': 'Grade Level', 'id': 'Tingkat Kelas'}),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(Icons.layers_outlined, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: _availableGradeLevels.map((gradeStr) {
          final grade = int.tryParse(gradeStr) ?? 0;
          String gradeText;
          if (grade <= 6) {
            gradeText = 'Kelas $grade SD';
          } else if (grade <= 9) {
            gradeText = 'Kelas $grade SMP';
          } else {
            gradeText = 'Kelas $grade SMA';
          }
          return DropdownMenuItem<String>(value: gradeStr, child: Text(gradeText));
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: ColorUtils.slate500),
      ),
    );
  }

  Widget _buildHomeroomTeacherDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    // Deduplicate teachers based on ID
    final uniqueTeachers = <String, Map<String, dynamic>>{};
    for (var teacher in _teachers) {
      if (teacher['id'] != null) {
        uniqueTeachers[teacher['id'].toString()] = teacher;
      }
    }

    // Validate value - ensure it exists in the list
    String? validValue = value;
    if (validValue != null && !uniqueTeachers.containsKey(validValue)) {
      validValue = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({'en': 'Homeroom Teacher', 'id': 'Wali Kelas'}),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(Icons.person_outline, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(languageProvider.getTranslatedText({'en': 'No Homeroom Teacher', 'id': 'Tidak ada wali kelas'})),
          ),
          ...uniqueTeachers.values.map((teacher) {
            final teacherName = teacher['name'] ?? 'Unknown';
            final teacherNip = teacher['nip']?.toString() ?? '';
            final displayText = teacherNip.isNotEmpty ? '$teacherName (NIP: $teacherNip)' : teacherName;
            return DropdownMenuItem<String>(
              value: teacher['id'].toString(),
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: ColorUtils.slate500),
      ),
    );
  }

  Future<void> _deleteClass(Map<String, dynamic> classData) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete Class',
          'id': 'Hapus Kelas',
        }),
        content: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Are you sure you want to delete this class?',
          'id': 'Yakin ingin menghapus kelas ini?',
        }),
        confirmText: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClassService.deleteClass(classData['id'].toString());
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Class successfully deleted',
                  'id': 'Kelas berhasil dihapus',
                }),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.read<LanguageProvider>().getTranslatedText({'en': 'Gagal menghapus kelas', 'id': 'Gagal menghapus kelas'})}: ${ErrorUtils.getFriendlyMessage(e)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildClassCard(Map<String, dynamic> classData, int index) {
    final languageProvider = context.read<LanguageProvider>();
    final avatarColor = ColorUtils.getColorForIndex(index);
    final className = classData['name'] ?? 'Class';
    final gradeText = _getGradeLevelText(classData['grade_level'], languageProvider);
    final studentCount = classData['student_count'] ?? 0;
    final teacherName = (classData['homeroom_teacher'] is List &&
            (classData['homeroom_teacher'] as List).isNotEmpty)
        ? classData['homeroom_teacher'][0]['name']
        : (classData['homeroom_teacher'] is Map
            ? classData['homeroom_teacher']['name']
            : classData['homeroom_teacher_name'] ??
                  classData['wali_kelas_nama'] ??
                  languageProvider.getTranslatedText({
                    'en': 'Not Assigned',
                    'id': 'Belum Ditugaskan',
                  }));

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showClassDetail(classData),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200, width: 1),
                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
              ),
              child: Row(
                children: [
                  // Colored initial avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      className.isNotEmpty ? className[0].toUpperCase() : 'C',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: avatarColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Name + info tags
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          className,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildInfoTag(Icons.layers_outlined, gradeText),
                        SizedBox(height: 4),
                        _buildInfoTag(Icons.person_outline, teacherName),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Student count chip + action buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: ColorUtils.corporateBlue600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$studentCount ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                            style: TextStyle(
                              color: ColorUtils.corporateBlue600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      ),
                      Consumer<AcademicYearProvider>(
                        builder: (context, academicYearProvider, child) {
                          if (academicYearProvider.isReadOnly) return SizedBox.shrink();
                          return Column(children: [
                            SizedBox(height: 8),
                            Row(children: [
                              InkWell(
                                onTap: () => _showAddEditDialog(classData: classData),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.edit_outlined, size: 16, color: ColorUtils.corporateBlue600),
                                ),
                              ),
                              SizedBox(width: 6),
                              InkWell(
                                onTap: () => _deleteClass(classData),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.error600.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete_outline, size: 16, color: ColorUtils.error600),
                                ),
                              ),
                            ]),
                          ]);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: ColorUtils.slate600),
        SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: ColorUtils.slate700, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }

  void _showClassDetail(Map<String, dynamic> classData) {
    final languageProvider = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: colored avatar + grade badge + X close (Pattern #10)
              Builder(builder: (context) {
                final name = classData['name'] ?? 'C';
                final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
                final avatarColor = ColorUtils.getColorForIndex(nameHash);
                final gradeText = _getGradeLevelText(classData['grade_level'], languageProvider);
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ColorUtils.corporateBlue600, ColorUtils.corporateBlue600.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: avatarColor,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: Offset(0, 4))],
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            name,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.layers_outlined, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(gradeText, style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      icon: Icons.people,
                      label: languageProvider.getTranslatedText({
                        'en': 'Total Students',
                        'id': 'Jumlah Siswa',
                      }),
                      value:
                          '${classData['student_count'] ?? 0} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                    ),
                    _buildDetailItem(
                      icon: Icons.person,
                      label: languageProvider.getTranslatedText({
                        'en': 'Homeroom Teacher',
                        'id': 'Wali Kelas',
                      }),
                      value:
                          // Handle Pivot/List structure for display
                          (classData['homeroom_teacher'] is List &&
                              (classData['homeroom_teacher'] as List)
                                  .isNotEmpty)
                          ? classData['homeroom_teacher'][0]['name']
                          : (classData['homeroom_teacher'] is Map
                                ? classData['homeroom_teacher']['name']
                                : classData['homeroom_teacher_name'] ??
                                      classData['wali_kelas_nama'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'Not Assigned',
                                        'id': 'Belum Ditugaskan',
                                      })),
                    ),

                    SizedBox(height: 20),

                    // View Students Button (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to student management screen with class filter
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentManagementScreen(
                                initialClassId: classData['id'].toString(),
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.list, color: Colors.white),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'View Students',
                            'id': 'Lihat Daftar Siswa',
                          }),
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),
                    // Footer buttons (Pattern #10)
                    Container(
                      padding: EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: ColorUtils.slate100)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({'en': 'Close', 'id': 'Tutup'}),
                              style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ),
                        if (!Provider.of<AcademicYearProvider>(context, listen: false).isReadOnly) ...[
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddEditDialog(classData: classData);
                              },
                              icon: Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                              label: Text(
                                languageProvider.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorUtils.corporateBlue600,
                                padding: EdgeInsets.symmetric(vertical: 13),
                                elevation: 2,
                                shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ]),
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

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ColorUtils.corporateBlue600.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                SizedBox(height: 3),
                Text(value, style: TextStyle(fontSize: 14, color: ColorUtils.slate800, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    if (gradeLevel == null) return '-';

    final level = int.tryParse(gradeLevel.toString());
    if (level == null) return '-';

    if (level <= 6) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SD';
    } else if (level <= 9) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMP';
    } else {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMA';
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_errorMessage != null) {
          return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
        }

        // Backend handles all filtering, so we use _classes directly
        final filteredClasses = _classes;

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_getPrimaryColor(), _getPrimaryColor()],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
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
                                  'en': 'Class Management',
                                  'id': 'Manajemen Kelas',
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
                                  'en': 'Manage and monitor classes',
                                  'id': 'Kelola dan pantau kelas',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'export':
                                _exportToExcel();
                                break;
                              case 'import':
                                _importFromExcel();
                                break;
                              case 'template':
                                _downloadTemplate();
                                break;
                            }
                          },
                          icon: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.download, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Export to Excel',
                                      'id': 'Export ke Excel',
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'import',
                              child: Row(
                                children: [
                                  Icon(Icons.upload, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Import from Excel',
                                      'id': 'Import dari Excel',
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'template',
                              child: Row(
                                children: [
                                  Icon(Icons.file_download, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Download Template',
                                      'id': 'Download Template',
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar with Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    // onChanged: (value) => setState(() {}), // Disabling this to prevent excessive rebuilds
                                    style: TextStyle(color: Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: languageProvider
                                          .getTranslatedText({
                                            'en': 'Search classes...',
                                            'id': 'Cari kelas...',
                                          }),
                                      hintStyle: TextStyle(color: Colors.grey),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    onSubmitted: (_) {
                                      setState(() {
                                        _currentPage = 1;
                                      });
                                      _loadData();
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
                                      setState(() {
                                        _currentPage = 1;
                                      });
                                      _loadData();
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
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
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

                    // Show active filters as chips
                    if (_hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.filter_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
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
                                            color: _getPrimaryColor(),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: _getPrimaryColor(),
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: _getPrimaryColor()
                                            .withValues(alpha: 0.1),
                                        side: BorderSide(
                                          color: _getPrimaryColor().withValues(
                                            alpha: 0.3,
                                          ),
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
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.clear_all,
                                  size: 18,
                                  color: Colors.white,
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

              Expanded(
                child: _isLoading && _classes.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : filteredClasses.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No classes',
                          'id': 'Tidak ada kelas',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a class',
                                'id': 'Tap + untuk menambah kelas',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.school_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              filteredClasses.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredClasses.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final classItem = filteredClasses[index];
                            return _buildClassCard(classItem, index);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: Consumer<AcademicYearProvider>(
            builder: (context, academicYearProvider, child) {
              final languageProvider = context.read<LanguageProvider>();

              if (academicYearProvider.isReadOnly) return SizedBox.shrink();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isFabOpen) ...[
                    ScaleTransition(
                      scale: _fabScaleAnimation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Promote Class',
                                'id': 'Naik Kelas / Promosi',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 8),
                          FloatingActionButton(
                            heroTag: 'fab_promote_class',
                            mini: true,
                            backgroundColor: Colors.orange,
                            onPressed: () {
                              setState(() {
                                _isFabOpen = false;
                                _fabAnimationController.reverse();
                              });
                              _showPromotionWizard();
                            },
                            child: Icon(Icons.upgrade, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    ScaleTransition(
                      scale: _fabScaleAnimation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Create New Class',
                                'id': 'Buat Kelas Baru',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 8),
                          FloatingActionButton(
                            heroTag: 'fab_add_class',
                            mini: true,
                            backgroundColor: _getPrimaryColor(),
                            onPressed: () {
                              setState(() {
                                _isFabOpen = false;
                                _fabAnimationController.reverse();
                              });
                              _showAddEditDialog();
                            },
                            child: Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  FloatingActionButton(
                    heroTag: 'fab_main_class',
                    onPressed: () {
                      setState(() {
                        _isFabOpen = !_isFabOpen;
                        if (_isFabOpen) {
                          _fabAnimationController.forward();
                        } else {
                          _fabAnimationController.reverse();
                        }
                      });
                    },
                    backgroundColor: _getPrimaryColor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RotationTransition(
                      turns: _fabRotateAnimation,
                      child: Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showPromotionWizard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClassPromotionWizard()),
    );
  }
}
