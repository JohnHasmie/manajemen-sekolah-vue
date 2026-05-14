// Pure formatting and translation helpers for payment types and finance data.
// Extracted from [AdminFinanceController] to keep main controller lean.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Pure formatting helpers for payment types, amounts, and dates.
/// No state, no side effects — analogous to a Vue filters plugin.
class PaymentTypesFormatter {
  final Ref _ref;

  PaymentTypesFormatter(this._ref);

  // ─── Color & gradient ───────────────────────────────────────────────────

  /// Returns the primary theme color for the admin role.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Returns the card gradient for admin finance UI elements.
  /// Centralized via [ColorUtils.headerFadeGradient] so this matches the
  /// rest of the brand fade-gradient sites.
  LinearGradient getCardGradient() {
    return ColorUtils.headerFadeGradient(getPrimaryColor());
  }

  // ─── Currency formatting ────────────────────────────────────────────────

  /// Formats a raw numeric amount into Indonesian Rupiah string.
  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final double value = double.parse(amount.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(value);
    } catch (e) {
      return 'Rp 0';
    }
  }

  // ─── Month formatting ───────────────────────────────────────────────────

  /// Converts a `YYYY-MM` string like `"2024-03"` into a human-readable
  /// Indonesian month name: `"Maret 2024"`.
  String formatMonth(String? monthStr) {
    if (monthStr == null || monthStr.isEmpty) return '';
    try {
      final parts = monthStr.split('-');
      if (parts.length != 2) return monthStr;

      final year = parts[0];
      final month = int.tryParse(parts[1]) ?? 1;

      const monthNames = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      return '${monthNames[month - 1]} $year';
    } catch (e) {
      return monthStr;
    }
  }

  // ─── Goal parsing ───────────────────────────────────────────────────────

  /// Parses a JSON-encoded or Map goal/target object into a plain Dart Map.
  /// Returns an empty map on null or parse error.
  Map<String, dynamic> parseGoal(dynamic goalData) {
    if (goalData == null) return {};
    if (goalData is Map<String, dynamic>) return goalData;
    if (goalData is String) {
      try {
        return json.decode(goalData) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.error('finance', e);
        return {};
      }
    }
    return {};
  }

  /// Extracts the human-readable goal description from raw goal data.
  String getGoalDescription(dynamic goalData) {
    final parsed = parseGoal(goalData);
    return parsed['description'] ?? 'Tujuan pembayaran';
  }

  // ─── Period translation ──────────────────────────────────────────────────

  /// Returns the translated period label for a payment type period string.
  String getTranslatedPeriod(String? period) {
    if (period == null) return '-';

    final languageProvider = _ref.read(languageRiverpod);
    final lower = period.toLowerCase();

    if (lower == 'once' || lower == 'sekali') {
      return languageProvider.getTranslatedText({
        'en': 'One Time',
        'id': 'Sekali',
      });
    } else if (lower == 'bulanan' || lower == 'monthly') {
      return languageProvider.getTranslatedText({
        'en': 'Monthly',
        'id': 'Bulanan',
      });
    } else if (lower == 'tahunan' || lower == 'yearly') {
      return languageProvider.getTranslatedText({
        'en': 'Yearly',
        'id': 'Tahunan',
      });
    } else if (lower == 'semester') {
      return languageProvider.getTranslatedText({
        'en': 'Semester',
        'id': 'Semester',
      });
    }

    return period;
  }

  // ─── Filtering ──────────────────────────────────────────────────────────

  /// Filters [paymentTypeList] by [searchTerm], [statusFilter], and
  /// [periodFilter]. Pure function — no side effects.
  ///
  /// Filter values are translated to backend tokens:
  ///   * statusFilter: `'aktif'` → backend `'active'`,
  ///                   `'non_aktif'` → backend `'inactive'`.
  ///     Earlier revisions compared `'aktif'` directly to
  ///     `item['status']`, but the backend stores `'active'` /
  ///     `'inactive'` (English), so the comparison never matched and
  ///     the chip filter silently emptied the list.
  ///   * periodFilter: accepts both Indonesian (`'bulanan'`,
  ///     `'tahunan'`, `'sekali bayar'`, `'semester'`) and the
  ///     uppercase English variants seen in legacy backend rows
  ///     (`'MONTHLY'`, `'YEARLY'`, etc.) — see
  ///     `app/Console/Commands/GenerateBills.php` which checks both.
  List<dynamic> getFilteredPaymentTypes({
    required List<dynamic> paymentTypeList,
    required String searchTerm,
    String? statusFilter,
    String? periodFilter,
  }) {
    String? expectedStatus;
    if (statusFilter == 'aktif' || statusFilter == 'active') {
      expectedStatus = 'active';
    } else if (statusFilter == 'non_aktif' ||
        statusFilter == 'non-aktif' ||
        statusFilter == 'inactive') {
      expectedStatus = 'inactive';
    }

    Set<String>? acceptedPeriods;
    if (periodFilter != null) {
      switch (periodFilter.toLowerCase()) {
        case 'bulanan':
        case 'monthly':
          acceptedPeriods = {'bulanan', 'monthly'};
          break;
        case 'tahunan':
        case 'yearly':
          acceptedPeriods = {'tahunan', 'yearly'};
          break;
        case 'sekali bayar':
        case 'sekali':
        case 'once':
          acceptedPeriods = {'sekali bayar', 'sekali', 'once'};
          break;
        case 'semester':
          acceptedPeriods = {'semester'};
          break;
        default:
          acceptedPeriods = {periodFilter.toLowerCase()};
      }
    }

    final lowerSearch = searchTerm.toLowerCase();

    return paymentTypeList.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          name.contains(lowerSearch) ||
          description.contains(lowerSearch);

      final itemStatus = item['status']?.toString().toLowerCase() ?? '';
      final matchesStatus =
          expectedStatus == null || itemStatus == expectedStatus;

      final itemPeriod = item['periode']?.toString().toLowerCase() ?? '';
      final matchesPeriod =
          acceptedPeriods == null || acceptedPeriods.contains(itemPeriod);

      return matchesSearch && matchesStatus && matchesPeriod;
    }).toList();
  }
}
