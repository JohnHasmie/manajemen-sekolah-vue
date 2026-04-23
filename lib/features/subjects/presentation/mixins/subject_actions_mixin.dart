import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/'
    'action_confirm_sheet.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/controllers/admin_subject_controller.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/screens/admin_subject_management_screen.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/screens/subject_class_management_page.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/widgets/subject_add_edit_sheet.dart';

/// Mixin handling subject CRUD actions and dialogs.
mixin SubjectActionsMixin on ConsumerState<AdminSubjectManagementScreen> {
  void showAddEditDialog({Map<String, dynamic>? subject}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectAddEditSheet(
        subject: subject,
        availableMasterSubjects: availableMasterSubjects,
        onSaved: loadSubjects,
      ),
    );
  }

  Future<void> deleteSubject(Map<String, dynamic> subject) async {
    final confirmed = await _showDeleteConfirm(subject);

    if (confirmed == true) {
      final ctrl = ref.read(adminSubjectControllerProvider);
      final errorMsg = await ctrl.deleteSubject(Subject.fromJson(subject).id);

      if (!mounted) return;
      _handleDeleteResult(errorMsg);
    }
  }

  Future<bool?> _showDeleteConfirm(Map<String, dynamic> subject) async {
    final lp = ref.read(languageRiverpod);
    final name = Subject.fromJson(subject).name;
    return ActionConfirmSheet.show(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Delete Subject',
        'id': 'Hapus Mata Pelajaran',
      }),
      message: lp.getTranslatedText({
        'en':
            'Are you sure you want to delete '
            'subject "$name"?',
        'id':
            'Yakin ingin menghapus mata '
            'pelajaran "$name"?',
      }),
      confirmText: lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
      isDestructive: true,
    );
  }

  void _handleDeleteResult(String? errorMsg) {
    final languageProvider = ref.read(languageRiverpod);
    final ctrl = ref.read(adminSubjectControllerProvider);

    if (errorMsg == null) {
      ctrl.showSuccessSnackBar(
        context,
        languageProvider.getTranslatedText({
          'en': 'Subject successfully deleted',
          'id': 'Mata pelajaran berhasil dihapus',
        }),
      );
      loadSubjects();
    } else {
      ctrl.showErrorSnackBar(
        context,
        '${languageProvider.getTranslatedText({'en': 'Failed to delete: ', 'id': 'Gagal menghapus: '})}$errorMsg',
      );
    }
  }

  void navigateToClassManagement(Map<String, dynamic> subject) {
    AppNavigator.push(context, SubjectClassManagementPage(subject: subject));
  }

  Future<void> exportToExcel() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.exportToExcel(subjects: subjectList, context: context);
  }

  Future<void> importFromExcel() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final languageProvider = ref.read(languageRiverpod);

    final errorMsg = await ctrl.importFromExcel();

    if (!mounted) return;

    if (errorMsg == null) {
      await loadSubjects();
      if (mounted) {
        ctrl.showSuccessSnackBar(
          context,
          languageProvider.getTranslatedText({
            'en': 'Subjects imported successfully',
            'id': 'Mata pelajaran berhasil diimpor',
          }),
        );
      }
    } else {
      ctrl.showErrorSnackBar(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to import file: $errorMsg',
          'id':
              '${AppLocalizations.failedToImport.tr}: '
              '$errorMsg',
        }),
      );
    }
  }

  Future<void> downloadTemplate() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.downloadTemplate(context);
  }

  // Abstract properties from data mixin
  List<dynamic> get subjectList;
  List<dynamic> get availableMasterSubjects;

  Future<void> loadSubjects({bool resetPage = true, bool useCache = true});
}
