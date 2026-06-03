import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';

/// Mixin for navigation and back button logic.
mixin ReportCardNavMixin on ConsumerState<ReportCardDetailScreen> {
  Future<bool> onWillPop() async {
    if (!hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Perubahan Belum Disimpan'),
          content: const Text(
            'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin meninggalkan halaman ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, false),
              child: Text(AppLocalizations.cancel.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => AppNavigator.pop(context, true),
              child: const Text(
                'Tinggalkan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void handleBackButton() async {
    if (hasUnsavedChanges) {
      final canLeave = await onWillPop();
      if (!canLeave) return;
    }

    if (mounted) {
      AppNavigator.pop(context);
    }
  }

  Future<void> onPopInvoked(bool didPop, dynamic result) async {
    if (didPop) return;
    final canLeave = await onWillPop();
    if (canLeave && mounted) {
      AppNavigator.pop(context, result);
    }
  }

  // Abstract declarations for state
  bool get hasUnsavedChanges;
}
