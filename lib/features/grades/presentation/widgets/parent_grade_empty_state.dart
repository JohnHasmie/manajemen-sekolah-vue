// Empty state for the parent grade screen.
//
// Thin shim over the shared `BrandEmptyState` so the existing call
// sites (`ParentGradeEmptyState(message: ...)`) keep compiling. Future
// callers should use `BrandEmptyState` directly.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';

class ParentGradeEmptyState extends StatelessWidget {
  /// The human-readable message displayed below the icon.
  final String message;

  const ParentGradeEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return BrandEmptyState(
      icon: Icons.assignment_outlined,
      tone: BrandEmptyStateTone.info,
      kicker: 'Belum ada data',
      title: 'Belum ada nilai',
      message: message,
    );
  }
}
