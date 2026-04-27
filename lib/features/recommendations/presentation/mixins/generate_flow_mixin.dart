import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/scope_option_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

/// Mixin for recommendation generation UI flow in
/// [LearningRecommendationClassScreen].
///
/// Handles user interactions for scope and subject selection before
/// generating recommendations. The actual generation logic is in the
/// main state class to access teacher ID and perform caching.
mixin GenerateFlowMixin on ConsumerState<LearningRecommendationClassScreen> {
  // Generate state
  final Map<String, bool> generating = {};

  /// Gets primary color for the teacher role.
  Color getPrimaryColor();

  /// Shows scope picker bottom sheet.
  /// Returns true for all students, false for students needing help.
  Future<bool?> showScopePicker(String className) async {
    final primaryColor = getPrimaryColor();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(
              title: 'Cakupan Siswa',
              subtitle: 'Generate rekomendasi AI untuk $className',
              icon: Icons.groups_rounded,
              primaryColor: primaryColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  ScopeOptionTile(
                    ctx: ctx,
                    value: true,
                    icon: Icons.groups_rounded,
                    title: 'Semua Siswa',
                    subtitle:
                        'Generate rekomendasi untuk semua siswa '
                        'termasuk yang sudah baik',
                    color: primaryColor,
                  ),
                  ScopeOptionTile(
                    ctx: ctx,
                    value: false,
                    icon: Icons.person_search_rounded,
                    title: 'Siswa yang Perlu Saja',
                    subtitle:
                        'Hanya siswa yang membutuhkan rekomendasi '
                        'berdasarkan data performa',
                    color: ColorUtils.amber500,
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  /// Gets subjects for a class (implemented by state).
  List<Map<String, String>> getSubjectsForClass(String classId);
}
