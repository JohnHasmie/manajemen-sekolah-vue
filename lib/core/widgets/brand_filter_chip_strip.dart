// Horizontal strip of filter chips designed to live inside a brand
// gradient hero (parent role azure, admin navy, teacher teal/azure).
//
// Why this exists
// ---------------
// The parent deep-tab screens — Nilai, Tagihan, Aktivitas Kelas,
// Pengumuman — all need a "what filters are currently applied?" strip
// just below the child selector. The pattern is consistent across
// every screen:
//
//   • Each *applied* filter renders as a solid white-tinted pill
//     showing its current value, with an optional dropdown chevron
//     hinting "tap to change".
//   • Each *unset* filter renders as a dashed-border placeholder
//     `+ <Filter name>` so the parent can discover the filter without
//     opening a separate sheet.
//
// Putting both states in one strip keeps the header compact (no
// separate "Filter" button → bottom sheet round-trip just to add a
// status filter), and the whole strip shares the brand-gradient
// styling so it visually belongs to the hero rather than the body.
//
// Visual contract (mockups: `Parent_Phase3_Nilai_Mockup.svg`,
// `Parent_Phase3_Tagihan_Mockup.svg`)
// --------------------------------------------------------------------
//   • Strip height: 36 px.
//   • Applied chip: 18% white fill, no border, white text 11pt-12.5pt
//     (varies by content), optional 6 px chevron-down on the right.
//   • Placeholder chip: 14% white fill, dashed white border (28% white,
//     3-3 dash pattern), white "+" + 11pt 78%-white label text.
//   • 8 px gap between chips, scrollable horizontally when total
//     width exceeds the screen.
//
// Used by:
//   • parent_grade_screen — Nilai (Periode + Mapel + Jenis).
//   • parent_billing_screen — Tagihan (Periode + Status).
//   • parent_attendance_screen — Kehadiran (Bulan + Status).
//   • parent_class_activity_screen — Aktivitas (Mapel + Tipe).
//   • parent_announcement_screen — Pengumuman (Kategori + Sumber).
import 'package:flutter/material.dart';

/// One entry in the filter chip strip.
///
/// When [value] is non-null the chip renders as the *applied* state
/// showing that value. When [value] is null it renders as the dashed
/// placeholder `+ <label>`. Tapping either fires [onTap] — typically
/// the host screen opens a bottom sheet or popup to let the parent
/// pick a value.
class BrandFilterChip {
  /// Short filter label shown either alone (placeholder) or as the
  /// hint behind the value (e.g. "Jenis", "Status", "Periode").
  final String label;

  /// Currently selected value. `null` ⇒ render as dashed placeholder.
  final String? value;

  /// Tap handler — opens the picker for this filter. If null the chip
  /// renders but is non-interactive (rare; useful for read-only
  /// surfaces).
  final VoidCallback? onTap;

  /// Show a chevron-down on the right edge of the *applied* state to
  /// hint that the value can be changed. Defaults to true. Not shown
  /// in the placeholder state (the `+` already does that job).
  final bool showChevron;

  /// Optional explicit width override. Most chips are content-sized;
  /// pass a width for the lead "Periode"-style chip that anchors the
  /// strip and shouldn't shrink/grow with neighbouring chips.
  final double? width;

  const BrandFilterChip({
    required this.label,
    required this.value,
    required this.onTap,
    this.showChevron = true,
    this.width,
  });
}

/// Horizontal strip of brand-tinted filter chips for use inside a
/// gradient hero header.
///
/// Example:
/// ```dart
/// BrandFilterChipStrip(
///   chips: [
///     BrandFilterChip(
///       label: 'Periode',
///       value: 'Sem. Ganjil 2025/2026',
///       onTap: _openPeriodPicker,
///       width: 172,
///     ),
///     BrandFilterChip(
///       label: 'Mapel',
///       value: 'Matematika',
///       onTap: _openSubjectPicker,
///     ),
///     BrandFilterChip(
///       label: 'Jenis',
///       value: null,
///       onTap: _openTypePicker,
///     ),
///   ],
/// );
/// ```
class BrandFilterChipStrip extends StatelessWidget {
  /// The chips to render, left-to-right.
  final List<BrandFilterChip> chips;

  /// Vertical padding above and below the strip. Defaults to 0 — the
  /// host header places the strip with its own spacing.
  final EdgeInsetsGeometry padding;

  const BrandFilterChipStrip({
    super.key,
    required this.chips,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    // Two layout modes, picked at build time via LayoutBuilder:
    //
    //  • FILL mode (default for parent / 2–3-chip strips): Row of
    //    Expanded / fixed-width chips so the strip fills the gradient
    //    header width. Matches the v3 mockup. Chips that declare an
    //    explicit `width` (e.g. the lead "Periode" chip) keep that
    //    width; chips without a `width` flex to share the remainder.
    //
    //  • SCROLL mode (admin Jadwal-style 4-chip strip on narrow
    //    devices): a horizontal scroller with intrinsic-width chips so
    //    placeholder chips like "+ Kelas" never get clipped. Triggered
    //    when the estimated minimum row width exceeds the available
    //    width.
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 32,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Minimum width a *flex* chip needs to render its content
            // without overflow. Calibrated for "+ Kelas" placeholder
            // (largest of the common admin labels) at the current
            // 11pt font + 10dp horizontal padding.
            const minFlexChipWidth = 72.0;
            const gap = 6.0;

            double minRequired = 0;
            for (var i = 0; i < chips.length; i++) {
              if (i > 0) minRequired += gap;
              minRequired += chips[i].width ?? minFlexChipWidth;
            }

            final overflows = minRequired > constraints.maxWidth;

            if (overflows) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _ChipView(chip: chips[i]),
                    ],
                  ],
                ),
              );
            }

            return Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  if (chips[i].width != null)
                    _ChipView(chip: chips[i])
                  else
                    Expanded(child: _ChipView(chip: chips[i])),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChipView extends StatelessWidget {
  final BrandFilterChip chip;

  const _ChipView({required this.chip});

  @override
  Widget build(BuildContext context) {
    final isApplied = chip.value != null;
    final inner = isApplied ? _buildApplied() : _buildPlaceholder();

    final container = Container(
      width: chip.width,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        // Hard colors only. Applied chip = 25%-fill solid white;
        // placeholder = 18%-fill with a 1px hairline white border.
        color: isApplied
            ? const Color(0x40FFFFFF)
            : const Color(0x2EFFFFFF),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: isApplied
            ? null
            : Border.all(
                color: Colors.white,
                width: 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
      ),
      alignment: Alignment.center,
      child: inner,
    );

    if (chip.onTap == null) return container;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: chip.onTap,
        child: container,
      ),
    );
  }

  Widget _buildApplied() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            chip.value!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
        if (chip.showChevron) ...[
          const SizedBox(width: 4),
          const _ChevronDown(),
        ],
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '+',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          chip.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            // Solid white — placeholder text reads as a clear
            // affordance on the gradient.
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ChevronDown extends StatelessWidget {
  const _ChevronDown();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: CustomPaint(painter: _ChevronPainter()),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.32)
      ..lineTo(size.width / 2, size.height * 0.78)
      ..lineTo(size.width, size.height * 0.32);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) => false;
}
