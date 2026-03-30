// RPP signature/sign-off card. Extracted from lesson_plan_detail_screen.dart.
// Shows the two signature columns (Kepala Sekolah + Guru) and an AI-generated notice.
// Like a `<SignatureCard>` Vue component — purely display, reads two boolean flags.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Signature block shown at the bottom of a rendered RPP.
///
/// Constructor params:
/// - [isAiGenerated] — when true, appends an italic "AI-generated" notice below the lines
/// - [primaryColor]  — brand colour for the card's drop shadow tint
class LessonPlanSignatureCard extends StatelessWidget {
  final bool isAiGenerated;
  final Color primaryColor;

  const LessonPlanSignatureCard({
    super.key,
    required this.isAiGenerated,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Row(
              children: [
                // Left column: Kepala Sekolah
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Mengetahui',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text('Kepala Sekolah', style: TextStyle(fontSize: 13)),
                      SizedBox(height: 40),
                      Text(
                        '...................................',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'NIP ..............................',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right column: Guru Mata Pelajaran
                Expanded(
                  child: Column(
                    children: [
                      Text('', style: TextStyle(fontSize: 13)),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Guru Mata Pelajaran',
                        style: TextStyle(fontSize: 13),
                      ),
                      SizedBox(height: 40),
                      Text(
                        '...................................',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'NIP ..............................',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // AI-generated notice — only rendered when the RPP was AI-generated
            if (isAiGenerated) ...[
              SizedBox(height: AppSpacing.lg),
              Divider(color: ColorUtils.slate200),
              SizedBox(height: AppSpacing.sm),
              Text(
                'RPP ini digenerate secara otomatis menggunakan AI',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: ColorUtils.slate400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
