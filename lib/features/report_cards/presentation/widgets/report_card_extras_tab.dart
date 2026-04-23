// Tab 3 (Tambahan) of the report card detail form.
// Contains editable lists of extracurricular activities and achievements,
// each with add/delete actions. All mutations are surfaced through
// callbacks.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/mixins/extras_list_builder_mixin.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/mixins/achievements_list_builder_mixin.dart';

/// Tab widget for extracurricular and achievement entries on a report card.
///
/// Like a Vue component that receives two arrays as props and emits
/// list-mutation events instead of touching parent state directly. The
/// parent (screen) owns the actual list state and calls setState; this
/// widget is purely presentational with callbacks for every mutation.
class ReportCardExtrasTab extends StatelessWidget
    with ExtrasListBuilderMixin, AchievementsListBuilderMixin {
  /// Current list of extracurricular entries. Each map has keys: `name`,
  /// `score`, `description`.
  @override
  final List<Map<String, dynamic>> extras;

  /// Current list of achievement entries. Each map has keys: `name`,
  /// `type`, `description`.
  @override
  final List<Map<String, dynamic>> achievements;

  /// Called when the user taps "Add" in the extracurricular section.
  @override
  final VoidCallback onAddExtra;

  /// Called when the user taps "Add" in the achievements section.
  @override
  final VoidCallback onAddAchievement;

  /// Called when a field inside an extra item changes.
  /// [index] is the position in [extras], [field] is the map key,
  /// [value] is the new string.
  @override
  final void Function(int index, String field, String value) onExtraChanged;

  /// Called when the user deletes an extra item at [index].
  @override
  final void Function(int index) onDeleteExtra;

  /// Called when a field inside an achievement item changes.
  @override
  final void Function(int index, String field, String value)
  onAchievementChanged;

  /// Called when the user deletes an achievement item at [index].
  @override
  final void Function(int index) onDeleteAchievement;

  /// Called whenever any mutation occurs so the parent can flag
  /// unsaved changes.
  @override
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ekstrakurikuler section
        buildExtrasHeader(),
        ...buildExtrasList(_buildExtraItem),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: ColorUtils.slate100),
        ),

        // Prestasi section
        buildAchievementsHeader(),
        ...buildAchievementsList(_buildAchievementItem),
      ],
    );
  }

  /// Builds an extra item widget for the list.
  Widget _buildExtraItem(
    Map<String, dynamic> extra,
    void Function(String field, String value) onChanged,
    VoidCallback onDelete,
  ) {
    return _ExtraItem(extra: extra, onChanged: onChanged, onDelete: onDelete);
  }

  /// Builds an achievement item widget for the list.
  Widget _buildAchievementItem(
    Map<String, dynamic> achievement,
    void Function(String field, String value) onChanged,
    VoidCallback onDelete,
  ) {
    return _AchievementItem(
      achievement: achievement,
      onChanged: onChanged,
      onDelete: onDelete,
    );
  }
}

// ---------------------------------------------------------------------------

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
    return _ItemCard(
      onDelete: onDelete,
      firstField: (label: 'Nama', value: extra['name'] ?? '', field: 'name'),
      secondField: (
        label: 'Nilai',
        value: extra['score'] ?? '',
        field: 'score',
      ),
      descriptionField: (
        label: 'Keterangan',
        value: extra['description'] ?? '',
        field: 'description',
      ),
      onChanged: onChanged,
    );
  }
}

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
    return _ItemCard(
      onDelete: onDelete,
      firstField: (
        label: 'Nama Prestasi',
        value: achievement['name'] ?? '',
        field: 'name',
      ),
      secondField: (
        label: 'Jenis',
        value: achievement['type'] ?? '',
        field: 'type',
      ),
      descriptionField: (
        label: 'Keterangan',
        value: achievement['description'] ?? '',
        field: 'description',
      ),
      onChanged: onChanged,
    );
  }
}

/// Common item card widget for extras and achievements.
///
/// Builds a container with two compact text fields in a row, a delete
/// button, and a description field below. Fields are configured via
/// named records.
typedef _FieldConfig = ({String label, String value, String field});

class _ItemCard extends StatelessWidget {
  final _FieldConfig firstField;
  final _FieldConfig secondField;
  final _FieldConfig descriptionField;
  final void Function(String field, String value) onChanged;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.firstField,
    required this.secondField,
    required this.descriptionField,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Column(
        children: [
          _buildFieldsRow(),
          const SizedBox(height: 6),
          _buildDescriptionField(),
        ],
      ),
    );
  }

  /// Builds the top row with two fields and delete button.
  Widget _buildFieldsRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _CompactTextField(
            label: firstField.label,
            initialValue: firstField.value,
            onChanged: (v) => onChanged(firstField.field, v),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: _CompactTextField(
            label: secondField.label,
            initialValue: secondField.value,
            onChanged: (v) => onChanged(secondField.field, v),
          ),
        ),
        GestureDetector(
          onTap: onDelete,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.close, size: 16, color: ColorUtils.error600),
          ),
        ),
      ],
    );
  }

  /// Builds the description field widget.
  Widget _buildDescriptionField() {
    return _CompactTextField(
      label: descriptionField.label,
      initialValue: descriptionField.value,
      onChanged: (v) => onChanged(descriptionField.field, v),
    );
  }
}

/// Compact text-field helper shared by both item card types.
///
/// Uses [initialValue] rather than a controller — uncontrolled input,
/// like a Vue `v-model` on a child component that only emits on
/// change.
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
      decoration: _buildInputDecoration(p),
      onChanged: onChanged,
    );
  }

  /// Builds the text field input decoration.
  InputDecoration _buildInputDecoration(Color roleColor) {
    final borderRadius = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorUtils.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorUtils.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: roleColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
}
