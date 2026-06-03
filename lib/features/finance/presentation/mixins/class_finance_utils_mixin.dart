import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';

/// Utility methods for file handling and formatting.
mixin ClassFinanceUtilsMixin on State<ClassFinanceReportScreen> {
  /// Formats amount as Indonesian Rupiah currency.
  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final double value = double.parse(amount.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(value);
    } catch (e) {
      return 'Rp $amount';
    }
  }

  /// Gets human-readable file type text from file path.
  String getFileTypeText(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'Gambar JPEG';
      case 'png':
        return 'Gambar PNG';
      case 'pdf':
        return 'Dokumen PDF';
      default:
        return 'File $extension';
    }
  }

  /// Gets primary color for the screen.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Picks an image from gallery or camera.
  Future<void> pickImage(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();
      final source = await showImageSourceDialog();

      if (source != null) {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (file != null && context.mounted) {
          setDialogState(() {
            onImagePicked(File(file.path));
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<ImageSource?> showImageSourceDialog() async {
    return AppBottomSheet.show<ImageSource>(
      context: context,
      title: AppLocalizations.chooseSource.tr,
      subtitle: AppLocalizations.chooseImageSource.tr,
      icon: Icons.camera_alt_rounded,
      primaryColor: getPrimaryColor(),
      content: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: getPrimaryColor(),
              ),
              title: Text(AppLocalizations.gallery.tr),
              onTap: () => AppNavigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: getPrimaryColor(),
              ),
              title: Text(AppLocalizations.camera.tr),
              onTap: () => AppNavigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  /// Picks a PDF file.
  Future<void> pickPDF(StateSetter setDialogState) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setDialogState(() {
          onFilePicked(File(result.files.single.path!));
        });
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
    }
  }

  /// Shows file picker dialog.
  Future<void> pickFile(StateSetter setDialogState) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      title: AppLocalizations.chooseFileType.tr,
      subtitle: AppLocalizations.uploadPaymentProof.tr,
      icon: Icons.upload_file_rounded,
      primaryColor: getPrimaryColor(),
      content: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image_outlined, color: getPrimaryColor()),
              title: Text(AppLocalizations.imageCameraGallery.tr),
              onTap: () => AppNavigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: Icon(
                Icons.picture_as_pdf_outlined,
                color: getPrimaryColor(),
              ),
              title: Text(AppLocalizations.pdfDocument.tr),
              onTap: () => AppNavigator.pop(sheetContext, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (action == 'image') {
      await pickImage(setDialogState);
    } else if (action == 'pdf') {
      await pickPDF(setDialogState);
    }
  }

  /// Callback when image is picked - must be implemented by State.
  void onImagePicked(File file);

  /// Callback when file is picked - must be implemented by State.
  void onFilePicked(File file);
}
