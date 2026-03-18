import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/components/gradient_page_header.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/admin/teacher_detail_screen.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/services/excel_teacher_service.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TeacherAdminScreen extends StatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  TeacherAdminScreenState createState() => TeacherAdminScreenState();
}

class TeacherAdminScreenState extends State<TeacherAdminScreen> {
  final ApiTeacherService _teacherService = ApiTeacherService();
  final ApiSubjectService _subjectService = ApiSubjectService();
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  String? _selectedClassId;
  String? _selectedHomeroomFilter;
  String? _selectedGender;
  String? _selectedEmploymentStatus;
  String? _selectedTeachingClassId;
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availableClass = [];
  List<dynamic> _availableGenders = [];
  List<dynamic> _availableEmploymentStatus = [];

  final String _lastSearchQuery = '';

  // Search debounce
  Timer? _searchDebounce;

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  String? _tourId;

  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // _searchController.addListener(_onSearchChanged); // Removed auto-search listener

    // Listen to academic year changes
    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    academicYearProvider.addListener(_onAcademicYearChanged);

    _loadFilterOptions();
    _loadData();

    // Listen to real-time sync trigger
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_teachers' ||
            trigger['type'] == 'refresh_schedules')) {
      if (mounted) {
        if (kDebugMode) print('📦 Sync triggered: ${trigger['type']}');
        _loadData(useCache: false);
      }
    }
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // _searchController.removeListener(_onSearchChanged); // Removed auto-search listener
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onAcademicYearChanged() {
    if (mounted) {
      _loadFilterOptions(); // Refresh class options
      _loadData(); // Refresh teacher list
    }
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  // void _onSearchChanged() { ... } // Removed entire method to prevent auto-search

  bool _showAllTeachers = false; // Filter to show all teachers

  Future<void> _loadFilterOptions() async {
    try {
      String? academicYearId;
      if (mounted) {
        try {
          final academicYearProvider = Provider.of<AcademicYearProvider>(
            context,
            listen: false,
          );
          academicYearId = academicYearProvider.selectedAcademicYear?['id']
              ?.toString();
        } catch (e) {
          // provider might not be available or other error
        }
      }

      // ─── Cache-first: return early on hit ───
      final cacheKey = 'teacher_filter_options_${academicYearId ?? 'default'}';
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          setState(() {
            _availableClass = List<dynamic>.from(cachedData['kelas'] ?? []);
            _availableGenders = List<dynamic>.from(cachedData['gender_options'] ?? []);
            _availableEmploymentStatus =
                List<dynamic>.from(cachedData['employment_status_options'] ?? []);
          });
          if (kDebugMode) print('⚡ Teacher filter options loaded from cache');
          return;
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Teacher filter cache load failed: $e');
      }

      final response = await ApiTeacherService.getTeacherFilterOptions(
        academicYearId: academicYearId,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableClass = response['data']['kelas'] ?? [];
          _availableGenders = response['data']['gender_options'] ?? [];
          _availableEmploymentStatus =
              response['data']['employment_status_options'] ?? [];
        });
        // Non-blocking cache save
        LocalCacheService.save(cacheKey, {
          'kelas': response['data']['kelas'] ?? [],
          'gender_options': response['data']['gender_options'] ?? [],
          'employment_status_options': response['data']['employment_status_options'] ?? [],
        });
        if (kDebugMode) {
          print(
            '✅ Filter options loaded: ${_availableClass.length} kelas, ${_availableGenders.length} gender, ${_availableEmploymentStatus.length} employment status',
          );
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
          _selectedHomeroomFilter != null ||
          _selectedClassId != null ||
          _selectedGender != null ||
          _selectedEmploymentStatus != null ||
          _selectedTeachingClassId != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedClassId = null;
      _selectedHomeroomFilter = null;
      _selectedGender = null;
      _selectedEmploymentStatus = null;
      _selectedTeachingClassId = null;
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

    if (_selectedHomeroomFilter != null) {
      final statusText = _selectedHomeroomFilter == 'wali_kelas'
          ? languageProvider.getTranslatedText({
              'en': 'Homeroom Teacher',
              'id': 'Wali Kelas',
            })
          : languageProvider.getTranslatedText({
              'en': 'Regular Teacher',
              'id': 'Guru Biasa',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedHomeroomFilter = null;
          });
          _checkActiveFilter();
          _loadData(); // Reload data setelah remove filter
        },
      });
    }

    if (_selectedGender != null) {
      final genderText = _selectedGender == 'L'
          ? languageProvider.getTranslatedText({
              'en': 'Male',
              'id': 'Laki-laki',
            })
          : languageProvider.getTranslatedText({
              'en': 'Female',
              'id': 'Perempuan',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Gender', 'id': 'Jenis Kelamin'})}: $genderText',
        'onRemove': () {
          setState(() {
            _selectedGender = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedEmploymentStatus != null) {
      final statusLabel = _availableEmploymentStatus.firstWhere(
        (s) => s['value'].toString() == _selectedEmploymentStatus,
        orElse: () => {'label': _selectedEmploymentStatus},
      )['label'];
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Employment', 'id': 'Status Kepegawaian'})}: $statusLabel',
        'onRemove': () {
          setState(() {
            _selectedEmploymentStatus = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedTeachingClassId != null) {
      final className = _availableClass.firstWhere(
        (c) => c['id'].toString() == _selectedTeachingClassId,
        orElse: () => {'name': _selectedTeachingClassId},
      )['name'];
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Teaching', 'id': 'Kelas Ajar'})}: $className',
        'onRemove': () {
          setState(() {
            _selectedTeachingClassId = null;
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
    String? tempSelectedHomeroom = _selectedHomeroomFilter;
    String? tempSelectedGender = _selectedGender;
    String? tempSelectedEmploymentStatus = _selectedEmploymentStatus;
    String? tempSelectedTeachingClass = _selectedTeachingClassId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header gradient (Pattern #11)
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
                        Row(
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Filter Teachers',
                                'id': 'Filter Guru',
                              }),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedHomeroom = null;
                              tempSelectedGender = null;
                              tempSelectedEmploymentStatus = null;
                              tempSelectedTeachingClass = null;
                              _showAllTeachers = false;
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show All Teachers Toggle
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ColorUtils.slate200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Show All Teachers',
                                          'id': 'Tampilkan Semua Guru',
                                        }),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: ColorUtils.slate800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        languageProvider.getTranslatedText({
                                          'en':
                                              'Include inactive (ignores academic year)',
                                          'id':
                                              'Termasuk tidak aktif (abaikan tahun ajaran)',
                                        }),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: ColorUtils.slate500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _showAllTeachers,
                                  activeThumbColor: ColorUtils.corporateBlue600,
                                  activeTrackColor: ColorUtils.corporateBlue600
                                      .withValues(alpha: 0.4),
                                  onChanged: (bool value) {
                                    setModalState(() {
                                      _showAllTeachers = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),

                          // Gender Section
                          Row(
                            children: [
                              Icon(
                                Icons.transgender_rounded,
                                size: 16,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Gender',
                                  'id': 'Jenis Kelamin',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedGender,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedGender = null;
                                  });
                                },
                              ),
                              ..._availableGenders.map((gender) {
                                return buildStatusChip(
                                  label: gender['label'],
                                  value: gender['value'].toString(),
                                  selectedValue: tempSelectedGender,
                                  onSelected: () {
                                    setModalState(() {
                                      tempSelectedGender = gender['value']
                                          .toString();
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Employment Status Section
                          Row(
                            children: [
                              Icon(
                                Icons.work_outline_rounded,
                                size: 16,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Employment Status',
                                  'id': 'Status Kepegawaian',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedEmploymentStatus,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedEmploymentStatus = null;
                                  });
                                },
                              ),
                              ..._availableEmploymentStatus.map((status) {
                                return buildStatusChip(
                                  label: status['label'],
                                  value: status['value'].toString(),
                                  selectedValue: tempSelectedEmploymentStatus,
                                  onSelected: () {
                                    setModalState(() {
                                      tempSelectedEmploymentStatus =
                                          status['value'].toString();
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Teaching Class Section
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 16,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Teaching Class',
                                  'id': 'Kelas Ajar',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate50,
                              border: Border.all(color: ColorUtils.slate200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: tempSelectedTeachingClass,
                                hint: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Select Class',
                                    'id': 'Pilih Kelas',
                                  }),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Clear Selection',
                                        'id': 'Hapus Pilihan',
                                      }),
                                    ),
                                  ),
                                  ..._availableClass.map((kelas) {
                                    return DropdownMenuItem<String>(
                                      value: kelas['id'].toString(),
                                      child: Text(kelas['name'].toString()),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    tempSelectedTeachingClass = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 20),

                          // Homeroom Status Section
                          Row(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 16,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Homeroom Teacher Status',
                                  'id': 'Status Wali Kelas',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedHomeroom,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedHomeroom = null;
                                  });
                                },
                              ),
                              buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Homeroom Teacher',
                                  'id': 'Wali Kelas',
                                }),
                                value: 'wali_kelas',
                                selectedValue: tempSelectedHomeroom,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedHomeroom = 'wali_kelas';
                                  });
                                },
                              ),
                              buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Regular Teacher',
                                  'id': 'Bukan Wali Kelas',
                                }),
                                value: 'guru_biasa',
                                selectedValue: tempSelectedHomeroom,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedHomeroom = 'guru_biasa';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer Buttons (Pattern #11)
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: ColorUtils.slate200),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.slate900.withValues(alpha: 0.05),
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
                                color: ColorUtils.slate700,
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
                                _selectedHomeroomFilter = tempSelectedHomeroom;
                                _selectedGender = tempSelectedGender;
                                _selectedEmploymentStatus =
                                    tempSelectedEmploymentStatus;
                                _selectedTeachingClassId =
                                    tempSelectedTeachingClass;
                              });
                              _checkActiveFilter();
                              Navigator.pop(context);
                              _loadData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Apply Filter',
                                'id': 'Terapkan Filter',
                              }),
                              style: TextStyle(
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
            ),
          );
        },
      ),
    );
  }

  Widget buildStatusChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
      checkmarkColor: ColorUtils.corporateBlue600,
      labelStyle: TextStyle(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  /// Build cache key — only cache default view (page 1, no filters/search).
  String? _buildTeacherCacheKey() {
    if (_currentPage != 1) return null;
    if (_selectedClassId != null ||
        _selectedHomeroomFilter != null ||
        _selectedGender != null ||
        _selectedEmploymentStatus != null ||
        _selectedTeachingClassId != null ||
        _showAllTeachers ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }
    final yearId = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).selectedAcademicYear?['id']?.toString() ?? 'default';
    return 'teacher_list_$yearId';
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _hasMoreData = true;

        // ─── Step 1: Load from cache for instant display ───
        if (useCache) {
          final cacheKey = _buildTeacherCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null && mounted) {
                final cachedData = Map<String, dynamic>.from(cached);
                setState(() {
                  _teachers = List<dynamic>.from(cachedData['teachers'] ?? []);
                  _subjects = List<dynamic>.from(cachedData['subjects'] ?? []);
                  _classes = List<dynamic>.from(cachedData['classes'] ?? []);
                  _paginationMeta = cachedData['pagination'] != null
                      ? Map<String, dynamic>.from(cachedData['pagination'])
                      : null;
                  _hasMoreData = cachedData['pagination']?['has_next_page'] ?? false;
                  _isLoading = false;
                  _errorMessage = null;
                });
                if (kDebugMode) print('⚡ Teachers loaded from cache');
                // Cache hit → return early, no background API refresh
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) _checkAndShowTour();
                });
                return;
              }
            } catch (e) {
              if (kDebugMode) print('⚠️ Teacher cache load failed: $e');
            }
          }
        }

        // Show skeleton only if no cached data displayed
        if (_teachers.isEmpty && mounted) {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // Load subjects and classes (untuk dropdown/reference)
      final subjectData = await _subjectService.getSubject();
      final classData = await ApiClassService.getClass(
        academicYearId: selectedYearId,
      );

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = _showAllTeachers ? null : selectedYearId;

      final response = await ApiTeacherService.getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        classId: _selectedHomeroomFilter == 'wali_kelas'
            ? _selectedClassId
            : null,
        gender: _selectedGender,
        employmentStatus: _selectedEmploymentStatus,
        teachingClassId: _selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        useCache: useCache,
      );

      if (!mounted) return;

      setState(() {
        _teachers = response['data'] ?? [];
        _subjects = subjectData;
        _classes = classData;
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // ─── Step 3: Save to cache (only for default view) ───
      final cacheKey = _buildTeacherCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'teachers': response['data'] ?? [],
          'subjects': subjectData,
          'classes': classData,
          'pagination': response['pagination'],
        });
      }
    } catch (e) {
      if (kDebugMode) print('Load teachers error: $e');
      if (!mounted) return;

      // Only show error if no cached data displayed
      if (_teachers.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      } else {
        setState(() => _isLoading = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Failed to load data: ${ErrorUtils.getFriendlyMessage(e)}',
              'id': 'Gagal memuat data: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Trigger tour
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  /// Force refresh: clear cache and reload from API
  Future<void> _forceRefresh() async {
    final cacheKey = _buildTeacherCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_teacher_admin_');
    final yearId = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).selectedAcademicYear?['id']?.toString() ?? 'default';
    await LocalCacheService.invalidate('teacher_filter_options_$yearId');
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Load next page
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = _showAllTeachers ? null : selectedYearId;

      // Load next page
      final response = await ApiTeacherService.getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        classId: _selectedHomeroomFilter == 'wali_kelas'
            ? _selectedClassId
            : null,
        gender: _selectedGender,
        employmentStatus: _selectedEmploymentStatus,
        teachingClassId: _selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _teachers.addAll(response['data'] ?? []);
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      print(
        '✅ Loaded more data: Page $_currentPage, Total items: ${_teachers.length}',
      );
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

  // Export teachers to Excel
  Future<void> exportToExcel() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Preparing export...',
              'id': 'Menyiapkan export...',
            }),
          ),
          duration: Duration(seconds: 1),
        ),
      );

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = _showAllTeachers ? null : selectedYearId;

      // Fetch all teachers with current filters
      final response = await ApiTeacherService.getTeachersPaginated(
        page: 1,
        limit: 10000, // Fetch all data
        classId: _selectedClassId,
        gender: null,
        academicYearId: effectiveAcademicYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      final allTeachers = response['data'] ?? [];

      await ExcelTeacherService.exportTeachersToExcel(
        teachers: allTeachers,
        context: context,
      );
    } catch (e) {
      if (kDebugMode) print('Export teachers error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
              'id': 'Gagal mengexport: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Import teachers from Excel
  Future<void> importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        if (kDebugMode) {
          print(
            'Import teachers - picked file: ${pickedFile.path}, size: ${await pickedFile.length()} bytes',
          );
        }

        try {
          final response = await ApiTeacherService.importTeachersFromExcel(
            pickedFile,
          );
          if (kDebugMode) print('Import response: $response');

          // If backend returned structured errors, show them to user
          // show errors array if present
          if (response['errors'] != null &&
              response['errors'] is List &&
              (response['errors'] as List).isNotEmpty) {
            final errors = (response['errors'] as List).take(10).join('\n');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import finished with errors:\n$errors'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (response['error'] != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import failed: ${response['error']}'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Import completed',
                    'id': 'Import selesai',
                  }),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Refresh data setelah import
          await _loadData();
        } catch (apiError) {
          if (kDebugMode) print('Error calling import API: $apiError');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en':
                      'Failed to import file: ${ErrorUtils.getFriendlyMessage(apiError)}',
                  'id':
                      'Gagal mengimpor file: ${ErrorUtils.getFriendlyMessage(apiError)}',
                }),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Import from Excel picker/process error: $e');
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

  // Download template
  Future<void> downloadTemplate() async {
    await ExcelTeacherService.downloadTemplate(context);
  }

  // Import teacher from Excel (API call)
  Future<Map<String, dynamic>> importTeachersFromExcelAPI(
    String base64File,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'Calling /guru/import (API) with base64 size=${base64File.length}',
        );
      }
      final response = await ApiService().post('/guru/import', {
        'file_data': base64File,
      });
      if (kDebugMode) debugPrint('Response from /guru/import: $response');
      return response;
    } catch (e) {
      debugPrint('Error importing teachers from Excel: $e');
      rethrow;
    }
  }

  // Download teacher template (API call)
  Future<String> downloadTeacherTemplateAPI() async {
    try {
      final response = await ApiService().get('/guru/template');
      return response['file_data'];
    } catch (e) {
      debugPrint('Error downloading teacher template: $e');
      rethrow;
    }
  }

  // Import teacher from Excel
  Future<Map<String, dynamic>> importTeachersFromExcel(
    String base64File,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'Calling /guru/import (helper) with base64 size=${base64File.length}',
        );
      }
      final response = await ApiService().post('/guru/import', {
        'file_data': base64File,
      });
      if (kDebugMode) {
        debugPrint('Response from /guru/import (helper): $response');
      }
      return response;
    } catch (e) {
      debugPrint('Error importing teachers from Excel: $e');
      rethrow;
    }
  }

  // Download teacher template
  Future<String> downloadTeacherTemplate() async {
    try {
      final response = await ApiService().get('/guru/template');
      return response['file_data'];
    } catch (e) {
      debugPrint('Error downloading teacher template: $e');
      rethrow;
    }
  }

  Future<void> manageTeacherSubject(
    String teacherId,
    List<String> selectedSubjectIds,
  ) async {
    try {
      final currentSubjects = await _teacherService.getSubjectByTeacher(
        teacherId,
      );
      final currentIds = currentSubjects
          .map((subject) => subject['id'] as String)
          .toList();

      for (final subjectId in selectedSubjectIds) {
        if (!currentIds.contains(subjectId)) {
          await _teacherService.addSubjectToTeacher(teacherId, subjectId);
        }
      }

      for (final currentId in currentIds) {
        if (!selectedSubjectIds.contains(currentId)) {
          await _teacherService.removeSubjectFromTeacher(teacherId, currentId);
        }
      }
    } catch (error) {
      if (kDebugMode) print('Update teacher subjects error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en':
                  'Failed to update teacher subjects: ${ErrorUtils.getFriendlyMessage(error)}',
              'id':
                  'Gagal mengupdate mata pelajaran guru: ${ErrorUtils.getFriendlyMessage(error)}',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showAddEditDialog({Map<String, dynamic>? teacher}) {
    final nameController = TextEditingController(
      text: teacher?['name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text:
          teacher?['email']?.toString() ??
          teacher?['user']?['email']?.toString() ??
          '',
    );
    final nipController = TextEditingController(
      text: teacher?['employee_number']?.toString() ?? '',
    );

    // New fields for updated structure
    String? selectedGender = teacher?['gender']?.toString();

    // Fix: Check Object/List first for homeroom ID
    String? selectedWaliKelasId;
    if (teacher != null) {
      if (teacher['homeroom_class'] != null &&
          teacher['homeroom_class'] is Map) {
        selectedWaliKelasId = teacher['homeroom_class']['id']?.toString();
      } else if (teacher['homeroom_classes'] != null &&
          teacher['homeroom_classes'] is List &&
          (teacher['homeroom_classes'] as List).isNotEmpty) {
        selectedWaliKelasId = teacher['homeroom_classes'][0]['id']?.toString();
      } else {
        selectedWaliKelasId = teacher['homeroom_class_id']?.toString();
      }
    }

    // Normalize employment_status - convert Indonesian translations to English values
    String? rawStatus = teacher?['employment_status']?.toString();
    String? selectedStatus;
    if (rawStatus != null) {
      // Map Indonesian values to English values
      final statusMap = {
        'Tetap': 'permanent',
        'Kontrak': 'contract',
        'Honor': 'temporary',
        'permanent': 'permanent',
        'contract': 'contract',
        'temporary': 'temporary',
      };
      selectedStatus = statusMap[rawStatus] ?? rawStatus;
    }

    // Parse subject IDs
    List<String> selectedSubjectIds = [];
    if (teacher != null) {
      if (teacher['subjects'] != null && teacher['subjects'] is List) {
        selectedSubjectIds = (teacher['subjects'] as List)
            .map((e) => e['id'].toString())
            .toList();
      } else if (teacher['subject_ids'] != null) {
        final idsString = teacher['subject_ids'].toString();
        if (idsString.isNotEmpty) {
          selectedSubjectIds = idsString
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    // Parse class IDs
    List<String> selectedClassIds = [];
    if (teacher != null) {
      if (teacher['classes'] != null && teacher['classes'] is List) {
        selectedClassIds = (teacher['classes'] as List)
            .map((e) => e['id'].toString())
            .toList();
      } else if (teacher['class_ids'] != null) {
        final idsString = teacher['class_ids'].toString();
        if (idsString.isNotEmpty) {
          selectedClassIds = idsString
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    bool isChangeUserMode = false;

    // Validate that selectedWaliKelasId exists in _classes AND has a name (matching dropdown filter)
    if (selectedWaliKelasId != null) {
      final exists = _classes.any(
        (c) =>
            c['id']?.toString() == selectedWaliKelasId &&
            c['name'] != null, // Must match dropdown filter
      );
      if (!exists) {
        selectedWaliKelasId = null;
      }
    }

    Future<void> showDialogWithSubjects(List<String> subjectIds) async {
      selectedSubjectIds = subjectIds;
      selectedSubjectIds = selectedSubjectIds.toSet().toList();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return StatefulBuilder(
              builder: (context, setState) {
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
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Header dengan gradient (Pattern #9)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                            decoration: BoxDecoration(
                              gradient: getCardGradient(),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    teacher == null
                                        ? Icons.person_add_rounded
                                        : Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacher == null
                                            ? languageProvider
                                                  .getTranslatedText({
                                                    'en': 'Add Teacher',
                                                    'id': 'Tambah Guru',
                                                  })
                                            : languageProvider
                                                  .getTranslatedText({
                                                    'en': 'Edit Teacher',
                                                    'id': 'Edit Guru',
                                                  }),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        teacher == null
                                            ? languageProvider.getTranslatedText({
                                                'en':
                                                    'Fill in teacher information',
                                                'id': 'Isi data guru baru',
                                              })
                                            : languageProvider.getTranslatedText({
                                                'en':
                                                    'Update teacher information',
                                                'id': 'Perbarui data guru',
                                              }),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
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
                                  buildDialogTextField(
                                    controller: nameController,
                                    label: languageProvider.getTranslatedText({
                                      'en': 'Teacher Name',
                                      'id': 'Nama Guru',
                                    }),
                                    icon: Icons.person,
                                  ),
                                  SizedBox(height: 12),
                                  if (teacher != null)
                                    Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: ColorUtils.warning600.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: ColorUtils.warning600.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: SwitchListTile(
                                        title: Text(
                                          languageProvider.getTranslatedText({
                                            'en':
                                                'Use Another User / Change Account',
                                            'id':
                                                'Ganti Akun / Gunakan User Lain',
                                          }),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: ColorUtils.warning600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          languageProvider.getTranslatedText({
                                            'en':
                                                'Link this teacher to a different user account based on the email below (does not edit the current linked user).',
                                            'id':
                                                'Pindahkan guru ini ke akun user lain berdasarkan email di bawah (tidak merubah data user saat ini).',
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.slate600,
                                          ),
                                        ),
                                        value: isChangeUserMode,
                                        activeThumbColor: ColorUtils.warning600,
                                        onChanged: (val) {
                                          setState(() {
                                            isChangeUserMode = val;
                                          });
                                        },
                                      ),
                                    ),
                                  buildDialogTextField(
                                    controller: emailController,
                                    label: languageProvider.getTranslatedText({
                                      'en': 'Email',
                                      'id': 'Email',
                                    }),
                                    icon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  SizedBox(height: 12),
                                  buildDialogTextField(
                                    controller: nipController,
                                    label: 'NIP',
                                    icon: Icons.badge,
                                  ),
                                  SizedBox(height: 12),

                                  // Gender Dropdown (REQUIRED)
                                  buildDialogDropdown(
                                    value: selectedGender,
                                    label: languageProvider.getTranslatedText({
                                      'en': 'Gender*',
                                      'id': 'Jenis Kelamin*',
                                    }),
                                    icon: Icons.person_outline,
                                    items: [
                                      DropdownMenuItem(
                                        value: 'L',
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Male',
                                            'id': 'Laki-laki',
                                          }),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'P',
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Female',
                                            'id': 'Perempuan',
                                          }),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => selectedGender = value);
                                    },
                                  ),
                                  SizedBox(height: 16),

                                  // Subjects Section
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Subjects:',
                                            'id': 'Mata Pelajaran:',
                                          }),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ..._subjects
                                            .where(
                                              (subject) =>
                                                  subject['id'] != null &&
                                                  subject['name'] != null,
                                            )
                                            .map(
                                              (subject) => CheckboxListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  subject['name']?.toString() ??
                                                      'Unknown Subject',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                value: selectedSubjectIds
                                                    .contains(
                                                      subject['id']?.toString(),
                                                    ),
                                                onChanged: (value) {
                                                  final subjectId =
                                                      subject['id']?.toString();
                                                  if (subjectId == null) return;

                                                  setState(() {
                                                    if (value == true) {
                                                      selectedSubjectIds.add(
                                                        subjectId,
                                                      );
                                                    } else {
                                                      selectedSubjectIds.remove(
                                                        subjectId,
                                                      );
                                                    }
                                                  });
                                                },
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 12),

                                  // Homeroom Class Dropdown (Optional)
                                  buildDialogDropdown(
                                    value: selectedWaliKelasId,
                                    label: languageProvider.getTranslatedText({
                                      'en': 'Homeroom Class (Optional)',
                                      'id': 'Wali Kelas (Opsional)',
                                    }),
                                    icon: Icons.class_,
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'None',
                                            'id': 'Tidak ada',
                                          }),
                                        ),
                                      ),
                                      ..._classes
                                          .where(
                                            (classItem) =>
                                                classItem['id'] != null &&
                                                classItem['name'] != null,
                                          )
                                          .fold<
                                            Map<String, Map<String, dynamic>>
                                          >({}, (map, item) {
                                            map[item['id'].toString()] = item;
                                            return map;
                                          })
                                          .values
                                          .map(
                                            (
                                              classItem,
                                            ) => DropdownMenuItem<String>(
                                              value: classItem['id'].toString(),
                                              child: Text(
                                                classItem['name']?.toString() ??
                                                    'Unknown Class',
                                              ),
                                            ),
                                          ),
                                    ],
                                    onChanged: (value) {
                                      setState(
                                        () => selectedWaliKelasId = value,
                                      );
                                    },
                                  ),
                                  SizedBox(height: 12),

                                  // Employment Status Dropdown (Optional)
                                  buildDialogDropdown(
                                    value: selectedStatus,
                                    label: languageProvider.getTranslatedText({
                                      'en': 'Employment Status (Optional)',
                                      'id': 'Status Kepegawaian (Opsional)',
                                    }),
                                    icon: Icons.work_outline,
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'None',
                                            'id': 'Tidak ada',
                                          }),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'permanent',
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Permanent',
                                            'id': 'Tetap',
                                          }),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'contract',
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Contract',
                                            'id': 'Kontrak',
                                          }),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'temporary',
                                        child: Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Temporary/Honorary',
                                            'id': 'Honor',
                                          }),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => selectedStatus = value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Enhanced Footer
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: ColorUtils.slate200),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorUtils.slate900.withValues(
                                    alpha: 0.05,
                                  ),
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
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                        color: ColorUtils.slate300,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      AppLocalizations.cancel.tr,
                                      style: TextStyle(
                                        color: ColorUtils.slate700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final name = nameController.text.trim();
                                      final email = emailController.text.trim();
                                      // final nip = nipController.text.trim(); // Removed unused variable

                                      // Validate required fields
                                      if (name.isEmpty ||
                                          email.isEmpty ||
                                          selectedGender == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Name, email, and gender are required',
                                                'id':
                                                    'Nama, email, dan jenis kelamin wajib diisi',
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
                                        final selectedYearId =
                                            academicYearProvider
                                                .selectedAcademicYear?['id']
                                                ?.toString();

                                        // Prepare data with new structure
                                        final data = {
                                          'name': nameController.text,
                                          'email': emailController.text,
                                          'employee_number':
                                              nipController.text.isNotEmpty
                                              ? nipController.text
                                              : null,
                                          'gender': selectedGender,
                                          'homeroom_class_id':
                                              selectedWaliKelasId,
                                          'employment_status': selectedStatus,
                                          'subject_ids': selectedSubjectIds,
                                          'class_ids': selectedClassIds,
                                          'academic_year_id': selectedYearId,
                                          if (teacher != null && isChangeUserMode)
                                            'use_another_user': true,
                                        };

                                        String teacherId;
                                        if (teacher == null) {
                                          final result = await _teacherService
                                              .addTeacher(data);
                                          teacherId =
                                              result['id']?.toString() ?? '';
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  languageProvider.getTranslatedText({
                                                    'en':
                                                        'Teacher added successfully. Default password: password123',
                                                    'id':
                                                        'Guru berhasil ditambahkan. Password default: password123',
                                                  }),
                                                ),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 5),
                                              ),
                                            );
                                          }
                                        } else {
                                          teacherId =
                                              teacher['id']?.toString() ?? '';
                                          await _teacherService.updateTeacher(
                                            teacherId,
                                            data,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  languageProvider.getTranslatedText({
                                                    'en':
                                                        'Teacher updated successfully',
                                                    'id':
                                                        'Guru berhasil diupdate',
                                                  }),
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        }

                                        // No need to manage subjects separately anymore
                                        // Backend handles it in POST/PUT

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                        _loadData();
                                      } catch (error) {
                                        if (kDebugMode)
                                          print(
                                            'Save/Update teacher error: $error',
                                          );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${languageProvider.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(error)}',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          ColorUtils.corporateBlue600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      elevation: 2,
                                      shadowColor: ColorUtils.corporateBlue600
                                          .withValues(alpha: 0.4),
                                    ),
                                    child: Text(
                                      AppLocalizations.save.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
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
                );
              },
            );
          },
        ),
      );
    }

    // Show dialog with already-parsed subject IDs
    // (parsed in initialization at line 784-791)
    showDialogWithSubjects(selectedSubjectIds);
  }

  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
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
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget buildDialogDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
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
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }

  Future<void> deleteTeacher(Map<String, dynamic> teacher) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete Teacher',
          'id': 'Hapus Guru',
        }),
        content: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Are you sure you want to delete this teacher?',
          'id': 'Apakah Anda yakin ingin menghapus guru ini?',
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
        final teacherId = teacher['id']?.toString();
        if (teacherId != null && teacherId.isNotEmpty) {
          await _teacherService.deleteTeacher(teacherId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.read<LanguageProvider>().getTranslatedText({
                    'en': 'Teacher successfully deleted',
                    'id': 'Guru berhasil dihapus',
                  }),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadData();
        }
      } catch (error) {
        if (kDebugMode) print('Delete teacher error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.read<LanguageProvider>().getTranslatedText({'en': 'Failed to delete teacher: ', 'id': 'Gagal menghapus guru: '})}${ErrorUtils.getFriendlyMessage(error)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void navigateToDetail(Map<String, dynamic> teacher) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherDetailScreen(teacher: teacher),
      ),
    );
  }

  Widget buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final languageProvider = context.read<LanguageProvider>();
    final isHomeroomTeacher =
        (teacher['homeroom_class'] != null &&
            teacher['homeroom_class'] is! List) ||
        (teacher['homeroom_class'] is List &&
            (teacher['homeroom_class'] as List).isNotEmpty);
    final className = (teacher['homeroom_class'] is Map)
        ? teacher['homeroom_class']['name']
        : (teacher['homeroom_class'] is List &&
              (teacher['homeroom_class'] as List).isNotEmpty)
        ? teacher['homeroom_class'][0]['name']
        : (teacher['homeroom_class_name'] ?? '-');
    final email = teacher['user']?['email'] ?? teacher['email'] ?? '-';
    final avatarColor = ColorUtils.getColorForIndex(index);
    final isReadOnly = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).isReadOnly;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => navigateToDetail(teacher),
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
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    (teacher['name'] ?? 'N')[0].toUpperCase(),
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
                        teacher['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (isHomeroomTeacher && className != '-') ...[
                        _buildInfoTag(Icons.class_outlined, className),
                        SizedBox(height: 4),
                      ],
                      _buildInfoTag(Icons.email_outlined, email),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Status chip + action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isHomeroomTeacher)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.corporateBlue600.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ColorUtils.corporateBlue600.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: ColorUtils.corporateBlue600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Homeroom',
                                'id': 'Wali Kelas',
                              }),
                              style: TextStyle(
                                color: ColorUtils.corporateBlue600,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.success600.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ColorUtils.success600.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: ColorUtils.success600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Active',
                                'id': 'Aktif',
                              }),
                              style: TextStyle(
                                color: ColorUtils.success600,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isReadOnly) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => showAddEditDialog(teacher: teacher),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: ColorUtils.corporateBlue600.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: ColorUtils.corporateBlue600,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          InkWell(
                            onTap: () => deleteTeacher(teacher),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: ColorUtils.error600.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: ColorUtils.error600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.7)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_errorMessage != null) {
          return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
        }

        // Local filtering removed - relying on backend search
        final displayedTeachers = _teachers;

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header
              GradientPageHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Teacher Management',
                  'id': 'Manajemen Guru',
                }),
                subtitle: languageProvider.getTranslatedText({
                  'en': 'Manage and monitor teachers',
                  'id': 'Kelola dan pantau guru',
                }),
                primaryColor: getPrimaryColor(),
                actionMenu: PopupMenuButton<String>(
                  key: _menuKey,
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _forceRefresh();
                        break;
                      case 'export':
                        exportToExcel();
                        break;
                      case 'import':
                        importFromExcel();
                        break;
                      case 'template':
                        downloadTemplate();
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
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Refresh Data',
                              'id': 'Perbarui Data',
                            }),
                          ),
                        ],
                      ),
                    ),
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
                searchBar: Row(
                  children: [
                    Expanded(
                      child: Container(
                        key: _searchKey,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
                                    'en': 'Search teachers...',
                                    'id': 'Cari guru...',
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
                                  color: getPrimaryColor(),
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
                      key: _filterKey,
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
                                  ? getPrimaryColor()
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
                filterChips: _hasActiveFilter
                    ? SizedBox(
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
                                            color: getPrimaryColor(),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: getPrimaryColor(),
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: getPrimaryColor()
                                            .withValues(alpha: 0.1),
                                        side: BorderSide(
                                          color: getPrimaryColor().withValues(
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
                      )
                    : null,
              ),
              SizedBox(height: 8),
              Expanded(
                child: _isLoading && _teachers.isEmpty
                    ? SkeletonListLoading(itemCount: 6, infoTagCount: 2)
                    : displayedTeachers.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No teachers',
                          'id': 'Tidak ada guru',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a teacher',
                                'id': 'Tap + untuk menambah guru',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.person_outline,
                      )
                    : RefreshIndicator(
                        onRefresh: onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              displayedTeachers.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == displayedTeachers.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final teacher = displayedTeachers[index];
                            return buildTeacherCard(teacher, index);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton:
              Provider.of<AcademicYearProvider>(context).isReadOnly
              ? null
              : FloatingActionButton(
                  key: _fabKey,
                  onPressed: () => showAddEditDialog(),
                  backgroundColor: getPrimaryColor(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 20),
                ),
        );
      },
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      // ─── Cache-first: skip API if tour already dismissed ───
      const tourCacheKey = 'tour_teacher_admin_screen_admin';
      try {
        final cached = await LocalCacheService.load(
          tourCacheKey,
          ttl: const Duration(hours: 24),
        );
        if (cached != null && cached['should_show'] == false) {
          if (kDebugMode) print('⚡ Teacher admin tour skipped (cached)');
          return;
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Tour cache load failed: $e');
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'admin',
        name: 'teacher_admin_tour',
      );

      // Non-blocking cache save
      LocalCacheService.save(tourCacheKey, status);

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];

        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = context.read<LanguageProvider>();

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_teacher_admin_screen_admin', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_teacher_admin_screen_admin', {'should_show': false});
        }
        return true;
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

    targets.add(
      TargetFocus(
        identify: "TeacherMenu",
        keyTarget: _menuKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Teacher Data Tools',
                      'id': 'Alat Data Guru',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Export, import, or download teacher templates from this menu.',
                        'id':
                            'Ekspor, impor, atau unduh template data guru dari menu ini.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "TeacherSearch",
        keyTarget: _searchKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Find Teachers',
                      'id': 'Cari Guru',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Search by name or email to quickly find a specific teacher.',
                        'id':
                            'Cari berdasarkan nama atau email untuk menemukan guru tertentu dengan cepat.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "TeacherFilter",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Filter Options',
                      'id': 'Opsi Filter',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Filter by class, gender, or employment status.',
                        'id':
                            'Filter berdasarkan kelas, jenis kelamin, atau status kepegawaian.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "AddTeacher",
        keyTarget: _fabKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Add Teacher',
                      'id': 'Tambah Guru',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Tap here to add a new teacher record.',
                        'id': 'Ketuk di sini untuk menambahkan data guru baru.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}
