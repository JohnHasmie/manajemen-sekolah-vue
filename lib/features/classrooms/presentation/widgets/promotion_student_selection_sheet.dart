// Bottom-sheet widget for manually selecting students to promote.
//
// Extracted from ClassPromotionWizard._showStudentSelectionDialog.
// Displays a scrollable checklist of students with avatar, name, and
// a "already promoted" badge — like a `<v-dialog>` with a `<v-list>` in Vue.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Modal bottom-sheet that lets the admin pick students for promotion.
///
/// [students] — full list of students in the source class.
/// [selectedStudentIds] — mutable Set passed by reference; updated in-place
///   so the parent [ClassPromotionWizard] sees the changes via [onSelectionChanged].
/// [isAlreadyPromoted] — callback that checks whether a student is already in
///   the target year (avoids duplicating that logic here).
class PromotionStudentSelectionSheet extends StatefulWidget {
  const PromotionStudentSelectionSheet({
    super.key,
    required this.students,
    required this.selectedStudentIds,
    required this.isAlreadyPromoted,
    required this.primaryColor,
    required this.cardGradient,
    required this.languageProvider,
    required this.onSelectionChanged,
  });

  final List<dynamic> students;
  final Set<String> selectedStudentIds;
  final bool Function(dynamic student) isAlreadyPromoted;
  final Color primaryColor;
  final LinearGradient cardGradient;
  final LanguageProvider languageProvider;
  final VoidCallback onSelectionChanged;

  @override
  State<PromotionStudentSelectionSheet> createState() =>
      _PromotionStudentSelectionSheetState();
}

class _PromotionStudentSelectionSheetState
    extends State<PromotionStudentSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              gradient: widget.cardGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.languageProvider.getTranslatedText({
                              'en': 'Select Students',
                              'id': 'Pilih Siswa',
                            }),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.selectedStudentIds.length}/${widget.students.length} dipilih',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Student list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.students.length,
              itemBuilder: (context, index) {
                final student = widget.students[index];
                final model = Student.fromJson(student as Map<String, dynamic>);
                final id = model.id;
                final isPromoted = widget.isAlreadyPromoted(student);
                final isSelected = widget.selectedStudentIds.contains(id);
                final nameStr = model.name.isNotEmpty ? model.name : 'Unknown';
                final nameHash = nameStr.codeUnits.fold(0, (sum, c) => sum + c);
                final avatarColor = ColorUtils.getColorForIndex(nameHash);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isPromoted
                        ? ColorUtils.slate50
                        : isSelected
                        ? widget.primaryColor.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: isSelected
                          ? widget.primaryColor.withValues(alpha: 0.3)
                          : ColorUtils.slate200,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      onTap: isPromoted
                          ? null
                          : () {
                              setState(() {
                                if (isSelected) {
                                  widget.selectedStudentIds.remove(id);
                                } else {
                                  widget.selectedStudentIds.add(id);
                                }
                              });
                              widget.onSelectionChanged();
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isPromoted
                                  ? ColorUtils.slate200
                                  : avatarColor.withValues(alpha: 0.15),
                              child: Text(
                                nameStr.isNotEmpty
                                    ? nameStr[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isPromoted
                                      ? ColorUtils.slate400
                                      : avatarColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nameStr,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isPromoted
                                          ? ColorUtils.slate400
                                          : ColorUtils.slate900,
                                      fontWeight: FontWeight.w600,
                                      decoration: isPromoted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (isPromoted)
                                    Text(
                                      widget.languageProvider
                                          .getTranslatedText({
                                            'en': 'Already Promoted',
                                            'id': 'Sudah Naik Kelas',
                                          }),
                                      style: TextStyle(
                                        color: ColorUtils.warning600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!isPromoted)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.primaryColor
                                      : Colors.white,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(6),
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.primaryColor
                                        : ColorUtils.slate300,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.languageProvider.getTranslatedText({
                      'en': 'Done',
                      'id': 'Selesai',
                    }),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
