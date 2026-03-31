// "Referensi" tab content for the AI material result screen.
// Lists all reference cards and provides a "Ganti" (replace) action button.
// Like a Vue `<ReferenceTab :refs :materialId :isRegenerating @regenRefs />` component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_reference_card.dart';

/// Renders the full "Referensi" tab: an optional header row with reference count
/// and "Ganti" button, then a scrollable list of [MaterialReferenceCard]s.
///
/// When [refs] is empty, a friendly empty-state is shown instead.
/// HTML stripping is delegated to [stripHtml], keeping this widget decoupled
/// from HTML-parsing logic (like injecting a utility function in Laravel).
class MaterialReferenceTab extends StatelessWidget {
  /// List of raw reference data maps from the AI API.
  final List<dynamic> refs;

  /// The server-assigned material ID; the header row is hidden when null.
  final String? materialId;

  /// Whether a regeneration request is currently in flight.
  /// Disables the "Ganti" button when true.
  final bool isRegenerating;

  /// Accent colour for interactive elements.
  final Color primaryColor;

  /// Called when the user taps "Ganti" to regenerate all references.
  /// Parent handles the actual API call and state update.
  final VoidCallback onRegenRefs;

  /// HTML-stripping function injected from the parent screen.
  /// Keeps HTML parsing logic in one place (DRY, like a Laravel helper).
  final String Function(String) stripHtml;

  const MaterialReferenceTab({
    super.key,
    required this.refs,
    required this.materialId,
    required this.isRegenerating,
    required this.primaryColor,
    required this.onRegenRefs,
    required this.stripHtml,
  });

  @override
  Widget build(BuildContext context) {
    // Empty state
    if (refs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: ColorUtils.slate300,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Belum ada referensi',
              style: TextStyle(color: ColorUtils.slate500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row: count + replace-refs button (only when materialId is known)
        if (materialId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${refs.length} Referensi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                  ),
                ),
                TextButton.icon(
                  onPressed: isRegenerating ? null : onRegenRefs,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
                  label: const Text(
                    'Ganti',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        // Scrollable reference list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: refs.length,
            itemBuilder: (context, index) {
              final ref = Map<String, dynamic>.from(refs[index]);
              return MaterialReferenceCard(
                ref: ref,
                primaryColor: primaryColor,
                strippedContent: stripHtml(ref['content'] ?? ''),
              );
            },
          ),
        ),
      ],
    );
  }
}
