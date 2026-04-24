import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// Mixin handling dialog UI construction (header, footer) for the manual
/// lesson plan form. Uses shared BottomSheetHeader and BottomSheetFooter.
mixin LessonPlanFormDialogMixin on State<LessonPlanFormDialog> {
  /// Builds the header section using shared BottomSheetHeader.
  Widget buildHeader(dynamic lang, Color color, bool isEditMode) {
    return BottomSheetHeader(
      title: isEditMode
          ? lang.getTranslatedText({'en': 'Edit RPP', 'id': 'Edit RPP'})
          : lang.getTranslatedText({
              'en': 'Add New RPP',
              'id': 'Tambah RPP Baru',
            }),
      subtitle: isEditMode
          ? lang.getTranslatedText({
              'en': 'Update RPP details',
              'id': 'Perbarui detail RPP',
            })
          : lang.getTranslatedText({
              'en': 'Create a new RPP document',
              'id': 'Buat dokumen RPP baru',
            }),
      icon: isEditMode ? Icons.edit_note : Icons.add_task,
      primaryColor: color,
    );
  }

  /// Builds footer buttons using shared BottomSheetFooter.
  Widget buildFooterButtons(
    dynamic lang,
    Color color,
    bool isEditMode,
    bool isUploading,
    GlobalKey<FormState> formKey,
    String? selectedSubjectId,
    String? selectedClassId,
    String? selectedTerm,
    String? selectedFileName,
    dynamic selectedFile,
    TextEditingController titleController,
    TextEditingController academicYearController,
    Function(bool) setIsUploading,
  ) {
    if (isUploading) {
      return _buildUploadingFooter(color);
    }

    return BottomSheetFooter(
      primaryLabel: isEditMode
          ? lang.getTranslatedText({'en': 'Update', 'id': 'Perbarui'})
          : lang.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
      secondaryLabel: lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
      primaryColor: color,
      onPrimary: () => submitFormAction(
        formKey,
        selectedSubjectId,
        selectedClassId,
        selectedTerm,
        selectedFileName,
        selectedFile,
        titleController,
        academicYearController,
        setIsUploading,
      ),
      onSecondary: () => Navigator.of(context).pop(),
    );
  }

  /// Custom footer shown while uploading — spinner + disabled buttons.
  Widget _buildUploadingFooter(Color color) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to trigger form submission from button.
  void submitFormAction(
    GlobalKey<FormState> formKey,
    String? selectedSubjectId,
    String? selectedClassId,
    String? selectedTerm,
    String? selectedFileName,
    dynamic selectedFile,
    TextEditingController titleController,
    TextEditingController academicYearController,
    Function(bool) setIsUploading,
  );
}
