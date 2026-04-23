import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin providing bill information display builders.
mixin BillInfoMixin {
  /// Abstract: Primary color for styling.
  Color get primaryColor;

  /// Abstract: Bill data object.
  dynamic get bill;

  /// Abstract: Currency formatter function.
  String Function(dynamic) get formatCurrency;

  /// Builds header with gradient background.
  Widget buildHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: _buildHeaderDecoration(),
    child: Row(
      children: [
        _buildHeaderIcon(),
        const SizedBox(width: 14),
        Expanded(child: _buildHeaderTitle()),
      ],
    ),
  );

  /// Builds gradient decoration for header.
  BoxDecoration _buildHeaderDecoration() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
    ),
  );

  /// Builds the header icon container.
  Widget _buildHeaderIcon() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
    ),
    child: const Icon(Icons.payment_rounded, color: Colors.white, size: 22),
  );

  /// Builds the header title text section.
  Widget _buildHeaderTitle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        AppLocalizations.uploadPaymentProof.tr,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      AppSpacing.v2,
      Text(
        'Catat pembayaran manual siswa',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    ],
  );

  /// Builds bill information display.
  Widget buildBillInfo() => Column(
    children: [
      _infoRow(
        AppLocalizations.paymentTypes.tr,
        bill['payment_type']?['name'] ?? bill['jenis_pembayaran_nama'] ?? '-',
      ),
      _infoRow(
        AppLocalizations.billAmount.tr,
        formatCurrency(bill['amount'] ?? bill['bill_amount']),
      ),
    ],
  );

  /// Builds a single info row with label and value.
  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
