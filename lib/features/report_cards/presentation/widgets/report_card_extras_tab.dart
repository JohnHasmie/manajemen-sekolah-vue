// Tab 3 (Tambahan) of the report card detail form.
// Contains editable lists of extracurricular activities and achievements,
// each with add/delete actions. All mutations are surfaced through callbacks.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Tab widget for extracurricular and achievement entries on a report card.
///
/// Like a Vue component that receives two arrays as props and emits list-mutation
/// events instead of touching parent state directly. The parent (screen) owns
/// the actual list state and calls setState; this widget is purely presentational
/// with callbacks for every mutation.
class ReportCardExtrasTab extends StatelessWidget {
  /// Current list of extracurricular entries. Each map has keys: `name`,
  /// `score`, `description`.
  final List<Map<String, dynamic>> extras;

  /// Current list of achievement entries. Each map has keys: `name`, `type`,
  /// `description`.
  final List<Map<String, dynamic>> achievements;

  /// Called when the user taps "Add" in the extracurricular section.
  final VoidCallback onAddExtra;

  /// Called when the user taps "Add" in the achievements section.
  final VoidCallback onAddAchievement;

  /// Called when a field inside an extra item changes.
  /// [index] is the position in [extras], [field] is the map key, [value] is
  /// the new string.
  final void Function(int index, String field, String value) onExtraChanged;

  /// Called when the user deletes an extra item at [index].
  final void Function(int index) onDeleteExtra;

  /// Called when a field inside an achievement item changes.
  final void Function(int index, String field, String value)
  onAchievementChanged;

  /// Called when the user deletes an achievement item at [index].
  final void Function(int index) onDeleteAchievement;

  /// Called whenever any mutation occurs so the parent can flag unsaved changes.
  final VoidCallback onMarkUnsaved;

  const ReportCardExtrasTab({
    super.key,
    required this.extras,
    required this.achievements,
    required this.onAddExtra,
    required this.onAddAchievement,
    required this.onExtraChanged,
    required this.onDeleteExtra,
    required this.onAchievementChanged,
    required this.onDeleteAchievement,
    required this.onMarkUnsaved,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ekstrakurikuler section
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.sports_soccer_rounded, size: 16, color: p)),
          const SizedBox(width: 10),
          Text('Ekstrakurikuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
          const Spacer(),
          GestureDetector(
            onTap: () { onAddExtra(); onMarkUnsaved(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: p),
                const SizedBox(width: 4),
                Text('Tambah', style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        if (extras.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Belum ada ekstrakurikuler', style: TextStyle(fontSize: 12, color: ColorUtils.slate400, fontStyle: FontStyle.italic), textAlign: TextAlign.center))
        else
          ...List.generate(extras.length, (i) => _ExtraItem(extra: extras[i],
            onChanged: (f, v) { onExtraChanged(i, f, v); onMarkUnsaved(); },
            onDelete: () { onDeleteExtra(i); onMarkUnsaved(); })),

        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: ColorUtils.slate100)),

        // Prestasi section
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: ColorUtils.warning600.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.emoji_events_rounded, size: 16, color: ColorUtils.warning600)),
          const SizedBox(width: 10),
          Text(AppLocalizations.achievements.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
          const Spacer(),
          GestureDetector(
            onTap: () { onAddAchievement(); onMarkUnsaved(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: p),
                const SizedBox(width: 4),
                Text('Tambah', style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        if (achievements.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Belum ada prestasi', style: TextStyle(fontSize: 12, color: ColorUtils.slate400, fontStyle: FontStyle.italic), textAlign: TextAlign.center))
        else
          ...List.generate(achievements.length, (i) => _AchievementItem(achievement: achievements[i],
            onChanged: (f, v) { onAchievementChanged(i, f, v); onMarkUnsaved(); },
            onDelete: () { onDeleteAchievement(i); onMarkUnsaved(); })),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ExtraItem extends StatelessWidget {
  final Map<String, dynamic> extra;
  final void Function(String field, String value) onChanged;
  final VoidCallback onDelete;

  const _ExtraItem({required this.extra, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ColorUtils.slate100)),
      child: Column(children: [
        Row(children: [
          Expanded(flex: 2, child: _CompactTextField(label: 'Nama', initialValue: extra['name'] ?? '', onChanged: (v) => onChanged('name', v))),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: _CompactTextField(label: 'Nilai', initialValue: extra['score'] ?? '', onChanged: (v) => onChanged('score', v))),
          GestureDetector(onTap: onDelete, child: Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.close, size: 16, color: ColorUtils.error600))),
        ]),
        const SizedBox(height: 6),
        _CompactTextField(label: 'Keterangan', initialValue: extra['description'] ?? '', onChanged: (v) => onChanged('description', v)),
      ]),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final void Function(String field, String value) onChanged;
  final VoidCallback onDelete;

  const _AchievementItem({required this.achievement, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ColorUtils.slate100)),
      child: Column(children: [
        Row(children: [
          Expanded(flex: 2, child: _CompactTextField(label: 'Nama Prestasi', initialValue: achievement['name'] ?? '', onChanged: (v) => onChanged('name', v))),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: _CompactTextField(label: 'Jenis', initialValue: achievement['type'] ?? '', onChanged: (v) => onChanged('type', v))),
          GestureDetector(onTap: onDelete, child: Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.close, size: 16, color: ColorUtils.error600))),
        ]),
        const SizedBox(height: 6),
        _CompactTextField(label: 'Keterangan', initialValue: achievement['description'] ?? '', onChanged: (v) => onChanged('description', v)),
      ]),
    );
  }
}

/// Compact text-field helper shared by both item card types in this file.
///
/// Uses [initialValue] rather than a controller — uncontrolled input, like
/// a Vue `v-model` on a child component that only emits on change.
class _CompactTextField extends StatelessWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _CompactTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}
