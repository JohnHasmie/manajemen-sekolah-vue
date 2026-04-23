import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';

/// Mixin for parsing and extracting goal data from payment types.
mixin PaymentFormParsersMixin on ConsumerState<PaymentTypeFormSheet> {
  /// Parses goal data from various formats (Map, JSON string, or null).
  /// Returns empty map if parsing fails.
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

  /// Extracts a human-readable description from goal data.
  /// Falls back to default text if description is not found.
  String getGoalDescription(dynamic goalData) {
    final parsedGoal = parseGoal(goalData);
    return parsedGoal['description'] ?? 'Tujuan pembayaran';
  }
}
