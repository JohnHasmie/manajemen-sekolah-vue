import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_state.dart';

final parentFinanceProvider =
    AsyncNotifierProvider<ParentFinanceController, ParentFinanceState>(
      ParentFinanceController.new,
      isAutoDispose: true,
    );

class ParentFinanceController extends AsyncNotifier<ParentFinanceState> {
  Timer? _markReadTimer;

  @override
  FutureOr<ParentFinanceState> build() async {
    ref.onDispose(() {
      _markReadTimer?.cancel();
    });
    return _init();
  }

  Future<ParentFinanceState> _init() async {
    // 1. Load Students (Cache-first)
    final students = await _loadStudents();
    final selectedStudent = students.isNotEmpty ? students.first : null;

    // 2. Load Billing for first student (Cache-first)
    List<dynamic> billing = [];
    if (selectedStudent != null) {
      billing = await _loadBilling(selectedStudent.id);
    }

    return ParentFinanceState(
      students: students,
      selectedStudent: selectedStudent,
      billingItems: billing,
      isLoading: false,
    );
  }

  // --- Actions ---

  Future<void> selectStudent(Student student) async {
    state = state.whenData(
      (s) => s.copyWith(
        selectedStudent: student,
        isLoading: true,
        billingItems: [],
      ),
    );
    final billing = await _loadBilling(student.id, useCache: true);
    state = state.whenData(
      (s) => s.copyWith(billingItems: billing, isLoading: false),
    );
  }

  Future<void> updateFilters({String? status, String? period}) async {
    final currentState = state.value;
    if (currentState?.selectedStudent == null) return;
    state = AsyncData(
      currentState!.copyWith(
        statusFilter: status,
        periodFilter: period,
        isLoading: true,
      ),
    );
    final billing = await _loadBilling(
      currentState.selectedStudent!.id,
      useCache: false,
    );
    state = state.whenData(
      (s) => s.copyWith(billingItems: billing, isLoading: false),
    );
  }

  Future<void> updateSearch(String query) async {
    final currentState = state.value;
    if (currentState?.selectedStudent == null) return;
    state = AsyncData(
      currentState!.copyWith(searchQuery: query, isLoading: true),
    );
    final billing = await _loadBilling(
      currentState.selectedStudent!.id,
      useCache: false,
    );
    state = state.whenData(
      (s) => s.copyWith(billingItems: billing, isLoading: false),
    );
  }

  void markItemVisible(String id, bool isRead) {
    final currentState = state.value;
    if (currentState == null) return;
    if (!isRead && !currentState.processedReadIds.contains(id)) {
      final newProcessed = {...currentState.processedReadIds, id};
      final newPending = {...currentState.pendingReadIds, id};

      state = AsyncData(
        currentState.copyWith(
          processedReadIds: newProcessed,
          pendingReadIds: newPending,
        ),
      );

      _scheduleMarkRead();
    }
  }

  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 1000), () {
      final currentState = state.value;
      if (currentState != null && currentState.pendingReadIds.isNotEmpty) {
        final idsToMark = currentState.pendingReadIds.toList();
        _markAsReadBulk(idsToMark);
      }
    });
  }

  Future<void> _markAsReadBulk(List<String> ids) async {
    final currentState = state.value;
    if (currentState == null || currentState.selectedStudent == null) return;

    // Optimistic Update
    final newBillingItems = currentState.billingItems.map((item) {
      if (ids.contains(item['id'].toString())) {
        final newItem = Map<String, dynamic>.from(item);
        newItem['is_read'] = true;
        return newItem;
      }
      return item;
    }).toList();

    state = AsyncData(
      currentState.copyWith(billingItems: newBillingItems, pendingReadIds: {}),
    );

    try {
      await FinanceService.markBillRead(
        studentId: currentState.selectedStudent!.id,
        billIds: ids,
      );
    } catch (e) {
      AppLogger.error('finance', e);
    }
  }

  Future<void> forceRefresh() async {
    state = state.whenData((s) => s.copyWith(isLoading: true));
    await LocalCacheService.clearStartingWith('parent_billing_');
    state = AsyncData(await _init());
  }

  // --- Data Loading ---

  Future<List<Student>> _loadStudents() async {
    const cacheKey = 'parent_billing_students';
    final cached = await LocalCacheService.load(
      cacheKey,
      ttl: const Duration(hours: 6),
    );

    if (cached != null && cached is List && cached.isNotEmpty) {
      return cached.map((s) => Student.fromJson(s)).toList();
    }

    try {
      final prefs = PreferencesService();
      final userString = prefs.getString('user');
      if (userString == null) return [];
      final userData = json.decode(userString);
      final userId = userData['id'].toString();
      final guardianEmail = userData['email'];

      final allStudents = await getIt<ApiStudentService>().getStudent(
        userId: userId,
        guardianEmail: guardianEmail,
      );

      List<dynamic> filtered = allStudents;
      if (userData['siswa_id'] != null && userData['siswa_id'].isNotEmpty) {
        filtered = allStudents
            .where((s) => s['id'] == userData['siswa_id'])
            .toList();
      }

      LocalCacheService.save(cacheKey, filtered);
      return filtered.map((s) => Student.fromJson(s)).toList();
    } catch (e) {
      AppLogger.error('finance', e);
      return [];
    }
  }

  Future<List<dynamic>> _loadBilling(
    String studentId, {
    bool useCache = true,
  }) async {
    final cacheKey = 'parent_billing_list_$studentId';

    if (useCache) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        return List<dynamic>.from(cached);
      }
    }

    try {
      final response = await ApiService().get(
        '/bill/parent',
        params: {
          'student_id': studentId,
          if (state.value?.searchQuery.isNotEmpty ?? false)
            'search': state.value?.searchQuery,
          if (state.value?.statusFilter != null)
            'status': state.value?.statusFilter,
          if (state.value?.periodFilter != null)
            'periode': state.value?.periodFilter,
        },
      );
      final list = response is List ? response : [];
      // Only cache unfiltered results to avoid stale filtered data
      final hasFilters =
          (state.value?.searchQuery.isNotEmpty ?? false) ||
          state.value?.statusFilter != null ||
          state.value?.periodFilter != null;
      if (!hasFilters) {
        LocalCacheService.save(cacheKey, list);
      }
      return list;
    } catch (e) {
      AppLogger.error('finance', e);
      return [];
    }
  }

  Future<void> refreshBilling() async {
    final current = state.value;
    if (current?.selectedStudent == null) return;
    state = state.whenData((s) => s.copyWith(isLoading: true));
    final billing = await _loadBilling(
      current!.selectedStudent!.id,
      useCache: false,
    );
    state = state.whenData(
      (s) => s.copyWith(billingItems: billing, isLoading: false),
    );
  }
}
