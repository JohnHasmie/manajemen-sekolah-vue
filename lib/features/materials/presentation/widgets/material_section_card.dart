// Card widget for a single section of the AI-generated full material.
// Renders a numbered section header and formatted body (paragraphs or bullet list).
// Like a Vue `<MaterialSectionCard :title :content :index />` component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Displays one named section of the AI material (e.g. "Ringkasan", "Contoh").
///
/// Uses [index] to rotate through an accent-colour palette so neighbouring
/// sections are visually distinguished (like CSS nth-child colour bands).
/// Body text is rendered via [_buildFormattedContent], which detects bullet
/// lists and paragraph blocks automatically.
class MaterialSectionCard extends StatelessWidget {
  /// Section heading (already formatted by the caller, e.g. "Tujuan Pembelajaran").
  final String title;

  /// Plain-text body content for this section (HTML already stripped).
  final String content;

  /// 0-based position in the section list — used to pick the accent colour.
  final int index;

  /// Primary colour from the screen, used as the first accent in the palette.
  final Color primaryColor;

  const MaterialSectionCard({
    super.key,
    required this.title,
    required this.content,
    required this.index,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Accent colour palette — index wraps around, like CSS nth-child(n)
    final colors = [
      primaryColor,
      Colors.orange,
      Colors.teal,
      Colors.purple,
      Colors.indigo,
      Colors.pink,
    ];
    final accentColor = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header strip with numbered badge
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom:
                    BorderSide(color: accentColor.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                // Numbered badge — like a CSS counter
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section body
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildFormattedContent(content, accentColor),
          ),
        ],
      ),
    );
  }

  /// Renders [content] as paragraphs or a bullet list.
  ///
  /// Like a Vue template with `v-if` / `v-for` — detects multi-paragraph
  /// blocks and bullet-like lines, then delegates to [_buildBulletList].
  Widget _buildFormattedContent(String content, Color accentColor) {
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paragraphs.length <= 1) {
      // Single paragraph — check for bullet-like lines
      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.length > 1 &&
          lines.any(
              (l) => l.trim().startsWith(RegExp(r'[-•\d]+[.)]?\s')))) {
        return _buildBulletList(lines, accentColor);
      }
      return Text(
        content.replaceAll(r'\n', '\n'),
        style: TextStyle(
            fontSize: 14, color: ColorUtils.slate700, height: 1.6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final paragraph = entry.value.trim();
        final lines = paragraph
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();

        // If every line in this paragraph looks like a bullet, render as list
        if (lines.length > 1 &&
            lines.every((l) =>
                l.trim().startsWith(RegExp(r'[-•\d]+[.)]?\s')))) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBulletList(lines, accentColor),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            paragraph,
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate700,
              height: 1.6,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Renders a list of text lines as a vertically stacked bullet/number list.
  ///
  /// Strips leading markers (-, •, 1., 1)) and replaces them with a coloured
  /// dot — analogous to replacing `<li>` with a styled bullet in CSS.
  Widget _buildBulletList(List<String> lines, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        final isBullet = trimmed.startsWith(RegExp(r'[-•]\s'));
        final isNumbered = trimmed.startsWith(RegExp(r'\d+[.)]\s'));

        String text = trimmed;
        if (isBullet) {
          text = trimmed.replaceFirst(RegExp(r'^[-•]\s*'), '');
        } else if (isNumbered) {
          text = trimmed.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
        }

        if (isBullet || isNumbered) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bullet dot — accent colour to tie back to the section header
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 10, left: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.slate700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            trimmed,
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate700,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}
