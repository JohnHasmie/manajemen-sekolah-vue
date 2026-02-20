import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/enhanced_search_bar.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/excel_subject_service.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  SubjectManagementScreenState createState() => SubjectManagementScreenState();
}

class SubjectManagementScreenState extends State<SubjectManagementScreen> {
  List<dynamic> _subjectList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States (Backend filtering)
  String? _selectedStatusFilter; // 'active', 'inactive', atau null untuk semua

  String?
  _selectedKelasStatusFilter; // 'ada', 'tidak_ada', atau null untuk semua
  String? _selectedGradeLevelFilter; // '1' sampai '12', atau null untuk semua
  String?
  _selectedClassNameFilter; // Nama kelas spesifik (7A, 7B, dll), atau null untuk semua
  bool _hasActiveFilter = false;

  // Dynamic list untuk nama kelas yang tersedia
  List<String> _availableClassNames = [];
  List<String> _availableGradeLevels = [];

  List<dynamic> _availableMasterSubjects = [];

  // Filter Options (from backend)
  List<dynamic> _availableStatusOptions = [];

  // Search debounce
  Timer? _searchDebounce;

  // Animations

  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    _loadFilterOptions();
    _loadMasterSubjects();
    _loadSubjects();

    // Listen to background sync triggers (FCM)
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  void _onSyncTriggered() {
    if (FCMService().syncTrigger.value == 'refresh_subjects') {
      if (kDebugMode) {
        print('♻️ Refreshing subjects due to FCM sync trigger');
      }
      _loadSubjects(resetPage: true).then((_) {
        // Optional: show a small snackbar if item count changed
      });
    }
  }

