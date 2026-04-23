import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Subject filter chips display widget.
class SubjectFilterChips extends StatelessWidget {
  final List<Map<String, dynamic>> filters;
  final VoidCallback onClear;
  final Color primaryColor;

  const SubjectFilterChips({
    super.key,
    required this.filters,
    required this.onClear,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        color: Colors.grey[100],
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: const Icon(Icons.filter_alt, size: 18, color: Colors.grey),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...filters.map((filter) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          filter['label'],
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red,
                        ),
                        onDeleted: filter['onRemove'],
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        labelPadding: const EdgeInsets.only(left: 4),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onClear,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(
                  Icons.clear_all,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
