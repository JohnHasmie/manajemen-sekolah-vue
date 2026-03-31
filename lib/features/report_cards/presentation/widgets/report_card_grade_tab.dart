// Tab 2 (Nilai Akademik) of the report card detail form.
// Displays a scrollable list of subject cards, each with editable knowledge
// and skill score/predicate/description fields. Stateless; mutations via callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tab widget that lists all academic subjects for a student's report card.
///
/// Like a Vue component receiving `subjects` as a prop and emitting `update:subjects`
/// events. Each subject card exposes its knowledge and skill fields for in-place
/// editing. All mutations are surfaced through [onSubjectChanged] and
/// [onMarkUnsaved] rather than calling setState internally.
class ReportCardGradeTab extends StatelessWidget {
  /// The list of subject maps, each containing keys like `subject_name`,
  /// `knowledge_score`, `knowledge_predicate`, `knowledge_description`,
  /// `skill_score`, `skill_predicate`, `skill_description`.
  final List<Map<String, dynamic>> subjects;

  /// Called when a single field in a subject at [index] changes to [value].
  /// The parent is responsible for updating the list and calling setState.
  final void Function(int index, String field, String value) onSubjectChanged;

  /// Called whenever any field changes so the parent can track unsaved state.
  final VoidCallback onMarkUnsaved;

  const ReportCardGradeTab({
    super.key,
    required this.subjects,
    required this.onSubjectChanged,
    required this.onMarkUnsaved,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(
              color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
            ),
            boxShadow: [...ColorUtils.corporateShadow()],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject['subject_name'] ?? 'Mapel',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Pengetahuan
                const Text(
                  'Aspek Pengetahuan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _CompactTextField(
                        label: 'Nilai',
                        initialValue: subject['knowledge_score'] ?? '',
                        onChanged: (v) {
                          onSubjectChanged(index, 'knowledge_score', v);
                          onMarkUnsaved();
                        },
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 1,
                      child: _CompactTextField(
                        label: 'Predikat',
                        initialValue: subject['knowledge_predicate'] ?? '',
                        onChanged: (v) {
                          onSubjectChanged(index, 'knowledge_predicate', v);
                          onMarkUnsaved();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _CompactTextField(
                  label: 'Deskripsi',
                  initialValue: subject['knowledge_description'] ?? '',
                  onChanged: (v) {
                    onSubjectChanged(index, 'knowledge_description', v);
                    onMarkUnsaved();
                  },
                  maxLines: 2,
                ),

                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),

                // Keterampilan
                const Text(
                  'Aspek Keterampilan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _CompactTextField(
                        label: 'Nilai',
                        initialValue: subject['skill_score'] ?? '',
                        onChanged: (v) {
                          onSubjectChanged(index, 'skill_score', v);
                          onMarkUnsaved();
                        },
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 1,
                      child: _CompactTextField(
                        label: 'Predikat',
                        initialValue: subject['skill_predicate'] ?? '',
                        onChanged: (v) {
                          onSubjectChanged(index, 'skill_predicate', v);
                          onMarkUnsaved();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _CompactTextField(
                  label: 'Deskripsi',
                  initialValue: subject['skill_description'] ?? '',
                  onChanged: (v) {
                    onSubjectChanged(index, 'skill_description', v);
                    onMarkUnsaved();
                  },
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Private compact text field used only within this file.
///
/// Wraps [TextFormField] with the app's standard rounded, filled styling.
/// Uses [initialValue] (not a controller) so each item rebuild starts fresh —
/// analogous to a Vue uncontrolled input.
class _CompactTextField extends StatelessWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool isNumber;

  const _CompactTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
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
