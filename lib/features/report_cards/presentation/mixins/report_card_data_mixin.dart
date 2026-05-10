import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

/// Mixin for data loading and population logic.
mixin ReportCardDataMixin on ConsumerState<ReportCardDetailScreen> {
  String? getAcademicYearId() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  String buildDetailCacheKey() {
    final academicYearId = getAcademicYearId() ?? '';
    return 'raport_detail_'
        '${widget.studentClassId}_$academicYearId';
  }

  Future<String> resolveAcademicTerm() async {
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

  Future<void> loadData({bool useCache = true}) async {
    final detailCacheKey = buildDetailCacheKey();
    final academicYearId = getAcademicYearId() ?? '';

    if (academicYearId.isEmpty) {
      if (mounted) {
        setState(() {
          errorMessage = 'Tahun ajaran tidak valid.';
          isLoading = false;
        });
      }
      return;
    }

    if (useCache) {
      await tryLoadFromCache(detailCacheKey);
      if (!isLoading) return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final semester = await resolveAcademicTerm();

      final existingDetail = await getIt<ApiReportCardService>()
          .getRaportDetail(
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
        existingRaport = existingDetail;
        populateFromExisting(existingDetail);
        if (initialData != null && initialData['grades'] != null) {
          syncSubjectsWithRecap(List<dynamic>.from(initialData['grades']));
        }
        // Mirror the initial-data attendance into the existing raport
        // when the raport itself didn't ship attendance yet — used for
        // the autofill hint on the Info tab.
        if (initialData != null && initialData['attendance'] is Map) {
          existingRaport!['_initial_attendance'] = Map<String, dynamic>.from(
            initialData['attendance'] as Map,
          );
        }
        // Also stash the initial-data summary so the hero pill can
        // fall back to recap-based rerata if the raport's own
        // raport_subjects are empty (newly-created drafts).
        if (initialData != null && initialData['summary'] is Map) {
          existingRaport!['_initial_summary'] = Map<String, dynamic>.from(
            initialData['summary'] as Map,
          );
        }
      } else if (initialData != null) {
        populateFromInitial(initialData);
        // Stash a synthetic raport-shaped map so the header has
        // something to derive the hero pill from even before the
        // first save.
        existingRaport = {
          '_initial_summary': initialData['summary'] is Map
              ? Map<String, dynamic>.from(initialData['summary'] as Map)
              : <String, dynamic>{},
          '_initial_attendance': initialData['attendance'] is Map
              ? Map<String, dynamic>.from(initialData['attendance'] as Map)
              : <String, dynamic>{},
          '_synthetic': true,
        };
      } else {
        throw Exception('Failed to load initial data');
      }

      setState(() {
        isLoading = false;
      });

      await LocalCacheService.save(detailCacheKey, {
        'existingDetail': existingDetail,
        'initialData': initialData,
      });
    } catch (e) {
      if (mounted && subjects.isEmpty) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          checkAndShowTour();
        }
      });
    }
  }

  Future<void> tryLoadFromCache(String key) async {
    final cached = await LocalCacheService.load(key);
    if (cached != null && cached is Map<String, dynamic>) {
      final cachedDetail = cached['existingDetail'];
      final cachedInitial = cached['initialData'];

      if (cachedDetail != null) {
        existingRaport = Map<String, dynamic>.from(cachedDetail);
        populateFromExisting(existingRaport!);
        if (cachedInitial != null && cachedInitial['grades'] != null) {
          syncSubjectsWithRecap(List<dynamic>.from(cachedInitial['grades']));
        }
      } else if (cachedInitial != null) {
        populateFromInitial(Map<String, dynamic>.from(cachedInitial));
      }

      if (mounted && (existingRaport != null || cachedInitial != null)) {
        setState(() {
          isLoading = false;
          errorMessage = '';
        });
        checkAndShowTour();
        AppLogger.debug(
          'report_card',
          'ReportCardDetailScreen: Data from cache',
        );
      }
    }
  }

  // Abstract declarations for state properties
  late String errorMessage;
  late bool isLoading;
  late Map<String, dynamic>? existingRaport;
  late List<Map<String, dynamic>> subjects;

  // Abstract methods
  void populateFromExisting(Map<String, dynamic> data);
  void populateFromInitial(Map<String, dynamic> data);
  void syncSubjectsWithRecap(List<dynamic> initialGrades);
  Future<void> checkAndShowTour();
}
