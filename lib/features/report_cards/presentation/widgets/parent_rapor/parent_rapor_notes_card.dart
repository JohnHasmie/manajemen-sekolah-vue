import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ParentRaporNotesCard extends StatelessWidget {
  const ParentRaporNotesCard({
    super.key,
    required this.notes,
    required this.teacher,
  });

  final String notes;
  final String teacher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 64,
            decoration: BoxDecoration(
              color: ColorUtils.brandAzureDeep,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notes,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate900,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '— $teacher',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                    fontStyle: FontStyle.italic,
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
