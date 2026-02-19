import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/enhanced_search_bar.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
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
  String? _selectedClassId;
  String? _selectedClassName;
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
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
              _usedBab[bab['id']] != true && // Exclude used
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
              _generatedSubBab[subBab['id']] != true &&
              _usedSubBab[subBab['id']] != true, // Exclude used
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
          initialClassId: _selectedClassId ?? widget.initialClassId,
          initialClassName: _selectedClassName ?? widget.initialClassName,
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
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
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

      // Load Classes Taught by Teacher
      final classes = await ApiTeacherService.getTeacherClasses(teacherId);

      // Sort classes numerically/alphabetically (e.g., 7A, 7B, 8A)
      classes.sort((a, b) {
        String nameA = (a['name'] ?? a['nama'] ?? '').toString();
        String nameB = (b['name'] ?? b['nama'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

      if (kDebugMode) {
        print('Classes found: ${classes.length}');
      }

      // Jika guru tidak memiliki mata pelajaran, tampilkan pesan
      if (subject.isEmpty) {
        setState(() {
          _isLoading = false;
          _subjectList = [];
          _classList = classes;
          _debugInfo = 'Guru ini belum memiliki mata pelajaran yang ditugaskan';
        });
        return;
      }

      final materi = await ApiSubjectService.getMateri(teacherId: teacherId);

      setState(() {
        _subjectList = subject;
        _classList = classes;
        _materiList = materi;
        _isLoading = false;
        _debugInfo = '${subject.length} mata pelajaran ditemukan';

        // Set initial class
        if (widget.initialClassId != null &&
            classes.any((c) => c['id'] == widget.initialClassId)) {
          _selectedClassId = widget.initialClassId;
          _selectedClassName = widget.initialClassName;
        } else if (classes.isNotEmpty) {
          _selectedClassId = classes[0]['id'];
          _selectedClassName = classes[0]['name'] ?? classes[0]['nama'];
        }

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
      if (kDebugMode) {
        print('Error loading MateriPage data: $e');
      }
      setState(() {
        _isLoading = false;
        _debugInfo = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadBabMateri(String subjectId) async {
    try {
      // Find Master Subject ID from the selected School Subject ID
      final subject = _subjectList.firstWhere(
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

      final babMateri = await ApiSubjectService.getBabMateri(
        subjectId: masterSubjectId,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
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
        classId: _selectedClassId,
      );

      if (kDebugMode) {
        print('=== LOADING MATERI PROGRESS ===');
        print('Teacher ID: $teacherId');
        print('Subject ID: $mataPelajaranId');
        print('API Response Items: ${progress.length}');
        if (progress.isNotEmpty) {
          print('First item sample: ${progress.first}');
        }
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
        'class_id': _selectedClassId,
        'chapter_id': babId,
        'sub_chapter_id': subBabId,
        'is_checked': isChecked ? 1 : 0,
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
          'bab_id': babId,
          'sub_bab_id': null,
          'is_checked': isChecked ? 1 : 0,
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
          'bab_id': babId,
          'sub_bab_id': subBab['id'],
          'is_checked': isChecked ? 1 : 0,
        });
      }

      // Batch save
      await ApiSubjectService.batchSaveMateriProgress({
        'guru_id': teacherId,
        'mata_pelajaran_id': _selectedSubject,
        'class_id': _selectedClassId,
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
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
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
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _navigateToGenerateRPP,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _loadData,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
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
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
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
                        style: TextStyle(color: ColorUtils.slate500, fontSize: 14),
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

  Widget _buildFilterSection(LanguageProvider languageProvider) {
    final totalChecked = _getCheckedCount();
    final primaryColor = _getPrimaryColor();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200, width: 1)),
      ),
      child: Column(
        children: [
          // Info Filter Aktif
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.filter_alt_rounded, size: 16, color: primaryColor),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _subjectList.isEmpty
                        ? languageProvider.getTranslatedText({
                            'en': 'No subjects available',
                            'id': 'Tidak ada mata pelajaran',
                          })
                        : '${_babMateriList.length} ${languageProvider.getTranslatedText({'en': 'materials', 'id': 'bab materi'})} • ${_getSelectedSubjectName()}',
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate700),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalChecked ${languageProvider.getTranslatedText({'en': 'checked', 'id': 'dicentang'})}',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Tombol Generate RPP jika ada yang dicentang
          if (totalChecked > 0 && _getCheckedNotGeneratedCount() > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToGenerateRPP,
                icon: Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  'Generate RPP (${_getCheckedNotGeneratedCount()})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.success600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: 12),
          ],

          // Dropdown Kelas
          _buildKelasDropdown(languageProvider),
          SizedBox(height: 12),

          // Dropdown Mata Pelajaran
          _buildMataPelajaranDropdown(languageProvider),
        ],
      ),
    );
  }

  Widget _buildKelasDropdown(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorUtils.slate600),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedClassId,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate500),
              items: _classList.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.class_rounded,
                          size: 16,
                          color: ColorUtils.slate500,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c['name'] ?? c['nama'] ?? 'Unknown',
                            style: TextStyle(color: ColorUtils.slate800, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedClassId = newValue;
                    final selectedClass = _classList.firstWhere(
                      (c) => c['id'] == newValue,
                    );
                    _selectedClassName =
                        selectedClass['name'] ?? selectedClass['nama'];
                    _babMateriList = [];
                    _subBabMateriList = [];
                    _searchController.clear();
                  });
                  if (_selectedSubject != null) {
                    _loadBabMateri(_selectedSubject!);
                  }
                }
              },
            ),
          ),
        ),
      ],
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorUtils.slate600),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubject,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate500),
              items: _subjectList.map((mp) {
                return DropdownMenuItem<String>(
                  value: mp['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: ColorUtils.slate500,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mp['name'] ?? mp['nama'] ?? 'Unknown',
                            style: TextStyle(color: ColorUtils.slate800, fontSize: 14),
                          ),
                        ),
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

  Color _getCheckboxColor(String id, {bool isSubBab = false}) {
    if (isSubBab) {
      if (_usedSubBab[id] == true) return ColorUtils.info600;
      if (_generatedSubBab[id] == true) return Color(0xFF8B5CF6);
      return ColorUtils.success600;
    } else {
      if (_usedBab[id] == true) return ColorUtils.info600;
      if (_generatedBab[id] == true) return Color(0xFF8B5CF6);
      return ColorUtils.success600;
    }
  }

  Widget _buildMateriList() {
    final filteredBabMateri = _getFilteredBabMateri();

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredBabMateri.length,
      itemBuilder: (context, index) {
        final bab = filteredBabMateri[index];
        final cardColor = ColorUtils.getColorForIndex(index);
        final babIdStr = bab['id'].toString();
        final isExpanded = _expandedBab[babIdStr] ?? false;

        return Container(
          margin: EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _expandedBab[babIdStr] = !isExpanded;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorUtils.slate200),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cardColor.withValues(alpha: 0.25)),
                            ),
                            child: Center(
                              child: Text(
                                '${bab['urutan']}',
                                style: TextStyle(
                                  color: cardColor,
                                  fontWeight: FontWeight.w700,
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: ColorUtils.slate900,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Bab ${bab['urutan']}',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: _checkedBab[babIdStr] ?? false,
                            onChanged: (value) {
                              _handleBabCheck(babIdStr, value);
                            },
                            activeColor: _getCheckboxColor(babIdStr),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: ColorUtils.slate500,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sub Bab List (Expandable)
                    if (isExpanded) ...[
                      Divider(height: 1, color: ColorUtils.slate200),
                      _buildSubBabList(bab),
                    ],
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
    final subBabsForBab = _subBabMateriList
        .where((subBab) => subBab['bab_id'].toString() == bab['id'].toString())
        .toList();

    if (subBabsForBab.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(color: ColorUtils.slate400),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: subBabsForBab.map((subBab) {
        final subBabIdStr = subBab['id'].toString();
        final subBabColor = ColorUtils.getColorForIndex(
          int.parse(subBab['urutan']?.toString() ?? '0'),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToSubBabDetail(subBab, bab),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: subBabColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: subBabColor.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Text(
                        '${subBab['urutan']}',
                        style: TextStyle(
                          color: subBabColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ColorUtils.slate800,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: _checkedSubBab[subBabIdStr] ?? false,
                    onChanged: (value) {
                      _handleSubBabCheck(
                        subBabIdStr,
                        bab['id'].toString(),
                        value,
                      );
                    },
                    activeColor: _getCheckboxColor(subBabIdStr, isSubBab: true),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: ColorUtils.slate400,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
            .where(
              (konten) =>
                  (konten['sub_chapter_id'] ?? konten['sub_bab_id']) ==
                  widget.subBab['id'],
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading content materi: $e');
      }
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
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
                      'BAB ${widget.bab['urutan']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
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
              GestureDetector(
                onTap: () {
                  final newValue = !_isChecked;
                  setState(() {
                    _isChecked = newValue;
                  });
                  widget.onCheckChanged(newValue);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isChecked
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isChecked ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Done',
                          'id': 'Selesai',
                        }),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description_rounded, color: Colors.white, size: 16),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub Bab ${widget.subBab['urutan']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
          backgroundColor: ColorUtils.slate50,
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
        final cardColor = ColorUtils.getColorForIndex(index);

        return Container(
          margin: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardColor.withValues(alpha: 0.25)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: cardColor,
                        fontWeight: FontWeight.w700,
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
                        content['judul_konten'] ??
                            content['title'] ??
                            'Judul Konten',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      Text(
                        content['isi_konten'] ??
                            content['description'] ??
                            'Isi konten tidak tersedia',
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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
  }
}
