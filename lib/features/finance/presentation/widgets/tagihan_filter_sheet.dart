// Bottom-sheet for filtering the Tagihan list by jenis pembayaran
// (multi-select). Year and month are picked from the header pill.
//
// Returns the chosen [TagihanFilterResult] when the admin taps Apply,
// or `null` if dismissed. The caller is responsible for storing the
// result and applying it to the local bill list.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

class TagihanFilterResult {
  /// IDs of payment types to keep. Empty set means "all jenis".
  final Set<String> selectedJenisIds;

  const TagihanFilterResult({
    required this.selectedJenisIds,
  });

  /// Convenience helper — produces the empty / no-filter result.
  factory TagihanFilterResult.empty() =>
      const TagihanFilterResult(selectedJenisIds: {});

  bool get hasAny => selectedJenisIds.isNotEmpty;
}

/// Shows the sheet and returns the result on Apply, or `null` if
/// dismissed via Batal / drag-down.
Future<TagihanFilterResult?> showTagihanFilterSheet(
  BuildContext context, {
  required Color primaryColor,
  required List<Map<String, String>> jenisOptions,
  required Set<String> initialJenisIds,
}) {
  return showModalBottomSheet<TagihanFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TagihanFilterSheet(
      primaryColor: primaryColor,
      jenisOptions: jenisOptions,
      initialJenisIds: initialJenisIds,
    ),
  );
}

class TagihanFilterSheet extends StatefulWidget {
  /// Brand primary color (admin navy).
  final Color primaryColor;

  /// All payment types — `[{id, name}, …]`. Driven by the parent's
  /// already-fetched payment-type list so we don't refetch.
  final List<Map<String, String>> jenisOptions;

  /// Pre-selected jenis IDs (from screen state).
  final Set<String> initialJenisIds;

  const TagihanFilterSheet({
    super.key,
    required this.primaryColor,
    required this.jenisOptions,
    required this.initialJenisIds,
  });

  @override
  State<TagihanFilterSheet> createState() => _TagihanFilterSheetState();
}

class _TagihanFilterSheetState extends State<TagihanFilterSheet> {
  late Set<String> _jenisIds;

  @override
  void initState() {
    super.initState();
    _jenisIds = Set<String>.from(widget.initialJenisIds);
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;

    return AppBottomSheet(
      title: 'Filter tagihan',
      subtitle: 'Saring berdasarkan jenis pembayaran.',
      icon: Icons.tune_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.86,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _SectionHeader(
            label: 'JENIS PEMBAYARAN',
            icon: Icons.credit_card_rounded,
            trailing: '${widget.jenisOptions.length} TIPE',
          ),
          const SizedBox(height: 10),
          if (widget.jenisOptions.isEmpty)
            const _PlaceholderTile(
              icon: Icons.payments_outlined,
              label: 'Belum ada jenis pembayaran terdata.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in widget.jenisOptions)
                  _PillToggle(
                    label: opt['name'] ?? '-',
                    selected: _jenisIds.contains(opt['id']),
                    primaryColor: navy,
                    onTap: () {
                      setState(() {
                        final id = opt['id']!;
                        if (_jenisIds.contains(id)) {
                          _jenisIds.remove(id);
                        } else {
                          _jenisIds.add(id);
                        }
                      });
                    },
                  ),
              ],
            ),
          const SizedBox(height: 22),
          // Reset link
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _jenisIds.clear();
              }),
              icon: const Icon(
                Icons.cleaning_services_rounded,
                size: 14,
                color: Color(0xFFDC2626),
              ),
              label: const Text(
                'Hapus semua filter',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Terapkan',
        primaryColor: navy,
        secondaryLabel: 'Batal',
        onPrimary: () => AppNavigator.pop(
          context,
          TagihanFilterResult(
            selectedJenisIds: Set.from(_jenisIds),
          ),
        ),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? trailing;
  const _SectionHeader({
    required this.label,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ColorUtils.slate500),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ColorUtils.slate500,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            '· $trailing',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ColorUtils.slate300,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: ColorUtils.slate100)),
      ],
    );
  }
}

class _PillToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;
  const _PillToggle({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 13, color: primaryColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? primaryColor : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
