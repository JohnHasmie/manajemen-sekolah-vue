// Class activity (journal) management screen for teachers.
//
// Multi-step wizard: Step 0 (select class) -> Step 1 (select subject) ->
// Step 2 (view/manage activities via EmbeddedActivityListScreen).
//
// Step 2 logic (activity list, CRUD, pagination, search/filter, tabs) is
// fully owned by EmbeddedActivityListScreen. This file only handles the
// wizard navigation (steps 0–1) and teacher/class/subject resolution.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_activity_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_selector_list.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/subject_selection_list.dart';

/// Teacher's class activity (teaching journal) management screen.
///
/// Supports deep linking via optional initial* parameters, allowing other
/// screens to navigate here with pre-selected class/subject/chapter.
class ClassActivityScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  const ClassActivityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
  });

  @override
  ClassActivityScreenState createState() => ClassActivityScreenState();
}

class ClassActivityScreenState extends ConsumerState<ClassActivityScreen> {
  static const String _prefKeyLastCacheKey = 'class_activity_last_cache_key';

  List<dynamic> _scheduleList = [];
  List<dynamic> _subjectList = [];
  bool _isLoading = true;
  String _teacherId = '';
  String _teacherName = '';

  // Wizard navigation: 0 = Class List, 1 = Subject List, 2 = Activity List
  int _currentStep = 0;
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _selectedSubjectCanEdit = false;

  List<dynamic> _classList = [];

  // Key to access EmbeddedActivityListScreen state for header tab switcher / refresh
  final GlobalKey<EmbeddedActivityListScreenState> _activityListKey =
      GlobalKey<EmbeddedActivityListScreenState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ── View builders (Step 0 & 1) ──

  Widget _buildClassList(LanguageProvider languageProvider) {
    return ClassSelectorList(
      isLoading: _isLoading,
      classList: _classList,
      languageProvider: languageProvider,
      onClassSelected: (classData) async {
        setState(() {
          _selectedClassId = classData['id'].toString();
          _selectedClassName = classData['name'] ?? classData['nama'];
          _currentStep = 1;
        });
        await _loadSubjectsForClass();
      },
    );
  }

  Widget _buildSubjectList(LanguageProvider languageProvider) {
    return SubjectSelectionList(
      isLoading: _isLoading,
      subjectList: _subjectList,
      selectedClassName: _selectedClassName,
      languageProvider: languageProvider,
      onSubjectSelected: (subject) async {
        setState(() {
          _selectedSubjectId = subject['id'].toString();
          _selectedSubjectName = subject['name'] ?? subject['nama'] ?? '-';
          _selectedSubjectCanEdit = subject['can_edit'] == true;
          _currentStep = 2;
        });
      },
    );
  }

  // ── Data loading (teacher, classes, subjects) ──

