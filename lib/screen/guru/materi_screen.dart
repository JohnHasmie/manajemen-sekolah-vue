import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/enhanced_search_bar.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class MateriPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;

  const MateriPage({
    super.key,
    required this.teacher,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
  });

  @override
  MateriPageState createState() => MateriPageState();
}

class MateriPageState extends State<MateriPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedSubject;
  List<dynamic> _subjectList = [];
  List<dynamic> _materiList = [];
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  List<dynamic> _contentMateriList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['All', 'Today', 'This Week'];
  String _selectedFilter = 'All';

  // State untuk expanded/collapsed
  final Map<String, bool> _expandedBab = {};

  // State untuk ceklis
  final Map<String, bool> _checkedBab = {};
  final Map<String, bool> _checkedSubBab = {};

  // State untuk generated (sudah pernah di-generate)
  final Map<String, bool> _generatedBab = {};
  final Map<String, bool> _generatedSubBab = {};

  // State untuk used (sudah digunakan di class activity) - Blue Check
  final Map<String, bool> _usedBab = {};
  final Map<String, bool> _usedSubBab = {};

  // Fungsi untuk mendapatkan bab yang dicentang tapi belum di-generate
  List<Map<String, dynamic>> _getCheckedNotGeneratedBab() {
    return _babMateriList
        .where((bab) {
          final hasSubChapters = _subBabMateriList.any(
            (sb) => sb['bab_id'].toString() == bab['id'].toString(),
          );

          return _checkedBab[bab['id']] == true &&
              _generatedBab[bab['id']] != true &&
              !hasSubChapters; // Only include if it has NO sub-chapters
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk mendapatkan sub bab yang dicentang tapi belum di-generate
  List<Map<String, dynamic>> _getCheckedNotGeneratedSubBab() {
    return _subBabMateriList
        .where(
          (subBab) =>
              _checkedSubBab[subBab['id']] == true &&
              _generatedSubBab[subBab['id']] != true,
        )
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk navigate ke halaman class activity dengan bab yang dipilih
  void _navigateToGenerateRPP() async {
    // Gunakan yang belum di-generate
    final checkedBab = _getCheckedNotGeneratedBab();
    final checkedSubBab = _getCheckedNotGeneratedSubBab();

    if (checkedBab.isEmpty && checkedSubBab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pilih minimal 1 bab atau sub bab untuk di-generate'),
        ),
      );
      return;
    }

    String? selectedBabId;
    String? selectedSubBabId;

    // If sub bab is selected, get its parent bab and the sub bab itself
    if (checkedSubBab.isNotEmpty) {
      final firstSubBab = checkedSubBab.first;
      selectedSubBabId = firstSubBab['id']?.toString();
      selectedBabId = firstSubBab['bab_id']?.toString();

      if (kDebugMode) {
        print(
          'Selected sub bab: $selectedSubBabId, parent bab: $selectedBabId',
        );
      }
    }
    // If only bab is selected (no sub bab)
    else if (checkedBab.isNotEmpty) {
      selectedBabId = checkedBab.first['id']?.toString();

      if (kDebugMode) {
        print('Selected bab only: $selectedBabId');
      }
    }

    // Prepare additional materials (all checked sub-chapters)
    // We pass ALL checked sub-chapters as "additional" materials.
    // The activity form logic will filter out the primary one if needed.
    List<Map<String, dynamic>> additionalMaterials = [];
    if (checkedSubBab.isNotEmpty) {
      for (var sub in checkedSubBab) {
        additionalMaterials.add({
          'chapter_id': sub['bab_id'],
          'sub_chapter_id': sub['id'],
        });
      }
    }

    // Prepare list to mark as generated upon success
    final List<Map<String, dynamic>> materialsToMarkAsGenerated = [];
    for (var bab in checkedBab) {
      materialsToMarkAsGenerated.add({'bab_id': bab['id'], 'sub_bab_id': null});
    }
    for (var subBab in checkedSubBab) {
      materialsToMarkAsGenerated.add({
        'bab_id': subBab['bab_id'],
        'sub_bab_id': subBab['id'],
      });
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassActifityScreen(
          initialSubjectId: _selectedSubject,
          initialSubjectName: _getSelectedSubjectName(),
          initialClassId: widget.initialClassId,
          initialClassName: widget.initialClassName,
          initialBabId: selectedBabId,
          initialSubBabId: selectedSubBabId,
          initialAdditionalMaterials: additionalMaterials,
          materialsToMarkAsGenerated: materialsToMarkAsGenerated,
          autoShowActivityDialog: true,
        ),
      ),
    );

    // Refresh data after returning
    if (mounted && _selectedSubject != null) {
      _loadBabMateri(_selectedSubject!);
    }
  }

  // Mark selected materials as generated
  Future<void> _markSelectedAsGenerated(
    List<Map<String, dynamic>> babs,
    List<Map<String, dynamic>> subBabs,
  ) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      final List<Map<String, dynamic>> items = [];

      // Add babs
      for (var bab in babs) {
        items.add({'bab_id': bab['id'], 'sub_bab_id': null});
      }

      // Add sub-babs
      for (var subBab in subBabs) {
        items.add({'bab_id': subBab['bab_id'], 'sub_bab_id': subBab['id']});
      }

      if (items.isEmpty) return;

      await ApiSubjectService.markMateriGenerated({
        'guru_id': teacherId,
        'mata_pelajaran_id': _selectedSubject,
        'items': items,
      });

      // Update local state
      setState(() {
        for (var bab in babs) {
          _generatedBab[bab['id']] = true;
        }
        for (var subBab in subBabs) {
          _generatedSubBab[subBab['id']] = true;
        }
      });

      if (kDebugMode) {
        print('Marked ${items.length} items as generated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as generated: $e');
      }
    }
  }

  bool _isLoading = false;
  String _debugInfo = '';

  // Color scheme matching teaching schedule
  final Map<String, Color> _hariColorMap = {
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

    if (kDebugMode) {
      print('Teacher data received: ${widget.teacher}');
    }
    if (kDebugMode) {
      print('Teacher ID: ${widget.teacher['id']}');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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

      final String? teacherId = widget.teacher['id'];
      if (kDebugMode) {
        print('Loading data for teacher ID: $teacherId');
      }

      if (teacherId == null || teacherId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: ID guru tidak valid')),
        );
        return;
      }

      final ApiTeacherService apiTeacherService = ApiTeacherService();
      final subject = await apiTeacherService.getSubjectByTeacher(teacherId);

      if (kDebugMode) {
        print('Mata pelajaran found: ${subject.length}');
      }

      // Jika guru tidak memiliki mata pelajaran, tampilkan pesan
      if (subject.isEmpty) {
        setState(() {
          _isLoading = false;
          _subjectList = [];
          _debugInfo = 'Guru ini belum memiliki mata pelajaran yang ditugaskan';
        });
        return;
      }

      final materi = await ApiSubjectService.getMateri(teacherId: teacherId);

      setState(() {
        _subjectList = subject;
        _materiList = materi;
        _isLoading = false;
        _debugInfo = '${subject.length} mata pelajaran ditemukan';

        // Use initialSubjectId if provided, otherwise use first subject
        if (widget.initialSubjectId != null &&
            subject.any((mp) => mp['id'] == widget.initialSubjectId)) {
          _selectedSubject = widget.initialSubjectId;
          _loadBabMateri(_selectedSubject!);
        } else if (subject.isNotEmpty) {
          _selectedSubject = subject[0]['id'];
          _loadBabMateri(_selectedSubject!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugInfo = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _loadBabMateri(String subjectId) async {
    try {
      final babMateri = await ApiSubjectService.getBabMateri(
        subjectId: subjectId,
      );

      // Pre-fetch all sub-chapters for these babs in parallel
      final List<Future<List<dynamic>>> futures = [];
      for (var bab in babMateri) {
        futures.add(
          ApiSubjectService.getSubBabMateri(babId: bab['id'].toString()),
        );
      }

      final List<List<dynamic>> allSubBabsResults = await Future.wait(futures);

      setState(() {
        _babMateriList = babMateri;
        // Clear sub bab list when changing subject
        _subBabMateriList.clear();

        // Add all fetched sub-chapters to the list
        for (var subBabs in allSubBabsResults) {
          _subBabMateriList.addAll(subBabs);
        }

        // Clear expanded, checked, and generated states
        _expandedBab.clear();
        _checkedBab.clear();
        _checkedSubBab.clear();
        _generatedBab.clear();
        _generatedSubBab.clear();
        _usedBab.clear(); // Clear used state
        _usedSubBab.clear(); // Clear used state

        // Inisialisasi state expanded dan checked untuk setiap bab
        for (var bab in babMateri) {
          _expandedBab[bab['id'].toString()] = false;
          _checkedBab[bab['id'].toString()] = false;
          _generatedBab[bab['id'].toString()] = false;
          _usedBab[bab['id'].toString()] = false; // Initialize used state
        }

        // Inisialisasi state checked untuk setiap sub-bab
        for (var subBab in _subBabMateriList) {
          _checkedSubBab[subBab['id'].toString()] = false;
        }

        _debugInfo =
            '${babMateri.length} bab materi, ${_subBabMateriList.length} sub-bab ditemukan';
      });

      // Load progress dari database
      await _loadMateriProgress(subjectId);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading bab and sub-bab: $e');
      }
      setState(() {
        _debugInfo = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Fungsi untuk menangani perubahan ceklis pada sub bab
  void _handleSubBabCheck(String subBabId, String babId, bool? value) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedSubBab[subBabId] == true || _usedSubBab[subBabId] == true) &&
        value == false) {
      return;
    }

    setState(() {
      _checkedSubBab[subBabId] = value ?? false;

      // Cek apakah semua sub bab dalam bab ini sudah dicentang
      // Ambil daftar sub bab yang dimiliki oleh babId ini
      final subBabsForThisBab = _subBabMateriList.where((sb) {
        return sb['bab_id'].toString() == babId.toString();
      }).toList();

      if (subBabsForThisBab.isNotEmpty) {
        // Cek apakah setiap sub bab sudah dicentang
        final allChecked = subBabsForThisBab.every((sb) {
          final sbId = sb['id'].toString();
          return _checkedSubBab[sbId] == true;
        });

        // Update status ceklis bab
        _checkedBab[babId] = allChecked;

        if (kDebugMode) {
          print('SubBab check changed: $subBabId -> $value');
          print('Bab $babId auto-check status: $allChecked');
        }
      }
    });

    // Save to database
    _saveProgress(babId, subBabId, value ?? false);
  }

  // Fungsi untuk menangani perubahan ceklis pada bab
  void _handleBabCheck(String babId, bool? value) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedBab[babId] == true || _usedBab[babId] == true) &&
        value == false) {
      return;
    }

    setState(() {
      _checkedBab[babId] = value ?? false;

      // Update sub-babs logic:
      // If checking Bab (True): Check all sub-babs.
      // If unchecking Bab (False): Uncheck all sub-babs EXCEPT those that are Generated (Purple).
      for (var subBab in _subBabMateriList.where(
        (subBab) => subBab['bab_id'] == babId,
      )) {
        if (value == true) {
          _checkedSubBab[subBab['id']] = true;
        } else {
          // If unchecking, only uncheck if NOT generated and NOT used
          if (_generatedSubBab[subBab['id']] != true &&
              _usedSubBab[subBab['id']] != true) {
            _checkedSubBab[subBab['id']] = false;
          }
        }
      }
    });

    // Save to database (bab and all its sub-babs)
    _saveBabAndSubBabsProgress(babId, value ?? false);
  }

  // Load materi progress from database
  Future<void> _loadMateriProgress(String mataPelajaranId) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null) return;

      final progress = await ApiSubjectService.getMateriProgress(
        guruId: teacherId,
        mataPelajaranId: mataPelajaranId,
      );

      if (kDebugMode) {
        print('Loaded progress: ${progress.length} items');
      }

      setState(() {
        // Apply checked and generated state from database
        for (var item in progress) {
          final babId = item['bab_id'];
          final subBabId = item['sub_bab_id'];
          final isChecked =
              item['is_checked'] == 1 || item['is_checked'] == true;
          final isGenerated =
              item['is_generated'] == 1 || item['is_generated'] == true;
          final isUsed = item['is_used'] == 1 || item['is_used'] == true;

          if (subBabId != null) {
            // Sub bab checked and generated status
            _checkedSubBab[subBabId.toString()] = isChecked;
            _generatedSubBab[subBabId.toString()] = isGenerated;
            _usedSubBab[subBabId.toString()] = isUsed;
          } else if (babId != null) {
            // Bab checked and generated status (no specific sub bab)
            _checkedBab[babId.toString()] = isChecked;
            _generatedBab[babId.toString()] = isGenerated;
            _usedBab[babId.toString()] = isUsed;
          }
        }

        // Final pass: Recalculate Bab status based on Sub-Babs
        // This ensures visual correctness even if Bab record is absent in DB
        for (var bab in _babMateriList) {
          final babId = bab['id'].toString();
          final subBabsForThisBab = _subBabMateriList
              .where((sb) => sb['bab_id'].toString() == babId)
              .toList();

          if (subBabsForThisBab.isNotEmpty) {
            final allSubBabsChecked =
                subBabsForThisBab.isNotEmpty &&
                subBabsForThisBab.every(
                  (sb) => _checkedSubBab[sb['id'].toString()] == true,
                );
            _checkedBab[babId] = allSubBabsChecked;
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading progress: $e');
      }
    }
  }

  // Save single progress to database
  Future<void> _saveProgress(
    String babId,
    String? subBabId,
    bool isChecked,
  ) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      await ApiSubjectService.saveMateriProgress({
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
        'chapter_id': babId,
        'sub_chapter_id': subBabId,
        'is_checked': isChecked,
      });

      if (kDebugMode) {
        print(
          'Progress saved: bab=$babId, sub_bab=$subBabId, checked=$isChecked',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving progress: $e');
      }
    }
  }

  // Save bab and all its sub-babs progress to database
  Future<void> _saveBabAndSubBabsProgress(String babId, bool isChecked) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      // Prepare batch items
      final List<Map<String, dynamic>> progressItems = [];

      // Debug sub-bab count
      final subBabsForThisBab = _subBabMateriList
          .where((sb) => sb['bab_id'].toString() == babId.toString())
          .toList();

      if (kDebugMode) {
        print('Found ${subBabsForThisBab.length} sub-babs for bab $babId');
      }

      // Add bab itself ONLY if it has NO sub-chapters
      // If it has sub-chapters, its status is derived and shouldn't be saved explicitly
      if (subBabsForThisBab.isEmpty) {
        progressItems.add({
          'chapter_id': babId,
          'sub_chapter_id': null,
          'is_checked': isChecked,
        });
      }

      // Add all sub-babs of this bab
      for (var subBab in subBabsForThisBab) {
        // Respect locks: If unchecking, don't include if Generated or Used
        if (isChecked == false) {
          final isGenerated = _generatedSubBab[subBab['id']] == true;
          final isUsed = _usedSubBab[subBab['id']] == true;
          if (isGenerated || isUsed) continue;
        }

        progressItems.add({
          'chapter_id': babId,
          'sub_chapter_id': subBab['id'],
          'is_checked': isChecked,
        });
      }

      // Batch save
      await ApiSubjectService.batchSaveMateriProgress({
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
        'progress_items': progressItems,
      });

      if (kDebugMode) {
        print('Batch progress saved: ${progressItems.length} items');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error batch saving progress: $e');
      }
    }
  }

  // Navigasi ke halaman detail sub bab
  void _navigateToSubBabDetail(
    Map<String, dynamic> subBab,
    Map<String, dynamic> bab,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubBabDetailPage(
          subBab: subBab,
          bab: bab,
          checked: _checkedSubBab[subBab['id'].toString()] ?? false,
          onCheckChanged: (value) {
            _handleSubBabCheck(
              subBab['id'].toString(),
              bab['id'].toString(),
              value,
            );
          },
        ),
      ),
    );
  }

  Color _getCardColor(int index) {
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  List<dynamic> _getFilteredBabMateri() {
    final searchTerm = _searchController.text.toLowerCase();

    if (searchTerm.isEmpty) {
      return _babMateriList;
    }

    return _babMateriList.where((bab) {
      final matchesBab =
          (bab['judul_bab']?.toString().toLowerCase().contains(searchTerm) ??
          false);

      // Cari juga di sub bab yang terkait
      final subBabMatches = _subBabMateriList
          .where((subBab) => subBab['bab_id'] == bab['id'])
          .any(
            (subBab) =>
                subBab['judul_sub_bab']?.toString().toLowerCase().contains(
                  searchTerm,
                ) ??
                false,
          );

      return matchesBab || subBabMatches;
    }).toList();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.7)],
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
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
                onTap: () => Navigator.pop(context),
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
                      languageProvider.getTranslatedText({
                        'en': 'Learning Materials',
                        'id': 'Materi Pembelajaran',
                      }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.selectAndOrganizeMaterials.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.auto_awesome, color: Colors.white),
                onPressed: _navigateToGenerateRPP,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Generate RPP',
                  'id': 'Generate RPP',
                }),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Refresh',
                  'id': 'Muat Ulang',
                }),
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
        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header dengan gradient seperti presence_teacher
              _buildHeader(languageProvider),

              // Filter Section
              _buildFilterSection(languageProvider),

              // Search Bar
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) {
                  final translatedFilterOptions = [
                    languageProvider.getTranslatedText({
                      'en': 'All',
                      'id': 'Semua',
                    }),
                    languageProvider.getTranslatedText({
                      'en': 'Today',
                      'id': 'Hari Ini',
                    }),
                    languageProvider.getTranslatedText({
                      'en': 'This Week',
                      'id': 'Minggu Ini',
                    }),
                  ];

                  return EnhancedSearchBar(
                    controller: _searchController,
                    hintText: languageProvider.getTranslatedText({
                      'en': 'Search materials...',
                      'id': 'Cari materi...',
                    }),
                    onChanged: (value) {
                      setState(() {});
                    },
                    filterOptions: translatedFilterOptions,
                    selectedFilter:
                        translatedFilterOptions[_selectedFilter == 'All'
                            ? 0
                            : _selectedFilter == 'Today'
                            ? 1
                            : 2],
                    onFilterChanged: (filter) {
                      final index = translatedFilterOptions.indexOf(filter);
                      setState(() {
                        _selectedFilter = index == 0
                            ? 'All'
                            : index == 1
                            ? 'Today'
                            : 'This Week';
                      });
                    },
                    showFilter: true,
                  );
                },
              ),

              // Search Results Info
              if (_searchController.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_getFilteredBabMateri().length} ${languageProvider.getTranslatedText({'en': 'materials found', 'id': 'materi ditemukan'})}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 8),

              // Content Section
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading materials...',
                          'id': 'Memuat materi...',
                        }),
                      )
                    : _selectedSubject == null
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'Select subject to view materials',
                          'id': 'Pilih mata pelajaran untuk melihat materi',
                        }),
                        languageProvider,
                      )
                    : _babMateriList.isEmpty
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'No materials available for this subject',
                          'id': 'Tidak ada materi untuk mata pelajaran ini',
                        }),
                        languageProvider,
                      )
                    : _getFilteredBabMateri().isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No Materials Found',
                          'id': 'Materi Tidak Ditemukan',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en':
                              'No search results found for "${_searchController.text}"',
                          'id':
                              'Tidak ditemukan hasil pencarian untuk "${_searchController.text}"',
                        }),
                        icon: Icons.search,
                      )
                    : _buildMateriList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Update Filter Section untuk tambah info dan tombol
  Widget _buildFilterSection(LanguageProvider languageProvider) {
    final totalChecked = _getCheckedCount();

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Info Filter Aktif
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _subjectList.isEmpty
                        ? languageProvider.getTranslatedText({
                            'en': 'No subjects available',
                            'id': 'Tidak ada mata pelajaran',
                          })
                        : '${_babMateriList.length} ${languageProvider.getTranslatedText({'en': 'materials', 'id': 'bab materi'})} • ${_getSelectedSubjectName()}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
                Text(
                  '$totalChecked ${languageProvider.getTranslatedText({'en': 'checked', 'id': 'dicentang'})}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Tombol Generate RPP jika ada yang dicentang
          if (totalChecked > 0 && _getCheckedNotGeneratedCount() > 0) ...[
            // Tombol Generate (untuk yang baru / belum di-generate)
            ElevatedButton.icon(
              onPressed: _navigateToGenerateRPP,
              icon: Icon(Icons.auto_awesome, size: 18),
              label: Text(
                'Generate RPP (${_getCheckedNotGeneratedCount()})',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 12),
          ],

          // Dropdown Mata Pelajaran
          _buildMataPelajaranDropdown(languageProvider),
        ],
      ),
    );
  }

  Widget _buildMataPelajaranDropdown(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubject,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              items: _subjectList.map((mp) {
                return DropdownMenuItem<String>(
                  value: mp['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subject,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(mp['nama'] ?? 'Unknown')),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedSubject = newValue;
                    _babMateriList = [];
                    _subBabMateriList = [];
                    _contentMateriList = [];
                    _searchController.clear();
                  });
                  _loadBabMateri(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Materials',
        'id': 'Tidak Ada Materi',
      }),
      subtitle: message,
      icon: Icons.menu_book,
    );
  }

  Widget _buildMateriList() {
    final filteredBabMateri = _getFilteredBabMateri();

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredBabMateri.length,
      itemBuilder: (context, index) {
        final bab = filteredBabMateri[index];
        final cardColor = _getCardColor(index);
        final babIdStr = bab['id'].toString();
        final isExpanded = _expandedBab[babIdStr] ?? false;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _expandedBab[babIdStr] = !isExpanded;
                });
              },
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

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Bab
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${bab['urutan']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bab['judul_bab'] ?? 'Judul Bab',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Bab ${bab['urutan']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value:
                                    _checkedBab[bab['id'].toString()] ?? false,
                                onChanged: (value) {
                                  _handleBabCheck(bab['id'].toString(), value);
                                },
                                activeColor:
                                    _usedBab[bab['id'].toString()] == true
                                    ? Colors.blue
                                    : _generatedBab[bab['id'].toString()] ==
                                          true
                                    ? Color(0xFF8B5CF6)
                                    : Color(0xFF10B981),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),

                        // Sub Bab List (Expandable)
                        if (isExpanded) ...[
                          Divider(height: 1),
                          _buildSubBabList(bab),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubBabList(Map<String, dynamic> bab) {
    if (_subBabMateriList.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: _subBabMateriList
          .where(
            (subBab) => subBab['bab_id'].toString() == bab['id'].toString(),
          )
          .map((subBab) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getCardColor(
                        int.parse(subBab['urutan']?.toString() ?? '0'),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${subBab['urutan']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Checkbox(
                    value: _checkedSubBab[subBab['id'].toString()] ?? false,
                    onChanged: (value) {
                      _handleSubBabCheck(
                        subBab['id'].toString(),
                        bab['id'].toString(),
                        value,
                      );
                    },
                    activeColor: _usedSubBab[subBab['id'].toString()] == true
                        ? Colors.blue
                        : _generatedSubBab[subBab['id'].toString()] == true
                        ? Color(0xFF8B5CF6)
                        : Color(0xFF10B981),
                  ),
                  onTap: () {
                    _navigateToSubBabDetail(subBab, bab);
                  },
                ),
              ),
            );
          })
          .toList(),
    );
  }

  String _getSelectedSubjectName() {
    if (_selectedSubject == null) return '-';
    final mp = _subjectList.firstWhere(
      (mp) => mp['id'] == _selectedSubject,
      orElse: () => {'nama': '-'},
    );
    return mp['nama'] ?? '-';
  }

  int _getCheckedCount() {
    final babChecked = _checkedBab.values.where((checked) => checked).length;
    final subBabChecked = _checkedSubBab.values
        .where((checked) => checked)
        .length;
    return babChecked + subBabChecked;
  }

  int _getCheckedNotGeneratedCount() {
    return _getCheckedNotGeneratedBab().length +
        _getCheckedNotGeneratedSubBab().length;
  }
}

