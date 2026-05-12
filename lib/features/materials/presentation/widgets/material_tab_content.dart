// Scrollable content for the Materi tab of the sub-chapter detail page.
//
// Renders AI-generated sections (ringkasan, tujuan_pembelajaran,
// poin_utama, cara_mengajar) as `SectionCard`s with per-card pencil
// affordances, plus a dashed-violet "Materi Lebih Lengkap dari AI"
// CTA card at the bottom — matches Frame C of the Materi redesign
// mockup.
//
// Edit flow: tapping a section's pencil fires `onEditSection(key,
// currentValue)` so the parent can open `MaterialSectionEditorSheet`
// and persist the result.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/section_card.dart';

/// Tab body for AI and manual material content.
///
/// Like a Vue presentational component: all data comes in as props and
/// side-effects go out through callbacks — no direct state mutation here.
/// [parsedContent] is the decoded `material_content` JSON map (may be null),
/// [aiGeneratedData] is the full AI response map (may be null),
/// [contentList] is the list of manual backend content items,
/// [stripHtml] is a pure utility function injected from the parent,
/// [onRegenerateTap] fires when the bottom AI CTA is tapped,
/// [onEditSection] fires when a per-card pencil is tapped — the parent
/// is responsible for opening the editor sheet and writing back the
/// new value into `material_content`.
class MaterialTabContent extends StatelessWidget {
  final Map<String, dynamic>? parsedContent;
  final Map<String, dynamic>? aiGeneratedData;
  final List<dynamic> contentList;
  final Color primaryColor;

  /// Strips HTML tags from a string — injected so this widget stays stateless.
  final String Function(String) stripHtml;

  /// Called when the bottom dashed-violet "Generate dengan AI" CTA is tapped.
  final VoidCallback onRegenerateTap;

  /// Called when a per-section pencil is tapped. `fieldKey` is the
  /// `material_content` JSON key, `fieldLabel` is the user-facing
  /// title, `currentValue` is the value to seed the editor with (for
  /// list-shaped sections, items joined with `\n`).
  final void Function(String fieldKey, String fieldLabel, String currentValue)?
  onEditSection;

  const MaterialTabContent({
    super.key,
    required this.parsedContent,
    required this.aiGeneratedData,
    required this.contentList,
    required this.primaryColor,
    required this.stripHtml,
    required this.onRegenerateTap,
    this.onEditSection,
  });

  String _listToText(List<dynamic> items) =>
      items.map((e) => e.toString()).join('\n');

  void _editIfWired(String key, String label, String value) {
    final h = onEditSection;
    if (h != null) h(key, label, value);
  }

