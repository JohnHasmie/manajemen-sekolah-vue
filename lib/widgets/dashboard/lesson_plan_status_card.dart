import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class LessonPlanStatusCard extends StatelessWidget {
  final int approved;
  final int rejected;
  final int pending;
  final VoidCallback? onTap;

  const LessonPlanStatusCard({
    super.key,
    required this.approved,
    required this.rejected,
    required this.pending,
    this.onTap,
  });

  int get total => approved + rejected + pending;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200, width: 1),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon and title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: ColorUtils.corporateBlue600,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total RPP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                            height: 1.1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Lesson Plans',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Spacer(),
              // Status breakdown - vertical
              _buildStatusRow(ColorUtils.success600, 'Disetujui', approved),
              SizedBox(height: 4),
              _buildStatusRow(ColorUtils.error600, 'Ditolak', rejected),
              SizedBox(height: 4),
              _buildStatusRow(ColorUtils.warning600, 'Menunggu', pending),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate600,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
      ],
    );
  }
}
