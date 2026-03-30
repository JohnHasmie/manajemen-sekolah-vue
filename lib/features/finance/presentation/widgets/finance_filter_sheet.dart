// Bottom-sheet for filtering payment types by status and period.
//
// Extracted from `_showFilterSheet` in admin_finance_screen.dart.
// Owns its own temporary selection state via StatefulWidget — like a Vue
// component with local `tempSelectedStatus` / `tempSelectedPeriod` data.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Bottom-sheet widget for filtering payment types.
///
/// Receives the current filter selections and a primary colour from the
/// parent, manages temporary state internally, then calls [onApply] with
/// the new (status, period) pair when the admin taps "Apply".
///
/// Like a Vue `<FilterSheet :status="s" :period="p" @apply="onApply" />`
/// component that emits updated values back to the parent on close.
class FinanceFilterSheet extends StatefulWidget {
  /// Currently active status filter ('aktif', 'non_aktif', or null).
  final String? currentStatus;

  /// Currently active period filter ('bulanan', 'tahunan', or null).
  final String? currentPeriod;

  /// Resolved language provider from the parent (avoids a second ref.read).
  final LanguageProvider languageProvider;

  /// Primary brand colour already resolved by the parent screen.
  /// Defaults to [ColorUtils.primary] so callers that don't pass a role colour
  /// (e.g. the parent billing screen) still render correctly.
  final Color? primaryColor;

  /// Called with the new (status, period) values when the admin taps Apply.
  /// Both can be null to clear filters.
  final void Function(String? status, String? period) onApply;

  const FinanceFilterSheet({
    super.key,
    this.currentStatus,
    this.currentPeriod,
    required this.languageProvider,
    this.primaryColor,
    required this.onApply,
  });

  @override
  State<FinanceFilterSheet> createState() => _FinanceFilterSheetState();
}

class _FinanceFilterSheetState extends State<FinanceFilterSheet> {
  // Temporary selections — only committed to the parent when Apply is tapped.
  // Like `data()` in a Vue component: local reactive state.
  late String? _tempStatus;
  late String? _tempPeriod;

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.currentStatus;
    _tempPeriod = widget.currentPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;
    // Fall back to the app's default primary if no role colour was supplied.
    final primary = widget.primaryColor ?? ColorUtils.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primary.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      lang.getTranslatedText({'en': 'Filter', 'id': 'Filter'}),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tempStatus = null;
                    _tempPeriod = null;
                  }),
                  child: Text(
                    lang.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Filter Content ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status section
                  Row(
                    children: [
                      Icon(Icons.toggle_on_rounded,
                          size: 18, color: ColorUtils.slate700),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: ColorUtils.slate900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {
                        'value': 'aktif',
                        'label': lang.getTranslatedText(
                            {'en': 'Active', 'id': 'Aktif'}),
                      },
                      {
                        'value': 'non_aktif',
                        'label': lang.getTranslatedText(
                            {'en': 'Inactive', 'id': 'Non-Aktif'}),
                      },
                    ].map((item) {
                      final isSelected = _tempStatus == item['value'];
                      return FilterChip(
                        label: Text(item['label']!),
                        selected: isSelected,
                        onSelected: (selected) => setState(() {
                          _tempStatus = selected ? item['value'] : null;
                        }),
                        backgroundColor: Colors.white,
                        selectedColor: primary.withValues(alpha: 0.15),
                        checkmarkColor: primary,
                        side: BorderSide(
                          color: isSelected ? primary : ColorUtils.slate300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        labelStyle: TextStyle(
                          color: isSelected ? primary : ColorUtils.slate700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Divider(color: ColorUtils.slate100),
                  const SizedBox(height: AppSpacing.sm),

                  // Period section
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 18, color: ColorUtils.slate700),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        lang.getTranslatedText({
                          'en': 'Payment Period',
                          'id': 'Periode Pembayaran',
                        }),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: ColorUtils.slate900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {
                        'value': 'bulanan',
                        'label': lang.getTranslatedText(
                            {'en': 'Monthly', 'id': 'Bulanan'}),
                      },
                      {
                        'value': 'tahunan',
                        'label': lang.getTranslatedText(
                            {'en': 'Yearly', 'id': 'Tahunan'}),
                      },
                    ].map((item) {
                      final isSelected = _tempPeriod == item['value'];
                      return FilterChip(
                        label: Text(item['label']!),
                        selected: isSelected,
                        onSelected: (selected) => setState(() {
                          _tempPeriod = selected ? item['value'] : null;
                        }),
                        backgroundColor: Colors.white,
                        selectedColor: primary.withValues(alpha: 0.15),
                        checkmarkColor: primary,
                        side: BorderSide(
                          color: isSelected ? primary : ColorUtils.slate300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        labelStyle: TextStyle(
                          color: isSelected ? primary : ColorUtils.slate700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer Buttons ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
                      style: TextStyle(color: ColorUtils.slate600),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      AppNavigator.pop(context);
                      widget.onApply(_tempStatus, _tempPeriod);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.getTranslatedText(
                          {'en': 'Apply Filter', 'id': 'Terapkan'}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
