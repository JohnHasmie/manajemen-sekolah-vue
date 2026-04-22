import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Mixin for dialog management (show and handle save).
mixin SchoolLevelDialogMixin {
  BuildContext get context;
  void setState(VoidCallback fn);
  Widget buildDialogHeader();
  Widget buildDialogFormFields({
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required List<String> jenjangOptions,
    required Function(String) onJenjangChanged,
  });
  Widget buildDialogFooter({
    required bool isSaving,
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required Function(bool) onSaving,
    required Function(String, String, String) onSaveSettings,
    required Function() onLoadSettings,
  });

  /// Shows a dialog to edit school info.
  /// Uses `StatefulBuilder` inside the dialog - like nested component with
  /// local state inside a modal.
  Future<void> showEditDialog({
    required String schoolName,
    required String schoolAddress,
    required String selectedJenjang,
    required List<String> jenjangOptions,
    required Function() onLoadSettings,
    required Function(String, String, String) onSaveSettings,
  }) async {
    final nameController = TextEditingController(text: schoolName);
    final addressController = TextEditingController(text: schoolAddress);
    String tempJenjang = selectedJenjang;

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildDialogHeader(),
                  buildDialogFormFields(
                    nameController: nameController,
                    addressController: addressController,
                    tempJenjang: tempJenjang,
                    jenjangOptions: jenjangOptions,
                    onJenjangChanged: (value) {
                      setDialogState(() => tempJenjang = value);
                    },
                  ),
                  buildDialogFooter(
                    isSaving: isSaving,
                    context: context,
                    nameController: nameController,
                    addressController: addressController,
                    tempJenjang: tempJenjang,
                    onSaving: (saving) {
                      setDialogState(() => isSaving = saving);
                    },
                    onSaveSettings: onSaveSettings,
                    onLoadSettings: onLoadSettings,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Handles the save button logic - called from builder mixin footer.
  Future<void> handleSaveAction({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required Function(bool) onSaving,
    required Function(String, String, String) onSaveSettings,
    required Function() onLoadSettings,
  }) async {
    final name = nameController.text.trim();
    if (name.length < 3) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nama sekolah minimal harus 3 karakter'),
          backgroundColor: ColorUtils.error600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    onSaving(true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await onSaveSettings(name, addressController.text.trim(), tempJenjang);

      if (!context.mounted) return;
      AppNavigator.pop(context);
      onLoadSettings();

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Pengaturan berhasil disimpan'),
          backgroundColor: ColorUtils.success600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.error('settings', e);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan: '
              '${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: ColorUtils.error600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        onSaving(false);
      }
    }
  }
}
