import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/admin_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';

/// Mixin for data loading and pagination.
mixin FinanceDataMixin on ConsumerState<FinanceScreen> {
  AdminFinanceController get controller;

  TextEditingController get searchController;

  String? get selectedStatusFilter;

  String? get selectedPeriodFilter;

  ScrollController get billScrollController;

  ScrollController get pendingScrollController;

  int get currentPage;

  int get perPage;

  int get pendingPage;

  int get pendingPerPage;

  bool get hasMoreData;

  bool get hasMorePending;

  bool get isLoadingMore;

  bool get isLoadingMorePending;

  List<dynamic> get billList;

  List<dynamic> get pendingPaymentList;

  void updateBillPage(int value);

  void updatePendingPage(int value);

  void updateBillList(List<dynamic> bills, {bool append = false});

  void updatePendingPaymentList(List<dynamic> payments, {bool append = false});

  void updateHasMoreData(bool value);

  void updateHasMorePending(bool value);

  void updateIsLoadingMore(bool value);

  void updateIsLoadingMorePending(bool value);

  void updateIsLoading(bool value);

  Future<void> forceRefresh() async {
    final cacheKey = buildFinanceCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('finance_');
    await LocalCacheService.clearStartingWith('tour_finance_');
    await loadData(useCache: false);
  }

  String? buildFinanceCacheKey() => controller.buildFinanceCacheKey(
    selectedStatusFilter: selectedStatusFilter,
    selectedPeriodFilter: selectedPeriodFilter,
    searchText: searchController.text,
  );

  Future<void> loadData({bool useCache = true}) async {
    final cacheKey = buildFinanceCacheKey();

    if (useCache && cacheKey != null) {
      try {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached is Map<String, dynamic>) {
          if (mounted) {
            applyLoadedData(cached);
            AppLogger.info('finance', 'Loaded from cache');
            // Still fetch fresh data in background to catch
            // stale cache (e.g. payment types added/removed
            // in another session).
            _refreshInBackground(cacheKey);
            return;
          }
        }
      } catch (e) {
        AppLogger.error('finance', e);
      }
    }

    final hasData = billList.isNotEmpty;
    if (!hasData) {
      updateIsLoading(true);
    }

    try {
      final results = await Future.wait([
        controller.loadPaymentTypes(),
        controller.loadBills(
          page: 1,
          perPage: perPage,
          statusFilter: selectedStatusFilter,
        ),
        controller.loadPendingPayments(page: 1, perPage: pendingPerPage),
        controller.loadDashboardData(),
        controller.loadClassData(),
      ]);

      final ptResult = results[0] as LoadPaymentTypesResult;
      final billResult = results[1] as LoadBillsResult;
      final pendingResult = results[2] as LoadPendingPaymentsResult;
      final dashResult = results[3] as LoadDashboardResult;
      final classResult = results[4] as LoadClassDataResult;

      if (mounted) {
        applyResults(
          ptResult,
          billResult,
          pendingResult,
          dashResult,
          classResult,
        );
      }

      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, buildCacheData());
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
        updateIsLoading(false);
        handleLoadError(error);
      }
    }
  }

  /// Background refresh after cache hit — silently updates UI + cache
  /// if the API returns different data.
  Future<void> _refreshInBackground(String cacheKey) async {
    try {
      final results = await Future.wait([
        controller.loadPaymentTypes(),
        controller.loadBills(
          page: 1,
          perPage: perPage,
          statusFilter: selectedStatusFilter,
        ),
        controller.loadPendingPayments(page: 1, perPage: pendingPerPage),
        controller.loadDashboardData(),
        controller.loadClassData(),
      ]);

      if (!mounted) return;

      applyResults(
        results[0] as LoadPaymentTypesResult,
        results[1] as LoadBillsResult,
        results[2] as LoadPendingPaymentsResult,
        results[3] as LoadDashboardResult,
        results[4] as LoadClassDataResult,
      );

      LocalCacheService.save(cacheKey, buildCacheData());
    } catch (_) {
      // Silent — cache data is already showing
    }
  }

  void applyLoadedData(Map<String, dynamic> cached);

  void applyResults(
    LoadPaymentTypesResult ptResult,
    LoadBillsResult billResult,
    LoadPendingPaymentsResult pendingResult,
    LoadDashboardResult dashResult,
    LoadClassDataResult classResult,
  );

  Map<String, dynamic> buildCacheData();

  void handleLoadError(dynamic error);

  Future<void> loadBills({bool resetPage = true}) async {
    if (resetPage) {
      updateBillPage(1);
      updateBillList([], append: false);
      updateHasMoreData(true);
    }

    updateIsLoading(resetPage);
    updateIsLoadingMore(!resetPage);

    final result = await controller.loadBills(
      page: currentPage,
      perPage: perPage,
      statusFilter: selectedStatusFilter,
    );

    if (mounted) {
      if (result.error != null) {
        SnackBarUtils.showError(context, 'Failed to load: ${result.error}');
      } else {
        updateBillList(result.bills, append: true);
        updateHasMoreData(result.hasMoreData);
      }
      updateIsLoading(false);
      updateIsLoadingMore(false);
    }
  }

  Future<void> loadMoreBills() async {
    if (!hasMoreData) return;
    updateBillPage(currentPage + 1);
    await loadBills(resetPage: false);
  }

  Future<void> loadMorePendingPayments() async {
    if (!hasMorePending) return;
    updateIsLoadingMorePending(true);
    updatePendingPage(pendingPage + 1);
    final result = await controller.loadPendingPayments(
      page: pendingPage,
      perPage: pendingPerPage,
      loadMore: true,
    );
    if (mounted) {
      if (result.error == null) {
        updatePendingPaymentList(result.pendingPaymentList, append: true);
        updateHasMorePending(result.hasMorePending);
      } else {
        updatePendingPage(pendingPage - 1);
      }
      updateIsLoadingMorePending(false);
    }
  }
}