  @override
  Widget build(BuildContext context) {
    final hasAi = parsedContent != null || aiGeneratedData != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // ── AI Materi Section ────────────────────────────────────────────
        if (parsedContent != null) ...[
          // Ringkasan
          if (parsedContent!['ringkasan'] != null)
            SectionCard(
              icon: Icons.summarize_rounded,
              iconColor: ColorUtils.info600,
              title: 'Ringkasan Materi',
              onEdit: onEditSection == null
                  ? null
                  : () => _editIfWired(
                      'ringkasan',
                      'Ringkasan Materi',
                      parsedContent!['ringkasan']?.toString() ?? '',
                    ),
              child: Text(
                parsedContent!['ringkasan']?.toString() ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),

          // Tujuan Pembelajaran (mockup Frame C)
          if (parsedContent!['tujuan_pembelajaran'] != null) ...[
            const SizedBox(height: AppSpacing.md),
            Builder(
              builder: (_) {
                final tp = parsedContent!['tujuan_pembelajaran'];
                final isList = tp is List;
                final seedValue = isList
                    ? _listToText(tp)
                    : tp?.toString() ?? '';
                return SectionCard(
                  icon: Icons.flag_rounded,
                  iconColor: ColorUtils.success600,
                  title: 'Tujuan Pembelajaran',
                  onEdit: onEditSection == null
                      ? null
                      : () => _editIfWired(
                          'tujuan_pembelajaran',
                          'Tujuan Pembelajaran',
                          seedValue,
                        ),
                  child: isList
                      ? _NumberedList(
                          items: List.from(tp),
                          accent: ColorUtils.success600,
                        )
                      : Text(
                          seedValue,
                          style: TextStyle(
                            color: ColorUtils.slate700,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                );
              },
            ),
          ],

          // Poin Utama
          if (parsedContent!['poin_utama'] is List) ...[
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.lightbulb_rounded,
              iconColor: ColorUtils.amber500,
              title: 'Poin Utama',
              onEdit: onEditSection == null
                  ? null
                  : () => _editIfWired(
                      'poin_utama',
                      'Poin Utama',
                      _listToText(parsedContent!['poin_utama'] as List),
                    ),
              child: _NumberedList(
                items: List.from(parsedContent!['poin_utama'] as List),
                accent: ColorUtils.amber500,
              ),
            ),
          ],

          // Cara Mengajar
          if (parsedContent!['cara_mengajar'] != null) ...[
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.school_rounded,
              iconColor: primaryColor,
              title: 'Cara Mengajar',
              onEdit: onEditSection == null
                  ? null
                  : () => _editIfWired(
                      'cara_mengajar',
                      'Cara Mengajar',
                      parsedContent!['cara_mengajar']?.toString() ?? '',
                    ),
              child: Text(
                parsedContent!['cara_mengajar']?.toString() ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ] else if (aiGeneratedData != null) ...[
          // Fallback: raw material_content as plain text
          SectionCard(
            icon: Icons.auto_awesome,
            iconColor: Colors.orange,
            title: 'Materi AI',
            onEdit: onEditSection == null
                ? null
                : () => _editIfWired(
                    'material_content',
                    'Materi AI',
                    stripHtml(
                      aiGeneratedData!['material_content']?.toString() ?? '',
                    ),
                  ),
            child: Text(
              stripHtml(aiGeneratedData!['material_content']?.toString() ?? ''),
              style: TextStyle(
                color: ColorUtils.slate700,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],

        // ── Bottom AI CTA — dashed violet card (Frame C) ─────────────────
        // Shown when AI content is already present, as an upsell to
        // regenerate / get a more comprehensive version. When there is
        // no AI content, the parent shows `SubChapterEmptyContent`
        // instead — this CTA is for the populated case only.
        if (hasAi) ...[
          const SizedBox(height: AppSpacing.lg),
          _AiUpsellCard(onTap: onRegenerateTap),
        ],

        // ── Manual Content from backend ──────────────────────────────────
        if (contentList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: ColorUtils.slate600,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Lampiran (Manual)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...contentList.asMap().entries.map((entry) {
            final index = entry.key;
            final content = entry.value;
            final cardColor = ColorUtils.getColorForIndex(index);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.slate200.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: () {
                    // Tap attachment detail placeholder
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.description_rounded,
                              color: cardColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content['judul_konten'] ??
                                    content['title'] ??
                                    'Lampiran',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: ColorUtils.slate800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((content['isi_konten'] ??
                                      content['description'] ??
                                      '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  content['isi_konten'] ??
                                      content['description'] ??
                                      '',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: ColorUtils.slate400,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// Numbered-pill list, used for `poin_utama` and list-shaped
/// `tujuan_pembelajaran`. Extracted out of the main build so both
/// sections render the same way.
class _NumberedList extends StatelessWidget {
  final List<dynamic> items;
  final Color accent;

  const _NumberedList({required this.items, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final isLast = entry.key == items.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(7)),
                ),
                child: Center(
                  child: Text(
                    '${entry.key + 1}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.value.toString(),
                  style: TextStyle(
                    color: ColorUtils.slate700,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Dashed-violet "Materi Lebih Lengkap dari AI" upsell card —
/// pixel-aligned with `.ai-empty` in the redesign mockup. Tap routes
/// to `onTap` (typically the AI regenerate flow).
class _AiUpsellCard extends StatelessWidget {
  static const Color _violet = Color(0xFF7C3AED);

  final VoidCallback onTap;

  const _AiUpsellCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: DottedBorderBox(
          color: _violet.withValues(alpha: 0.30),
          radius: 16,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _violet.withValues(alpha: 0.08),
                  ColorUtils.brandCobalt.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _violet.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _violet,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Materi Lebih Lengkap dari AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate ringkasan, contoh soal, dan referensi '
                  'tambahan untuk sub-bab ini dalam beberapa detik.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _violet,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _violet.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Generate dengan AI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed-border wrapper around any child. Painted in CustomPainter so
/// we don't need to pull in the `dotted_border` package — keeps the
/// dependency surface tight.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        dashed.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
