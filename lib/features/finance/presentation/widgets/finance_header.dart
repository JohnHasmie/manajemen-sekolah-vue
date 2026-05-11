// Admin Keuangan header — adopts the parent role's `BrandPageHeader`
// pattern so admin/parent feel like siblings of the same brand.
//
// The chip strip in the bottom slot is now driven by the screen — the
// screen builds whatever `BrandFilterChip`s make sense for the active
// tab and passes them in. This lets the Tagihan tab show
// Status/Bulan/Jenis chips while the Jenis tab shows Status/Periode
// chips without the header itself caring about which is which.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';

class FinanceHeader extends ConsumerWidget {
  const FinanceHeader({
    required this.languageProvider,
    required this.primaryColor,
    required this.onTuneTap,
    required this.activeFilterCount,
    required this.chips,
    this.kpiOverlayHeight = 0,
    this.isRealtimeFresh,
    super.key,
  });

  final dynamic languageProvider;

  /// Forwarded to [BrandPageHeader.isRealtimeFresh] — paints the
  /// compact green/grey dot beside the centered title. Defaults to
  /// `null` (no dot) since admin Keuangan currently has no realtime
  /// surface; pass a bool from the screen if/when one is wired up.
  final bool? isRealtimeFresh;

  /// Brand primary — passed through so the badge ring on the action
  /// icon matches the gradient even when the role color is overridden.
  final Color primaryColor;

  /// Tap handler for the trailing tune icon — opens the most-relevant
  /// filter sheet for the active tab. Screen decides which.
  final VoidCallback onTuneTap;

  /// Combined count of all currently-applied filters across the chip
  /// strip — drives the small badge on the tune icon.
  final int activeFilterCount;

  /// Chip strip rendered in the bottomSlot. The screen builds different
  /// chips per active tab so the header stays presentation-only.
  final List<BrandFilterChip> chips;

  /// Forwarded straight to [BrandPageHeader.kpiOverlayHeight] so the
  /// gradient extends past the chip strip and a KPI card stacked
  /// below tucks into the bottom of the gradient — same pattern the
  /// parent role uses on its Tagihan / Nilai screens.
  final double kpiOverlayHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = languageProvider;
    return BrandPageHeader(
      role: 'admin',
      // Tab-root surface — the bottom shell drives navigation, so we
      // suppress the default back chevron.
      showBackButton: false,
      kpiOverlayHeight: kpiOverlayHeight,
      isRealtimeFresh: isRealtimeFresh,
      subtitle: lp.getTranslatedText({'en': 'Operations', 'id': 'Operasional'}),
      title: lp.getTranslatedText({'en': 'Finance', 'id': 'Keuangan'}),
      // Single action icon — Tune. Matches the parent Tagihan header
      // exactly. Pull-to-refresh on the body still works for reload.
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: onTuneTap,
          badgeCount: activeFilterCount > 0 ? activeFilterCount : null,
          badgeBorderColor: primaryColor,
        ),
      ],
      bottomSlot: BrandFilterChipStrip(chips: chips),
    );
  }
}
