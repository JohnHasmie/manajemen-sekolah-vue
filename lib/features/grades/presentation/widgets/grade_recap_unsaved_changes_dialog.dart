// Unsaved-changes confirmation dialog for the grade recap screen.
// Extracted from _GradeRecapPageState._onWillPop() so the main screen file
// stays under the line-count budget.
// Like a Vue `<UnsavedChangesModal>` component — purely presentational.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Shows an [AlertDialog] asking the user whether to discard unsaved changes.
///
/// Returns `true` if the user confirms leaving, `false` if they cancel.
/// Like a Vue `beforeRouteLeave` guard rendered as a dialog.
///
/// In Laravel terms: a "dirty-check" confirmation before navigating away.
Future<bool> showGradeRecapUnsavedChangesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final languageProvider = ref.read(languageRiverpod);
      return AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Unsaved Changes',
            'id': 'Perubahan Belum Disimpan',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'You have unsaved changes. Are you sure you want to leave? Your changes will be lost.',
            'id':
                'Anda memiliki perubahan yang belum disimpan. Yakin ingin keluar? Perubahan akan hilang.',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false), // Cancel
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => AppNavigator.pop(context, true), // Leave
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Leave',
                'id': 'Keluar',
              }),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