  Future<void> _loadMasterSubjects() async {
    try {
      final data = await ApiSubjectService.getAllMasterSubjects();
      if (kDebugMode) {
        print('✅ Master Subjects Loaded: ${data.length} items');
        if (data.isNotEmpty) {
          print('First item: ${data[0]}');
        }
      }
      setState(() {
        _availableMasterSubjects = data;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading master subjects: $e');
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    _searchController.dispose();
    _searchDebounce?.cancel();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    super.dispose();
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreSubjects();
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final response = await ApiSubjectService.getSubjectFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableStatusOptions = response['data']['status_options'] ?? [];
        });
        if (kDebugMode) {
          print('✅ Filter options loaded');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading filter options: $e');
      }
      // Continue with empty options - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedStatusFilter != null ||
          _selectedKelasStatusFilter != null ||
          _selectedGradeLevelFilter != null ||
          _selectedClassNameFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedKelasStatusFilter = null;
      _selectedGradeLevelFilter = null;
      _selectedClassNameFilter = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadSubjects(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      final statusText = _selectedStatusFilter == 'active'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : _selectedStatusFilter == 'inactive'
          ? languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Tidak Aktif',
            })
          : languageProvider.getTranslatedText({'en': 'All', 'id': 'Semua'});
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    if (_selectedKelasStatusFilter != null) {
      final statusText = _selectedKelasStatusFilter == 'ada'
          ? languageProvider.getTranslatedText({
              'en': 'Has Classes',
              'id': 'Ada Kelas',
            })
          : languageProvider.getTranslatedText({
              'en': 'No Classes',
              'id': 'Tidak Ada Kelas',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Classes', 'id': 'Kelas'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedKelasStatusFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    if (_selectedGradeLevelFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat Kelas'})}: $_selectedGradeLevelFilter',
        'onRemove': () {
          setState(() {
            _selectedGradeLevelFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    if (_selectedClassNameFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Nama Kelas'})}: $_selectedClassNameFilter',
        'onRemove': () {
          setState(() {
            _selectedClassNameFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;
    String? tempSelectedClassStatus = _selectedKelasStatusFilter;
    String? tempSelectedGradeLevel = _selectedGradeLevelFilter;
    String? tempSelectedClassName = _selectedClassNameFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Gradient Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Filter Subjects',
                            'id': 'Filter Mata Pelajaran',
                          }),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempSelectedStatus = null;
                            tempSelectedClassStatus = null;
                            tempSelectedGradeLevel = null;
                            tempSelectedClassName = null;
                          });
                        },
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Reset',
                            'id': 'Reset',
                          }),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Filter Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Filter
                        _buildFilterSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Status',
                            'id': 'Status',
                          }),
                          Icons.circle_outlined,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                {
                                  'value': 'active',
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'Active',
                                    'id': 'Aktif',
                                  }),
                                },
                                {
                                  'value': 'inactive',
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'Inactive',
                                    'id': 'Tidak Aktif',
                                  }),
                                },
                                {
                                  'value': 'all',
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'All',
                                    'id': 'Semua',
                                  }),
                                },
                              ].map((item) {
                                final isSelected =
                                    tempSelectedStatus == item['value'];
                                return FilterChip(
                                  label: Text(item['label']!),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempSelectedStatus = selected
                                          ? item['value']
                                          : null;
                                    });
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: ColorUtils.corporateBlue600
                                      .withValues(alpha: 0.12),
                                  checkmarkColor: ColorUtils.corporateBlue600,
                                  side: BorderSide(
                                    color: isSelected
                                        ? ColorUtils.corporateBlue600
                                        : ColorUtils.slate300,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? ColorUtils.corporateBlue600
                                        : ColorUtils.slate700,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                );
                              }).toList(),
                        ),

                        // Status Kelas Filter
                        _buildFilterSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Classes Status',
                            'id': 'Status Kelas',
                          }),
                          Icons.class_outlined,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                {
                                  'value': 'ada',
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'Has Classes',
                                    'id': 'Ada Kelas',
                                  }),
                                },
                                {
                                  'value': 'tidak_ada',
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'No Classes',
                                    'id': 'Tidak Ada Kelas',
                                  }),
                                },
                              ].map((item) {
                                final isSelected =
                                    tempSelectedClassStatus == item['value'];
                                return FilterChip(
                                  label: Text(item['label']!),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempSelectedClassStatus = selected
                                          ? item['value']
                                          : null;
                                    });
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: ColorUtils.corporateBlue600
                                      .withValues(alpha: 0.12),
                                  checkmarkColor: ColorUtils.corporateBlue600,
                                  side: BorderSide(
                                    color: isSelected
                                        ? ColorUtils.corporateBlue600
                                        : ColorUtils.slate300,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? ColorUtils.corporateBlue600
                                        : ColorUtils.slate700,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                );
                              }).toList(),
                        ),

                        // Tingkat Kelas Filter
                        _buildFilterSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Grade Level',
                            'id': 'Tingkat Kelas',
                          }),
                          Icons.layers_outlined,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              (_availableGradeLevels.isEmpty
                                      ? List.generate(
                                          12,
                                          (i) => (i + 1).toString(),
                                        )
                                      : _availableGradeLevels)
                                  .map((gradeLevel) {
                                    final isSelected =
                                        tempSelectedGradeLevel == gradeLevel;
                                    return FilterChip(
                                      label: Text('Kelas $gradeLevel'),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          tempSelectedGradeLevel = selected
                                              ? gradeLevel
                                              : null;
                                        });
                                      },
                                      backgroundColor: Colors.white,
                                      selectedColor: ColorUtils.corporateBlue600
                                          .withValues(alpha: 0.12),
                                      checkmarkColor:
                                          ColorUtils.corporateBlue600,
                                      side: BorderSide(
                                        color: isSelected
                                            ? ColorUtils.corporateBlue600
                                            : ColorUtils.slate300,
                                        width: 1,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? ColorUtils.corporateBlue600
                                            : ColorUtils.slate700,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    );
                                  })
                                  .toList(),
                        ),

                        // Class Name Filter (Dynamic)
                        if (_availableClassNames.isNotEmpty) ...[
                          _buildFilterSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Class Name',
                              'id': 'Nama Kelas',
                            }),
                            Icons.school_outlined,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableClassNames.map((className) {
                              final isSelected =
                                  tempSelectedClassName == className;
                              return FilterChip(
                                label: Text(className),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedClassName = selected
                                        ? className
                                        : null;
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.12),
                                checkmarkColor: ColorUtils.corporateBlue600,
                                side: BorderSide(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 12),
                        ],
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Footer buttons
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate100)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
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
                            style: TextStyle(
                              color: ColorUtils.slate600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatusFilter = tempSelectedStatus;
                              _selectedKelasStatusFilter =
                                  tempSelectedClassStatus;
                              _selectedGradeLevelFilter =
                                  tempSelectedGradeLevel;
                              _selectedClassNameFilter = tempSelectedClassName;
                            });
                            _checkActiveFilter();
                            Navigator.pop(context);
                            _loadSubjects();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: ColorUtils.corporateBlue600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Apply Filter',
                              'id': 'Terapkan Filter',
                            }),
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
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

  Widget _buildFilterSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate600),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSubjects({bool resetPage = true}) async {
    try {
      if (resetPage) {
        setState(() {
          _isLoading = true;
          _currentPage = 1;
          _hasMoreData = true;
          _subjectList = []; // Reset list
          _errorMessage = '';
        });
      }

      // Load with pagination and backend filtering
      final response = await ApiSubjectService.getSubjectsPaginated(
        page: _currentPage,
        limit: _perPage,
        status: _selectedStatusFilter,
        gradeLevel: _selectedGradeLevelFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      final data = response['data'] ?? [];

      if (kDebugMode) {
        print('✅ Subjects received: ${data.length} items');
      }

      // Extract unique class names and grade levels from subjects
      Set<String> classNamesSet = {};
      Set<String> gradeLevelsSet = {};

      for (var subject in data) {
        // Support both naming conventions
        final kelasNames =
            (subject['class_names'] ?? subject['kelas_names'])?.toString() ??
            '';
        if (kelasNames.isNotEmpty) {
          final names = kelasNames
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          classNamesSet.addAll(names);
        }

        // Extract grade levels
        final gradeLevels =
            (subject['class_grade_levels'] ?? subject['kelas_grade_levels'])
                ?.toString() ??
            '';
        if (gradeLevels.isNotEmpty) {
          final levels = gradeLevels
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          gradeLevelsSet.addAll(levels);
        }
      }

      setState(() {
        _subjectList = data;
        _availableClassNames = classNamesSet.toList()..sort();
        _availableGradeLevels = gradeLevelsSet.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a) ?? 0;
            final bInt = int.tryParse(b) ?? 0;
            return aInt.compareTo(bInt);
          });
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (error) {
      if (kDebugMode) print('Load subjects error: $error');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(error);
      });
    }
  }

  Future<void> _loadMoreSubjects() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      final response = await ApiSubjectService.getSubjectsPaginated(
        page: _currentPage,
        limit: _perPage,
        status: _selectedStatusFilter,
        gradeLevel: _selectedGradeLevelFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      final data = response['data'] ?? [];

      // Extract class names and grade levels
      Set<String> classNamesSet = Set.from(_availableClassNames);
      Set<String> gradeLevelsSet = Set.from(_availableGradeLevels);

      for (var subject in data) {
        final kelasNames = subject['class_names']?.toString() ?? '';
        if (kelasNames.isNotEmpty) {
          final names = kelasNames
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          classNamesSet.addAll(names);
        }

        final kelasGradeLevels =
            subject['kelas_grade_levels']?.toString() ?? '';
        if (kelasGradeLevels.isNotEmpty) {
          final levels = kelasGradeLevels
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          gradeLevelsSet.addAll(levels);
        }
      }

      setState(() {
        // Append new data to existing list
        _subjectList.addAll(data);
        _availableClassNames = classNamesSet.toList()..sort();
        _availableGradeLevels = gradeLevelsSet.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a) ?? 0;
            final bInt = int.tryParse(b) ?? 0;
            return aInt.compareTo(bInt);
          });
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      if (kDebugMode) {
        print(
          '✅ Loaded more subjects: Page $_currentPage, Total: ${_subjectList.length}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading more data: $e');
      }
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });
    }
  }

  Future<void> _exportToExcel() async {
    await ExcelSubjectService.exportSubjectsToExcel(
      subjects: _subjectList,
      context: context,
    );
  }

  Future<void> _importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await ApiSubjectService.importSubjectFromExcel(
          File(result.files.single.path!),
        );

        // Refresh data setelah import
        await _loadSubjects();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en': 'Subjects imported successfully',
                  'id': 'Mata pelajaran berhasil diimpor',
                }),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Import subjects error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en':
                  'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
              'id': 'Gagal mengimpor file: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    await ExcelSubjectService.downloadTemplate(context);
  }

  void _showAddEditDialog({Map<String, dynamic>? subject}) {
    final codeController = TextEditingController(
      text: subject?['code'] ?? subject?['kode'],
    );
    final nameController = TextEditingController(text: subject?['name']);
    final descriptionController = TextEditingController(
      text: subject?['description'] ?? subject?['deskripsi'],
    );
    int? selectedMasterSubjectId;
    if (subject != null && subject['subject_id'] != null) {
      selectedMasterSubjectId = int.tryParse(subject['subject_id'].toString());
    }

    // Initialize is_active state
    // Default to true for new subjects, or use existing value
    bool isActive = subject?['is_active'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
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
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20, 20, 16, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ColorUtils.corporateBlue600,
                            ColorUtils.corporateBlue600.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              subject == null
                                  ? Icons.add_rounded
                                  : Icons.edit_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject == null
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Add Subject',
                                          'id': 'Tambah Mata Pelajaran',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Edit Subject',
                                          'id': 'Edit Mata Pelajaran',
                                        }),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  subject == null
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Fill in subject details',
                                          'id': 'Isi detail mata pelajaran',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Update subject information',
                                          'id':
                                              'Perbarui informasi mata pelajaran',
                                        }),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
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
                              controller: codeController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Code',
                                'id': 'Kode',
                              }),
                              icon: Icons.code,
                            ),
                            SizedBox(height: 12),
                            // Select Master Subject (Autocomplete)
                            Autocomplete<Map<String, dynamic>>(
                              initialValue: TextEditingValue(
                                text: () {
                                  if (selectedMasterSubjectId != null) {
                                    final master = _availableMasterSubjects
                                        .firstWhere(
                                          (m) =>
                                              m['id'] ==
                                              selectedMasterSubjectId,
                                          orElse: () => {},
                                        );
                                    if (master.isNotEmpty) {
                                      return master['name'];
                                    }
                                  }
                                  return nameController.text;
                                }(),
                              ),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text == '') {
                                      return const Iterable<
                                        Map<String, dynamic>
                                      >.empty();
                                    }
                                    return _availableMasterSubjects
                                        .cast<Map<String, dynamic>>()
                                        .where((Map<String, dynamic> option) {
                                          return option['name']
                                              .toString()
                                              .toLowerCase()
                                              .contains(
                                                textEditingValue.text
                                                    .toLowerCase(),
                                              );
                                        });
                                  },
                              displayStringForOption:
                                  (Map<String, dynamic> option) =>
                                      option['name'],
                              onSelected: (Map<String, dynamic> selection) {
                                // Use setDialogState if updating visual state inside dialog,
                                // but here we just update controllers which is fine.
                                // Actually we need to update selectedMasterSubjectId which is local.
                                setDialogState(() {
                                  // Auto-format name: "SubjectName Grade"
                                  nameController.text =
                                      '${selection['name']} ${selection['grade']}';
                                  selectedMasterSubjectId = selection['id'];
                                });
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    fieldController,
                                    fieldFocusNode,
                                    onFieldSubmitted,
                                  ) {
                                    return _buildDialogTextField(
                                      controller: fieldController,
                                      focusNode: fieldFocusNode,
                                      label: languageProvider
                                          .getTranslatedText({
                                            'en': 'Select Subject',
                                            'id': 'Pilih Mata Pelajaran',
                                          }),
                                      icon: Icons.search,
                                    );
                                  },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    child: SizedBox(
                                      height: 200.0,
                                      width: 300.0,
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(8.0),
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                              final Map<String, dynamic>
                                              option = options.elementAt(index);
                                              return GestureDetector(
                                                onTap: () {
                                                  onSelected(option);
                                                },
                                                child: ListTile(
                                                  title: Text(option['name']),
                                                  subtitle: Text(
                                                    'Kelas ${option['grade']}',
                                                  ),
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 12),

                            // Subject Name (Standard TextField)
                            _buildDialogTextField(
                              controller: nameController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Subject Name',
                                'id': 'Nama Mata Pelajaran',
                              }),
                              icon: Icons.menu_book,
                            ),
                            SizedBox(height: 12),
                            _buildDialogTextField(
                              controller: descriptionController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Description',
                                'id': 'Deskripsi',
                              }),
                              icon: Icons.description,
                              maxLines: 3,
                            ),
                            SizedBox(height: 12),
                            // Active Status Switch
                            Container(
                              decoration: BoxDecoration(
                                color: ColorUtils.slate50,
                                border: Border.all(color: ColorUtils.slate200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SwitchListTile(
                                title: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Active Status',
                                    'id': 'Status Aktif',
                                  }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: ColorUtils.slate700,
                                  ),
                                ),
                                value: isActive,
                                activeThumbColor: ColorUtils.corporateBlue600,
                                activeTrackColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.3),
                                onChanged: (bool value) {
                                  setDialogState(() {
                                    isActive = value;
                                  });
                                },
                                secondary: Icon(
                                  Icons.check_circle_outline,
                                  color: isActive
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions footer
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: ColorUtils.slate100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: ColorUtils.slate300),
                              ),
                              child: Text(
                                AppLocalizations.cancel.tr,
                                style: TextStyle(
                                  color: ColorUtils.slate600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (codeController.text.isEmpty ||
                                    nameController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Code and name must be filled',
                                          'id': 'Kode dan nama harus diisi',
                                        }),
                                      ),
                                      backgroundColor: Colors.red.shade400,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                // Validation logic removed to allow custom names
                                // while keeping the master subject link.

                                try {
                                  if (subject == null) {
                                    await ApiSubjectService.addSubject({
                                      'name': nameController.text,
                                      'code': codeController.text,
                                      'description': descriptionController.text,
                                      'subject_id': selectedMasterSubjectId,
                                      'is_active': isActive,
                                    });
                                  } else {
                                    await ApiSubjectService.updateSubject(
                                      subject['id'],
                                      {
                                        'name': nameController.text,
                                        'code': codeController.text,
                                        'description':
                                            descriptionController.text,
                                        'subject_id': selectedMasterSubjectId,
                                        'is_active': isActive,
                                      },
                                    );
                                  }
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _loadSubjects(); // Reload data
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Data saved successfully',
                                            'id': 'Data berhasil disimpan',
                                          }),
                                        ),
                                        backgroundColor: Colors.green.shade400,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (kDebugMode)
                                    print('Save/Update subject error: $error');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${languageProvider.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(error)}',
                                        ),
                                        backgroundColor: Colors.red.shade400,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorUtils.corporateBlue600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 14),
                                elevation: 2,
                              ),
                              child: Text(
                                AppLocalizations.save.tr,
                                style: TextStyle(fontWeight: FontWeight.w600),
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
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 14),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return ConfirmationDialog(
            title: languageProvider.getTranslatedText({
              'en': 'Delete Subject',
              'id': 'Hapus Mata Pelajaran',
            }),
            content: languageProvider.getTranslatedText({
              'en':
                  'Are you sure you want to delete subject "${subject['name']}"?',
              'id':
                  'Yakin ingin menghapus mata pelajaran "${subject['name']}"?',
            }),
            confirmText: languageProvider.getTranslatedText({
              'en': 'Delete',
              'id': 'Hapus',
            }),
            confirmColor: Colors.red,
          );
        },
      ),
    );

    if (confirmed == true) {
      try {
        await ApiSubjectService.deleteSubject(subject['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Subject successfully deleted',
                  'id': 'Mata pelajaran berhasil dihapus',
                }),
              ),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadSubjects();
      } catch (error) {
        if (kDebugMode) print('Delete subject error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.read<LanguageProvider>().getTranslatedText({'en': 'Failed to delete: ', 'id': 'Gagal menghapus: '})}${ErrorUtils.getFriendlyMessage(error)}',
              ),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // Navigasi ke halaman manajemen kelas untuk mata pelajaran
  void _navigateToClassManagement(Map<String, dynamic> subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectClassManagementPage(subject: subject),
      ),
    );
  }

  List<dynamic> _getFilteredSubjects() {
    return _subjectList.where((subject) {
      final searchTerm = _searchController.text.toLowerCase();
      final subjectName = subject['name']?.toString().toLowerCase() ?? '';
      final subjectCode =
          (subject['code'] ?? subject['kode'])?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          subjectCode.contains(searchTerm);

      // Kelas status filter
      final hasClasses = (subject['jumlah_kelas'] ?? 0) > 0;
      final matchesKelasStatusFilter =
          _selectedKelasStatusFilter == null ||
          (_selectedKelasStatusFilter == 'ada' && hasClasses) ||
          (_selectedKelasStatusFilter == 'tidak_ada' && !hasClasses);

      // Class Name filter
      final kelasNames = subject['kelas_names']?.toString() ?? '';
      final matchesClassNameFilter =
          _selectedClassNameFilter == null ||
          (kelasNames.isNotEmpty &&
              kelasNames
                  .split(',')
                  .map((e) => e.trim())
                  .contains(_selectedClassNameFilter));

      return matchesSearch &&
          matchesKelasStatusFilter &&
          matchesClassNameFilter;
    }).toList();
  }

  Widget _buildHeader(BuildContext context, LanguageProvider languageProvider) {
    return Container(
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
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Subject Management',
                        'id': 'Manajemen Mata Pelajaran',
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
                        'en': 'Manage and monitor subjects',
                        'id': 'Kelola dan pantau mata pelajaran',
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
                  child: Icon(Icons.more_vert, color: Colors.white, size: 20),
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
                          // onChanged: (value) => setState(() {}),
                          style: TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Search subjects...',
                              'id': 'Cari mata pelajaran...',
                            }),
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (value) {
                            setState(() {
                              _currentPage = 1;
                            });
                            _loadSubjects();
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: _getPrimaryColor()),
                          onPressed: () {
                            setState(() {
                              _currentPage = 1;
                            });
                            _loadSubjects();
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
                        ..._buildFilterChips(languageProvider).map((filter) {
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
                                color: Colors.red,
                              ),
                              onDeleted: filter['onRemove'],
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
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
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, int index) {
    final languageProvider = context.read<LanguageProvider>();
    final kelasCount = subject['jumlah_kelas'] ?? 0;
    final isActive = subject['is_active'] ?? true;
    final avatarColor = ColorUtils.getColorForIndex(index);
    final subjectCode = subject['code'] ?? subject['kode'] ?? '-';
    final kelasNames = (subject['kelas_names']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _navigateToClassManagement(subject),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CircleAvatar with first letter
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    (subject['name'] ?? 'S')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject name
                      Text(
                        subject['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: 4),
                      // Subject code and status
                      Row(
                        children: [
                          Text(
                            subjectCode,
                            style: TextStyle(
                              fontSize: 13,
                              color: ColorUtils.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: ColorUtils.slate300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? ColorUtils.success600.withValues(alpha: 0.1)
                                  : ColorUtils.error600.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? ColorUtils.success600
                                        : ColorUtils.error600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isActive
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Active',
                                          'id': 'Aktif',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Inactive',
                                          'id': 'Tidak Aktif',
                                        }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? ColorUtils.success600
                                        : ColorUtils.error600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // Info tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoTag(
                            Icons.class_outlined,
                            '$kelasCount ${languageProvider.getTranslatedText({'en': 'Classes', 'id': 'Kelas'})}',
                          ),
                          if (kelasNames.isNotEmpty)
                            _buildInfoTag(
                              Icons.groups_outlined,
                              kelasNames.join(', '),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions column
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: _getPrimaryColor(),
                      onPressed: () => _showAddEditDialog(subject: subject),
                    ),
                    SizedBox(height: 8),
                    _buildCircleActionButton(
                      icon: Icons.delete_outline,
                      color: ColorUtils.error600,
                      onPressed: () => _deleteSubject(subject),
                    ),
                  ],
                ),
              ],
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

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Column(
              children: [
                _buildHeader(context, languageProvider),
                Expanded(
                  child: SkeletonListLoading(itemCount: 6, infoTagCount: 2),
                ),
              ],
            ),
          );
        }

        if (_errorMessage.isNotEmpty) {
          return ErrorScreen(
            errorMessage: _errorMessage,
            onRetry: _loadSubjects,
          );
        }

        final filteredSubjects = _getFilteredSubjects();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              _buildHeader(context, languageProvider),

              Expanded(
                child: filteredSubjects.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No subjects',
                          'id': 'Tidak ada mata pelajaran',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a subject',
                                'id': 'Tap + untuk menambah mata pelajaran',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.school_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSubjects,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              filteredSubjects.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredSubjects.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            return _buildSubjectCard(
                              filteredSubjects[index],
                              index,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEditDialog(),
            backgroundColor: _getPrimaryColor(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, color: Colors.white, size: 20),
          ),
        );
      },
    );
  }
}

