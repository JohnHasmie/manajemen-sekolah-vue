import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';

/// Mixin for handling submission logic in payment form.
mixin PaymentFormHandlersMixin on ConsumerState<PaymentTypeFormSheet> {
  // Allowed values mirror the backend's CreatePaymentTypeRequest `in:` rule
  // so the client rejects bad combinations *before* hitting the server.
  // Keep these in sync with:
  //   backendmanajemensekolah_laravel/app/Http/Requests/CreatePaymentTypeRequest.php
  // Backend rename: canonical English values are `once` / `monthly`
  // / `yearly`. Keep `semester` (not in guide §4 mapping) and the
  // legacy Indonesian aliases so existing forms continue to validate.
  static const _allowedPeriodes = {
    'sekali',
    'bulanan',
    'semester',
    'tahunan',
    'once',
    'monthly',
    'yearly',
  };
  static const _allowedStatuses = {'active', 'inactive'};

  // Backend rules: name max:255, description nullable, amount numeric|min:1.
  // We add a sensible upper bound on amount + description so an admin can't
  // paste a 50k-char block that'll bloat the row and then trip a 422.
  static const _maxNameLength = 255;
  static const _maxDescriptionLength = 1000;
  static const _maxAmount = 999999999999; // Rp 999,999,999,999 (12 digits)

  /// Validates and submits payment type form data.
  /// Handles both create and update scenarios via API.
  Future<void> handleFormSubmit(
    BuildContext context, {
    required TextEditingController nameController,
    required TextEditingController amountController,
    required TextEditingController periodController,
    required String status,
    required Map<String, dynamic>? goalData,
    required Map<String, dynamic>? paymentType,
    required VoidCallback onSaved,
    required TextEditingController descriptionController,
    // Activation flow (Step 3) — null means "use backend defaults"
    // (today + day-10). On create the sheet always supplies these
    // because the form initialises them with sensible defaults.
    DateTime? startDate,
    int? dayOfMonth,
  }) async {
    // Run every pre-submit check up front. Each returns a localised
    // message when something is wrong; the first failure short-circuits.
    //
    // Order matches the form's vertical reading order so the toast
    // points the admin at the section they need to fix without making
    // them scroll up and down hunting for the bad field.
    final validationError = _validate(
      name: nameController.text,
      amountText: amountController.text,
      description: descriptionController.text,
      periode: periodController.text,
      status: status,
      goalData: goalData,
      dayOfMonth: dayOfMonth,
    );
    if (validationError != null) {
      SnackBarUtils.showError(context, validationError);
      return;
    }

    final parsedAmount = CurrencyInputFormatter.parseCurrency(
      amountController.text,
    );

    try {
      final data = <String, dynamic>{
        // Trim user-entered text — Laravel won't strip whitespace, and
        // trailing spaces on `name` create duplicate-looking rows.
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'amount': parsedAmount,
        // Backend rename: `payment_types.periode` → `payment_types.period`.
        'period': periodController.text,
        'status': status == 'active' ? 'active' : 'inactive',
        'goal': goalData,
        // Activation flow — send ISO date so Laravel's `date` rule
        // accepts it cleanly. day_of_month only meaningful for
        // periode=bulanan, but we send it always; the backend ignores
        // it for other periodes.
        if (startDate != null) 'start_date': _formatDateIso(startDate),
        if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      };

      final apiService = ApiService();
      if (paymentType == null) {
        await apiService.post('/payment-types', data);
      } else {
        await apiService.put('/payment-types/${paymentType['id']}', data);
      }

      if (context.mounted) {
        AppNavigator.pop(context);
      }
      onSaved();

      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Data berhasil disimpan');
      }
    } on DioException catch (e) {
      // Dig the real error out of the response body before falling
      // back to ErrorUtils. Without this, Laravel's 422 validation
      // bag and 500 messages all collapse into the generic "Gagal
      // memproses permintaan, silakan hubungi admin." copy, which
      // hides the actual problem from the admin.
      //
      // Laravel-shaped responses we handle:
      //   * 422 → { message: "...", errors: { field: ["msg", ...] } }
      //   * 4xx → { error: "..." }  or  { message: "..." }
      //   * 5xx → may be HTML or { message: "..." } depending on env
      AppLogger.error(
        'finance',
        'payment-type save failed: ${e.response?.statusCode} ${e.message} '
            'body=${e.response?.data}',
      );
      final friendly =
          _extractDioMessage(e) ?? ErrorUtils.getFriendlyMessage(e);
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal menyimpan: $friendly');
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal menyimpan: '
          '${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }

  /// Runs every pre-submit check and returns the first localised error
  /// message — or null when the form is ready to POST.
  ///
  /// Mirrors the backend's `CreatePaymentTypeRequest` rules so the admin
  /// sees a precise toast (e.g. "Nama maksimal 255 karakter") instead
  /// of bouncing off Laravel with a generic 422 → "Gagal memproses".
  ///
  /// Returning a String keeps the call site flat — the handler just
  /// shows the message and returns; no exception plumbing needed.
  String? _validate({
    required String name,
    required String amountText,
    required String description,
    required String periode,
    required String status,
    required Map<String, dynamic>? goalData,
    int? dayOfMonth,
  }) {
    // 1. Nama — required, trimmed, length-capped.
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return 'Nama jenis pembayaran harus diisi';
    }
    if (trimmedName.length > _maxNameLength) {
      return 'Nama maksimal $_maxNameLength karakter';
    }

    // 2. Jumlah — required, > 0, under the 12-digit ceiling.
    if (amountText.trim().isEmpty) {
      return 'Jumlah harus diisi';
    }
    final parsedAmount = CurrencyInputFormatter.parseCurrency(amountText);
    if (parsedAmount <= 0) {
      return 'Jumlah harus lebih besar dari Rp 0';
    }
    if (parsedAmount > _maxAmount) {
      return 'Jumlah terlalu besar, gunakan nilai di bawah '
          'Rp 1 triliun';
    }

    // 3. Deskripsi — optional but length-capped.
    if (description.trim().length > _maxDescriptionLength) {
      return 'Deskripsi maksimal $_maxDescriptionLength karakter';
    }

    // 4. Periode — must be one of the four chip values. Guards against
    //    stale state from older app builds sending values the backend
    //    no longer accepts.
    if (!_allowedPeriodes.contains(periode)) {
      return 'Periode penagihan tidak valid, pilih salah satu opsi';
    }

    // 5. Status — should always be one of two values, but verify so a
    //    refactor on `_StatusSegmented` doesn't silently send garbage.
    final normalisedStatus = status == 'active' ? 'active' : 'inactive';
    if (!_allowedStatuses.contains(normalisedStatus)) {
      return 'Status aktivasi tidak valid';
    }

    // 6. Target penerima — goal must be selected AND non-empty.
    //    Without this the backend stores `{}` and the bill generator
    //    later can't figure out who to charge.
    if (goalData == null || goalData.isEmpty) {
      return 'Tujuan pembayaran harus dipilih';
    }
    final goalError = _validateGoalShape(goalData);
    if (goalError != null) return goalError;

    // 7. Day-of-month — only relevant for monthly Jenis. Clamped 1-28
    //    to match the backend rule (avoids Feb-29 edge cases).
    if ((periode == 'monthly' || periode == 'bulanan') && dayOfMonth != null) {
      if (dayOfMonth < 1 || dayOfMonth > 28) {
        return 'Tanggal jatuh tempo harus antara 1 dan 28';
      }
    }

    return null;
  }

  /// Formats a DateTime as ISO date `YYYY-MM-DD` for Laravel's `date`
  /// validation rule. We strip the time component so daylight-saving
  /// shifts at midnight can't bump the date back by one day.
  String _formatDateIso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Validates the structure of the target-picker payload.
  ///
  /// Two valid shapes (matching `selection_logic_mixin.buildGoalData`):
  ///   * `{ type: 'all', description: '...' }`
  ///   * `{ type: 'custom', classes: [...], students: {classId: [...]},
  ///        description: '...' }`
  ///
  /// For 'custom' the admin must have picked at least one class —
  /// otherwise the backend stores a payload with empty arrays and the
  /// next bill-generation cycle silently produces zero tagihan.
  String? _validateGoalShape(Map<String, dynamic> goal) {
    final type = goal['type'];
    if (type != 'all' && type != 'custom') {
      return 'Target penerima tidak valid, pilih ulang dari daftar';
    }
    if (type == 'custom') {
      final classes = goal['classes'];
      if (classes is! List || classes.isEmpty) {
        return 'Pilih minimal satu kelas pada target penerima';
      }
    }
    return null;
  }

  /// Pulls the most actionable error string out of a DioException.
  ///
  /// Order of preference:
  ///   1. Laravel 422 `errors` map → first field's first message.
  ///   2. Top-level `error` string (our backend uses this often).
  ///   3. Top-level `message` string (Laravel default).
  ///
  /// Returns null when the body doesn't match any known shape so the
  /// caller can fall through to the friendly translator.
  String? _extractDioMessage(DioException e) {
    final body = e.response?.data;
    if (body is! Map) return null;

    // Laravel validation bag: prefer the first field-level message
    // because it tells the admin *which* field tripped the rule.
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty && first.first is String) {
        return first.first as String;
      }
      if (first is String) return first;
    }

    if (body['error'] is String) return body['error'] as String;
    if (body['message'] is String) return body['message'] as String;
    return null;
  }
}
