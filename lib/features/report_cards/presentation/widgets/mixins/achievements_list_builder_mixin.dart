import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin providing UI builders for the achievements section.
///
/// Provides methods to build the section header and list, with support
/// for add/delete actions via abstract callbacks.
mixin AchievementsListBuilderMixin {
  /// List of achievement entries (name, type, description).
  List<Map<String, dynamic>> get achievements;

  /// Callback when user taps "Add" button.
  VoidCallback get onAddAchievement;

  /// Callback when a field in an achievement item changes.
  void Function(int index, String field, String value) get onAchievementChanged;

  /// Callback when user deletes an achievement item.
  void Function(int index) get onDeleteAchievement;

  /// Callback to mark parent as unsaved.
  VoidCallback get onMarkUnsaved;

  /// Builds the achievements section header with add button.
  ///
  /// Returns a [Row] with icon, title, and add button.
  /// Max width ~80 chars.
  Widget buildAchievementsHeader() {
    final p = ColorUtils.getRoleColor('guru');
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: ColorUtils.warning600.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            size: 16,
            color: ColorUtils.warning600,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Prestasi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            onAddAchievement();
            onMarkUnsaved();
          },
          child: _buildAddButton(p),
        ),
      ],
    );
  }

  /// Builds the add button used in achievements header.
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

  /// Builds the achievements list or empty state.
  ///
  /// Returns either a centered empty message or a list of
  /// achievement item widgets. Each item is wrapped with
  /// onChanged/onDelete callbacks.
  List<Widget> buildAchievementsList(
    Widget Function(
      Map<String, dynamic> achievement,
      void Function(String, String) onChanged,
      VoidCallback onDelete,
    )
    itemBuilder,
  ) {
    if (achievements.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Belum ada prestasi',
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
      achievements.length,
      (i) => itemBuilder(
        achievements[i],
        (f, v) {
          onAchievementChanged(i, f, v);
          onMarkUnsaved();
        },
        () {
          onDeleteAchievement(i);
          onMarkUnsaved();
        },
      ),
    );
  }
}