// Halaman Manajemen Kelas untuk Mata Pelajaran (Updated dengan style yang sama)
class SubjectClassManagementPage extends StatefulWidget {
  final Map<String, dynamic> subject;

  const SubjectClassManagementPage({super.key, required this.subject});

  @override
  SubjectClassManagementPageState createState() =>
      SubjectClassManagementPageState();
}

class SubjectClassManagementPageState
    extends State<SubjectClassManagementPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _availableClasses = [];
  List<dynamic> _assignedClasses = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load semua kelas yang tersedia
      final allClassesResponse = await _apiService.get('/class');

      // Load kelas yang sudah ditetapkan untuk mata pelajaran ini
      // getKelasByMataPelajaran already returns List<dynamic>
      final assignedClasses = await _apiService.getClassBySubjectId(
        widget.subject['id'].toString(),
      );

      // Handle both Map (pagination) and List formats for allClasses
      List<dynamic> allClasses;
      if (allClassesResponse is Map<String, dynamic>) {
        allClasses = allClassesResponse['data'] ?? [];
      } else if (allClassesResponse is List) {
        allClasses = allClassesResponse;
      } else {
        allClasses = [];
      }

      setState(() {
        _availableClasses = allClasses;
        _assignedClasses = assignedClasses;
        _isLoading = false;
      });

      if (allClasses.isNotEmpty) {
        print('First class data: ${allClasses[0]}');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addClassToSubject(Map<String, dynamic> kelas) async {
    try {
      await ApiSubjectService.attachClass(
        widget.subject['id'].toString(),
        kelas['id'].toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kelas ${kelas['name']} berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeClassFromSubject(Map<String, dynamic> kelas) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Hapus Kelas',
        content:
            'Yakin ingin menghapus kelas ${kelas['name']} dari mata pelajaran ini?',
        confirmText: 'Hapus',
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await ApiSubjectService.detachClass(
          widget.subject['id'].toString(),
          kelas['id'].toString(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kelas ${kelas['name']} berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadData();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Method untuk menambah kelas secara cepat
  void _showQuickAddClassDialog() {
    final unassignedClasses = _availableClasses.where((kelas) {
      return !_isClassAssigned(kelas['id']);
    }).toList();

    if (unassignedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semua kelas sudah ditambahkan ke mata pelajaran ini'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header dengan gradient
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20, 20, 16, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getPrimaryColor(),
                          _getPrimaryColor().withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Kelas',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih kelas untuk ditambahkan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pilih kelas yang ingin ditambahkan ke ${widget.subject['nama']}:',
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorUtils.slate600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),

                        // Search bar dalam dialog
                        Container(
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Cari kelas...',
                              hintStyle: TextStyle(color: ColorUtils.slate400),
                              prefixIcon: Icon(
                                Icons.search,
                                color: ColorUtils.corporateBlue600,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setDialogState(() {});
                            },
                          ),
                        ),
                        SizedBox(height: 16),

                        Container(
                          constraints: BoxConstraints(maxHeight: 300),
                          child: unassignedClasses.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Semua kelas sudah ditambahkan',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: unassignedClasses.length,
                                  itemBuilder: (context, index) {
                                    final kelas = unassignedClasses[index];
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      elevation: 1,
                                      child: ListTile(
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: _getPrimaryColor()
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.class_,
                                            color: _getPrimaryColor(),
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          kelas['name'] ?? 'Kelas',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (kelas['tingkat'] != null)
                                              Text(
                                                'Tingkat: ${kelas['tingkat']}',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            if (kelas['wali_kelas_nama'] !=
                                                null)
                                              Text(
                                                'Wali: ${kelas['wali_kelas_nama']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: ColorUtils.slate500,
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Container(
                                          decoration: BoxDecoration(
                                            color: _getPrimaryColor(),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addClassToSubject(kelas);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Actions footer
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: ColorUtils.slate100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                color: ColorUtils.slate600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                            child: Text(
                              'Lihat Semua',
                              style: TextStyle(fontWeight: FontWeight.w600),
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
      ),
    );
  }

  bool _isClassAssigned(String classId) {
    return _assignedClasses.any((kelas) => kelas['id'] == classId);
  }

  List<dynamic> _getFilteredClasses() {
    final searchTerm = _searchController.text.toLowerCase();
    return _availableClasses.where((kelas) {
      final className = kelas['name']?.toString().toLowerCase() ?? '';
      final classLevel = kelas['tingkat']?.toString().toLowerCase() ?? '';
      final homeroomTeacher =
          kelas['wali_kelas_nama']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          className.contains(searchTerm) ||
          classLevel.contains(searchTerm) ||
          homeroomTeacher.contains(searchTerm);

      final isAssigned = _isClassAssigned(kelas['id']);

      final matchesFilter =
          _selectedFilter == 'All' ||
          (_selectedFilter == 'Assigned' && isAssigned) ||
          (_selectedFilter == 'Unassigned' && !isAssigned);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildClassCard(
    Map<String, dynamic> kelas,
    int index,
    bool isAssigned,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAssigned
              ? ColorUtils.corporateBlue600.withValues(alpha: 0.3)
              : ColorUtils.slate200,
          width: isAssigned ? 1.5 : 1,
        ),
        boxShadow: ColorUtils.corporateShadow(
          elevation: isAssigned ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (isAssigned) {
              _removeClassFromSubject(kelas);
            } else {
              _addClassToSubject(kelas);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAssigned
                        ? ColorUtils.corporateBlue600.withValues(alpha: 0.1)
                        : ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isAssigned
                          ? ColorUtils.corporateBlue600.withValues(alpha: 0.2)
                          : ColorUtils.slate200,
                    ),
                  ),
                  child: Icon(
                    Icons.class_outlined,
                    color: isAssigned
                        ? ColorUtils.corporateBlue600
                        : ColorUtils.slate500,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),

                // Informasi kelas
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kelas['name'] ?? 'Kelas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (kelas['tingkat'] != null)
                            _buildClassInfoTag(
                              Icons.layers_outlined,
                              'Tingkat ${kelas['tingkat']}',
                            ),
                          if (kelas['wali_kelas_nama'] != null)
                            _buildClassInfoTag(
                              Icons.person_outline,
                              kelas['wali_kelas_nama'],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),
                // Status indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAssigned
                        ? ColorUtils.success600.withValues(alpha: 0.1)
                        : ColorUtils.corporateBlue600.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAssigned
                          ? ColorUtils.success600.withValues(alpha: 0.3)
                          : ColorUtils.corporateBlue600.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAssigned
                            ? Icons.check_circle_outline
                            : Icons.add_circle_outline,
                        size: 14,
                        color: isAssigned
                            ? ColorUtils.success600
                            : ColorUtils.corporateBlue600,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isAssigned ? 'Terdaftar' : 'Tambahkan',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAssigned
                              ? ColorUtils.success600
                              : ColorUtils.corporateBlue600,
                          fontWeight: FontWeight.w600,
                        ),
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

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  Widget _buildClassInfoTag(IconData icon, String text) {
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

  @override
  Widget build(BuildContext context) {
    final filteredClasses = _getFilteredClasses();
    final assignedCount = _assignedClasses.length;

    // Terjemahan filter options
    final languageProvider = context.read<LanguageProvider>();
    final translatedFilterOptions = [
      languageProvider.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      languageProvider.getTranslatedText({'en': 'Assigned', 'id': 'Terdaftar'}),
      languageProvider.getTranslatedText({
        'en': 'Unassigned',
        'id': 'Belum Terdaftar',
      }),
    ];

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject['name'] ?? widget.subject['nama'] ?? 'Subject',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Manajemen Kelas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        backgroundColor: ColorUtils.corporateBlue600,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? SkeletonListLoading(itemCount: 6, infoTagCount: 2)
          : Column(
              children: [
                // Quick stats
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.corporateBlue600,
                        ColorUtils.corporateBlue600.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ColorUtils.corporateShadow(elevation: 2.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.class_,
                        value: _availableClasses.length.toString(),
                        label: 'Total Kelas',
                        color: Colors.white,
                      ),
                      _buildStatItem(
                        icon: Icons.check_circle,
                        value: assignedCount.toString(),
                        label: 'Terdaftar',
                        color: Colors.white,
                      ),
                      _buildStatItem(
                        icon: Icons.add_circle,
                        value: (_availableClasses.length - assignedCount)
                            .toString(),
                        label: 'Belum Terdaftar',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),

                EnhancedSearchBar(
                  controller: _searchController,
                  hintText: 'Cari kelas...',
                  onChanged: (value) {
                    setState(() {});
                  },
                  filterOptions: translatedFilterOptions,
                  selectedFilter:
                      translatedFilterOptions[_selectedFilter == 'All'
                          ? 0
                          : _selectedFilter == 'Assigned'
                          ? 1
                          : 2],
                  onFilterChanged: (filter) {
                    final index = translatedFilterOptions.indexOf(filter);
                    setState(() {
                      _selectedFilter = index == 0
                          ? 'All'
                          : index == 1
                          ? 'Assigned'
                          : 'Unassigned';
                    });
                  },
                  showFilter: true,
                ),

                if (filteredClasses.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${filteredClasses.length} kelas ditemukan',
                          style: TextStyle(
                            color: ColorUtils.slate500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 4),

                Expanded(
                  child: filteredClasses.isEmpty
                      ? EmptyState(
                          title: 'Tidak ada kelas',
                          subtitle:
                              _searchController.text.isEmpty &&
                                  _selectedFilter == 'All'
                              ? 'Semua kelas sudah ditampilkan'
                              : 'Tidak ditemukan hasil pencarian',
                          icon: Icons.class_outlined,
                        )
                      : ListView.builder(
                          itemCount: filteredClasses.length,
                          itemBuilder: (context, index) {
                            final kelas = filteredClasses[index];
                            final isAssigned = _isClassAssigned(kelas['id']);
                            return _buildClassCard(kelas, index, isAssigned);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton:
          Provider.of<AcademicYearProvider>(context, listen: false).isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: _showQuickAddClassDialog,
              backgroundColor: _getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