  Future<void> _loadUserData() async {
    AppLogger.debug('class_activity', '===== _loadUserData STARTED =====');
    try {
      final teacherProvider = ref.read(teacherRiverpod);
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final role = userData['role']?.toString().toLowerCase() ?? '';
      final isAdmin = role == 'admin' || role == 'super_admin';

      // Early cache load
      if (_classList.isEmpty) {
        final lastCacheKey = prefs.getString(_prefKeyLastCacheKey);
        if (lastCacheKey != null) {
          try {
            final cached = await LocalCacheService.load(
              lastCacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cached != null && mounted) {
              final cachedData = Map<String, dynamic>.from(cached);
              setState(() {
                _classList = List<dynamic>.from(cachedData['classes'] ?? []);
                _scheduleList = List<dynamic>.from(cachedData['schedules'] ?? []);
                if (_classList.isNotEmpty) _isLoading = false;
              });
            }
          } catch (e) {
            AppLogger.error('class_activity', 'Early cache load error: $e');
          }
        }
      }

      if (!isAdmin &&
          teacherProvider.isLoaded &&
          teacherProvider.teacherId != null) {
        setState(() {
          _teacherId = teacherProvider.teacherId!;
          _teacherName = teacherProvider.teacherName ?? 'Guru';
        });

        if (widget.initialClassId != null && widget.initialSubjectId != null) {
          await _handleInitialNavigation();
          _loadClassesAndSchedule(teacherProvider.teacherId!, isAdmin: false);
          return;
        }

        await _loadClassesAndSchedule(teacherProvider.teacherId!, isAdmin: false);
        await _handleInitialNavigation();
        return;
      }

      // Fallback — fetch from API
      AppLogger.debug('class_activity', 'TeacherProvider empty, falling back to API');
      final userId = userData['id']?.toString() ?? '';
      setState(() {
        _teacherId = userId;
        _teacherName = userData['nama']?.toString() ?? 'Guru';
      });

      if (userId.isNotEmpty) {
        if (isAdmin) {
          await _loadClasses(userId, isAdmin: true);
        } else {
          try {
            String? resolvedTeacherId;

            final looksLikeTeacher =
                userData.containsKey('employee_number') ||
                userData.containsKey('nip') ||
                userData.containsKey('user_id');

            if (looksLikeTeacher) {
              resolvedTeacherId = userId;
            } else {
              String? academicYearId;
              try {
                if (mounted) {
                  academicYearId = ref
                      .read(academicYearRiverpod)
                      .selectedAcademicYear?['id']
                      ?.toString();
                }
              } catch (_) {}

              await teacherProvider.ensureLoaded(academicYearId: academicYearId);

              if (teacherProvider.teacherId != null) {
                resolvedTeacherId = teacherProvider.teacherId;
              } else {
                final teacherData = await getIt<ApiTeacherService>()
                    .getTeacherByUserId(userId, academicYearId: academicYearId);
                if (teacherData != null && teacherData['id'] != null) {
                  resolvedTeacherId = teacherData['id'].toString();
                }
              }
            }

            if (resolvedTeacherId != null) {
              AppLogger.info('class_activity', 'Resolved Teacher ID: $resolvedTeacherId');
              setState(() => _teacherId = resolvedTeacherId!);

              if (widget.initialClassId != null && widget.initialSubjectId != null) {
                await _handleInitialNavigation();
                _loadClassesAndSchedule(resolvedTeacherId, isAdmin: false);
              } else {
                await _loadClassesAndSchedule(resolvedTeacherId, isAdmin: false);
                await _handleInitialNavigation();
              }
            } else {
              AppLogger.error('class_activity', 'Failed to resolve Teacher ID');
              await _loadClasses(userId, isAdmin: true);
              if (_classList.isEmpty) setState(() => _isLoading = false);
            }
          } catch (e) {
            AppLogger.error('class_activity', 'Error during teacher resolution: $e');
            if (mounted) _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
            setState(() => _isLoading = false);
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error in _loadUserData: $e');
      if (mounted) _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleInitialNavigation() async {
    if (widget.initialClassId == null) return;
    if (!mounted) return;

    setState(() {
      _selectedClassId = widget.initialClassId;
      _selectedClassName = widget.initialClassName;
      _currentStep = 1;
    });

    await _loadSubjectsForClass();

    if (widget.initialSubjectId != null && mounted) {
      final matchedSubject = _subjectList.firstWhere(
        (s) => s['id']?.toString() == widget.initialSubjectId,
        orElse: () => <String, dynamic>{},
      );
      setState(() {
        _selectedSubjectId = widget.initialSubjectId;
        _selectedSubjectName = widget.initialSubjectName;
        _selectedSubjectCanEdit = matchedSubject['can_edit'] == true;
        _currentStep = 2;
      });
    }
  }

  Future<void> _loadClassesAndSchedule(
    String teacherId, {
    bool isAdmin = false,
    bool useCache = true,
  }) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    final cacheKey = 'class_activity_classes_${teacherId}_$academicYearId';

    if (useCache && _classList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          setState(() {
            _classList = List<dynamic>.from(cachedData['classes'] ?? []);
            _scheduleList = List<dynamic>.from(cachedData['schedules'] ?? []);
            _isLoading = false;
          });
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Cache load error: $e');
      }
    }

    if (_classList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _fetchClasses(teacherId, isAdmin: isAdmin, academicYearId: academicYearId),
        _fetchSchedule(teacherId, academicYearId: academicYearId),
      ]);

      final classes = results[0];
      final schedules = results[1];

      if (!mounted) return;

      setState(() {
        _classList = classes;
        _scheduleList = schedules;
        _isLoading = false;
      });

      await LocalCacheService.save(cacheKey, {
        'classes': classes,
        'schedules': schedules,
      });
      final prefs = PreferencesService();
      await prefs.setString(_prefKeyLastCacheKey, cacheKey);
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading classes/schedule: $e');
      if (!mounted) return;
      if (_classList.isEmpty) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<List<dynamic>> _fetchClasses(
    String teacherId, {
    bool isAdmin = false,
    String? academicYearId,
  }) async {
    if (isAdmin) {
      final response = await getIt<ApiClassService>().getClassPaginated(
        limit: 100,
        academicYearId: academicYearId,
      );
      return response['data'] ?? [];
    } else {
      return await getIt<ApiTeacherService>().getTeacherClasses(
        teacherId,
        academicYearId: academicYearId,
      );
    }
  }

  Future<List<dynamic>> _fetchSchedule(
    String teacherId, {
    String? academicYearId,
  }) async {
    return await getIt<ApiScheduleService>().getScheduleByTeacher(
      teacherId: teacherId,
      academicYear: academicYearId,
    );
  }

  Future<void> _loadClasses(
    String teacherId, {
    bool isAdmin = false,
    bool useCache = true,
  }) async {
    await _loadClassesAndSchedule(teacherId, isAdmin: isAdmin, useCache: useCache);
  }

  Future<void> _loadSubjectsForClass({bool useCache = true}) async {
    if (_selectedClassId == null) return;

    final subjectCacheKey = CacheKeyBuilder.custom(
      'class_activity_subjects',
      _teacherId,
      _selectedClassId ?? '',
    );

    if (useCache && _subjectList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(
          subjectCacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          setState(() {
            _subjectList = List<dynamic>.from(cached);
            _isLoading = false;
          });
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Subject cache load error: $e');
      }
    }

    if (_subjectList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final selectedClass = _classList.firstWhere(
        (c) => c['id'].toString() == _selectedClassId,
        orElse: () => {},
      );
      final isHomeroom = selectedClass['is_homeroom'] == true;

      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      String userRole = '';
      if (userJson != null) {
        final userData = json.decode(userJson);
        userRole = userData['role'] ?? '';
      }
      final isAdmin = userRole == 'admin';

      final mySchedules = await getIt<ApiScheduleService>()
          .getSchedulesPaginated(
            limit: 100,
            teacherId: _teacherId,
            classId: _selectedClassId,
            academicYearId: academicYearId,
          );
      final myData = mySchedules['data'] ?? [];
      final mySubjectIds = <String>{};
      for (var item in myData) {
        final subject = item['subject'] ?? item['mata_pelajaran'];
        if (subject != null) {
          mySubjectIds.add(subject['id'].toString());
        }
      }

      List<dynamic> subjects = [];

      if (isHomeroom || isAdmin) {
        final response = await dioClient.get('/class/$_selectedClassId/subjects');
        final allSubjects = response.data is List ? response.data as List : [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};

        for (var subject in allSubjects) {
          final subjectId = subject['id'].toString();
          final s = Map<String, dynamic>.from(subject);
          s['can_edit'] = isAdmin || mySubjectIds.contains(subjectId);
          uniqueSubjects[subjectId] = s;
        }
        subjects = uniqueSubjects.values.toList();
      } else {
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var item in myData) {
          final subject = item['subject'] ?? item['mata_pelajaran'];
          if (subject != null) {
            final subjectId = subject['id'].toString();
            final s = Map<String, dynamic>.from(subject);
            s['can_edit'] = true;
            uniqueSubjects[subjectId] = s;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      subjects.sort((a, b) {
        final nameA = (a['name'] ?? a['nama'] ?? '').toString();
        final nameB = (b['name'] ?? b['nama'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _isLoading = false;
        });
      }

      await LocalCacheService.save(subjectCacheKey, subjects);
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading subjects: $e');
      if (mounted) {
        if (_subjectList.isEmpty) {
          _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
        }
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Navigation helpers ──

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
      return false;
    }
    return true;
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('class_activity_');
    final prefs = PreferencesService();
    await prefs.remove(_prefKeyLastCacheKey);
    if (_currentStep == 0) {
      setState(() => _isLoading = true);
      _loadUserData();
    } else if (_currentStep == 1) {
      setState(() {
        _subjectList.clear();
        _isLoading = true;
      });
      _loadSubjectsForClass(useCache: false);
    } else if (_currentStep == 2) {
      _activityListKey.currentState?.forceRefresh();
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) SnackBarUtils.showError(context, message);
  }

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _buildHeader(languageProvider),
            Expanded(child: _buildBodyContent(languageProvider)),
          ],
        ),
        floatingActionButton: _currentStep == 2
            ? _activityListKey.currentState?.buildFab()
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
        return EmbeddedActivityListScreen(
          key: _activityListKey,
          teacherId: _teacherId,
          teacherName: _teacherName,
          classId: _selectedClassId!,
          className: _selectedClassName ?? '',
          subjectId: _selectedSubjectId!,
          subjectName: _selectedSubjectName ?? '',
          canEdit: _selectedSubjectCanEdit,
          initialDate: widget.initialDate,
          initialChapterId: widget.initialChapterId,
          initialSubChapterId: widget.initialSubChapterId,
          initialAdditionalMaterials: widget.initialAdditionalMaterials,
          materialsToMarkAsGenerated: widget.materialsToMarkAsGenerated,
          autoShowActivityDialog: widget.autoShowActivityDialog,
          showScaffold: false,
        );
      default:
        return Container();
    }
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return ClassActivityHeader(
      currentStep: _currentStep,
      selectedClassName: _selectedClassName,
      selectedSubjectName: _selectedSubjectName,
      primaryColor: _getPrimaryColor(),
      languageProvider: languageProvider,
      onBackPressed: () async {
        final shouldPop = await _handleWillPop();
        if (shouldPop && mounted) {
          AppNavigator.pop(context);
        }
      },
      onRefreshPressed: _forceRefresh,
      tabSwitcherWidget: _currentStep == 2
          ? _activityListKey.currentState?.buildTabSwitcher(languageProvider)
          : null,
    );
  }
}
