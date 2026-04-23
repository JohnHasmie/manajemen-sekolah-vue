import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';

/// Mixin for data loading, caching, and styling logic.
mixin ReportCardDataMixin {
  // Abstract state access
  void setState(VoidCallback fn);
  BuildContext get context;

  // State fields
  late bool isLoading;
  late String errorMessage;
  late List<dynamic> studentsData;
  late Map<String, dynamic> parentData;
  late String selectedTermId;
  late String? academicYearId;

  /// Returns Riverpod provider accessor.
  dynamic getAcademicYearProvider() =>
      throw UnimplementedError('Implement in state');

  String buildCacheKey() {
    final provider = getAcademicYearProvider();
    final yearId =
        academicYearId ??
        provider.selectedAcademicYear?['id']?.toString() ??
        'unknown';
    return 'parent_raport_${yearId}_$selectedTermId';
  }

  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_raport_');
    await LocalCacheService.clearStartingWith('school_day_data');
    loadData(useCache: false);
  }

  Future<void> resolveAcademicTerm() async {
    // Use shared school_day_data cache (24h TTL)
    // instead of direct API call
    final cached = await LocalCacheService.load(
      'school_day_data',
      ttl: const Duration(hours: 24),
    );
    Map<String, dynamic>? dateBasedSemester;

    if (cached != null && cached is Map<String, dynamic>) {
      dateBasedSemester = cached;
    } else {
      dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      // Non-blocking save
      LocalCacheService.save('school_day_data', dateBasedSemester);
    }

    if (dateBasedSemester.containsKey('semester') &&
        dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
      selectedTermId = '2';
    }
  }

  /// Loads parent data and fetches raport for each child.
  /// Resolves current semester automatically, then fetches
  /// from cache or API.
  Future<void> loadData({bool useCache = true}) async {
    // Load parent data
    if (parentData.isEmpty || parentData['id'] == null) {
      final prefs = PreferencesService();
      parentData = json.decode(prefs.getString('user') ?? '{}');
    }

    // Resolve semester
    await resolveAcademicTerm();

    // Step 1: Try cache — return early on hit
    if (useCache) {
      final cacheKey = buildCacheKey();
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          studentsData = List<dynamic>.from(cached);
          isLoading = false;
          errorMessage = '';
        });
        return;
      }
    }

    // Step 2: Show skeleton only if list is empty
    if (studentsData.isEmpty && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    // Step 3: Fetch fresh from API
    try {
      if (parentData.isEmpty || parentData['id'] == null) {
        throw Exception(
          'Sesi wali murid tidak ditemukan. '
          'Silakan login kembali.',
        );
      }

      await fetchParentReportCards();
    } catch (e) {
      if (!mounted) return;
      // Only show error if no cached data
      if (studentsData.isEmpty) {
        setState(() => errorMessage = ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool get mounted => throw UnimplementedError('Implement in state');

  Future<void> fetchParentReportCards() async {
    final provider = getAcademicYearProvider();
    final yearId =
        academicYearId ?? provider.selectedAcademicYear?['id']?.toString();

    if (yearId == null) {
      throw Exception('Tahun ajaran belum dipilih.');
    }

    final response = await dioClient.get(
      '/parent/raports',
      queryParameters: {
        'academic_year_id': yearId,
        'semester_id': selectedTermId,
      },
    );

    // Dio auto-decodes JSON and throws on non-2xx
    // (handled by ErrorInterceptor)
    final jsonResponse = response.data;
    if (jsonResponse is Map<String, dynamic> &&
        jsonResponse['success'] == true) {
      final freshData = jsonResponse['data'] ?? [];
      if (!mounted) return;

      // Save to cache (non-blocking)
      LocalCacheService.save(buildCacheKey(), freshData);

      setState(() {
        studentsData = freshData;
      });
    } else {
      throw Exception(
        jsonResponse is Map
            ? (jsonResponse['message'] ??
                  AppLocalizations.failedToLoadReportCard.tr)
            : AppLocalizations.failedToLoadReportCard.tr,
      );
    }
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(parentData['role'] ?? 'wali');
  }

  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }
}
