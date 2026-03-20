// Report card detail/editing screen for a specific student.
// Like `pages/teacher/Raport/Detail.vue` in a Vue app.
//
// A tabbed form (4 tabs: Academic, Extracurricular, Character, Info) where
// teachers fill in grades, descriptions, attendance counts, and promotion
// decisions. Supports draft saving and finalization.
// In Laravel terms: `RaportController@show` + `@update`.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/screen/guru/raport_print_screen.dart';
import 'package:manajemensekolah/services/api_raport_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../providers/academic_year_provider.dart';

/// Report card detail form for a single student.
///
/// A complex multi-tab form with academic grades, extracurriculars,
/// character assessment, and attendance/promotion info. Tracks unsaved
/// changes and warns before navigation (like Vue `beforeRouteLeave`).
///
/// Props (like Vue props): [studentClassId], [studentName], [className].
class RaportDetailScreen extends StatefulWidget {
  final String studentClassId;
  final String studentName;
  final String className;

  const RaportDetailScreen({
    super.key,
    required this.studentClassId,
    required this.studentName,
    required this.className,
  });

  @override
  State<RaportDetailScreen> createState() => _RaportDetailScreenState();
}

/// State for [RaportDetailScreen].
///
/// Like a Vue component with `data() { return {...} }` containing form
/// controllers, tab state, and save/submit flags. Uses
/// `SingleTickerProviderStateMixin` for the 4-tab TabController.
///
/// Key state: form controllers for sikap (character), attendance counts,
/// notes, lists of subjects/extras/achievements, and unsaved change tracking.
class _RaportDetailScreenState extends State<RaportDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  bool _hasUnsavedChanges = false;

  // Data Containers
  Map<String, dynamic>? _existingRaport;

  // Form Controllers - Sikap
  final TextEditingController _spiritualDescCtrl = TextEditingController();
  final TextEditingController _socialDescCtrl = TextEditingController();
  String _spiritualPredicate = 'Baik';
  String _socialPredicate = 'Baik';

  // Form Controllers - Info
  final TextEditingController _sickCtrl = TextEditingController(text: '0');
  final TextEditingController _permitCtrl = TextEditingController(text: '0');
  final TextEditingController _absentCtrl = TextEditingController(text: '0');
  final TextEditingController _notesCtrl = TextEditingController();
  String _promotionDecision = 'Naik Kelas';

  // Lists
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _extras = [];
  List<Map<String, dynamic>> _achievements = [];

  final List<String> _predicates = ['Sangat Baik', 'Baik', 'Cukup', 'Kurang'];
  final List<String> _decisions = ['Naik Kelas', 'Tinggal di Kelas'];

  final GlobalKey _tabKey = GlobalKey();
  final GlobalKey _saveDraftKey = GlobalKey();
  final GlobalKey _finalizeKey = GlobalKey();
  String? _tourId;

  /// Like Vue's `mounted()` -- sets up tab controller, loads raport data,
  /// and adds listeners to track unsaved changes (like Vue `watch` on form fields).
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();

    _spiritualDescCtrl.addListener(_markUnsaved);
    _socialDescCtrl.addListener(_markUnsaved);
    _sickCtrl.addListener(_markUnsaved);
    _permitCtrl.addListener(_markUnsaved);
    _absentCtrl.addListener(_markUnsaved);
    _notesCtrl.addListener(_markUnsaved);
  }

  void _markUnsaved() {
    if (!_hasUnsavedChanges && !_isLoading && mounted) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  String? _getAcademicYearId() {
    final provider = Provider.of<AcademicYearProvider>(context, listen: false);
    return (provider.selectedAcademicYear?['id'] ?? provider.activeAcademicYear?['id'])?.toString();
  }

  String _buildDetailCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'raport_detail_${widget.studentClassId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('raport_detail_${widget.studentClassId}');
    _loadData(useCache: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spiritualDescCtrl.dispose();
    _socialDescCtrl.dispose();
    _sickCtrl.dispose();
    _permitCtrl.dispose();
    _absentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Resolve semester using shared school_day_data cache, falling back to API
  Future<String> _resolveSemester() async {
    final cachedDayData = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
    if (cachedDayData != null && cachedDayData is Map) {
      if (cachedDayData.containsKey('semester') &&
          cachedDayData['semester'].toString().toLowerCase() == 'genap') {
        return '2';
      }
      return '1';
    }
    final dateBasedSemester = await ApiScheduleService.getDateBasedSemester();
    if (dateBasedSemester.isNotEmpty) {
      await LocalCacheService.save('school_day_data', dateBasedSemester);
    }
    if (dateBasedSemester.containsKey('semester') &&
        dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
      return '2';
    }
    return '1';
  }

  Future<void> _loadData({bool useCache = true}) async {
    final detailCacheKey = _buildDetailCacheKey();
    final academicYearId = _getAcademicYearId() ?? '';

    if (academicYearId.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = "Tahun ajaran tidak valid.";
          _isLoading = false;
        });
      }
      return;
    }

    // Step 1: Try cache → return early
    if (useCache) {
      final cached = await LocalCacheService.load(detailCacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        final cachedDetail = cached['existingDetail'];
        final cachedInitial = cached['initialData'];

        if (cachedDetail != null) {
          _existingRaport = Map<String, dynamic>.from(cachedDetail);
          _populateFromExisting(_existingRaport!);
          if (cachedInitial != null && cachedInitial['grades'] != null) {
            _syncSubjectsWithRecap(List<dynamic>.from(cachedInitial['grades']));
          }
        } else if (cachedInitial != null) {
          _populateFromInitial(Map<String, dynamic>.from(cachedInitial));
        }

        if (mounted && (_existingRaport != null || cachedInitial != null)) {
          setState(() {
            _isLoading = false;
            _errorMessage = '';
          });
          _checkAndShowTour();
          if (kDebugMode) print('📦 RaportDetailScreen: Data from cache');
          return;
        }
      }
    }

    // Step 2: Show loading & fetch from API
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      // Use shared school_day_data cache for semester
      final semester = await _resolveSemester();

      final existingDetail = await ApiRaportService.getRaportDetail(
        studentClassId: widget.studentClassId,
        academicYearId: academicYearId,
        semesterId: semester,
      );

      final initialData = await ApiRaportService.getInitialData(
        studentClassId: widget.studentClassId,
        academicYearId: academicYearId,
        semesterId: semester,
      );

      if (!mounted) return;

      if (existingDetail != null) {
        _existingRaport = existingDetail;
        _populateFromExisting(existingDetail);
        if (initialData != null && initialData['grades'] != null) {
          _syncSubjectsWithRecap(initialData['grades']);
        }
      } else if (initialData != null) {
        _populateFromInitial(initialData);
      } else {
        throw Exception("Gagal mengambil data awal.");
      }

      setState(() {
        _isLoading = false;
      });

      // Save to cache
      await LocalCacheService.save(detailCacheKey, {
        'existingDetail': existingDetail,
        'initialData': initialData,
      });
    } catch (e) {
      if (mounted && _subjects.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  void _populateFromExisting(Map<String, dynamic> data) {
    _spiritualPredicate = data['spiritual_predicate'] ?? 'Baik';
    _spiritualDescCtrl.text = data['spiritual_description'] ?? '';
    _socialPredicate = data['social_predicate'] ?? 'Baik';
    _socialDescCtrl.text = data['social_description'] ?? '';

    _sickCtrl.text = (data['attendance_sick'] ?? 0).toString();
    _permitCtrl.text = (data['attendance_permit'] ?? 0).toString();
    _absentCtrl.text = (data['attendance_absent'] ?? 0).toString();
    _notesCtrl.text = data['homeroom_notes'] ?? '';
    _promotionDecision = data['promotion_decision'] ?? 'Naik Kelas';

    if (data['raport_subjects'] != null) {
      _subjects = List<Map<String, dynamic>>.from(
        data['raport_subjects'].map(
          (x) => {
            'subject_id': x['subject_id'],
            'subject_name': x['subject']?['name'] ?? 'Mapel',
            'knowledge_score': x['knowledge_score']?.toString() ?? '0',
            'knowledge_predicate': x['knowledge_predicate'] ?? '',
            'knowledge_description': x['knowledge_description'] ?? '',
            'skill_score': x['skill_score']?.toString() ?? '0',
            'skill_predicate': x['skill_predicate'] ?? '',
            'skill_description': x['skill_description'] ?? '',
          },
        ),
      );
    }

    if (data['extracurriculars'] != null) {
      _extras = List<Map<String, dynamic>>.from(
        data['extracurriculars'].map(
          (x) => {
            'name': x['name'] ?? '',
            'score': x['score'] ?? '',
            'description': x['description'] ?? '',
          },
        ),
      );
    }

    if (data['achievements'] != null) {
      _achievements = List<Map<String, dynamic>>.from(
        data['achievements'].map(
          (x) => {
            'name': x['name'] ?? '',
            'type': x['type'] ?? '',
            'description': x['description'] ?? '',
          },
        ),
      );
    }
  }

  void _populateFromInitial(Map<String, dynamic> data) {
    if (data['attendance'] != null) {
      _sickCtrl.text = (data['attendance']['sick'] ?? 0).toString();
      _permitCtrl.text = (data['attendance']['permit'] ?? 0).toString();
      _absentCtrl.text = (data['attendance']['absent'] ?? 0).toString();
    }

    if (data['grades'] != null) {
      _subjects = List<Map<String, dynamic>>.from(
        data['grades'].map(
          (x) => {
            'subject_id': x['subject_id'],
            'subject_name': x['subject_name'] ?? 'Mapel',
            'knowledge_score': x['knowledge_score']?.toString() ?? '0',
            'knowledge_predicate': x['knowledge_predicate'] ?? '',
            'knowledge_description': x['knowledge_description'] ?? '',
            'skill_score': x['skill_score']?.toString() ?? '0',
            'skill_predicate': x['skill_predicate'] ?? '',
            'skill_description': x['skill_description'] ?? '',
          },
        ),
      );
    }
  }

  void _syncSubjectsWithRecap(List<dynamic> initialGrades) {
    // Add missing subjects from recap
    for (var recapItem in initialGrades) {
      bool exists = _subjects.any(
        (s) => s['subject_id'] == recapItem['subject_id'],
      );
      if (!exists) {
        _subjects.add({
          'subject_id': recapItem['subject_id'],
          'subject_name': recapItem['subject_name'] ?? 'Mapel',
          'knowledge_score': recapItem['knowledge_score']?.toString() ?? '0',
          'knowledge_predicate': recapItem['knowledge_predicate'] ?? '',
          'knowledge_description': recapItem['knowledge_description'] ?? '',
          'skill_score': recapItem['skill_score']?.toString() ?? '0',
          'skill_predicate': recapItem['skill_predicate'] ?? '',
          'skill_description': recapItem['skill_description'] ?? '',
        });
      }
    }
  }

  Future<void> _saveRaport({String status = 'draft'}) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final academicYearId = _getAcademicYearId() ?? '';

      final semesterId = await _resolveSemester();

      final payload = {
        'student_class_id': widget.studentClassId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
        'spiritual_predicate': _spiritualPredicate,
        'spiritual_description': _spiritualDescCtrl.text,
        'social_predicate': _socialPredicate,
        'social_description': _socialDescCtrl.text,
        'attendance_sick': int.tryParse(_sickCtrl.text) ?? 0,
        'attendance_permit': int.tryParse(_permitCtrl.text) ?? 0,
        'attendance_absent': int.tryParse(_absentCtrl.text) ?? 0,
        'homeroom_notes': _notesCtrl.text,
        'promotion_decision': _promotionDecision,
        'status': status,
        'subjects': _subjects,
        'extracurriculars': _extras,
        'achievements': _achievements,
      };

      final response = await ApiRaportService.saveRaport(payload);

      if (response != null) {
        // Invalidate cache after save
        await LocalCacheService.clearStartingWith('raport_detail_${widget.studentClassId}');
        await LocalCacheService.clearStartingWith('raport_students_');

        if (mounted) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'final' ? 'Raport diselesaikan!' : 'Draft disimpan!',
              ),
              backgroundColor: status == 'final' ? Colors.green : Colors.blue,
            ),
          );
          if (status == 'final') {
            Navigator.pop(context, true); // Return true to indicate change
          } else {
            _existingRaport = response;
          }
        }
      } else {
        throw Exception("Gagal menyimpan raport.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Perubahan Belum Disimpan'),
          content: const Text(
            'Anda memiliki perubahan yang belum disimpan. Yakin ingin keluar? Perubahan akan hilang.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true), // Leave
              child: const Text(
                'Keluar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _handleBackButton() async {
    if (_hasUnsavedChanges) {
      final canLeave = await _onWillPop();
      if (!canLeave) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final canLeave = await _onWillPop();
        if (canLeave && mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
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
                    ColorUtils.getRoleColor('guru'),
                    ColorUtils.getRoleColor('guru').withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.getRoleColor(
                      'guru',
                    ).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleBackButton,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Isi Raport',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.studentName} - ${widget.className}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_existingRaport != null &&
                      _existingRaport!['status'] == 'final')
                    GestureDetector(
                      onTap: () {
                        if (_existingRaport != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RaportPrintScreen(
                                raportData: _existingRaport!,
                                studentName: widget.studentName,
                                className: widget.className,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.print,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'refresh') _forceRefresh();
                    },
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    ),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                            const SizedBox(width: 8),
                            const Text('Perbarui Data'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // TabBar Container
            Container(
              key: _tabKey,
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: ColorUtils.corporateBlue600,
                unselectedLabelColor: ColorUtils.slate500,
                indicatorColor: ColorUtils.corporateBlue600,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Sikap'),
                  Tab(text: 'Nilai Akademik'),
                  Tab(text: 'Tambahan'),
                  Tab(text: 'Info & Keputusan'),
                ],
              ),
            ),

            // Body Content
            Expanded(
              child: _isLoading
                  ? const SkeletonListLoading()
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSikapTab(),
                        _buildNilaiTab(),
                        _buildTambahanTab(),
                        _buildInfoTab(),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: _saveDraftKey,
                    onPressed: _isSaving
                        ? null
                        : () => _saveRaport(status: 'draft'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.corporateBlue600),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Simpan Draft',
                            style: TextStyle(
                              color: ColorUtils.corporateBlue600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: _finalizeKey,
                    onPressed: _isSaving
                        ? null
                        : () {
                            // Confirmation dialog before final save
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Selesaikan Raport?'),
                                content: const Text(
                                  'Raport akan disimpan secara final. Pengiriman ke wali murid akan dilakukan oleh Admin nantinya.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _saveRaport(status: 'final');
                                    },
                                    child: const Text('Ya, Selesaikan'),
                                  ),
                                ],
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: ColorUtils.corporateBlue600,
                    ),
                    child: const Text(
                      'Selesaikan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: SIKAP ---
  Widget _buildSikapTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Sikap Spiritual'),
        _buildDropdown('Predikat', _spiritualPredicate, _predicates, (v) {
          setState(() => _spiritualPredicate = v!);
          _markUnsaved();
        }),
        const SizedBox(height: 12),
        _buildTextField('Deskripsi', _spiritualDescCtrl, maxLines: 4),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        _buildSectionTitle('Sikap Sosial'),
        _buildDropdown('Predikat', _socialPredicate, _predicates, (v) {
          setState(() => _socialPredicate = v!);
          _markUnsaved();
        }),
        const SizedBox(height: 12),
        _buildTextField('Deskripsi', _socialDescCtrl, maxLines: 4),
      ],
    );
  }

  // --- TAB 2: NILAI ---
  Widget _buildNilaiTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
            ),
            boxShadow: [...ColorUtils.corporateShadow()],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject['subject_name'] ?? 'Mapel',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: 16),

                // Pengetahuan
                const Text(
                  'Aspek Pengetahuan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildCompactTextField(
                        'Nilai',
                        subject['knowledge_score'],
                        (v) {
                          _subjects[index]['knowledge_score'] = v;
                          _markUnsaved();
                        },
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildCompactTextField(
                        'Predikat',
                        subject['knowledge_predicate'],
                        (v) {
                          _subjects[index]['knowledge_predicate'] = v;
                          _markUnsaved();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCompactTextField(
                  'Deskripsi',
                  subject['knowledge_description'],
                  (v) {
                    _subjects[index]['knowledge_description'] = v;
                    _markUnsaved();
                  },
                  maxLines: 2,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Keterampilan
                const Text(
                  'Aspek Keterampilan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildCompactTextField(
                        'Nilai',
                        subject['skill_score'],
                        (v) {
                          _subjects[index]['skill_score'] = v;
                          _markUnsaved();
                        },
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildCompactTextField(
                        'Predikat',
                        subject['skill_predicate'],
                        (v) {
                          _subjects[index]['skill_predicate'] = v;
                          _markUnsaved();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCompactTextField(
                  'Deskripsi',
                  subject['skill_description'],
                  (v) {
                    _subjects[index]['skill_description'] = v;
                    _markUnsaved();
                  },
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 3: TAMBAHAN ---
  Widget _buildTambahanTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Ekstrakurikuler'),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _extras.add({'name': '', 'score': '', 'description': ''});
                });
                _markUnsaved();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        ...List.generate(_extras.length, (index) => _buildExtraItem(index)),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Prestasi'),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _achievements.add({
                    'name': '',
                    'type': '',
                    'description': '',
                  });
                });
                _markUnsaved();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        ...List.generate(
          _achievements.length,
          (index) => _buildAchievementItem(index),
        ),
      ],
    );
  }

  Widget _buildExtraItem(int index) {
    final extra = _extras[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
        ),
        boxShadow: [...ColorUtils.corporateShadow()],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildCompactTextField(
                    'Nama Ekstrakurikuler',
                    extra['name'],
                    (v) {
                      _extras[index]['name'] = v;
                      _markUnsaved();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildCompactTextField('Nilai', extra['score'], (v) {
                    _extras[index]['score'] = v;
                    _markUnsaved();
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() => _extras.removeAt(index));
                    _markUnsaved();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCompactTextField('Keterangan', extra['description'], (v) {
              _extras[index]['description'] = v;
              _markUnsaved();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(int index) {
    final ach = _achievements[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
        ),
        boxShadow: [...ColorUtils.corporateShadow()],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildCompactTextField('Nama Prestasi', ach['name'], (
                    v,
                  ) {
                    _achievements[index]['name'] = v;
                    _markUnsaved();
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildCompactTextField(
                    'Jenis (Opsional)',
                    ach['type'],
                    (v) {
                      _achievements[index]['type'] = v;
                      _markUnsaved();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() => _achievements.removeAt(index));
                    _markUnsaved();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCompactTextField('Keterangan', ach['description'], (v) {
              _achievements[index]['description'] = v;
              _markUnsaved();
            }),
          ],
        ),
      ),
    );
  }

  // --- TAB 4: INFO & KEPUTUSAN ---
  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Ketidakhadiran'),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Sakit (Hari)', _sickCtrl, isNumber: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Izin (Hari)',
                _permitCtrl,
                isNumber: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Tanpa Ket. (Hari)',
                _absentCtrl,
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _buildSectionTitle('Catatan Wali Kelas'),
        _buildTextField(
          'Masukkan catatan, saran, atau motivasi untuk siswa...',
          _notesCtrl,
          maxLines: 4,
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        _buildSectionTitle('Keputusan Akhir Tahun (Opsional)'),
        _buildDropdown('Keputusan', _promotionDecision, _decisions, (v) {
          setState(() => _promotionDecision = v!);
          _markUnsaved();
        }),
      ],
    );
  }

  // --- WIDGET BUILDERS ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate700,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ColorUtils.getRoleColor('guru')),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTextField(
    String label,
    String initialValue,
    Function(String) onChanged, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ColorUtils.getRoleColor('guru')),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Check cache first (24h TTL)
      const tourCacheKey = 'tour_raport_detail_screen_guru';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (mounted) _showTour();
        }
        return;
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'raport_detail_screen_tour',
      );

      // Cache the result
      await LocalCacheService.save(tourCacheKey, status);

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

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_raport_detail_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_raport_detail_screen_guru', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "TabBar",
        keyTarget: _tabKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Tab Kategori Evaluasi",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Data raport siswa terbagi menjadi 4 kelompok. Akses masing-masing tab untuk melengkapi form penjabaran Sikap, sinkronisasi Nilai Akademik, Ekstrakurikuler, serta Kehadiran.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
        identify: "SimpanDraft",
        keyTarget: _saveDraftKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Simpan Draft",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Gunakan opsi ini jika Anda belum selesai mengisi seluruh data siswa. Raport akan tersimpan sementara sehingga Anda dapat melanjutkannya nanti.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
        identify: "Selesaikan",
        keyTarget: _finalizeKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Selesaikan Raport",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Klik Selesaikan jika seluruh tab formulir telah diisi dengan lengkap dan Anda sudah yakin datanya sudah valid. Status raport akan menjadi Final.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
