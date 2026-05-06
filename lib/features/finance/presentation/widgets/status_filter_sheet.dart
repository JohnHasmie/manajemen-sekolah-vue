// Single-purpose status picker for the Tagihan list.
//
// Replaces the old in-body sub-filter chip strip (Semua / Belum bayar /
// Jatuh tempo). The same three options now live in the page header as
// a `BrandFilterChip(label: 'Status')` — tapping the chip opens this
// sheet, the user picks one, and the result flows back to
// `admin_finance_screen.dart` to update `_tagihanFilterKey`.
//
// Returns the chosen [TagihanStatusFilter] or `null` if dismissed.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// One of the three Tagihan status filters. Maps 1:1 to the
/// `_tagihanFilterKey` strings used by [TagihanTab].
enum TagihanStatusFilter { all, unpaid, overdue }

extension TagihanStatusFilterX on TagihanStatusFilter {
  String get key => switch (this) {
    TagihanStatusFilter.all => 'all',
    TagihanStatusFilter.unpaid => 'unpaid',
    TagihanStatusFilter.overdue => 'overdue',
  };

  String get displayLabel => switch (this) {
    TagihanStatusFilter.all => 'Semua',
    TagihanStatusFilter.unpaid => 'Belum bayar',
    TagihanStatusFilter.overdue => 'Jatuh tempo',
  };

  /// Header chip value — `null` when "Semua" so the chip falls back to
  /// the dashed placeholder state instead of showing "Semua" as an
  /// applied filter (matches the parent role's filter chip pattern).
  String? get chipValueOrNull =>
      this == TagihanStatusFilter.all ? null : displayLabel;
}

TagihanStatusFilter tagihanStatusFromKey(String key) {
  switch (key) {
    case 'unpaid':
      return TagihanStatusFilter.unpaid;
    case 'overdue':
      return TagihanStatusFilter.overdue;
    default:
      return TagihanStatusFilter.all;
  }
}

/// Opens the picker and returns the chosen filter, or `null` if
/// dismissed via Batal / drag-down.
Future<TagihanStatusFilter?> showTagihanStatusFilterSheet(
  BuildContext context, {
  required Color primaryColor,
  required TagihanStatusFilter initial,
  required int overdueCount,
}) {
  return showModalBottomSheet<TagihanStatusFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TagihanStatusFilterSheet(
      primaryColor: primaryColor,
      initial: initial,
      overdueCount: overdueCount,
    ),
  );
}

class _TagihanStatusFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final TagihanStatusFilter initial;
  final int overdueCount;

  const _TagihanStatusFilterSheet({
    required this.primaryColor,
    required this.initial,
    required this.overdueCount,
  });

  @override
  State<_TagihanStatusFilterSheet> createState() =>
      _TagihanStatusFilterSheetState();
}

class _TagihanStatusFilterSheetState extends State<_TagihanStatusFilterSheet> {
  late TagihanStatusFilter _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    return AppBottomSheet(
      title: 'Status tagihan',
      subtitle: 'Saring tagihan berdasarkan status pembayaran.',
      icon: Icons.task_alt_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.55,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _Option(
            icon: Icons.list_rounded,
            label: 'Semua tagihan',
            description: 'Tampilkan semua tagihan tanpa filter status.',
            iconColor: ColorUtils.slate500,
            primaryColor: navy,
            selected: _selected == TagihanStatusFilter.all,
            onTap: () => setState(() => _selected = TagihanStatusFilter.all),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Belum bayar',
            description: 'Tagihan yang belum dilunasi wali / siswa.',
            iconColor: const Color(0xFFB45309),
            primaryColor: navy,
            selected: _selected == TagihanStatusFilter.unpaid,
            onTap: () => setState(() => _selected = TagihanStatusFilter.unpaid),
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.priority_high_rounded,
            label: 'Jatuh tempo',
            description:
                'Tagihan belum bayar yang sudah lewat tanggal jatuh tempo.',
            iconColor: const Color(0xFFDC2626),
            primaryColor: navy,
            badge: widget.overdueCount > 0 ? widget.overdueCount : null,
            selected: _selected == TagihanStatusFilter.overdue,
            onTap: () =>
                setState(() => _selected = TagihanStatusFilter.overdue),
          ),
          const SizedBox(height: 18),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Terapkan',
        primaryColor: navy,
        secondaryLabel: 'Batal',
        onPrimary: () => AppNavigator.pop(context, _selected),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color iconColor;
  final Color primaryColor;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    required this.description,
    required this.iconColor,
    required this.primaryColor,
    required this.selected,
    required this.onTap,
    this.badge,
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
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ],
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
