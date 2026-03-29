// Tab 3 (Tambahan) of the report card detail form.
// Contains editable lists of extracurricular activities and achievements,
// each with add/delete actions. All mutations are surfaced through callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Tab widget for extracurricular and achievement entries on a report card.
///
/// Like a Vue component that receives two arrays as props and emits list-mutation
/// events instead of touching parent state directly. The parent (screen) owns
/// the actual list state and calls setState; this widget is purely presentational
/// with callbacks for every mutation.
class ReportCardTambahanTab extends StatelessWidget {
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

  const ReportCardTambahanTab({
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(title: 'Ekstrakurikuler'),
            TextButton.icon(
              onPressed: () {
                onAddExtra();
                onMarkUnsaved();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.add.tr),
            ),
          ],
        ),
        ...List.generate(extras.length, (index) => _ExtraItem(
          extra: extras[index],
          onChanged: (field, value) {
            onExtraChanged(index, field, value);
            onMarkUnsaved();
          },
          onDelete: () {
            onDeleteExtra(index);
            onMarkUnsaved();
          },
        )),

        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(title: AppLocalizations.achievements.tr),
            TextButton.icon(
              onPressed: () {
                onAddAchievement();
                onMarkUnsaved();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.add.tr),
            ),
          ],
        ),
        ...List.generate(achievements.length, (index) => _AchievementItem(
          achievement: achievements[index],
          onChanged: (field, value) {
            onAchievementChanged(index, field, value);
            onMarkUnsaved();
          },
          onDelete: () {
            onDeleteAchievement(index);
            onMarkUnsaved();
          },
        )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets used only within this file
// ---------------------------------------------------------------------------

/// Section heading label — like a reusable `<h3>` in Vue templates.
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate700,
        ),
      ),
    );
  }
}

/// Card for a single extracurricular activity with name, score, and description.
class _ExtraItem extends StatelessWidget {
  final Map<String, dynamic> extra;
  final void Function(String field, String value) onChanged;
  final VoidCallback onDelete;

  const _ExtraItem({
    required this.extra,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
        ),
        boxShadow: [...ColorUtils.corporateShadow()],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _CompactTextField(
                    label: 'Nama Ekstrakurikuler',
                    initialValue: extra['name'] ?? '',
                    onChanged: (v) => onChanged('name', v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 1,
                  child: _CompactTextField(
                    label: 'Nilai',
                    initialValue: extra['score'] ?? '',
                    onChanged: (v) => onChanged('score', v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _CompactTextField(
              label: 'Keterangan',
              initialValue: extra['description'] ?? '',
              onChanged: (v) => onChanged('description', v),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for a single achievement entry with name, type, and description.
class _AchievementItem extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final void Function(String field, String value) onChanged;
  final VoidCallback onDelete;

  const _AchievementItem({
    required this.achievement,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
        ),
        boxShadow: [...ColorUtils.corporateShadow()],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _CompactTextField(
                    label: 'Nama Prestasi',
                    initialValue: achievement['name'] ?? '',
                    onChanged: (v) => onChanged('name', v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 1,
                  child: _CompactTextField(
                    label: 'Jenis (Opsional)',
                    initialValue: achievement['type'] ?? '',
                    onChanged: (v) => onChanged('type', v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _CompactTextField(
              label: 'Keterangan',
              initialValue: achievement['description'] ?? '',
              onChanged: (v) => onChanged('description', v),
            ),
          ],
        ),
      ),
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
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ColorUtils.getRoleColor('guru')),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      onChanged: onChanged,
    );
  }
}
