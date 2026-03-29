// ActivityEmptyState — centred placeholder shown when an activity list is empty.
//
// Extracted from `ParentClassActivityScreenState._buildEmptyState`.
// Like a Vue `<EmptyState :message="..." />` — a pure presentational widget.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A vertically centred empty-state card with an icon and a message.
///
/// Used by the parent class activity screen whenever there are no activities
/// to display (e.g. no child selected, or the selected child has no entries).
///
/// Props (constructor params — like Vue props):
/// - [message] — the human-readable explanation shown below the icon
class ActivityEmptyState extends StatelessWidget {
  final String message;

  const ActivityEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 36,
                color: ColorUtils.slate400,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
