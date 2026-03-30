// Report card detail/editing screen for a specific student.
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
// Like `pages/teacher/Raport/Detail.vue` in a Vue app.
//
// A tabbed form (4 tabs: Academic, Extracurricular, Character, Info) where
// teachers fill in grades, descriptions, attendance counts, and promotion
// decisions. Supports draft saving and finalization.
// In Laravel terms: `RaportController@show` + `@update`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_print_screen.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_grade_tab.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_extras_tab.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_info_tab.dart';

/// Report card detail form for a single student.
///
/// A complex multi-tab form with academic grades, extracurriculars,
/// character assessment, and attendance/promotion info. Tracks unsaved
/// changes and warns before navigation (like Vue `beforeRouteLeave`).
///
/// Props (like Vue props): [studentClassId], [studentName], [className].
class ReportCardDetailScreen extends ConsumerStatefulWidget {
  final String studentClassId;
  final String studentName;
  final String className;

  const ReportCardDetailScreen({
    super.key,
    required this.studentClassId,
    required this.studentName,
    required this.className,
  });

  @override
  ConsumerState createState() => _ReportCardDetailScreenState();
}

/// State for [ReportCardDetailScreen].
///
/// Like a Vue component with `data() { return {...} }` containing form
/// controllers, tab state, and save/submit flags. Uses
/// `SingleTickerProviderStateMixin` for the 4-tab TabController.
///
/// Key state: form controllers for sikap (character), attendance counts,
/// notes, lists of subjects/extras/achievements, and unsaved change tracking.
class _ReportCardDetailScreenState extends ConsumerState<ReportCardDetailScreen>
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
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  String _buildDetailCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'raport_detail_${widget.studentClassId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith(
      'raport_detail_${widget.studentClassId}',
    );
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
  Future<String> _resolveAcademicTerm() async {
    final cachedDayData = await LocalCacheService.load(
      'school_day_data',
      ttl: const Duration(hours: 24),
    );
    if (cachedDayData != null && cachedDayData is Map) {
      if (cachedDayData.containsKey('semester') &&
          cachedDayData['semester'].toString().toLowerCase() == 'genap') {
        return '2';
      }
      return '1';
    }
    final dateBasedSemester = await getIt<ApiScheduleService>()
        .getDateBasedSemester();
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
          AppLogger.debug('report_card', 'ReportCardDetailScreen: Data from cache');
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
      final semester = await _resolveAcademicTerm();

      final existingDetail = await getIt<ApiReportCardService>().getRaportDetail(
        studentClassId: widget.studentClassId,
        academicYearId: academicYearId,
        semesterId: semester,
      );

      final initialData = await getIt<ApiReportCardService>().getInitialData(
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
        throw Exception(AppLocalizations.failedToLoadInitialData.tr);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      final bool exists = _subjects.any(
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

  Future<void> _saveReportCard({String status = 'draft'}) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final academicYearId = _getAcademicYearId() ?? '';

      final semesterId = await _resolveAcademicTerm();

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

      final response = await getIt<ApiReportCardService>().saveReportCard(payload);

      if (response != null) {
        // Invalidate cache after save
        await LocalCacheService.clearStartingWith(
          'raport_detail_${widget.studentClassId}',
        );
        await LocalCacheService.clearStartingWith('raport_students_');

        if (mounted) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          SnackBarUtils.showInfo(
            context,
            status == 'final' ? 'Raport diselesaikan!' : 'Draft disimpan!',
          );
          if (status == 'final') {
            AppNavigator.pop(context, true); // Return true to indicate change
          } else {
            _existingRaport = response;
          }
        }
      } else {
        throw Exception(AppLocalizations.failedToSaveReportCard.tr);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: ${e.toString()}');
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
          title: Text(AppLocalizations.unsavedChanges.tr),
          content: Text(AppLocalizations.unsavedChangesConfirm.tr),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, false), // Cancel
              child: Text(AppLocalizations.cancel.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => AppNavigator.pop(context, true), // Leave
              child: Text(
                AppLocalizations.leave.tr,
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
      AppNavigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final canLeave = await _onWillPop();
        if (canLeave && context.mounted) {
          AppNavigator.pop(context, result);
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
                  const SizedBox(width: AppSpacing.lg),
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
                        const SizedBox(height: AppSpacing.xs),
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
                          AppNavigator.push(
                            context,
                            ReportCardPrintScreen(
                              reportCardData: _existingRaport!,
                              studentName: widget.studentName,
                              className: widget.className,
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
                      child: const Icon(
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
                            Icon(
                              Icons.refresh,
                              size: 20,
                              color: ColorUtils.info600,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(AppLocalizations.updateData.tr),
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
                        ReportCardGradeTab(
                          subjects: _subjects,
                          onSubjectChanged: (index, field, value) {
                            setState(() => _subjects[index][field] = value);
                          },
                          onMarkUnsaved: _markUnsaved,
                        ),
                        ReportCardExtrasTab(
                          extras: _extras,
                          achievements: _achievements,
                          onAddExtra: () => setState(
                            () => _extras.add(
                              {'name': '', 'score': '', 'description': ''},
                            ),
                          ),
                          onAddAchievement: () => setState(
                            () => _achievements.add(
                              {'name': '', 'type': '', 'description': ''},
                            ),
                          ),
                          onExtraChanged: (index, field, value) {
                            setState(() => _extras[index][field] = value);
                          },
                          onDeleteExtra: (index) {
                            setState(() => _extras.removeAt(index));
                          },
                          onAchievementChanged: (index, field, value) {
                            setState(
                              () => _achievements[index][field] = value,
                            );
                          },
                          onDeleteAchievement: (index) {
                            setState(() => _achievements.removeAt(index));
                          },
                          onMarkUnsaved: _markUnsaved,
                        ),
                        ReportCardInfoTab(
                          sickCtrl: _sickCtrl,
                          permitCtrl: _permitCtrl,
                          absentCtrl: _absentCtrl,
                          notesCtrl: _notesCtrl,
                          promotionDecision: _promotionDecision,
                          decisions: _decisions,
                          onPromotionChanged: (v) {
                            setState(() => _promotionDecision = v!);
                            _markUnsaved();
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                        : () => _saveReportCard(status: 'draft'),
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
                const SizedBox(width: AppSpacing.md),
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
                                title: Text(
                                  AppLocalizations.finalizeReportCard.tr,
                                ),
                                content: Text(
                                  AppLocalizations.finalizeReportCardConfirm.tr,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => AppNavigator.pop(context),
                                    child: Text(AppLocalizations.cancel.tr),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      AppNavigator.pop(context);
                                      _saveReportCard(status: 'final');
                                    },
                                    child: Text(
                                      AppLocalizations.yesFinalize.tr,
                                    ),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildSectionTitle('Sikap Spiritual'),
        _buildDropdown('Predikat', _spiritualPredicate, _predicates, (v) {
          setState(() => _spiritualPredicate = v!);
          _markUnsaved();
        }),
        const SizedBox(height: AppSpacing.md),
        _buildTextField('Deskripsi', _spiritualDescCtrl, maxLines: 4),

        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),

        _buildSectionTitle('Sikap Sosial'),
        _buildDropdown('Predikat', _socialPredicate, _predicates, (v) {
          setState(() => _socialPredicate = v!);
          _markUnsaved();
        }),
        const SizedBox(height: AppSpacing.md),
        _buildTextField('Deskripsi', _socialDescCtrl, maxLines: 4),
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
        const SizedBox(height: AppSpacing.xs),
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
        const SizedBox(height: AppSpacing.xs),
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
      // Cache-only: tour status pre-fetched from dashboard
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'raport_detail_screen',
        'guru',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('report_card', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'raport_detail_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_detail_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'raport_detail_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('raport_detail_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

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
