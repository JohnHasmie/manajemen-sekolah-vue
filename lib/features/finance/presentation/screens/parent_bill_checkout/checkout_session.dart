// Checkout session model + formatting helpers for the parent Bayar
// checkout screen.

part of '../parent_bill_checkout_screen.dart';

/// Mirror of the JSON returned by `POST /bill/{id}/checkout`. The
/// shape matches a typical Midtrans Snap response so swapping the
/// stub gateway for a real provider is a one-method change.
class _CheckoutSession {
  final double amount;
  final double qrisAdminFee;
  final double vaAdminFee;
  final double manualAdminFee;
  final String qrString;
  final String vaNumber;
  final String vaBank;
  final List<(String bank, String account, String owner)> manualBankList;
  final DateTime expiresAt;

  _CheckoutSession({
    required this.amount,
    required this.qrisAdminFee,
    required this.vaAdminFee,
    required this.manualAdminFee,
    required this.qrString,
    required this.vaNumber,
    required this.vaBank,
    required this.manualBankList,
    required this.expiresAt,
  });

  /// Build a session from the backend JSON envelope. Tolerates legacy
  /// or partial payloads by falling back to safe defaults.
  factory _CheckoutSession.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v, {double fallback = 0}) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

    final rawList = json['manual_bank_list'];
    final banks = <(String, String, String)>[];
    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is Map) {
          banks.add((
            (entry['bank'] ?? '').toString(),
            (entry['account_number'] ?? '').toString(),
            (entry['account_name'] ?? '').toString(),
          ));
        }
      }
    }

    DateTime expires;
    final rawExpires = json['expires_at']?.toString();
    if (rawExpires != null && rawExpires.isNotEmpty) {
      expires =
          DateTime.tryParse(rawExpires) ??
          DateTime.now().add(const Duration(hours: 24));
    } else {
      expires = DateTime.now().add(const Duration(hours: 24));
    }

    return _CheckoutSession(
      amount: asDouble(json['amount']),
      qrisAdminFee: asDouble(json['qris_admin_fee']),
      vaAdminFee: asDouble(json['va_admin_fee'], fallback: 4000),
      manualAdminFee: asDouble(json['manual_admin_fee']),
      qrString: (json['qr_string'] ?? '').toString(),
      vaNumber: (json['va_number'] ?? '').toString(),
      vaBank: (json['va_bank'] ?? 'BCA').toString(),
      manualBankList: banks,
      expiresAt: expires,
    );
  }

  /// Per-method admin fee picker. The screen passes the active tab
  /// in so total/breakdown rows always reflect the right surcharge.
  double adminFeeFor(_PayMethod method) {
    switch (method) {
      case _PayMethod.qris:
        return qrisAdminFee;
      case _PayMethod.va:
        return vaAdminFee;
      case _PayMethod.manual:
        return manualAdminFee;
    }
  }

  double totalFor(_PayMethod method) => amount + adminFeeFor(method);
}

/// Turn a "YYYY-MM" bill period (Bill.month format) into a human
/// label like "Mei 2026". Returns the raw value when the shape is
/// unrecognized so the caller can fall through.
String _humanMonthFromBill(String yyyymm) {
  final parts = yyyymm.split('-');
  if (parts.length != 2) return yyyymm;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return yyyymm;
  }
  const months = [
    '',
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
  return '${months[month]} $year';
}

String _formatRupiah(double amount) {
  final whole = amount.round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final remain = s.length - i;
    buf.write(s[i]);
    if (remain > 1 && (remain - 1) % 3 == 0) buf.write('.');
  }
  return 'Rp $buf';
}
