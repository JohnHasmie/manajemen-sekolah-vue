// Two tiny single-purpose pickers used by the Jenis tab's header
// chips:
//
//   • [showJenisStatusPickerSheet]  — Aktif / Nonaktif (or Semua)
//   • [showJenisPeriodPickerSheet]  — Sekali / Bulanan / Semester /
//                                     Tahunan (or Semua)
//
// They replace the in-body `FinanceSubFilterStrip` that used to sit
// at the top of the Jenis tab. The two filters now live in the page
// header as `BrandFilterChip`s — tapping a chip opens one of these
// sheets and the result writes to the existing FinanceFilterMixin
// state (`_selectedStatusFilter` / `_selectedPeriodFilter`).
//
// Both return a `String?` — `null` means "Semua / no filter applied",
// non-null is the backend token (`'active'` / `'inactive'` /
// `'sekali bayar'` / `'bulanan'` / `'semester'` / `'tahunan'`). The
// sheets return `null` for both "user picked Semua" *and* "user
// dismissed" — the screen guards against the latter by checking a
// dedicated `bool` from the result wrapper below.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Wraps the chosen value so callers can distinguish "user picked
/// Semua / cleared the filter" (`value == null`) from "user dismissed
/// the sheet" (the whole `JenisFilterResult` is null).
class JenisFilterResult {
  final String? value;
  const JenisFilterResult(this.value);
}

// =====================================================================
// Status picker — Aktif / Nonaktif
// =====================================================================

Future<JenisFilterResult?> showJenisStatusPickerSheet(
  BuildContext context, {
  required Color primaryColor,
  required String? initial,
}) {
  return showModalBottomSheet<JenisFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _JenisStatusPickerSheet(primaryColor: primaryColor, initial: initial),
  );
}

class _JenisStatusPickerSheet extends StatefulWidget {
  final Color primaryColor;
  final String? initial;

  const _JenisStatusPickerSheet({
    required this.primaryColor,
    required this.initial,
  });

  @override
  State<_JenisStatusPickerSheet> createState() =>
      _JenisStatusPickerSheetState();
}

class _JenisStatusPickerSheetState extends State<_JenisStatusPickerSheet> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    return AppBottomSheet(
      title: 'Status jenis',
      subtitle: 'Pilih jenis pembayaran berdasarkan status aktivasi.',
      icon: Icons.toggle_on_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.5,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _Option(
            icon: Icons.list_rounded,
            label: 'Semua',
            description: 'Tampilkan semua jenis tanpa filter status.',
            iconColor: ColorUtils.slate500,
            primaryColor: navy,
            selected: _value == null,
            onTap: () => setState(() => _value = null),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.check_circle_rounded,
            label: 'Aktif',
            description: 'Hanya jenis yang sedang aktif menagih.',
            iconColor: const Color(0xFF059669),
            primaryColor: navy,
            selected: _value == 'active',
            onTap: () => setState(() => _value = 'active'),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.pause_circle_filled_rounded,
            label: 'Nonaktif',
            description: 'Jenis yang dijeda dan tidak membuat tagihan baru.',
            iconColor: ColorUtils.slate500,
            primaryColor: navy,
            selected: _value == 'inactive',
            onTap: () => setState(() => _value = 'inactive'),
          ),
          const SizedBox(height: 18),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Terapkan',
        primaryColor: navy,
        secondaryLabel: 'Batal',
        onPrimary: () => AppNavigator.pop(context, JenisFilterResult(_value)),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

// =====================================================================
// Period picker — Sekali / Bulanan / Semester / Tahunan
// =====================================================================

Future<JenisFilterResult?> showJenisPeriodPickerSheet(
  BuildContext context, {
  required Color primaryColor,
  required String? initial,
}) {
  return showModalBottomSheet<JenisFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _JenisPeriodPickerSheet(primaryColor: primaryColor, initial: initial),
  );
}

class _JenisPeriodPickerSheet extends StatefulWidget {
  final Color primaryColor;
  final String? initial;

  const _JenisPeriodPickerSheet({
    required this.primaryColor,
    required this.initial,
  });

  @override
  State<_JenisPeriodPickerSheet> createState() =>
      _JenisPeriodPickerSheetState();
}

class _JenisPeriodPickerSheetState extends State<_JenisPeriodPickerSheet> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    return AppBottomSheet(
      title: 'Periode penagihan',
      subtitle: 'Pilih jenis pembayaran berdasarkan frekuensi penagihan.',
      icon: Icons.schedule_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.7,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _Option(
            icon: Icons.list_rounded,
            label: 'Semua periode',
            description: 'Tanpa filter frekuensi.',
            iconColor: ColorUtils.slate500,
            primaryColor: navy,
            selected: _value == null,
            onTap: () => setState(() => _value = null),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.looks_one_rounded,
            label: 'Sekali',
            description: 'Tagihan sekali jalan tanpa pengulangan.',
            iconColor: navy,
            primaryColor: navy,
            selected: _value == 'sekali bayar',
            onTap: () => setState(() => _value = 'sekali bayar'),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.calendar_view_month_rounded,
            label: 'Bulanan',
            description: 'Tagihan otomatis terbit setiap bulan.',
            iconColor: navy,
            primaryColor: navy,
            selected: _value == 'bulanan',
            onTap: () => setState(() => _value = 'bulanan'),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.date_range_rounded,
            label: 'Semester',
            description: 'Tagihan otomatis terbit per semester.',
            iconColor: navy,
            primaryColor: navy,
            selected: _value == 'semester',
            onTap: () => setState(() => _value = 'semester'),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.calendar_today_rounded,
            label: 'Tahunan',
            description: 'Tagihan otomatis terbit setiap tahun.',
            iconColor: navy,
            primaryColor: navy,
            selected: _value == 'tahunan',
            onTap: () => setState(() => _value = 'tahunan'),
          ),
          const SizedBox(height: 18),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Terapkan',
        primaryColor: navy,
        secondaryLabel: 'Batal',
        onPrimary: () => AppNavigator.pop(context, JenisFilterResult(_value)),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

// =====================================================================
// Display-label helpers — used by the screen to derive the chip value
// from the stored backend token. Returning `null` keeps the chip in
// the dashed placeholder state (matches parent role pattern).
// =====================================================================

String? jenisStatusChipLabel(String? token) {
  switch (token) {
    case 'active':
      return 'Aktif';
    case 'inactive':
      return 'Nonaktif';
    default:
      return null;
  }
}

String? jenisPeriodChipLabel(String? token) {
  switch (token) {
    case 'sekali bayar':
    case 'sekali':
    case 'once':
      return 'Sekali';
    case 'bulanan':
    case 'monthly':
      return 'Bulanan';
    case 'semester':
      return 'Semester';
    case 'tahunan':
    case 'yearly':
      return 'Tahunan';
    default:
      return null;
  }
}

// =====================================================================
// Shared option row — the same look as
// `status_filter_sheet.dart`'s `_Option`. Kept private here so the two
// pickers stay self-contained.
// =====================================================================

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color iconColor;
  final Color primaryColor;
  final bool selected;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    required this.description,
    required this.iconColor,
    required this.primaryColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 20, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