// Halaman detail untuk sub bab (diperbarui dengan design yang sama)
class SubBabDetailPage extends StatefulWidget {
  final Map<String, dynamic> subBab;
  final Map<String, dynamic> bab;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;

  const SubBabDetailPage({
    super.key,
    required this.subBab,
    required this.bab,
    required this.checked,
    required this.onCheckChanged,
  });

  @override
  SubBabDetailPageState createState() => SubBabDetailPageState();
}

class SubBabDetailPageState extends State<SubBabDetailPage> {
  late bool _isChecked;
  List<dynamic> _contentMateriList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.checked;
    _loadContentMateri();
  }

  Future<void> _loadContentMateri() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final kontenMateri = await ApiSubjectService.getContentMateri(
        subBabId: widget.subBab['id'],
      );

      setState(() {
        _contentMateriList = kontenMateri
            .where((konten) => konten['sub_bab_id'] == widget.subBab['id'])
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getCardColor(int index) {
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.7)],
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
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
                onTap: () => Navigator.pop(context),
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
                      'BAB ${widget.bab['urutan']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      widget.bab['judul_bab'] ?? 'Judul Bab',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Done',
                        'id': 'Selesai',
                      }),
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    Checkbox(
                      value: _isChecked,
                      onChanged: (value) {
                        setState(() {
                          _isChecked = value ?? false;
                        });
                        widget.onCheckChanged(value);
                      },
                      fillColor: WidgetStateProperty.all(Colors.white),
                      checkColor: _getPrimaryColor(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub Bab ${widget.subBab['urutan']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header dengan gradient
              _buildHeader(languageProvider),

              // Content
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading content...',
                          'id': 'Memuat konten...',
                        }),
                      )
                    : _contentMateriList.isEmpty
                    ? _buildEmptyContent(languageProvider)
                    : _buildContentList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyContent(LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Content',
        'id': 'Tidak Ada Konten',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Content for this sub-chapter is not available yet',
        'id': 'Konten untuk sub bab ini belum tersedia',
      }),
      icon: Icons.article,
    );
  }

  Widget _buildContentList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _contentMateriList.length,
      itemBuilder: (context, index) {
        final content = _contentMateriList[index];
        final cardColor = _getCardColor(index);

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Number Section dengan background warna
                Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Konten',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content['judul_konten'] ?? 'Judul Konten',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Text(
                          content['isi_konten'] ?? 'Isi konten tidak tersedia',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
