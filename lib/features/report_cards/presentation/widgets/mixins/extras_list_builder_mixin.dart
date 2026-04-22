import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin providing UI builders for the extras section.
///
/// Provides methods to build the section header and list, with support
/// for add/delete actions via abstract callbacks.
mixin ExtrasListBuilderMixin {
  /// List of extracurricular entries (name, score, description).
  List<Map<String, dynamic>> get extras;

  /// Callback when user taps "Add" button.
  VoidCallback get onAddExtra;

  /// Callback when a field in an extra item changes.
  void Function(int index, String field, String value) get onExtraChanged;

  /// Callback when user deletes an extra item.
  void Function(int index) get onDeleteExtra;

  /// Callback to mark parent as unsaved.
  VoidCallback get onMarkUnsaved;

  /// Builds the extras list section header with add button.
  ///
  /// Returns a [Row] with icon, title, and add button.
  /// Max width ~80 chars.
  Widget buildExtrasHeader() {
    final p = ColorUtils.getRoleColor('guru');
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: p.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.sports_soccer_rounded, size: 16, color: p),
        ),
        const SizedBox(width: 10),
        Text(
          'Ekstrakurikuler',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            onAddExtra();
            onMarkUnsaved();
          },
          child: _buildAddButton(p),
        ),
      ],
    );
  }

  /// Builds the add button used in extras header.
  Widget _buildAddButton(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Tambah',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the extras list or empty state.
  ///
  /// Returns either a centered empty message or a list of
  /// extra item widgets. Each item is wrapped with
  /// onChanged/onDelete callbacks.
  List<Widget> buildExtrasList(
    Widget Function(
      Map<String, dynamic> extra,
      void Function(String, String) onChanged,
      VoidCallback onDelete,
    )
    itemBuilder,
  ) {
    if (extras.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Belum ada ekstrakurikuler',
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate400,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    return List.generate(
      extras.length,
      (i) => itemBuilder(
        extras[i],
        (f, v) {
          onExtraChanged(i, f, v);
          onMarkUnsaved();
        },
        () {
          onDeleteExtra(i);
          onMarkUnsaved();
        },
      ),
    );
  }
}
